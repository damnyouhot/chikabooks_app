/**
 * 기존 polls 문서에 displayOrder 백필
 *
 * - 이미 숫자 displayOrder 가 있으면 건너뜀
 * - 없으면: dayIndex → 문서 ID empathy_#### 순으로 유추
 * - 그래도 없으면 startsAt 오름차순으로 (기존 최대 order 초과) 연번 부여
 *
 * 자격·실행: polls-firestore-import.cjs 와 동일
 *   node tools/polls-displayorder-backfill.cjs
 *   POLL_DRY_RUN=1  (쓰기 없음)
 */

const path = require('path');
const fs = require('fs');
const admin = require(path.join(__dirname, '..', 'functions', 'node_modules', 'firebase-admin'));

function readDefaultProjectId(root) {
  try {
    const rc = JSON.parse(fs.readFileSync(path.join(root, '.firebaserc'), 'utf8'));
    return rc.projects?.default;
  } catch (_) {
    return undefined;
  }
}

function initFirebaseAdmin(root) {
  if (admin.apps.length) return;
  const projectId = readDefaultProjectId(root);
  const saEnv = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (saEnv) {
    const saPath = path.isAbsolute(saEnv) ? saEnv : path.join(root, saEnv);
    if (!fs.existsSync(saPath)) {
      throw new Error(`FIREBASE_SERVICE_ACCOUNT 파일을 찾을 수 없습니다: ${saPath}`);
    }
    const sa = JSON.parse(fs.readFileSync(saPath, 'utf8'));
    admin.initializeApp({
      credential: admin.credential.cert(sa),
      projectId: projectId || sa.project_id,
    });
    return;
  }
  admin.initializeApp(projectId ? { projectId } : undefined);
}

function inferOrder(docId, data) {
  if (typeof data.dayIndex === 'number' && Number.isFinite(data.dayIndex)) {
    return data.dayIndex;
  }
  const m = /^empathy_(\d+)$/.exec(docId);
  if (m) return parseInt(m[1], 10);
  return null;
}

async function main() {
  const root = path.join(__dirname, '..');
  const dry = process.env.POLL_DRY_RUN === '1';

  initFirebaseAdmin(root);
  const db = admin.firestore();

  const snap = await db.collection('polls').get();

  let maxOrder = 0;
  for (const doc of snap.docs) {
    const d = doc.data();
    const o = d.displayOrder;
    if (typeof o === 'number' && Number.isFinite(o) && o > maxOrder) maxOrder = o;
    const di = d.dayIndex;
    if (typeof di === 'number' && Number.isFinite(di) && di > maxOrder) maxOrder = di;
    const inf = inferOrder(doc.id, d);
    if (typeof inf === 'number' && inf > maxOrder) maxOrder = inf;
  }

  const pending = [];
  let skippedHasField = 0;

  for (const doc of snap.docs) {
    const d = doc.data();
    if (typeof d.displayOrder === 'number' && Number.isFinite(d.displayOrder)) {
      skippedHasField++;
      continue;
    }
    let order = inferOrder(doc.id, d);
    pending.push({
      ref: doc.ref,
      id: doc.id,
      order,
      startsAt: d.startsAt,
    });
  }

  const needSeq = pending.filter((p) => p.order == null);
  needSeq.sort((a, b) => {
    const ta = a.startsAt && a.startsAt.toMillis ? a.startsAt.toMillis() : 0;
    const tb = b.startsAt && b.startsAt.toMillis ? b.startsAt.toMillis() : 0;
    if (ta !== tb) return ta - tb;
    return String(a.id).localeCompare(String(b.id));
  });
  let seq = maxOrder;
  for (const row of needSeq) {
    row.order = ++seq;
  }

  console.log('총 polls:', snap.size);
  console.log('이미 displayOrder 보유 (스킵):', skippedHasField);
  console.log('백필 업데이트:', pending.length);

  if (dry) {
    console.log('DRY RUN — 미리보기 (최대 20건):');
    pending.slice(0, 20).forEach((p) => console.log(' ', p.id, '→', p.order));
    process.exit(0);
  }

  let batch = db.batch();
  let ops = 0;
  for (const p of pending) {
    batch.update(p.ref, { displayOrder: p.order });
    ops++;
    if (ops >= 450) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }
  if (ops > 0) await batch.commit();

  console.log('완료: displayOrder 설정', pending.length, '건');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
