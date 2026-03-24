/**
 * 공감투표.xlsx → Firestore polls + options 일괄 반영
 *
 * 사전: 아래 중 하나
 *   - FIREBASE_SERVICE_ACCOUNT=절대경로\서비스계정.json (권장, Firebase 콘솔 → 서비스 계정 → 키)
 *   - GOOGLE_APPLICATION_CREDENTIALS (서비스 계정 JSON 경로)
 *   - gcloud auth application-default login
 * 실행: node tools/polls-firestore-import.cjs
 *        또는: cd functions && npm run polls-import
 *
 * 환경변수 (선택):
 *   POLL_XLSX_PATH       기본: tools/공감투표.xlsx
 *   POLL_PROGRAM_START   1번 투표(엑셀 A열 1)가 시작되는 날, KST 기준 YYYY-MM-DD. 미설정 시 "오늘(서울)"
 *   POLL_DRY_RUN         1 이면 삭제/쓰기 없이 파싱·일정 요약만 출력
 *
 * 일정: A열 n번 → 프로그램 시작일로부터 (n-1)일째 KST 자정~23:59:59 한 판.
 *       과거 일 → status closed, 미래 → scheduled, 오늘 → active.
 */

const path = require('path');
const fs = require('fs');
const admin = require(path.join(__dirname, '..', 'functions', 'node_modules', 'firebase-admin'));
const XLSX = require(path.join(__dirname, '..', 'functions', 'node_modules', 'xlsx'));

const POLL_ID_PREFIX = 'empathy_';

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
    if (sa.type !== 'service_account') {
      throw new Error('FIREBASE_SERVICE_ACCOUNT 는 type이 service_account 인 JSON 이어야 합니다.');
    }
    admin.initializeApp({
      credential: admin.credential.cert(sa),
      projectId: projectId || sa.project_id,
    });
    return;
  }

  admin.initializeApp(projectId ? { projectId } : undefined);
}

function seoulYmd() {
  const fmt = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Seoul',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  const parts = Object.fromEntries(
    fmt.formatToParts(new Date()).map((p) => [p.type, p.value])
  );
  return { y: Number(parts.year), m: Number(parts.month), d: Number(parts.day) };
}

function parseProgramStartKst() {
  const env = process.env.POLL_PROGRAM_START;
  if (env && /^\d{4}-\d{1,2}-\d{1,2}$/.test(env.trim())) {
    const [y, mo, da] = env.trim().split('-').map((x) => Number(x));
    return { y, m: mo, d: da };
  }
  return seoulYmd();
}

function kstYmdFromInstant(date) {
  const fmt = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Seoul',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  const parts = Object.fromEntries(fmt.formatToParts(date).map((p) => [p.type, p.value]));
  return { y: Number(parts.year), m: Number(parts.month), d: Number(parts.day) };
}

/** 해당 KST 달력일의 00:00 ~ 23:59:59.999 (로컬 Date) */
function kstDayBounds(y, m, d) {
  const ys = String(y);
  const ms = String(m).padStart(2, '0');
  const ds = String(d).padStart(2, '0');
  return {
    start: new Date(`${ys}-${ms}-${ds}T00:00:00+09:00`),
    end: new Date(`${ys}-${ms}-${ds}T23:59:59.999+09:00`),
  };
}

function programAnchorNoon({ y, m, d }) {
  return new Date(
    `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}T12:00:00+09:00`
  );
}

async function deleteCollectionDocs(ref) {
  const snap = await ref.get();
  for (const doc of snap.docs) {
    await doc.ref.delete();
  }
}

async function deletePollSubtree(db, pollId) {
  const pollRef = db.collection('polls').doc(pollId);
  const optionsSnap = await pollRef.collection('options').get();
  for (const opt of optionsSnap.docs) {
    const reportsSnap = await opt.ref.collection('reports').get();
    for (const r of reportsSnap.docs) {
      await r.ref.delete();
    }
    await opt.ref.delete();
  }
  await deleteCollectionDocs(pollRef.collection('votes'));
  await deleteCollectionDocs(pollRef.collection('pollComments'));
  await pollRef.delete();
}

function parseRows(xlsxPath) {
  const wb = XLSX.readFile(xlsxPath);
  const sheet = wb.Sheets[wb.SheetNames[0]];
  const rows = XLSX.utils.sheet_to_json(sheet, { header: 1, defval: '' });
  if (rows.length < 3) {
    throw new Error('시트에 데이터가 없습니다.');
  }
  const header = rows[1];
  const col = {
    seq: 0,
    summary: 1,
    question: 2,
    opt1: 3,
    opt2: 4,
    opt3: 5,
  };
  const out = [];
  for (let i = 2; i < rows.length; i++) {
    const r = rows[i];
    const question = String(r[col.question] ?? '').trim();
    if (!question) continue;
    const seq = Number(r[col.seq]);
    const summary = String(r[col.summary] ?? '').trim();
    const options = [r[col.opt1], r[col.opt2], r[col.opt3]]
      .map((c) => String(c ?? '').trim())
      .filter(Boolean);
    if (options.length === 0) {
      console.warn(`행 ${i + 1}: 보기 없음, 스킵`);
      continue;
    }
    out.push({
      excelRow: i + 1,
      seq: Number.isFinite(seq) ? seq : out.length + 1,
      category: summary,
      question,
      options,
    });
  }
  return { header, polls: out };
}

async function main() {
  const root = path.join(__dirname, '..');
  const xlsxPath = process.env.POLL_XLSX_PATH
    ? path.isAbsolute(process.env.POLL_XLSX_PATH)
      ? process.env.POLL_XLSX_PATH
      : path.join(root, process.env.POLL_XLSX_PATH)
    : path.join(__dirname, '공감투표.xlsx');

  if (!fs.existsSync(xlsxPath)) {
    console.error('엑셀 파일이 없습니다:', xlsxPath);
    process.exit(1);
  }

  const dry = process.env.POLL_DRY_RUN === '1';
  const { polls } = parseRows(xlsxPath);
  const programStart = parseProgramStartKst();
  const anchor = programAnchorNoon(programStart);
  const nowMs = Date.now();

  console.log('파싱된 투표 수:', polls.length);
  console.log(
    '프로그램 1일차(KST):',
    `${programStart.y}-${String(programStart.m).padStart(2, '0')}-${String(programStart.d).padStart(2, '0')}`
  );

  let dryOpenSeq = null;
  let dryClosed = 0;
  let dryFuture = 0;
  for (const p of polls) {
    const noon = new Date(anchor.getTime() + (p.seq - 1) * 86400000);
    const { y, m, d } = kstYmdFromInstant(noon);
    const { start, end } = kstDayBounds(y, m, d);
    if (end.getTime() < nowMs) dryClosed++;
    else if (start.getTime() <= nowMs) {
      dryOpenSeq = p.seq;
    } else dryFuture++;
  }
  console.log(
    '현재 시각 기준 — 진행 중 A열 번호:',
    dryOpenSeq ?? '(없음)',
    '| 종료만',
    dryClosed,
    '| 예정',
    dryFuture
  );

  if (dry) {
    const open = dryOpenSeq != null ? polls.find((x) => x.seq === dryOpenSeq) : null;
    console.log('DRY RUN — 오늘의 투표 예시:', open ? open.question.slice(0, 60) + '…' : '없음');
    process.exit(0);
  }

  initFirebaseAdmin(root);
  const db = admin.firestore();

  const existingSnap = await db.collection('polls').get();
  console.log('기존 polls 문서 삭제 중…', existingSnap.size);
  for (const doc of existingSnap.docs) {
    await deletePollSubtree(db, doc.id);
  }

  let batch = db.batch();
  let ops = 0;

  const commitBatch = async () => {
    if (ops === 0) return;
    await batch.commit();
    batch = db.batch();
    ops = 0;
  };

  const nowMs2 = Date.now();

  for (const p of polls) {
    const writesThisPoll = 1 + p.options.length;
    if (ops + writesThisPoll > 400) {
      await commitBatch();
    }

    const pollId = `${POLL_ID_PREFIX}${String(p.seq).padStart(4, '0')}`;
    const pollRef = db.collection('polls').doc(pollId);

    const noon = new Date(anchor.getTime() + (p.seq - 1) * 86400000);
    const { y, m, d } = kstYmdFromInstant(noon);
    const { start, end } = kstDayBounds(y, m, d);

    let status;
    let closedAt = null;
    if (end.getTime() < nowMs2) {
      status = 'closed';
      closedAt = admin.firestore.Timestamp.fromDate(end);
    } else if (start.getTime() <= nowMs2) {
      status = 'active';
    } else {
      status = 'scheduled';
    }

    batch.set(pollRef, {
      question: p.question,
      status,
      startsAt: admin.firestore.Timestamp.fromDate(start),
      endsAt: admin.firestore.Timestamp.fromDate(end),
      ...(closedAt ? { closedAt } : {}),
      dayIndex: p.seq,
      totalEmpathyCount: 0,
      category: p.category,
    });
    ops++;

    p.options.forEach((text, idx) => {
      const optId = `sys_${idx + 1}`;
      const optRef = pollRef.collection('options').doc(optId);
      batch.set(optRef, {
        content: text,
        authorUid: null,
        isSystem: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        empathyCount: 0,
        reportCount: 0,
        isHidden: false,
      });
      ops++;
    });
  }

  await commitBatch();

  const cfgRef = db.collection('config').doc('poll_program');
  await cfgRef.set(
    {
      programStartKst: `${programStart.y}-${String(programStart.m).padStart(2, '0')}-${String(programStart.d).padStart(2, '0')}`,
      pollCount: polls.length,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  const last = polls[polls.length - 1];
  const lastNoon = new Date(anchor.getTime() + (last.seq - 1) * 86400000);
  const lastYmd = kstYmdFromInstant(lastNoon);
  console.log('완료: polls', polls.length, '개. 마지막 투표 KST일:', `${lastYmd.y}/${lastYmd.m}/${lastYmd.d}`);
}

main().catch((e) => {
  const msg = e && e.message ? String(e.message) : '';
  if (msg.includes('Could not load the default credentials')) {
    const pid = readDefaultProjectId(path.join(__dirname, '..'));
    console.error(`
[자격 증명 없음] Firestore에 쓰려면 서비스 계정 JSON이 필요합니다.

1) Firebase 콘솔 → 프로젝트 설정 → 서비스 계정 → "새 비공개 키 생성" → JSON 저장
2) PowerShell 예시:
   $env:FIREBASE_SERVICE_ACCOUNT="C:\\Users\\이름\\Downloads\\chikabooks3rd-xxxxx.json"
   node tools/polls-firestore-import.cjs

또는: gcloud auth application-default login

대상 프로젝트(.firebaserc): ${pid || '확인 필요'}
`);
  }
  console.error(e);
  process.exit(1);
});
