/**
 * 보존학 심화 30문항 추가 스크립트
 *
 * 실행 방법:
 *   cd functions
 *   node scripts/add_restorative_quizzes.js
 *
 * 기존 데이터를 삭제하지 않고 order를 이어서 등록합니다.
 */

const admin = require('firebase-admin');
const path = require('path');

// Firebase 초기화
const serviceAccount = require(path.join(__dirname, '..', '..', 'tools', 'serviceAccountKey.json'));
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();

const RESTORATIVE_BOOK = '보존학적_재료';
const RESTORATIVE_FILE = '알고보면_재미있는_보존과.pdf';

const restorativeQuizzes = [
  {
    question: '복합 레진 성분 중 충전재(Filler)의 함량이 증가함에 따라 나타나는 물리적 성질의 변화로 옳은 것은?',
    options: ['흐름성 증가', '중합 수축량 증가', '기계적 강도 향상', '정도(Viscosity) 감소'],
    correctIndex: 2,
    explanation: '충전재 함량이 높을수록 강도, 경도 등 기계적 성질이 향상되고 수축량은 줄어듭니다.',
    sourcePage: '5',
  },
  {
    question: '복합 레진의 유기질 기질(Matrix) 함량이 높을 때 발생할 수 있는 임상적 문제점은?',
    options: ['중합 수축 및 미세누출 증가', '내마모성 비약적 상승', '연고 형태의 조작 용이성', '광중합 시간의 단축'],
    correctIndex: 0,
    explanation: '유기질 기질 양이 많으면 흐름성은 좋으나 중합 수축량이 높아져 미세누출과 변색의 원인이 됩니다.',
    sourcePage: '5',
  },
  {
    question: '산 부식(Etching) 시 법랑질과 상아질의 부식 속도 차이를 고려한 올바른 도포 순서는?',
    options: ['상아질 우선 도포', '법랑질 우선 도포', '동시 도포 후 동시 세척', '부식 속도 차이 없음'],
    correctIndex: 1,
    explanation: '법랑질과 상아질의 부식 속도가 다르므로 법랑질에 먼저 도포한 후 상아질에 도포해야 합니다.',
    sourcePage: '7',
  },
  {
    question: '광중합형 복합 레진의 적층 충전 시 각 층의 권장 두께와 중합 시간은?',
    options: ['2mm 이하 / 40초', '5mm 이하 / 10초', '1mm 이하 / 60초', '두께 상관없음 / 20초'],
    correctIndex: 0,
    explanation: '중합 수축에 의한 응력을 줄이기 위해 각 층을 2mm 이하로 얇게 채우고 40초간 광중합 합니다.',
    sourcePage: '10',
  },
  {
    question: '아말감 충전 전 바니쉬를 도포하는 주된 목적은?',
    options: ['아말감과 치질의 화학 결합', '상아세관 폐쇄 및 착색 방지', '아말감의 경화 속도 촉진', '치아 미백 효과 유도'],
    correctIndex: 1,
    explanation: '미세 누출을 줄이고 금속 이온이 상아세관으로 침투해 치아가 변색되는 것을 막아줍니다.',
    sourcePage: '15',
  },
  {
    question: '아말감 연화 후 혼합물이 건조하고 가루가 날린다면 어떤 조치를 취해야 하는가?',
    options: ['그대로 와동에 응축', '액체 수은을 추가 혼합', '폐기 후 새로 혼합', '물을 섞어 점도 조절'],
    correctIndex: 2,
    explanation: '연화가 덜 된 아말감은 강도와 부식 저항성이 낮으므로 과감히 버리고 새로 혼합해야 합니다.',
    sourcePage: '17',
  },
  {
    question: '아말감 조각 전 문지르기의 효과로 옳은 것은?',
    options: ['잉여 수은 제거 및 밀도 증가', '해부학적 구 형성', '최종 광택 부여', '지혈 효과 유도'],
    correctIndex: 0,
    explanation: '조각 전 문지르기는 과도한 수은을 제거하고 변연 적합성과 경도를 높여줍니다.',
    sourcePage: '18',
  },
  {
    question: '아말감 수복물의 최종 연마를 충전 24시간 이후에 시행하는 물리적 이유는?',
    options: ['수은 증기 발생 차단', '압축 강도의 도달 시간 필요', '환자의 심리적 안정', '색상 안정화'],
    correctIndex: 1,
    explanation: '아말감은 압축 강도가 서서히 증가하여 24시간이 지나야 가장 단단해지기 때문입니다.',
    sourcePage: '13',
  },
  {
    question: 'GI가 갖는 가장 큰 생물학적 장점은?',
    options: ['탁월한 심미성', '높은 인장 강도', '지속적인 불소 유리 효과', '짧은 경화 시간'],
    correctIndex: 2,
    explanation: 'GI는 불소를 방출하여 충치 예방 효과를 나타내는 생체 친화적 재료입니다.',
    sourcePage: '22',
  },
  {
    question: 'GI 혼합 시 금속 혼합자 대신 플라스틱을 사용하는 이유는?',
    options: ['광택 유지', '금속 성분 분해 방지', '조작 시간 단축', '가격 절감'],
    correctIndex: 1,
    explanation: '금속 스파출라는 GI의 유리 성분을 분해하여 성분 변화를 초래할 수 있어 플라스틱을 권장합니다.',
    sourcePage: '25',
  },
  {
    question: 'GI 충전 직후 알코올 솜을 눌러주는 목적은?',
    options: ['수분 접촉 차단 및 성형', '광중합 촉진', '살균', '변색 제거'],
    correctIndex: 0,
    explanation: 'GI는 초기 경화 시 수분에 민감하므로 알코올 솜으로 틈새 방지와 외형 형성에 유리합니다.',
    sourcePage: '27',
  },
  {
    question: 'RMGI에 대한 올바른 설명은?',
    options: ['자가 중합보다 약함', '불소 유리 없음', 'GI와 레진 장점 혼합', '100% 건강보험'],
    correctIndex: 2,
    explanation: 'RMGI는 GI의 불소 유리 장점과 레진의 강도/내마모성을 결합한 비보험 재료입니다.',
    sourcePage: '22',
  },
  {
    question: '상아질 지각과민의 발생 기전은?',
    options: ['법랑질 증식', '상아세관 개방 및 자극 전달', '치수 괴사', '신경 마비'],
    correctIndex: 1,
    explanation: '상아세관이 노출되어 외부 자극이 내부로 전달되면서 통증을 느끼게 됩니다.',
    sourcePage: '29',
  },
  {
    question: '지각과민처치(나) 항목으로 산정되는 대표 재료와 기준은?',
    options: ['Gluma / 최대 600%', 'SE Bond / 1치 100%(2치부터 20%)', '불소 도포 / 전 환자', 'GI 충전 / 면수별'],
    correctIndex: 1,
    explanation: 'SE Bond는 (나) 항목으로 산정하며 1치 100%, 2치부터 20%로 계산합니다.',
    sourcePage: '30',
  },
  {
    question: 'NaOCl의 주요 약리학적 역할이 아닌 것은?',
    options: ['괴사 조직 용해', '강력한 항균', '윤활/표백', '상아질 재광화 촉진'],
    correctIndex: 3,
    explanation: 'NaOCl은 조직 용해와 살균이 주 목적이며 재광화와는 관련이 없습니다.',
    sourcePage: '66',
  },
  {
    question: 'K-File과 H-File의 형태 및 운동 차이는?',
    options: ['K-File 회전', 'H-File 회전', 'K-File 단면 원형', 'H-File 삭제 광범위'],
    correctIndex: 0,
    explanation: 'K-File은 네모난 단면으로 회전 동작을 하며, H-File은 원형 단면으로 잡아당기는 동작을 합니다.',
    sourcePage: '60',
  },
  {
    question: '비타펙스의 주요 특징은?',
    options: ['수용성으로 제거 쉽다', '지용성이며 유치 근관충전', '투명하여 엑스레이 안 보임', '영구치 고체 재료'],
    correctIndex: 1,
    explanation: '비타펙스는 지용성으로 방사선 불투과성이며 유치 근관충전에 사용합니다.',
    sourcePage: '59',
  },
  {
    question: '의도적 치아재식술이 치근단절제술과 다른 점은?',
    options: ['잇몸 절개 없음', '치아를 뽑아서 치료', '신경 살림', '재료 미사용'],
    correctIndex: 1,
    explanation: '기구 접근이 어려울 때 치아를 발치하여 구강 밖에서 치료 후 다시 심는 방법입니다.',
    sourcePage: '64',
  },
  {
    question: '미성숙 영구치의 뿌리 성장을 위해 시행하는 술식은?',
    options: ['치수절단술', '치근단절제술', '발치', '미백'],
    correctIndex: 0,
    explanation: '뿌리가 다 형성되지 않았을 경우 치관부 신경만 제거하여 뿌리 성장을 유도합니다.',
    sourcePage: '64',
  },
  {
    question: '신경치료 후 실활치 미백은?',
    options: ['자가 미백', '전문가 미백', '실활치 미백', '불소 미백'],
    correctIndex: 2,
    explanation: '실활치 미백은 수강에 미백제를 넣어 안쪽에서 미백하는 방식입니다.',
    sourcePage: '66',
  },
  {
    question: '자가 미백 시 교육 내용은?',
    options: ['고농도 30분', '트레이에 약재 도포 후 수면', '착색 음식 섭취', '잇몸 통증 시 약물 증량'],
    correctIndex: 1,
    explanation: '자가 미백은 낮은 농도로 트레이를 이용하여 장시간 착용하는 방식입니다.',
    sourcePage: '78',
  },
  {
    question: '전문가 미백 시 주의사항은?',
    options: ['저농도 확인', '연조직 보호제 도포', '광조사 금지', '1주일간 양치 금지'],
    correctIndex: 1,
    explanation: '고농도 미백제가 잇몸에 닿으면 화상을 입을 수 있으므로 보호막 형성이 필수입니다.',
    sourcePage: '78',
  },
  {
    question: 'GV Black 와동 분류 중 구치부 인접면은?',
    options: ['1급', '2급', '3급', '5급'],
    correctIndex: 1,
    explanation: '2급 와동은 소구치와 대구치의 인접면을 포함합니다.',
    sourcePage: '4',
  },
  {
    question: '자가 부식 시스템이 시작된 세대는?',
    options: ['4세대', '6세대', '1세대', '3세대'],
    correctIndex: 1,
    explanation: '6세대부터 별도의 에칭 없이 프라이머와 본딩을 사용하는 자가 부식 방식이 보편화되었습니다.',
    sourcePage: '9',
  },
  {
    question: '치경부 마모증에서 GI 충전이 유리한 환자군은?',
    options: ['심미 최우선', '우식 활성 높음', '저작력 강한 환자', '변색 민감한 환자'],
    correctIndex: 1,
    explanation: 'GI는 불소를 유리하여 우식 위험이 높은 환자에게 항우식 효과를 줍니다.',
    sourcePage: '22',
  },
  {
    question: '아말감 합금의 은(Ag)의 역할은?',
    options: ['강도 증가 및 팽창', '경화 속도 지연', '흐름성 증대', '부식 촉진'],
    correctIndex: 0,
    explanation: '은은 강도를 높이고 적절한 팽창을 일으켜 변연 봉쇄를 돕는 성분입니다.',
    sourcePage: '13',
  },
  {
    question: '갈바닉 반응이 발생하는 조건은?',
    options: ['동일 금속 접촉', '서로 다른 금속 타액 연결', '레진과 GI 인접', '틀니와 임플란트 결합'],
    correctIndex: 1,
    explanation: '서로 다른 전위차를 가진 금属이 타액을 통해 접촉할 때 전류가 흐르는 현상입니다.',
    sourcePage: '14',
  },
  {
    question: 'GI 표면 윤기가 사라졌다는 의미는?',
    options: ['최종 경화 / 광중합', '화학 결합 능력 상실', '접착력 최대화', '기포 제거 완료'],
    correctIndex: 1,
    explanation: '윤기가 사라졌다는 것은 경화가 시작되어 결합력이 떨어졌다는 뜻이므로 사용하면 안 됩니다.',
    sourcePage: '25',
  },
  {
    question: 'KNO3가 시린이를 완화하는 기전은?',
    options: ['상아세관 봉쇄', '칼륨 농도 증가로 신경 둔화', '산성도 강화', '법랑질 두께 증대'],
    correctIndex: 1,
    explanation: '칼륨 이온이 상아질 표면 농도를 높여 신경 전달을 억제합니다.',
    sourcePage: '29',
  },
  {
    question: '2020년 개정된 아말감 사용 규정에 따른 형태는?',
    options: ['분말형 합금', '정제형 아말감', '캡슐형 아말감', '액체형 수은 단독'],
    correctIndex: 2,
    explanation: '수은 노출 위험을 줄이기 위해 규격화된 캡슐형 아말감만 사용됩니다.',
    sourcePage: '13',
  },
];

async function addRestorativeQuizzes() {
  console.log('🚀 보존학 심화 문제 추가 시작...\\n');

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

  console.log('📝 보존학 문제 저장 중...');
  for (let i = 0; i < restorativeQuizzes.length; i++) {
    const quiz = restorativeQuizzes[i];
    await poolRef.add({
      order:           nextOrder,
      question:        quiz.question,
      options:         quiz.options,
      correctIndex:    quiz.correctIndex,
      explanation:     quiz.explanation,
      category:        '보존',
      difficulty:      'advanced',
      sourceBook:      RESTORATIVE_BOOK,
      sourceFileName:  RESTORATIVE_FILE,
      sourcePage:      quiz.sourcePage,
      isActive:        true,
      lastCycleServed: 0,
      createdAt:       now,
      updatedAt:       now,
    });
    process.stdout.write(`   [${i + 1}/${restorativeQuizzes.length}] ${quiz.question.substring(0, 40)}...\\r`);
    nextOrder++;
  }
  console.log(`\\n   ✅ 보존학 문제 ${restorativeQuizzes.length}개 저장 완료\\n`);

  console.log('📊 quiz_meta/state 업데이트...');
  const metaSnap = await metaRef.get();
  const prevTotal = metaSnap.exists ? (metaSnap.data().totalActiveCount || 0) : 0;
  const newTotal = prevTotal + restorativeQuizzes.length;

  const updateData = { totalActiveCount: newTotal, updatedAt: now };
  if (metaSnap.exists) {
    const rotation = metaSnap.data().bookRotation || [];
    if (!rotation.includes(RESTORATIVE_BOOK)) {
      updateData.bookRotation = [...rotation, RESTORATIVE_BOOK];
    }
  }

  await metaRef.update(updateData);
  console.log(`   이전 총 문제 수: ${prevTotal}`);
  console.log(`   추가 문제 수:    ${restorativeQuizzes.length}`);
  console.log(`   새 총 문제 수:   ${newTotal}`);
  console.log('   ✅ quiz_meta/state 업데이트 완료\\n');

  console.log('═══════════════════════════════════════════');
  console.log(`✅ 완료! 보존학 진료 30문제 추가`);
  console.log(`   order 범위: ${startOrder} ~ ${nextOrder - 1}`);
  console.log(`   카테고리: 보존`);
  console.log(`   소스 책: ${RESTORATIVE_BOOK}`);
  console.log(`   전체 풀 크기: ${newTotal}문제`);
  console.log('═══════════════════════════════════════════');

  process.exit(0);
}

addRestorativeQuizzes().catch((err) => {
  console.error('❌ 실패:', err);
  process.exit(1);
});






