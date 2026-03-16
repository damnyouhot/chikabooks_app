/**
 * 구치부 임시치아 30문항 추가 스크립트
 *
 * 실행 방법:
 *   cd functions
 *   node scripts/add_temporary_crown_quizzes.js
 *
 * ※ 기존 데이터를 삭제하지 않고 order를 이어서 추가합니다.
 */

const admin = require('firebase-admin');
const path  = require('path');

// ── Firebase 초기화 ──────────────────────────────────────────
const serviceAccount = require(path.join(__dirname, '..', '..', 'tools', 'serviceAccountKey.json'));
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();

// ══════════════════════════════════════════════════════════════
// 문제 데이터
// ══════════════════════════════════════════════════════════════

const TEMP_CROWN_BOOK     = '임시치아_구치부';
const TEMP_CROWN_FILENAME = '5분_임시치아_vol1_구치부.pdf';

const tempCrownQuizzes = [
  // ── 제1장 임시치아의 목적 및 재료학적 심화 ──
  {
    question:     '생활치(Vital tooth) 지대치 형성 후 임시치아를 장착해야 하는 가장 핵심적인 생물학적 이유는?',
    options:      ['법랑질 재광화 유도', '치수 자극 및 염증 차단', '치은 증식 억제', '타액 분비 조절'],
    correctIndex: 1,
    explanation:  '생활치는 온도 변화에 민감하며 외부 자극이 지속될 경우 치수염이 발생할 수 있어 임시치아를 통한 차단이 필수적입니다.',
    sourcePage:   '4',
  },
  {
    question:     '임시치아의 변연부(Margin)가 짧게 제작되었을 때 지대치에 미치는 직접적인 영향은?',
    options:      ['치은 퇴축 발생', '지대치 파절 및 손상', '인접치 근심 이동', '교합 고경 상승'],
    correctIndex: 1,
    explanation:  '마진이 짧으면 지대치 노출 부위가 외부 자극을 받아 손상되거나 시린 증상을 유발할 수 있습니다.',
    sourcePage:   '5',
  },
  {
    question:     '최종 보철물을 레진 시멘트로 부착할 예정일 때 임시 접착제 선택 시 주의사항은?',
    options:      ['유지놀 함유 제재 사용', '유지놀 프리(Non-eugenol) 사용', '접착력이 가장 강한 것 선택', '투명한 시멘트만 사용'],
    correctIndex: 1,
    explanation:  '유지놀(Eugenol) 성분은 레진의 중합을 방해하여 최종 접착력을 저하시키므로 반드시 유지놀 프리 제품을 써야 합니다.',
    sourcePage:   '8',
  },
  {
    question:     "기공용 덴쳐 버(Denture Bur) 중 '가장 높은 절삭력'을 지녀 초기 형태 조정에 쓰이는 색 띠는?",
    options:      ['노란색', '빨간색', '파란색', '초록색'],
    correctIndex: 2,
    explanation:  '파란색 띠는 절삭력이 가장 높아 거친 삭제나 초기 형태 조정에 효율적입니다.',
    sourcePage:   '7',
  },
  {
    question:     '폴리싱 버(Polishing Bur)를 이용한 연마가 불충분할 때 환자 구강 내에서 발생하는 문제는?',
    options:      ['지대치 지각과민', '플라그 부착 및 악취', '보철물 강도 저하', '대합치 이상 마모'],
    correctIndex: 1,
    explanation:  '표면이 거칠면 플라그가 쉽게 부착되어 구취, 잇몸 염증, 변색 등을 유발하고 연조직에 상처를 줄 수 있습니다.',
    sourcePage:   '8',
  },
  // ── 제2장 레진 중합 단계 및 제작 술식 심화 ──
  {
    question:     "아크릴릭 레진 혼합 후 '표면 광택이 소실'되며 반죽 상태가 되어 지대치에 삽입하기 가장 적절한 단계는?",
    options:      ['Sandy Stage', 'Sticky Stage', 'Dough Stage', 'Rubbery Stage'],
    correctIndex: 2,
    explanation:  '도우(Dough) 단계는 찰흙 같은 질감으로 손에 붙지 않고 형태 유지가 가능하여 지대치 삽입에 최적화된 시기입니다.',
    sourcePage:   '9',
  },
  {
    question:     "레진이 고무 같은 탄성을 지니며 발열과 함께 '변형'이 가장 많이 일어나는 주의 단계는?",
    options:      ['Dough Stage', 'Rubbery Stage', 'Set Stage', 'Sandy Stage'],
    correctIndex: 1,
    explanation:  '러버리(Rubbery) 단계는 탄성이 있어 제거 시 변형되기 쉬우므로, 완전 경화 전까지 착탈을 반복하며 형태를 유지해야 합니다.',
    sourcePage:   '9',
  },
  {
    question:     '임시치아 제작 시간을 단축하기 위해 처음 잡아야 하는 외형의 기초 모양은?',
    options:      ['원형 (Circle)', '사각형 (Square)', '타원형 (Oval)', '삼각형 (Triangle)'],
    correctIndex: 1,
    explanation:  '처음부터 디테일한 모양을 잡기보다 반듯한 사각형을 먼저 만들고 기준점을 잡아 깎는 것이 시간을 크게 단축합니다.',
    sourcePage:   '10',
  },
  {
    question:     '인상 채득과 임시치아 제작을 동시 진행할 때, 임시치아 외형 형성에 주어진 이상적인 시간은?',
    options:      ['인상재가 굳는 5분 이내', '마취 풀리는 1시간 이내', '기공소 배송 전까지', '당일 업무 종료 전까지'],
    correctIndex: 0,
    explanation:  '진료 효율을 위해 인상재가 구강 내에서 경화되는 약 5분 동안 임시치아 제작을 완료하는 것이 권장됩니다.',
    sourcePage:   '11',
  },
  {
    question:     '지대치에 언더컷(Undercut)이 있거나 주변 치아와 패스가 맞지 않을 때 사전에 취해야 할 조치는?',
    options:      ['레진 양 2배 혼합', '바셀린 충분히 도포', '리라이닝 전면 생략', '마진 부위 제거 후 삽입'],
    correctIndex: 1,
    explanation:  '언더컷이 있거나 패스가 좋지 않으면 경화된 임시치아가 지대치에서 빠지지 않을 수 있으므로 바셀린 처리를 철저히 해야 합니다.',
    sourcePage:   '13',
  },
  // ── 제3장 치아별 형태학 및 교합 관계 심화 ──
  {
    question:     '상악 대구치의 교합면을 형성할 때 기준이 되는 기초 기하학적 형태는?',
    options:      ['직사각형', '평행사변형', '정삼각형', '마름모꼴'],
    correctIndex: 1,
    explanation:  '상악 대구치는 평행사변형 모양의 4교두 형태를 지니는 것이 특징입니다.',
    sourcePage:   '12',
  },
  {
    question:     "정상 교합(Class 1) 상태에서 상악 대구치의 '기능 교두(Functional cusp)' 위치는?",
    options:      ['협측 (Buccal)', '구개측 (Palatal)', '원심측 (Distal)', '근심측 (Mesial)'],
    correctIndex: 1,
    explanation:  '상악은 구개측 교두가, 하악은 협측 교두가 기능 교두로서 대합치와 긴밀하게 물리는 역할을 합니다.',
    sourcePage:   '12',
  },
  {
    question:     '하악 제1대구치 임시치아 제작 시 재현해야 하는 교두의 개수와 크기 순서로 옳은 것은?',
    options:      ['4교두 / 근협 > 원협', '5교두 / 근협 > 근설 > 원설', '3교두 / 원심 > 근심', '6교두 / 설측 중심'],
    correctIndex: 1,
    explanation:  '하악 제1대구치는 5교두이며, 크기는 근협 > 근설 > 원설 > 원협 > 원심 순으로 형성합니다.',
    sourcePage:   '12',
  },
  {
    question:     '하악 제2대구치의 교합면 중앙부에서 나타나는 가장 전형적인 그루브(Groove) 모양은?',
    options:      ['H자 모양', 'Y자 모양', '+자 모양', 'U자 모양'],
    correctIndex: 2,
    explanation:  '하악 제2대구치는 중앙 소와를 중심으로 십자가(+) 형태의 4교두 모양을 가집니다.',
    sourcePage:   '12',
  },
  {
    question:     '상악 소구치가 대구치나 하악 소구치에 비해 갖는 형태적 차별점은?',
    options:      ['교두 발달이 미미함', '교합면 중심선이 매우 깊음', '교두 발달이 가장 뚜렷함', '원형에 가까운 외형'],
    correctIndex: 2,
    explanation:  '상악 소구치는 교두가 매우 발달되어 있어, 대구치처럼 일률적인 중심선을 만들지 않아야 교두의 굴곡을 더 잘 살릴 수 있습니다.',
    sourcePage:   '32',
  },
  {
    question:     '하악 소구치 임시치아의 교합면 모양을 결정할 때 가장 우선적인 기준은?',
    options:      ['술자의 선호도', '반대 측 같은 번호 치아 모양', '대구치의 크기', '환자의 성별'],
    correctIndex: 1,
    explanation:  '하악 소구치는 Y자 또는 U자 모양이 다양하므로, 반대 측 동일 치아의 모양을 참고하여 제작하는 것이 원칙입니다.',
    sourcePage:   '38',
  },
  // ── 제4장 임상 팁 및 트러블슈팅 심화 ──
  {
    question:     "임시치아가 헐거워 '껄떡거리는' 현상이 발생할 때의 올바른 조치는?",
    options:      ['접착제 양을 대폭 증량', '내면을 충분히 파내고 리라이닝', '외형 연마만 다시 시행', '그대로 장착 후 경과 관찰'],
    correctIndex: 1,
    explanation:  '껄떡거리는 경우 접착제만으로는 유지가 불가능하여 쉽게 탈락하므로, 내면 삭제 후 흐름성 있는 레진으로 리라이닝해야 합니다.',
    sourcePage:   '40',
  },
  {
    question:     '리라이닝(Relining) 시 교합이 과도하게 높아지는 현상을 예방하기 위한 테크닉은?',
    options:      ['리라이닝 후 즉시 물리기', '협측에 피셔 버로 배출구 형성', '지대치 끝부분만 레진 도포', '차가운 물에 즉시 침전'],
    correctIndex: 1,
    explanation:  '협측에 작은 구멍을 내주면 리라이닝 시 잉여 레진이 그쪽으로 빠져나와 교합이 높아지는 것을 막아줍니다.',
    sourcePage:   '40',
  },
  {
    question:     "임시치아 조절 중 '비비탄 총알' 만한 크기의 구멍이 났을 때 가장 효과적인 수선법은?",
    options:      ['단순 애딩 (Adding)', '전체 리라이닝 (Relining)', '새롭게 재제작', '접착제로 구멍 봉쇄'],
    correctIndex: 1,
    explanation:  '바늘구멍 같은 미세 구멍은 애딩이 좋으나, 큰 구멍은 전체적인 적합도를 위해 리라이닝을 권장합니다.',
    sourcePage:   '41',
  },
  {
    question:     '지대치가 짧아 탈락률이 높을 것으로 예상되는 경우의 의도적인 교합 형성 전략은?',
    options:      ['교합이 아예 닿지 않게 제작', '대합치와 아주 긴밀하게 밀착', '협측에 큰 돌기 형성', '유지놀 시멘트 과량 사용'],
    correctIndex: 0,
    explanation:  '지대치가 짧거나 과민 반응이 있는 경우, 탈락 방지를 위해 의도적으로 교합이 닿지 않게(Out of occlusion) 제작하기도 합니다.',
    sourcePage:   '42',
  },
  // ── 제5장 교합 조정 및 마무리 단계 심화 ──
  {
    question:     "교합지 검사 시 '반드시 조정해야 하는' 점의 형태적 특징은?",
    options:      ['넓게 번지고 밀린 모양', '아주 작고 연한 점 모양', '기능 교두에 찍힌 단일 점', '인접면 근처에 찍힌 점'],
    correctIndex: 0,
    explanation:  '진하게 찍히거나 넓게 번지며 밀린 모양의 교합점은 과도한 간섭을 의미하므로 반드시 삭제 조정을 해야 합니다.',
    sourcePage:   '21',
  },
  {
    question:     "정상 교합 하악 임시치아의 교합 조정 시 '절대 찍혀서는 안 되는' 부위는?",
    options:      ['협측 (Buccal)', '설측 (Lingual)', '중심와 (Central pit)', '근심 삼각구'],
    correctIndex: 1,
    explanation:  '하악의 기능 교두는 협측이므로, 비기능 교두인 설측에는 교합점이 찍히지 않도록 조정해야 합니다.',
    sourcePage:   '27',
  },
  {
    question:     '피셔 버(Fissure bur)를 이용하여 임시치아에 그루브(Groove)와 소와(Pit)를 형성하는 주된 목적은?',
    options:      ['보철물의 무게 감소', '입체감 부여 및 저작 효율 증대', '접착제 배출로 확보', '변색 방지'],
    correctIndex: 1,
    explanation:  '적절한 그루브 형성은 치아를 더 입체적으로 보이게 할 뿐만 아니라 음식물 분쇄 등의 저작 기능을 돕습니다.',
    sourcePage:   '24',
  },
  {
    question:     '인접면 접촉(Contact) 상태를 확인할 때 구치부 사이의 가장 이상적인 접촉 형태는?',
    options:      ['1자 모양 (Line)', '네모 모양 (Square/Surface)', '점 모양 (Point)', '삼각형 모양 (Triangle)'],
    correctIndex: 1,
    explanation:  '전치부는 1자 모양이나 구치부 사이의 컨택은 안정적인 유지를 위해 네모 모양의 면 접촉으로 형성되어야 합니다.',
    sourcePage:   '16',
  },
  {
    question:     '연필로 표시한 마진 자국이 보철물 내부 리라이닝 후에도 비쳐 보이는 것을 방지하는 법은?',
    options:      ['수성 사인펜 사용', '리라이닝 전 연필 자국 버로 제거', '검은색 대신 노란색 연필 사용', '리라이닝 레진을 아주 두껍게 도포'],
    correctIndex: 1,
    explanation:  '연필 자국 위에 리라이닝을 하면 지워지지 않고 밖에서 비쳐 보이므로, 리라이닝 직전에 버로 지워주는 것이 심미적입니다.',
    sourcePage:   '40',
  },
  {
    question:     '미디엄 폴리싱 버(Medium polishing bur)의 임상적 다목적 기능으로 옳은 것은?',
    options:      ['오로지 광택만 내는 기능', '미세 삭제를 통한 최종 외형 정리', '인상재 기포 제거 기능', '치석 제거 보조 기능'],
    correctIndex: 1,
    explanation:  '폴리싱 버는 어느 정도 절삭력이 있어 연마뿐만 아니라 전체적인 외형의 마지막 라인을 잡기에도 매우 유용합니다.',
    sourcePage:   '10',
  },
  {
    question:     "임시치아 제작 중 '원샷원킬(One-shot one-kill)'을 위해 버(Bur) 교체 시 지켜야 할 원칙은?",
    options:      ['한 번 쓴 버는 다시 쓰지 않는 마음가짐', '매 단계마다 소독 후 교체', '가장 비싼 버만 단독 사용', '대합치를 깎을 때만 교체'],
    correctIndex: 0,
    explanation:  '반복적인 버 교체와 지대치 착탈 횟수를 최소화하는 것이 전체 제작 시간을 줄이는 가장 큰 핵심입니다.',
    sourcePage:   '10',
  },
  {
    question:     '정상 교합(Class 1)에서 상악의 기능 교두 모양이 비기능 교두에 비해 갖는 특징은?',
    options:      ['더 뾰족하고 날카로움', '더 완만하고 낮은 모양', '크기가 2배 이상 큼', '원심측으로 심하게 치우침'],
    correctIndex: 1,
    explanation:  '기능 교두는 대합치와 절구질을 하는 주된 부위이므로 비기능 교두에 비해 상대적으로 완만하고 둥근 모양을 가집니다.',
    sourcePage:   '12',
  },
  {
    question:     '임시치아를 장착한 환자에게 반드시 교육해야 할 음식 섭취 주의사항의 조합은?',
    options:      ['뜨겁고 매운 음식', '끈적하고 딱딱한 음식', '차갑고 신 음식', '부드럽고 짠 음식'],
    correctIndex: 1,
    explanation:  '임시치아는 강도가 낮고 임시 접착제로 붙어 있어 끈적하거나 딱딱한 음식에 의해 파절되거나 탈락될 위험이 큽니다.',
    sourcePage:   '79',
  },
  {
    question:     "리라이닝 시 레진 반죽의 농도가 '너무 걸쭉(Thick)'할 때 발생하는 부작용은?",
    options:      ['기포가 많이 생김', '교합이 높아짐', '색상이 탁해짐', '수축량이 급격히 감소함'],
    correctIndex: 1,
    explanation:  '반죽이 너무 걸쭉하면 임시치아가 지대치에 끝까지 들어가지 못해 최종 교합이 높아지는 결과를 초래합니다.',
    sourcePage:   '41',
  },
];

// ══════════════════════════════════════════════════════════════
// 추가 함수
// ══════════════════════════════════════════════════════════════

async function addTempCrownQuizzes() {
  console.log('🚀 구치부 임시치아 문제 추가 시작...\n');

  const poolRef = db.collection('quiz_pool');
  const metaRef = db.doc('quiz_meta/state');
  const now     = admin.firestore.Timestamp.now();

  // ── 1. 현재 최대 order 파악 ──
  console.log('🔍 현재 quiz_pool 상태 확인 중...');
  const existing = await poolRef.orderBy('order', 'desc').limit(1).get();
  let nextOrder = 1;
  if (!existing.empty) {
    nextOrder = existing.docs[0].data().order + 1;
  }
  const startOrder = nextOrder;
  console.log(`   현재 마지막 order: ${nextOrder - 1}, 새 시작 order: ${nextOrder}\n`);

  // ── 2. 임시치아 문제 저장 ──
  console.log('📝 구치부 임시치아 문제 저장 중...');

  for (let i = 0; i < tempCrownQuizzes.length; i++) {
    const q = tempCrownQuizzes[i];
    await poolRef.add({
      order:           nextOrder,
      question:        q.question,
      options:         q.options,
      correctIndex:    q.correctIndex,
      explanation:     q.explanation,
      category:        '임시치아',
      difficulty:      'intermediate',
      sourceBook:      TEMP_CROWN_BOOK,
      sourceFileName:  TEMP_CROWN_FILENAME,
      sourcePage:      q.sourcePage,
      isActive:        true,
      lastCycleServed: 0,
      createdAt:       now,
      updatedAt:       now,
    });
    process.stdout.write(`   [${i + 1}/${tempCrownQuizzes.length}] ${q.question.substring(0, 35)}...\r`);
    nextOrder++;
  }
  console.log(`\n   ✅ 임시치아 문제 ${tempCrownQuizzes.length}개 저장 완료\n`);

  // ── 3. quiz_meta/state totalActiveCount 업데이트 ──
  console.log('📊 quiz_meta/state 업데이트...');
  const metaSnap = await metaRef.get();
  const prevTotal = metaSnap.exists ? (metaSnap.data().totalActiveCount || 0) : 0;
  const newTotal  = prevTotal + tempCrownQuizzes.length;

  const updateData = {
    totalActiveCount: newTotal,
    updatedAt:        now,
  };

  // bookRotation에 새 책 추가
  if (metaSnap.exists) {
    const rotation = metaSnap.data().bookRotation || [];
    if (!rotation.includes(TEMP_CROWN_BOOK)) {
      updateData.bookRotation = [...rotation, TEMP_CROWN_BOOK];
    }
  }

  await metaRef.update(updateData);
  console.log(`   이전 총 문제 수: ${prevTotal}`);
  console.log(`   추가 문제 수:    ${tempCrownQuizzes.length}`);
  console.log(`   새 총 문제 수:   ${newTotal}`);
  console.log('   ✅ quiz_meta/state 업데이트 완료\n');

  console.log('═══════════════════════════════════════════');
  console.log(`✅ 완료! 구치부 임시치아 ${tempCrownQuizzes.length}문제 추가`);
  console.log(`   order 범위: ${startOrder} ~ ${nextOrder - 1}`);
  console.log(`   카테고리: 임시치아`);
  console.log(`   소스 책: ${TEMP_CROWN_BOOK}`);
  console.log(`   전체 풀 크기: ${newTotal}문제`);
  console.log('═══════════════════════════════════════════');

  process.exit(0);
}

addTempCrownQuizzes().catch((err) => {
  console.error('❌ 실패:', err);
  process.exit(1);
});
