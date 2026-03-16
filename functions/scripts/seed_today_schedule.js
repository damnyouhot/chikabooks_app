/**
 * 오늘 날짜의 quiz_schedule을 수동으로 생성합니다.
 * pickTodayQuizzes 로직과 동일 — 각 책에서 1문제씩 랜덤 선정
 *
 * 실행: node scripts/seed_today_schedule.js [YYYY-MM-DD]
 */

const admin = require('firebase-admin');
const path  = require('path');

const serviceAccount = require(path.join(__dirname, '..', '..', 'tools', 'serviceAccountKey.json'));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

function shuffleArray(arr) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

async function main() {
  // KST 기준 오늘 날짜 (UTC+9)
  const nowKst  = new Date(Date.now() + 9 * 60 * 60 * 1000);
  const dateKey = process.argv[2] ?? nowKst.toISOString().slice(0, 10);
  console.log(`📅 날짜: ${dateKey}`);

  const scheduleRef = db.collection('quiz_schedule').doc(dateKey);
  const metaRef     = db.doc('quiz_meta/state');

  // 이미 있으면 덮어쓰기 (강제)
  const exists = await scheduleRef.get();
  if (exists.exists) {
    console.log('⚠️  이미 스케줄 존재 — 덮어씁니다');
  }

  const metaDoc = await metaRef.get();
  const meta    = metaDoc.exists ? metaDoc.data() : {};
  const usedIds = meta.usedQuizIds ?? [];
  const cycle   = meta.cycleCount  ?? 1;
  const bookRotation = meta.bookRotation ?? ['임플란트_초보탈출', '보철과'];

  // 전체 풀 조회
  const poolSnap = await db.collection('quiz_pool').where('isActive', '==', true).get();
  const allDocs  = poolSnap.docs;

  // 책 목록
  const bookSet = new Set(allDocs.map((d) => d.data().sourceBook));
  const books   = bookRotation.filter((b) => bookSet.has(b));
  bookSet.forEach((b) => { if (!books.includes(b)) books.push(b); });

  // 각 책별 미출제 문제
  const unusedByBook = {};
  for (const book of books) {
    unusedByBook[book] = shuffleArray(
      allDocs.filter((d) => d.data().sourceBook === book && !usedIds.includes(d.id))
    );
  }

  // 서로 다른 책에서 1문제씩
  const shuffledBooks = shuffleArray(books);
  const selected = [];
  for (const book of shuffledBooks) {
    if (selected.length >= 2) break;
    if (unusedByBook[book]?.length > 0) selected.push(unusedByBook[book][0]);
  }

  let nextCycle = cycle;
  let nextUsed  = [...usedIds];
  let wasReset  = false;

  if (selected.length < 2) {
    console.log('🔄 풀 소진 → 사이클 증가');
    nextCycle++;
    nextUsed  = [];
    wasReset  = true;
    selected.splice(0);
    for (const book of shuffleArray(books)) {
      if (selected.length >= 2) break;
      const c = shuffleArray(allDocs.filter((d) => d.data().sourceBook === book));
      if (c.length > 0) selected.push(c[0]);
    }
  }

  nextUsed = [...new Set([...nextUsed, ...selected.map((d) => d.id)])];

  const quizIds = selected.map((d) => d.id);
  const items   = selected.map((d) => ({
    id:             d.id,
    order:          d.data().order          ?? 0,
    question:       d.data().question       ?? '',
    options:        d.data().options        ?? [],
    correctIndex:   d.data().correctIndex   ?? 0,
    explanation:    d.data().explanation    ?? '',
    category:       d.data().category       ?? '',
    difficulty:     d.data().difficulty     ?? 'basic',
    sourceBook:     d.data().sourceBook     ?? '',
    sourceFileName: d.data().sourceFileName ?? '',
    sourcePage:     d.data().sourcePage     ?? '',
    isActive:       true,
    lastCycleServed: nextCycle,
  }));

  await scheduleRef.set({
    quizIds,
    items,
    cycleCount:  nextCycle,
    startOrder:  items[0]?.order ?? 0,
    endOrder:    items[items.length - 1]?.order ?? 0,
    createdAt:   admin.firestore.FieldValue.serverTimestamp(),
  });

  const batch = db.batch();
  for (const doc of selected) {
    batch.update(doc.ref, {
      lastCycleServed: nextCycle,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();

  await metaRef.set({
    cycleCount:        nextCycle,
    totalActiveCount:  allDocs.length,
    lastScheduledDate: dateKey,
    dailyCount:        2,
    usedQuizIds:       nextUsed,
    bookRotation,
  }, { merge: true });

  console.log('\n═══════════════════════════════════════');
  console.log(`✅ ${dateKey} 스케줄 생성 완료!`);
  console.log(`   사이클 초기화: ${wasReset}`);
  items.forEach((item, i) => {
    console.log(`\n   [Q${i + 1}] (${item.sourceBook} p.${item.sourcePage})`);
    console.log(`   ${item.question}`);
    console.log(`   정답: ${item.options[item.correctIndex]}`);
  });
  console.log('═══════════════════════════════════════');

  process.exit(0);
}

main().catch((e) => { console.error('❌', e); process.exit(1); });

