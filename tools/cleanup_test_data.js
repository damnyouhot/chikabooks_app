/**
 * cleanup_test_data.js
 *
 * 관리자 계정(ADMIN_UID) 한 명만 남기고
 * 아래 데이터를 모두 삭제합니다:
 *
 *   1. users/{uid}               (관리자 제외)
 *   2. users/{uid}/notes/*       (관리자 제외)
 *   3. activityLogs              (관리자 uid 로그 제외)
 *   4. analytics_daily/*         (전체 — 일별 집계 초기화)
 *
 * 실행:
 *   cd tools
 *   node cleanup_test_data.js
 */

const admin = require('firebase-admin');
const path = require('path');

const serviceAccount = require(path.join(__dirname, 'serviceAccountKey.json'));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const ADMIN_UID = 'rJ0MnNcwChMBPobjUc3Gpfs5ysx2';
const BATCH_SIZE = 400; // Firestore 배치 최대 500 미만

/** 배열을 chunk 단위로 나누기 */
function chunk(arr, size) {
  const result = [];
  for (let i = 0; i < arr.length; i += size) {
    result.push(arr.slice(i, i + size));
  }
  return result;
}

/** 문서 배열을 배치 삭제 */
async function deleteInBatches(docs, label) {
  if (docs.length === 0) {
    console.log(`  ✅ ${label}: 삭제 대상 없음`);
    return 0;
  }
  const chunks = chunk(docs, BATCH_SIZE);
  let total = 0;
  for (const c of chunks) {
    const batch = db.batch();
    for (const doc of c) batch.delete(doc.ref);
    await batch.commit();
    total += c.length;
    console.log(`  🗑️  ${label}: ${total}/${docs.length} 삭제 완료`);
  }
  return total;
}

async function main() {
  console.log('========================================');
  console.log(' 치카북스 테스트 데이터 초기화 스크립트');
  console.log(`  관리자 UID 보존: ${ADMIN_UID}`);
  console.log('========================================\n');

  // ─── 1. 삭제 대상 users 목록 확보 ───────────────────────────
  console.log('[1/4] users 컬렉션 조회 중...');
  const usersSnap = await db.collection('users').get();
  const usersToDelete = usersSnap.docs.filter(d => d.id !== ADMIN_UID);
  const uidsToDelete = usersToDelete.map(d => d.id);
  console.log(`  전체 유저: ${usersSnap.size}명, 삭제 대상: ${uidsToDelete.length}명`);

  if (uidsToDelete.length === 0) {
    console.log('  ✅ 삭제할 유저 없음, 종료');
    process.exit(0);
  }

  // ─── 2. users/{uid}/notes 서브컬렉션 삭제 ───────────────────
  console.log('\n[2/4] notes 서브컬렉션 삭제 중...');
  let notesTotal = 0;
  for (const uid of uidsToDelete) {
    const notesSnap = await db
      .collection('users').doc(uid)
      .collection('notes').get();
    if (notesSnap.size > 0) {
      await deleteInBatches(notesSnap.docs, `users/${uid}/notes`);
      notesTotal += notesSnap.size;
    }
  }
  console.log(`  → notes 총 ${notesTotal}건 삭제`);

  // ─── 3. users 문서 삭제 ──────────────────────────────────────
  console.log('\n[3/4] users 문서 삭제 중...');
  await deleteInBatches(usersToDelete, 'users');

  // ─── 4. activityLogs 삭제 (관리자 uid 제외) ─────────────────
  console.log('\n[4/4-a] activityLogs 삭제 중 (관리자 제외)...');
  // activityLogs 건수가 많을 수 있으므로 limit 반복으로 처리
  let logsDeleted = 0;
  while (true) {
    const snap = await db.collection('activityLogs').limit(BATCH_SIZE).get();
    if (snap.empty) break;

    const toDelete = snap.docs.filter(d => {
      const uid = d.data().userId;
      return uid !== ADMIN_UID;
    });

    if (toDelete.length === 0 && snap.docs.length < BATCH_SIZE) break;
    if (toDelete.length === 0) {
      // 이 배치가 모두 관리자 로그인 경우 → 더 이상 없음
      break;
    }

    const batch = db.batch();
    for (const doc of toDelete) batch.delete(doc.ref);
    await batch.commit();
    logsDeleted += toDelete.length;
    console.log(`  🗑️  activityLogs: ${logsDeleted}건 삭제 중...`);
  }
  console.log(`  → activityLogs 총 ${logsDeleted}건 삭제`);

  // ─── 5. analytics_daily 전체 삭제 ───────────────────────────
  console.log('\n[4/4-b] analytics_daily 전체 삭제 중...');
  const dailySnap = await db.collection('analytics_daily').get();
  await deleteInBatches(dailySnap.docs, 'analytics_daily');

  console.log('\n========================================');
  console.log(' ✅ 초기화 완료');
  console.log(`  - 삭제된 유저:          ${uidsToDelete.length}명`);
  console.log(`  - 삭제된 notes:         ${notesTotal}건`);
  console.log(`  - 삭제된 activityLogs:  ${logsDeleted}건`);
  console.log(`  - 삭제된 analytics_daily: ${dailySnap.size}건`);
  console.log('  - 보존된 관리자 UID:    ' + ADMIN_UID);
  console.log('========================================');
  process.exit(0);
}

main().catch(err => {
  console.error('❌ 오류 발생:', err);
  process.exit(1);
});
