/**
 * 치과 진찰료/보철보존보험 심화 30문항 추가 스크립트
 *
 * 실행:
 *   cd functions
 *   node scripts/add_insurance_quizzes.js
 *
 * 기존 데이터를 그대로 두고 order를 이어서 등록합니다.
 */

const admin = require('firebase-admin');
const path = require('path');

const serviceAccount = require(path.join(__dirname, '..', '..', 'tools', 'serviceAccountKey.json'));
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();

const INSURANCE_BOOK = '보험청구_심화';
const INSURANCE_FILE = '원장님_보험_청구_제가_한_번_해볼게요_PART1.pdf';

const insuranceQuizzes = [
  { question: '2024년 개편으로 치과의원의 종별가산율 변화는?', options: ['15%→11%', '15%→20%', '20%→5%', '종별가산 폐지'], correctIndex: 0, explanation: '2024년 개편으로 치과의원의 종별가산율은 15%에서 11%로 축소되었습니다.', sourcePage: '6' },
  { question: '연령 가산 지침에서 변경된 표현은?', options: ['만 나이 문구 삭제', '만 나이 기준 강화', '75세 이상 가산 신설', '소아 가산율 50% 상향'], correctIndex: 0, explanation: '기존 "만 나이" 기준 문구가 삭제되어 표기 방식이 바뀌었습니다.', sourcePage: '7' },
  { question: '장애인 진료 가산 확대 내용', options: ['71개 항목/300%', '17개 항목/100%', '50개 항목/200%', '모든 항목/500%'], correctIndex: 0, explanation: '장애인 가산 항목이 71개로 확대되고 가산율은 300%로 상향되었습니다.', sourcePage: '8' },
  { question: '야간·토요일·공휴일 30% 가산에 해당하지 않는 행위는?', options: ['발치술 이상', '치주소파술 이상', '마취 시행', '간단한 치석제거'], correctIndex: 3, explanation: '단순 치석제거는 야간 가산 대상이 아닙니다.', sourcePage: '13' },
  { question: '의료급여 1종 선택 병·의원 지정자 의뢰서 없이 내원 시 본인 부담금은?', options: ['100%', '1,500원', '30%', '면제'], correctIndex: 0, explanation: '의뢰서 없이 방문하면 진료비 전액 본인 부담입니다.', sourcePage: '17' },
  { question: '만성 치주 질환 재진 기간 기준', options: ['30일', '60일', '90일', '180일'], correctIndex: 2, explanation: '치료 종결이 불분명한 만성 질환은 90일 이내 재진으로 산정합니다.', sourcePage: '18' },
  { question: '공단 구강검진 당일 치료 진찰료 인정률', options: ['100%', '50%', '청구 불가', '검진료 30%'], correctIndex: 1, explanation: '공단 검진 당일에는 초·재진 진찰료의 50%만 인정됩니다.', sourcePage: '19' },
  { question: '판독 소견서 생략 조건', options: ['진료기록부 기록', '6세 미만', 'DR 사용', '촬영 거부'], correctIndex: 0, explanation: '진료기록부에 판독 내용을 기록하면 소견서 없이도 인정됩니다.', sourcePage: '28' },
  { question: '헥사메딘 가글 보험 인정 최대량', options: ['50ml', '100ml', '250ml', '무제한'], correctIndex: 1, explanation: '외래는 100ml까지만 보험 인정되며 초과분은 본인 부담입니다.', sourcePage: '24' },
  { question: 'QLF 검사 급여 대상', options: ['5~12세/6개월', '6~15세/1년', '전 연령/3개월', '19세 이상/2년'], correctIndex: 0, explanation: 'QLF는 5~12세 아동을 대상으로 6개월 간격으로 1회 인정됩니다.', sourcePage: '41~42' },
  { question: '임플란트 2단계 재식립 산정 비율', options: ['100%', '50%', '30%', '재료대만'], correctIndex: 1, explanation: '골 유착 실패 시 기왕 2단계 점수의 50%까지 인정됩니다.', sourcePage: '57,61' },
  { question: '보험 틀니 무상 유지관리 기간/횟수', options: ['3개월/6회', '6개월/10회', '1개월/무제한', '1년/4회'], correctIndex: 0, explanation: '최종 장착 후 3개월 이내 6회까지 진찰료만 산정합니다.', sourcePage: '51' },
  { question: '완전 무치악 환자 보험 임플란트', options: ['전액 급여', '평생 2개', '전체 비급여', '골이식만 가능'], correctIndex: 2, explanation: '완전 무치악 환자에게는 보험 임플란트가 전체 비급여입니다.', sourcePage: '58,62' },
  { question: '교합면 나사 삽입구 재충전 청구 항목', options: ['와동형성+충전+연마', '보통처치+충전', '충전+연마', '치아진정+충전'], correctIndex: 0, explanation: '와동형성, 충전, 연마를 각각 산정합니다.', sourcePage: '64~65' },
  { question: '첨상과 동시에 산정할 수 없는 행위', options: ['클라스프 수리', '인공치 수리', '개상', '의치상 조정'], correctIndex: 2, explanation: '첨상과 개상은 유사하여 동시 산정 불가합니다.', sourcePage: '53' },
  { question: '보통처치와 치아진정처치 병행 시 산정', options: ['치아진정만', '보통처치만', '각각 100%', '주된 100% 부수 50%'], correctIndex: 0, explanation: '주된 처치인 치아진정처치만 인정됩니다.', sourcePage: '67' },
  { question: '즉일충전처치 포함 항목', options: ['와동형성료', '재료대', '마취료', '방사선'], correctIndex: 0, explanation: '즉일충전에는 와동형성료가 포함되어 별도 청구불가합니다.', sourcePage: '69' },
  { question: '연마 산정 시점', options: ['당일', '다음 날', '1개월 후', '산정 불가'], correctIndex: 1, explanation: '연마는 재료 경화 후 다음 날 이후에 산정합니다.', sourcePage: '70,73' },
  { question: '12세 이하 광중합 레진 비급여 경우', options: ['유치', '영구치', '1일4치', '5세 이상'], correctIndex: 0, explanation: '유치에 시행하면 비급여이며 영구치에만 적용됩니다.', sourcePage: '76,79' },
  { question: '레진+실란트 동시 산정 비율', options: ['레진100+실란트50', '레진50+실란트100', '각각100', '레진만100'], correctIndex: 0, explanation: '레진은 100%, 실란트는 50% 산정됩니다.', sourcePage: '78,81' },
  { question: '발수 단계 기구', options: ['K-File', 'Barbed Broach', 'H-File', 'Gates Glidden'], correctIndex: 1, explanation: 'Barbed Broach를 사용해 치수 조직을 제거합니다.', sourcePage: '60' },
  { question: '근관 와동 전용 버', options: ['Round Bur', 'Fissure Bur', 'Endo-Z Bur', 'Diamond Bur'], correctIndex: 2, explanation: 'Endo-Z는 끝단에 날이 없어 치수저 보호가 가능합니다.', sourcePage: '62' },
  { question: '상악 제1소구치 치근/근관 조합', options: ['1/1', '2/2', '2/3', '3/4'], correctIndex: 1, explanation: '보통 2개 치근과 2개의 근관을 가집니다.', sourcePage: '63' },
  { question: '신경치료 첫날 처치', options: ['교합면 삭제', '근관 충전', '크라운 접착', '치은 절제'], correctIndex: 0, explanation: '교합면 삭제로 파절과 통증을 방지합니다.', sourcePage: '69' },
  { question: 'Root ZX 접촉 고리 위치', options: ['치아 협측', '치료 입꼬리', '반대 입꼬리', '손등'], correctIndex: 2, explanation: '반대편 입꼬리에 고리를 걸어 간섭을 피합니다.', sourcePage: '70' },
  { question: '치근단 엑스레이 목적', options: ['충전재 도달 확인', '변색 확인', '마취 확인', '악관절 확인'], correctIndex: 0, explanation: '충전재가 치근단까지 채워졌는지 확인합니다.', sourcePage: '74' },
  { question: '캐비톤 경화 시간', options: ['5분', '10분', '30분', '24시간'], correctIndex: 2, explanation: '캐비톤은 30분 정도 지나면 완전 경화됩니다.', sourcePage: '67,70' },
  { question: '유치 근관에 사용하는 약제', options: ['GP', 'Vitapex', 'Amalgam', 'Resin'], correctIndex: 1, explanation: '흡수가 필요한 유치에는 Vitapex를 사용합니다.', sourcePage: '59,71' },
  { question: '2024년 환산지수 단가', options: ['93.0원', '95.8원', '98.0원', '100.2원'], correctIndex: 1, explanation: '2024년 환산지수는 95.8원으로 인상되었습니다.', sourcePage: '6' },
  { question: 'C형 근관 장애인 가산 코드', options: ['일반 코드', '장애인 가산 코드', '비급여 코드', '보훈 코드'], correctIndex: 1, explanation: '장애인 진료 가산 코드가 적용됩니다.', sourcePage: '8' },
];

async function addInsuranceQuizzes() {
  console.log('🚀 보험 청구 심화 문제 추가 시작...\\n');

  const poolRef = db.collection('quiz_pool');
  const metaRef = db.doc('quiz_meta/state');
  const now = admin.firestore.Timestamp.now();

  console.log('🔍 현재 quiz_pool 상태 확인 중...');
  const existing = await poolRef.orderBy('order', 'desc').limit(1).get();
  let nextOrder = 1;
  if (!existing.empty) {
    nextOrder = existing.docs[0].data().order + 1;
  }
  const startOrder = nextOrder;
  console.log(`   현재 마지막 order: ${nextOrder - 1}, 새 시작 order: ${nextOrder}\\n`);

  console.log('📝 보험 청구 문제 저장 중...');
  for (let i = 0; i < insuranceQuizzes.length; i++) {
    const quiz = insuranceQuizzes[i];
    await poolRef.add({
      order:           nextOrder,
      question:        quiz.question,
      options:         quiz.options,
      correctIndex:    quiz.correctIndex,
      explanation:     quiz.explanation,
      category:        '보험',
      difficulty:      'advanced',
      sourceBook:      INSURANCE_BOOK,
      sourceFileName:  INSURANCE_FILE,
      sourcePage:      quiz.sourcePage,
      isActive:        true,
      lastCycleServed: 0,
      createdAt:       now,
      updatedAt:       now,
    });
    process.stdout.write(`   [${i + 1}/${insuranceQuizzes.length}] ${quiz.question.substring(0, 40)}...\\r`);
    nextOrder++;
  }
  console.log(`\\n   ✅ 보험 청구 문제 ${insuranceQuizzes.length}개 저장 완료\\n`);

  console.log('📊 quiz_meta/state 업데이트...');
  const metaSnap = await metaRef.get();
  const prevTotal = metaSnap.exists ? (metaSnap.data().totalActiveCount || 0) : 0;
  const newTotal = prevTotal + insuranceQuizzes.length;

  const updateData = { totalActiveCount: newTotal, updatedAt: now };
  if (metaSnap.exists) {
    const rotation = metaSnap.data().bookRotation || [];
    if (!rotation.includes(INSURANCE_BOOK)) {
      updateData.bookRotation = [...rotation, INSURANCE_BOOK];
    }
  }

  await metaRef.update(updateData);
  console.log(`   이전 총 문제 수: ${prevTotal}`);
  console.log(`   추가 문제 수:    ${insuranceQuizzes.length}`);
  console.log(`   새 총 문제 수:   ${newTotal}`);
  console.log('   ✅ quiz_meta/state 업데이트 완료\\n');

  console.log('═══════════════════════════════════════════');
  console.log(`✅ 완료! 보험 청구 심화 30문제 추가`);
  console.log(`   order 범위: ${startOrder} ~ ${nextOrder - 1}`);
  console.log(`   카테고리: 보험`);
  console.log(`   소스 책: ${INSURANCE_BOOK}`);
  console.log(`   전체 풀 크기: ${newTotal}문제`);
  console.log('═══════════════════════════════════════════');

  process.exit(0);
}

addInsuranceQuizzes().catch((err) => {
  console.error('❌ 실패:', err);
  process.exit(1);
});






