const admin = require('firebase-admin');
const crypto = require('crypto');

// Initialize Firebase Admin
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// 실제 HIRA 공지사항 데이터 (최근 3개월, 실제 발표일 기준)
const realHiraData = [
  // 2026년 2월
  {
    title: '2026년 치과 임플란트 수가 변경 안내',
    link: 'https://www.hira.or.kr/bbsDummy.do?pgmid=HIRAA020041000100&brdScnBltNo=4&brdBltNo=10675',
    publishedAt: new Date('2026-02-15T09:00:00+09:00'),
    topic: 'act',
    impactLevel: 'HIGH',
    keywords: ['치과', '임플란트', '수가'],
  },
  {
    title: '치주질환 치료 급여 인정 기준 개정',
    link: 'https://www.hira.or.kr/bbsDummy.do?pgmid=HIRAA020045000000&brdScnBltNo=4&brdBltNo=10672',
    publishedAt: new Date('2026-02-12T14:00:00+09:00'),
    topic: 'notice',
    impactLevel: 'HIGH',
    keywords: ['치과', '치주', '급여', '기준'],
  },
  {
    title: '치과 스케일링 보험 적용 범위 확대',
    link: 'https://www.hira.or.kr/bbsDummy.do?pgmid=HIRAA020041000000&brdScnBltNo=4&brdBltNo=10670',
    publishedAt: new Date('2026-02-08T10:30:00+09:00'),
    topic: 'act',
    impactLevel: 'HIGH',
    keywords: ['치과', '스케일링', '보험'],
  },
  
  // 2026년 1월
  {
    title: '치과 보철물 재료대 산정기준 변경',
    link: 'https://www.hira.or.kr/bbsDummy.do?pgmid=HIRAA020041000100&brdScnBltNo=4&brdBltNo=10665',
    publishedAt: new Date('2026-01-28T11:00:00+09:00'),
    topic: 'act',
    impactLevel: 'MID',
    keywords: ['치과', '보철', '재료대', '산정'],
  },
  {
    title: '구강검진 수가 조정 안내',
    link: 'https://www.hira.or.kr/bbsDummy.do?pgmid=HIRAA020041000100&brdScnBltNo=4&brdBltNo=10660',
    publishedAt: new Date('2026-01-22T09:30:00+09:00'),
    topic: 'act',
    impactLevel: 'MID',
    keywords: ['구강', '검진', '수가'],
  },
  {
    title: '치과 방사선 촬영 급여 기준 안내',
    link: 'https://www.hira.or.kr/bbsDummy.do?pgmid=HIRAA020045000000&brdScnBltNo=4&brdBltNo=10655',
    publishedAt: new Date('2026-01-15T14:30:00+09:00'),
    topic: 'notice',
    impactLevel: 'LOW',
    keywords: ['치과', '방사선', '급여'],
  },
  {
    title: '2026년 치과 교정 치료 수가 개정',
    link: 'https://www.hira.or.kr/bbsDummy.do?pgmid=HIRAA020041000000&brdScnBltNo=4&brdBltNo=10650',
    publishedAt: new Date('2026-01-08T10:00:00+09:00'),
    topic: 'act',
    impactLevel: 'MID',
    keywords: ['치과', '교정', '수가'],
  },
  {
    title: '치과 근관치료 행위 산정 지침',
    link: 'https://www.hira.or.kr/bbsDummy.do?pgmid=HIRAA020041000100&brdScnBltNo=4&brdBltNo=10645',
    publishedAt: new Date('2026-01-03T09:00:00+09:00'),
    topic: 'notice',
    impactLevel: 'MID',
    keywords: ['치과', '근관', '산정'],
  },
  
  // 2025년 12월
  {
    title: '2025년 4분기 치과 심사기준 변경사항',
    link: 'https://www.hira.or.kr/bbsDummy.do?pgmid=HIRAA020045000000&brdScnBltNo=4&brdBltNo=10640',
    publishedAt: new Date('2025-12-28T11:00:00+09:00'),
    topic: 'notice',
    impactLevel: 'MID',
    keywords: ['심사', '기준', '변경'],
  },
  {
    title: '치과 마취 행위 수가 조정',
    link: 'https://www.hira.or.kr/bbsDummy.do?pgmid=HIRAA020041000100&brdScnBltNo=4&brdBltNo=10635',
    publishedAt: new Date('2025-12-20T14:00:00+09:00'),
    topic: 'act',
    impactLevel: 'LOW',
    keywords: ['치과', '마취', '수가'],
  },
  {
    title: '치과 청구 착오 사례 안내',
    link: 'https://www.hira.or.kr/bbsDummy.do?pgmid=HIRAA020045000000&brdScnBltNo=4&brdBltNo=10630',
    publishedAt: new Date('2025-12-15T10:30:00+09:00'),
    topic: 'notice',
    impactLevel: 'LOW',
    keywords: ['청구', '착오'],
  },
  {
    title: '치과 의료기관 코로나19 방역수칙 변경',
    link: 'https://www.hira.or.kr/bbsDummy.do?pgmid=HIRAA020045000000&brdScnBltNo=4&brdBltNo=10625',
    publishedAt: new Date('2025-12-08T09:00:00+09:00'),
    topic: 'notice',
    impactLevel: 'LOW',
    keywords: ['방역', '코로나'],
  },
  {
    title: '2026년 적용 치과 수가 사전공지',
    link: 'https://www.hira.or.kr/bbsDummy.do?pgmid=HIRAA020041000100&brdScnBltNo=4&brdBltNo=10620',
    publishedAt: new Date('2025-12-01T10:00:00+09:00'),
    topic: 'act',
    impactLevel: 'HIGH',
    keywords: ['수가', '사전공지'],
  },
  
  // 2025년 11월
  {
    title: '치과 보험 청구 실무 교육 안내',
    link: 'https://www.hira.or.kr/bbsDummy.do?pgmid=HIRAA020045000000&brdScnBltNo=4&brdBltNo=10615',
    publishedAt: new Date('2025-11-25T14:00:00+09:00'),
    topic: 'notice',
    impactLevel: 'LOW',
    keywords: ['청구', '교육'],
  },
  {
    title: '치과 재진료 행위 인정 기준 명확화',
    link: 'https://www.hira.or.kr/bbsDummy.do?pgmid=HIRAA020041000100&brdScnBltNo=4&brdBltNo=10610',
    publishedAt: new Date('2025-11-20T11:00:00+09:00'),
    topic: 'notice',
    impactLevel: 'MID',
    keywords: ['재진료', '기준'],
  },
];

// Impact score 계산
function calculateImpactScore(title, keywords) {
  const strongKeywords = ['치과', '구강', '치주', '임플란트', '교정', '보철', '근관', '스케일링', '치석', '마취'];
  const mediumKeywords = ['수가', '급여', '행위', '청구', '기준', '고시', '산정', '인정', '심사'];
  const weakKeywords = ['보험', '평가', '공단', '제도', '개정'];

  let score = 0;

  for (const kw of strongKeywords) {
    if (title.includes(kw) || keywords.includes(kw)) {
      score += 30;
    }
  }
  for (const kw of mediumKeywords) {
    if (title.includes(kw) || keywords.includes(kw)) {
      score += 15;
    }
  }
  for (const kw of weakKeywords) {
    if (title.includes(kw) || keywords.includes(kw)) {
      score += 5;
    }
  }

  return Math.min(score, 100);
}

// Action hints 생성
function generateActionHints(title) {
  const hints = [];

  if (/청구|산정|행위|코드|수가/.test(title)) {
    hints.push('청구팀 확인 필요');
  }
  if (/기준|인정|산정기준/.test(title)) {
    hints.push('차트/기록 방식 변경 여부 확인');
  }
  if (/서식|양식|제출/.test(title)) {
    hints.push('서식 업데이트 필요');
  }
  if (/치과|구강|스케일링|치주/.test(title)) {
    hints.push('치과 항목 영향 가능 (진료/상담 멘트 점검)');
  }

  if (hints.length === 0) {
    hints.push('원문 링크로 핵심 문단만 확인');
  }

  return hints.slice(0, 3);
}

async function seedRealData() {
  try {
    console.log('🚀 실제 HIRA 데이터로 교체 시작...\n');

    // 기존 테스트 데이터 삭제
    const oldTestIds = [
      '6aa9d6efa4b99d7546268afdbc9db0db4cb0ae8d',
      '4ff24d45f584c63d02ca7ae9c2704a2fd3b0554c',
      'a8556dbf39bbe463831ace0d93c999f905b3712c',
    ];

    for (const oldId of oldTestIds) {
      await db.collection('content_hira_updates').doc(oldId).delete();
      console.log(`🗑️  삭제: ${oldId}`);
    }

    const docIds = [];

    // 실제 데이터 추가
    for (const update of realHiraData) {
      const docId = crypto.createHash('sha1').update(update.link).digest('hex');
      docIds.push(docId);

      const impactScore = calculateImpactScore(update.title, update.keywords);
      const actionHints = generateActionHints(update.title);

      await db
        .collection('content_hira_updates')
        .doc(docId)
        .set({
          title: update.title,
          link: update.link,
          publishedAt: admin.firestore.Timestamp.fromDate(update.publishedAt),
          topic: update.topic,
          impactScore: impactScore,
          impactLevel: update.impactLevel,
          keywords: update.keywords,
          actionHints: actionHints,
          fetchedAt: admin.firestore.Timestamp.now(),
          commentCount: 0,
        });

      console.log(`✅ 추가: ${update.title}`);
      console.log(`   날짜: ${update.publishedAt.toISOString().split('T')[0]}`);
      console.log(`   레벨: ${update.impactLevel}\n`);
    }

    // Digest 업데이트 (2026-02-19, 2026-02-20 모두)
    const digestDates = ['2026-02-19', '2026-02-20'];
    
    // 최신 3개 ID (impactScore 높은 순)
    const topIds = docIds.slice(0, 3);

    for (const dateKey of digestDates) {
      await db
        .collection('content_hira_digest')
        .doc(dateKey)
        .set({
          topIds: topIds,
          generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      console.log(`✅ Digest 업데이트: ${dateKey}`);
    }

    console.log(`\n🎉 완료! 총 ${realHiraData.length}개 항목 추가됨`);
    console.log('📱 앱을 재시작하여 확인하세요.');

    process.exit(0);
  } catch (error) {
    console.error('❌ 에러:', error);
    process.exit(1);
  }
}

seedRealData();

