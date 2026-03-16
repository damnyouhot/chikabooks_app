/**
 * 구강외과/치주 보험 청구 심화 30문항 추가 스크립트
 *
 * 실행:
 *   cd functions
 *   node scripts/add_oralsurgery_quizzes.js
 */

const admin = require('firebase-admin');
const path = require('path');

const serviceAccount = require(path.join(__dirname, '..', '..', 'tools', 'serviceAccountKey.json'));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const SURGERY_BOOK = '구강외과_치주보험';
const SURGERY_FILE = '원장님_보험_청구_제가_한_번_해볼게요_PART2.pdf';

const surgeryQuizzes = [
  { question: '치근분리술 후 올바른 청구법은?', options: ['유치 발치 100%', '난발치 100%', '유치 발치 150%', '난발치 50%'], correctIndex: 1, explanation: '심부 유치 잔근 제거 시 난발치 소정점수로 산정합니다.', sourcePage: '7' },
  { question: '보철물 제거 후 발치 산정 원칙은?', options: ['발치만 100%', '보철물 제거만 100%', '각각 100%', '주된 100% 부수 50%'], correctIndex: 2, explanation: '수복물 제거 후 발치는 순차적으로 각각 100% 산정됩니다.', sourcePage: '9' },
  { question: '난발치 청구 시 X-ray 없으면?', options: ['그대로 인정', '단순 발치로 조정', '보통처치로', '전액 삭감'], correctIndex: 1, explanation: '촬영 기록 없으면 일반 발치로 조정됩니다.', sourcePage: '10' },
  { question: '복잡 매복 기준은?', options: ['점막 절개만', '치아 분리술', '골 삭제+분리', '치관 2/3 이상'], correctIndex: 1, explanation: '치아분리술을 시행하면 복잡 매복입니다.', sourcePage: '12' },
  { question: '임플란트 제거(복잡)+치조골성형 시 청구', options: ['각각 100%', '임플란트 제거만', '주된 100% 부수 50%', '치조골성형만'], correctIndex: 1, explanation: '치조골성형이 포함되어 별도 산정 불가합니다.', sourcePage: '16' },
  { question: '금속제거술 시 판막 없이 나사 제거하면?', options: ['금속제거술 100%', '50%', '진찰료만', '단순 처치'], correctIndex: 2, explanation: '판막 거상 없이 제거하면 기본 진찰료만 인정됩니다.', sourcePage: '17' },
  { question: '치주치료+수술후 처치 동시 원칙은?', options: ['각각 100%', '주된 처치만', '수술후만', '처방전 기준'], correctIndex: 1, explanation: '주된 처치료만 산정합니다.', sourcePage: '20' },
  { question: '발치+재소파술 상병명/마취', options: ['불필요/치아우식', '필수/턱 치조염', '필수/만성 치주염', '선택/치아 파절'], correctIndex: 1, explanation: '마취 필수이며 상병명 K10.3 입니다.', sourcePage: '21' },
  { question: '매복치+치조골성형 여부', options: ['별도 불인정', '50%', '조건부 100%', 'Bur만'], correctIndex: 0, explanation: '골 삭제 포함되므로 주된 수술로 인정합니다.', sourcePage: '24' },
  { question: '골융기절제술 vs 치조골성형 차이', options: ['산정 단위', '마취', '상병명', '촬영'], correctIndex: 0, explanation: '치조골성형은 치당, 골융기절제술은 소정점수입니다.', sourcePage: '25' },
  { question: '치은판 절제술 대상 연령', options: ['만 15세 이하', '65세 이상', '전 연령', '유치 보유만'], correctIndex: 2, explanation: '2016년 개정으로 전 연령 대상입니다.', sourcePage: '26' },
  { question: '2개소 이상 구강내소염 최대 한도', options: ['100%', '150%', '200%', '300%'], correctIndex: 2, explanation: '당일 최대 200%까지 산정 가능합니다.', sourcePage: '28' },
  { question: '치근단절제술 MTA 산정', options: ['행위료 포함', '전액 급여', '비급여', '재료대 50%'], correctIndex: 2, explanation: 'MTA 재료는 비급여로 산정합니다.', sourcePage: '31' },
  { question: '치근낭적출술 가장 높은 항목', options: ['1/2치관', '1치관', '2치관', '3치관'], correctIndex: 3, explanation: "3치관 이상 '라' 항목이 가장 높습니다.", sourcePage: '34' },
  { question: '차114 골이식차이점', options: ['치주 목적', '각각 100%', '재료대 불가', '1/3악당'], correctIndex: 1, explanation: '차114는 외과 동시시 각각 100% 산정됩니다.', sourcePage: '51' },
  { question: '단계별 치주 치료 진행 순서', options: ['치근활택술→치석제거', '치석제거→치주소파', '조직유도→치근활택', '치주소파→치석제거'], correctIndex: 1, explanation: '하위 행위から上位行為へ 진행합니다.', sourcePage: '53' },
  { question: '치주 재진 기준 기간', options: ['30일', '60일', '90일', '180일'], correctIndex: 2, explanation: '완치 불명 시 90일 이내 재진으로 봅니다.', sourcePage: '53' },
  { question: '1/3악 단위 1/2악 시행 수가', options: ['100%', '120%', '150%', '200%'], correctIndex: 2, explanation: '1/2악 시행 시 150% 산정합니다.', sourcePage: '54' },
  { question: '전 처치 없이 실시 치은박리소파', options: ['전액 삭감', '50%', '치주소파', '치석제거'], correctIndex: 2, explanation: '치주소파술 점수만 인정됩니다.', sourcePage: '56' },
  { question: '유치 치석제거 청구명칭', options: ['치석제거(가)', '치석제거(나)', '치면세마', '보통처치'], correctIndex: 2, explanation: '유치 치석제거는 치면세마로 산정합니다.', sourcePage: '57' },
  { question: '1~2개 치아 치면세마 비율', options: ['30%', '50%', '100%', '불가'], correctIndex: 1, explanation: '1~2개는 50%만 산정합니다.', sourcePage: '58,60' },
  { question: '치주낭측정 횟수', options: ['1회', '2회', '매 내원', '3개월마다'], correctIndex: 0, explanation: '동일 부위는 치료완료까지 1회만 산정합니다.', sourcePage: '59' },
  { question: '치석제거(가) 구치 1개 산정', options: ['100%', '50%', '치면세마 100%', '진찰료만'], correctIndex: 1, explanation: '1/3악 기준 구치 1~2개 50% 산정입니다.', sourcePage: '61' },
  { question: '치석제거후 지각과민처치', options: ['각각 100%', '지각만', '치석제거만', '주된 100% 부수 50%'], correctIndex: 2, explanation: '지각과민처치는 인정되지 않으며 1주일 뒤 산정.', sourcePage: '62' },
  { question: '연1회 치석제거(나) 대상', options: ['만 15세', '만 19세', '만 20세', '전 연령'], correctIndex: 1, explanation: '만 19세 이상 건강보험 가입자 대상입니다.', sourcePage: '63' },
  { question: '수술용 스플린트/상고정장치 산정 시점', options: ['인상 당일', '제작일', '장착일', '실밥 제거'], correctIndex: 2, explanation: '장치는 장착하는 날 산정합니다.', sourcePage: '43,44' },
  { question: '상고정장치 별도 산정 가능한 항목', options: ['고정장치 제거', '인상 채득', '기공료', '재료대'], correctIndex: 0, explanation: '상고정장치는 제거술을 별도 산정할 수 있습니다.', sourcePage: '44' },
  { question: '치간고정 vs 잠간고정 차이', options: ['마취', 'Arch bar', '봉합사', '촬영'], correctIndex: 1, explanation: 'Arch bar 사용 시 치간고정, 와이어+레진은 잠간고정입니다.', sourcePage: '47' },
  { question: '설소대성형 보험 인정 목적 아닌 것', options: ['발음', '수유', '교합', '심미'], correctIndex: 3, explanation: '심미 목적은 비급여입니다.', sourcePage: '50' },
  { question: '치조골결손 골이식 최대 범위', options: ['1cc', '3cc', '5cc', '제한 없음'], correctIndex: 1, explanation: '골대체제만 사용 시 최대 3cc(2.5g)까지 인정.', sourcePage: '37' },
];

async function addOralSurgeryQuizzes() {
  console.log('🚀 구강외과/치주 보험 문제 추가 시작...\\n');

  const poolRef = db.collection('quiz_pool');
  const metaRef = db.doc('quiz_meta/state');
  const now = admin.firestore.Timestamp.now();

  console.log('🔍 현재 quiz_pool 상태 확인 중...');
  const existing = await poolRef.orderBy('order', 'desc').limit(1).get();
  let nextOrder = existing.empty ? 1 : existing.docs[0].data().order + 1;
  const startOrder = nextOrder;
  console.log(`   현재 마지막 order: ${nextOrder - 1}, 새 시작 order: ${nextOrder}\\n`);

  console.log('📝 구강외과/치주 문제 저장 중...');
  for (let i = 0; i < surgeryQuizzes.length; i++) {
    const quiz = surgeryQuizzes[i];
    await poolRef.add({
      order:           nextOrder,
      question:        quiz.question,
      options:         quiz.options,
      correctIndex:    quiz.correctIndex,
      explanation:     quiz.explanation,
      category:        '외과/치주',
      difficulty:      'advanced',
      sourceBook:      SURGERY_BOOK,
      sourceFileName:  SURGERY_FILE,
      sourcePage:      quiz.sourcePage,
      isActive:        true,
      lastCycleServed: 0,
      createdAt:       now,
      updatedAt:       now,
    });
    process.stdout.write(`   [${i + 1}/${surgeryQuizzes.length}] ${quiz.question.substring(0, 40)}...\\r`);
    nextOrder++;
  }
  console.log(`\\n   ✅ 구강외과/치주 문제 ${surgeryQuizzes.length}개 저장 완료\\n`);

  console.log('📊 quiz_meta/state 업데이트...');
  const metaSnap = await metaRef.get();
  const prevTotal = metaSnap.exists ? (metaSnap.data().totalActiveCount || 0) : 0;
  const newTotal = prevTotal + surgeryQuizzes.length;

  const updateData = { totalActiveCount: newTotal, updatedAt: now };
  if (metaSnap.exists) {
    const rotation = metaSnap.data().bookRotation || [];
    if (!rotation.includes(SURGERY_BOOK)) {
      updateData.bookRotation = [...rotation, SURGERY_BOOK];
    }
  }

  await metaRef.update(updateData);
  console.log(`   이전 총 문제 수: ${prevTotal}`);
  console.log(`   추가 문제 수:    ${surgeryQuizzes.length}`);
  console.log(`   새 총 문제 수:   ${newTotal}`);
  console.log('   ✅ quiz_meta/state 업데이트 완료\\n');

  console.log('═══════════════════════════════════════════');
  console.log(`✅ 완료! 구강외과/치주 보험 30문제 추가`);
  console.log(`   order 범위: ${startOrder} ~ ${nextOrder - 1}`);
  console.log(`   카테고리: 외과/치주`);
  console.log(`   소스 책: ${SURGERY_BOOK}`);
  console.log(`   전체 풀 크기: ${newTotal}문제`);
  console.log('═══════════════════════════════════════════');

  process.exit(0);
}

addOralSurgeryQuizzes().catch((err) => {
  console.error('❌ 실패:', err);
  process.exit(1);
});

