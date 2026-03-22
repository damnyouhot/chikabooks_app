/**
 * quiz_meta/state 를 실제 quiz_pool·quiz_schedule 과 맞춥니다.
 *
 * 기본: 활성 풀 개수 → totalActiveCount 만 merge (대시보드 "전체 문제")
 * --rebuild-used: 현재 meta.cycleCount 와 같은 quiz_schedule 문서들의
 *                 quizIds 를 합쳐 usedQuizIds 재구성 ("이번 사이클 배포")
 *
 * 실행 (프로젝트 루트에서):
 *   cd functions && node scripts/sync_quiz_meta_from_pool.js
 *   cd functions && node scripts/sync_quiz_meta_from_pool.js --rebuild-used
 *
 * 사전: tools/serviceAccountKey.json (기존 시드 스크립트와 동일)
 */

const admin = require('firebase-admin');
const path = require('path');

const serviceAccount = require(path.join(__dirname, '..', '..', 'tools', 'serviceAccountKey.json'));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

async function main() {
  const rebuildUsed = process.argv.includes('--rebuild-used');

  const poolSnap = await db.collection('quiz_pool').where('isActive', '==', true).get();
  const totalActive = poolSnap.size;

  const metaRef = db.doc('quiz_meta/state');
  const metaDoc = await metaRef.get();
  const meta = metaDoc.exists ? metaDoc.data() : {};
  const cycleCount = (meta.cycleCount ?? 1) | 0;
  const dailyCount = meta.dailyCount ?? 2;

  const patch = {
    totalActiveCount: totalActive,
  };

  if (rebuildUsed) {
    const schedSnap = await db.collection('quiz_schedule').get();
    const idSet = new Set();
    let maxDateKey = meta.lastScheduledDate || '';

    for (const d of schedSnap.docs) {
      const data = d.data();
      const c = (data.cycleCount ?? 1) | 0;
      if (c !== cycleCount) continue;

      const ids = data.quizIds || [];
      ids.forEach((id) => {
        if (typeof id === 'string' && id.length) idSet.add(id);
      });

      const key = d.id;
      if (/^\d{4}-\d{2}-\d{2}$/.test(key) && key > maxDateKey) maxDateKey = key;
    }

    patch.usedQuizIds = Array.from(idSet);
    if (maxDateKey) patch.lastScheduledDate = maxDateKey;

    console.log(`🔄 usedQuizIds 재구성: 사이클 ${cycleCount}, 고유 ID ${idSet.size}개`);
  }

  await metaRef.set(patch, { merge: true });

  console.log('═══════════════════════════════════════');
  console.log(`✅ quiz_meta/state 동기화 완료`);
  console.log(`   totalActiveCount: ${totalActive}`);
  if (rebuildUsed) {
    console.log(`   usedQuizIds.length: ${patch.usedQuizIds.length}`);
    console.log(`   lastScheduledDate: ${patch.lastScheduledDate || '(유지)'}`);
  }
  console.log('═══════════════════════════════════════');

  process.exit(0);
}

main().catch((e) => {
  console.error('❌', e);
  process.exit(1);
});
