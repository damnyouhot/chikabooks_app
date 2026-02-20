const admin = require('firebase-admin');
const crypto = require('crypto');

// Initialize Firebase Admin
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// 테스트 데이터
const testUpdates = [
  {
    title: '2026년 치과 임플란트 수가 변경 안내',
    link: 'https://www.hira.or.kr/test/implant-2026',
    publishedAt: new Date('2026-02-15'),
    topic: 'act',
    impactScore: 85,
    impactLevel: 'HIGH',
    keywords: ['치과', '임플란트', '수가'],
    actionHints: [
      '청구팀 확인 필요',
      '차트/기록 방식 변경 여부 확인',
      '치과 항목 영향 가능 (진료/상담 멘트 점검)',
    ],
  },
  {
    title: '치주질환 치료 급여 인정 기준 개정',
    link: 'https://www.hira.or.kr/test/periodontal-2026',
    publishedAt: new Date('2026-02-18'),
    topic: 'notice',
    impactScore: 70,
    impactLevel: 'HIGH',
    keywords: ['치과', '치주', '급여', '기준'],
    actionHints: [
      '청구팀 확인 필요',
      '차트/기록 방식 변경 여부 확인',
    ],
  },
  {
    title: '치과 스케일링 보험 적용 범위 확대',
    link: 'https://www.hira.or.kr/test/scaling-2026',
    publishedAt: new Date('2026-02-19'),
    topic: 'act',
    impactScore: 75,
    impactLevel: 'HIGH',
    keywords: ['치과', '스케일링', '보험'],
    actionHints: [
      '치과 항목 영향 가능 (진료/상담 멘트 점검)',
      '원문 링크로 핵심 문단만 확인',
    ],
  },
];

async function seedData() {
  try {
    console.log('🚀 HIRA 테스트 데이터 추가 시작...\n');

    const docIds = [];

    // 1. content_hira_updates에 데이터 추가
    for (const update of testUpdates) {
      const docId = crypto.createHash('sha1').update(update.link).digest('hex');
      docIds.push(docId);

      await db
        .collection('content_hira_updates')
        .doc(docId)
        .set({
          ...update,
          publishedAt: admin.firestore.Timestamp.fromDate(update.publishedAt),
          fetchedAt: admin.firestore.Timestamp.now(),
          commentCount: 0,
        });

      console.log(`✅ 추가됨: ${update.title}`);
      console.log(`   docId: ${docId}\n`);
    }

    // 2. 오늘 날짜로 digest 생성
    const today = new Date();
    const dateKey = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;

    await db
      .collection('content_hira_digest')
      .doc(dateKey)
      .set({
        topIds: docIds,
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    console.log(`✅ Digest 생성 완료: ${dateKey}`);
    console.log(`   포함된 항목: ${docIds.length}개\n`);

    console.log('🎉 모든 데이터 추가 완료!');
    console.log('\n📱 이제 앱에서 "급여변경" 탭을 확인하세요.');

    process.exit(0);
  } catch (error) {
    console.error('❌ 에러 발생:', error);
    process.exit(1);
  }
}

seedData();


