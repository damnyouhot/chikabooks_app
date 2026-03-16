/**
 * 수술 후 주의사항 심화 30문항 추가 스크립트
 *
 * 실행:
 *   cd functions
 *   node scripts/add_postop_quizzes.js
 */

const admin = require('firebase-admin');
const path = require('path');

const serviceAccount = require(path.join(__dirname, '..', '..', 'tools', 'serviceAccountKey.json'));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const POSTOP_BOOK = '수술후_주의사항';
const POSTOP_FILE = '치과책방_수술_후_주의사항.pdf';

const postopQuizzes = [
  { question: '거즈를 생리식염수에 적셔주는 이유', options: ['혈관 수축','혈병 유착','세균 억제','상처 냉각'], correctIndex:1, explanation:'혈병이 함께 뜯겨 재출혈을 막기 위해.', sourcePage:'7' },
  { question: '침을 뱉지 말고 삼키는 이유', options: ['음압 방지','응고 인자 유지','온도','타액 살균'], correctIndex:0, explanation:'음압이 혈병을 떼어낼 수 있음.', sourcePage:'6' },
  { question: '건성 발치 특징', options: ['즉시','혈병 탈락','항생제','잇몸 증식'], correctIndex:1, explanation:'혈병 조기 탈락으로 뼈 노출.', sourcePage:'10' },
  { question: '피임약과 건성 발치', options: ['혈소판','섬유소 용해','투과성','각화'], correctIndex:1, explanation:'Estrogen이 플라스민 활성 높여.', sourcePage:'11' },
  { question: '봉합 주요 기능', options: ['골재생','혈병 보호','신경 회복','타액'], correctIndex:1, explanation:'혈병 탈락 방지하며 창상 닫음.', sourcePage:'12' },
  { question: '흡수성 지혈제 기간', options: ['1-2일','1-2주','2-6주','6개월'], correctIndex:2, explanation:'보통 2~6주 내 흡수.', sourcePage:'13' },
  { question: '상악 구치 코피 이유', options: ['비강 연결','하악관','설하선','안면신경'], correctIndex:0, explanation:'상악동과 연결되고 미세혈관 자극.', sourcePage:'15' },
  { question: 'FGG 후 이식부 하얀색', options: ['농양','괴사','각화','혈관 수축'], correctIndex:1, explanation:'초기 상피 괴사 후 회복.', sourcePage:'17' },
  { question: 'CTG vs FGG 이점', options: ['통증','색조','시간','각화'], correctIndex:1, explanation:'색조 일치 뛰어남.', sourcePage:'18' },
  { question: 'COE-PACK 유지', options: ['습윤','건조','뜨거운','조기 칫솔'], correctIndex:1, explanation:'건조 상태에서 부착력 높음.', sourcePage:'19' },
  { question: '냉찜질 48h 목적', options: ['확장','수축','신경','육아'], correctIndex:1, explanation:'혈관 수축해 부종 감소.', sourcePage:'20' },
  { question: '부종 발생 기전', options: ['조직액 축적','파골','상피','타액'], correctIndex:0, explanation:'혈관 누출 조직액 쌓임.', sourcePage:'21' },
  { question: '48h 후 온찜질 이유', options: ['지혈','순환','마비','열 차단'], correctIndex:1, explanation:'혈류/영양 공급 촉진.', sourcePage:'20,23' },
  { question: '과격한 운동 금지', options: ['면역','혈류/혈압','마취','골밀도'], correctIndex:1, explanation:'혈압 상승으로 재출혈.', sourcePage:'24' },
  { question: '비행/등반 금지 이유', options: ['압력','빈혈','건조','균형'], correctIndex:0, explanation:'기압 저하로 체내 압력 상대 상승.', sourcePage:'26' },
  { question: '항공성 치통 자가처치', options: ['뜨거운','차가운','높은 베개','코 풀기'], correctIndex:1, explanation:'차가운 물로 혈관 수축.', sourcePage:'27' },
  { question: '발치와 회복 기간', options: ['1주','2주','수개월','1년'], correctIndex:2, explanation:'뼈 재형성은 수개월.', sourcePage:'28' },
  { question: '수술 부위 칫솔 금지 비유', options: ['코 파기','반창고','안대','화상 식히기'], correctIndex:0, explanation:'지혈 후 자극 위험.', sourcePage:'29' },
  { question: '힐링 어버트먼트 위생', options: ['절대','부드럽게','이쑤시개','강한 가글'], correctIndex:1, explanation:'부드러운 칫솔링으로 청결.', sourcePage:'31' },
  { question: '헥사메딘 30분 간격 이유', options: ['향료','계면활성','불소','타액'], correctIndex:1, explanation:'계면활성제가 효과 감소.', sourcePage:'33' },
  { question: '헥사메딘 권장 사용', options: ['원액','희석','물로 헹굼','10회'], correctIndex:0, explanation:'원액 10-15ml 가글 후 헹구지 않음.', sourcePage:'33' },
  { question: '헥사메딘 2주 부작용', options: ['미각','균총/착색','치은','법랑질'], correctIndex:1, explanation:'유익균 감소, 착색 가능.', sourcePage:'34' },
  { question: '헥사메딘 vs CPC', options: ['자극 없음','광범위','미백','시간'], correctIndex:1, explanation:'광범위 항균.', sourcePage:'35' },
  { question: '소금물 비권장', options: ['효과 없음','농도 어려움','각화','혈압'], correctIndex:1, explanation:'고농도서 점막 손상.', sourcePage:'36' },
  { question: '항생제 중단 이유', options: ['소화','내성','마취','체중'], correctIndex:1, explanation:'내성균 위험.', sourcePage:'38' },
  { question: '타이레놀 최대량', options: ['1,000','2,600','4,000','6,000'], correctIndex:2, explanation:'일일 최대 4,000mg.', sourcePage:'39' },
  { question: '교차 복용 원칙', options: ['동일','다른 계열','마약','중단'], correctIndex:1, explanation:'다른 계열 약을 시간차 투여.', sourcePage:'40' },
  { question: '페니실린 교차', options: ['마크로','세팔로','테트라','니트로'], correctIndex:1, explanation:'구조 유사해 교차 가능.', sourcePage:'42' },
  { question: '항혈전제 재복용', options: ['지혈 직후','7일','실밥','보철'], correctIndex:0, explanation:'지혈 확인 후 즉시.', sourcePage:'44' },
  { question: '임산부 금기 항생제', options: ['페니실린','테트라','세팔로','아목'], correctIndex:1, explanation:'테트라사이클린은 치아 변색.', sourcePage:'45' },
];

async function addPostopQuizzes() {
  console.log('🚀 수술 후 주의사항 문제 추가 시작...\\n');

  const poolRef = db.collection('quiz_pool');
  const metaRef = db.doc('quiz_meta/state');
  const now = admin.firestore.Timestamp.now();
  const existing = await poolRef.orderBy('order', 'desc').limit(1).get();
  let nextOrder = existing.empty ? 1 : existing.docs[0].data().order + 1;
  const startOrder = nextOrder;

  console.log(`🔍 현재 마지막 order: ${nextOrder - 1}, 새 시작 order: ${nextOrder}\\n`);
  console.log('📝 수술 후 주의사항 문제 저장 중...');

  for (let i = 0; i < postopQuizzes.length; i++) {
    const quiz = postopQuizzes[i];
    await poolRef.add({
      order:           nextOrder,
      question:        quiz.question,
      options:         quiz.options,
      correctIndex:    quiz.correctIndex,
      explanation:     quiz.explanation,
      category:        '수술후',
      difficulty:      'advanced',
      sourceBook:      POSTOP_BOOK,
      sourceFileName:  POSTOP_FILE,
      sourcePage:      quiz.sourcePage,
      isActive:        true,
      lastCycleServed: 0,
      createdAt:       now,
      updatedAt:       now,
    });
    process.stdout.write(`   [${i + 1}/${postopQuizzes.length}] ${quiz.question.substring(0, 35)}...\\r`);
    nextOrder++;
  }
  console.log(`\\n   ✅ 수술 후 주의사항 문제 ${postopQuizzes.length}개 저장 완료\\n`);

  console.log('📊 quiz_meta/state 업데이트...');
  const metaSnap = await metaRef.get();
  const prevTotal = metaSnap.exists ? (metaSnap.data().totalActiveCount || 0) : 0;
  const newTotal = prevTotal + postopQuizzes.length;
  const updateData = { totalActiveCount: newTotal, updatedAt: now };
  if (metaSnap.exists) {
    const rotation = metaSnap.data().bookRotation || [];
    if (!rotation.includes(POSTOP_BOOK)) updateData.bookRotation = [...rotation, POSTOP_BOOK];
  }
  await metaRef.update(updateData);
  console.log(`   이전 총 문제 수: ${prevTotal}`);
  console.log(`   추가 문제 수:    ${postopQuizzes.length}`);
  console.log(`   새 총 문제 수:   ${newTotal}`);
  console.log('   ✅ quiz_meta/state 업데이트 완료\\n');

  console.log('═══════════════════════════════════════════');
  console.log(`✅ 완료! 수술 후 주의사항 30문제 추가`);
  console.log(`   order 범위: ${startOrder} ~ ${nextOrder - 1}`);
  console.log(`   카테고리: 수술후`);
  console.log(`   소스 책: ${POSTOP_BOOK}`);
  console.log(`   전체 풀 크기: ${newTotal}문제`);
  console.log('═══════════════════════════════════════════');

  process.exit(0);
}

addPostopQuizzes().catch((err) => {
  console.error('❌ 실패:', err);
  process.exit(1);
});



