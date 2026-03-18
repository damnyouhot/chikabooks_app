/**
 * 예진/초기검진 심화 30문항 추가 스크립트
 *
 * 실행:
 *   cd functions
 *   node scripts/add_initial_exam_quizzes.js
 */

const admin = require('firebase-admin');
const path = require('path');

const serviceAccount = require(path.join(__dirname, '..', '..', 'tools', 'serviceAccountKey.json'));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const EXAM_BOOK = '예진초기검진';
const EXAM_FILE = '치과책방_신입을_위한_친절한_임상문답.pdf';

const examQuizzes = [
  { question: '유치 설측 영구치 맹출 원인', options: ['공간 과잉','치배 설측','설측 이동','유치 흡수'], correctIndex:1, explanation: '영구 치아 치배는 유치보다 설측에 있어 공간 부족 시 설측 맹출.', sourcePage:'5' },
  { question: '상하악 발달 속도', options: ['상악 1년 빠름','하악 1년 빠름','동일','견치 먼저'], correctIndex:1, explanation: '하악이 상악보다 약 1년 빠르게 맹출.', sourcePage:'6' },
  { question: '영구치 색 차이 원인', options: ['법랑질↓','두께 2배','치수 퇴축','유기질↓'], correctIndex:1, explanation: '상아질/법랑질 두께 약 2배.', sourcePage:'7' },
  { question: '불소도포 작용/주기', options: ['산 촉진 1년','재광화 6개월','마모 3개월','치태 증진 매달'], correctIndex:1, explanation: '재광화/내산성 강화, 6개월.', sourcePage:'8' },
  { question: '방사선량 최소', options: ['CT','파노라마','치근단','자연'], correctIndex:2, explanation: '치근단 0.003mSv.', sourcePage:'9' },
  { question: '임산부 방사선', options: ['금지','납복','초기 촬영','무위험'], correctIndex:1, explanation: '납 복 사용.', sourcePage:'10' },
  { question: '크랙 진단 도구', options: ['파노라마','큐레이','냉검사','타진'], correctIndex:1, explanation: '큐레이/스틱 통증.', sourcePage:'11' },
  { question: '유치 방치 결과', options: ['속도 증가','부정교합','치수염 예','치배 소실'], correctIndex:1, explanation: '공간 상실/부정교합.', sourcePage:'12' },
  { question: '충치 진행 속도', options: ['소아 느림','소아 빠름','성인 필수','무관'], correctIndex:1, explanation: '소아가 더 빠름.', sourcePage:'14' },
  { question: '엠브레저 음식물', options: ['레진','구강용품','인레이','절개'], correctIndex:1, explanation: '구강위생용품 사용 권장.', sourcePage:'15' },
  { question: '신경치료 내원 주기 이유', options: ['경화','세균 제거','피로','청구'], correctIndex:1, explanation: '세균 제거/치유 시간 확보.', sourcePage:'16' },
  { question: '신경치료 후 크라운 이유', options: ['색상','영양 차단','재생','마모'], correctIndex:1, explanation: '영양 공급 차단으로 보호 필요.', sourcePage:'17' },
  { question: '치근단 농양 기전', options: ['당분','크랙','칫솔','스케일링'], correctIndex:1, explanation: '크랙/파절로 균 침입.', sourcePage:'18' },
  { question: '치경부 마모 주요 원인', options: ['횡마법','측방력','세정기','부드러운 음식'], correctIndex:1, explanation: '이갈이/측방력.', sourcePage:'19' },
  { question: '임시치아 탈락 오류', options: ['침하','근심 이동','증식','강도'], correctIndex:1, explanation: '인접치 이동.', sourcePage:'22' },
  { question: 'PT 금 함량', options: ['42-49','55-63','60-75','85-99'], correctIndex:2, explanation: 'PT 타입 금 60-75%.', sourcePage:'24' },
  { question: '금 보철물 이유', options: ['세균','분산','신경','재광화'], correctIndex:1, explanation: '저작력 분산/파절 방지.', sourcePage:'25' },
  { question: '왁스 덴쳐 전', options: ['예비 인상','개인 트레이','최종 합착','퇴축술'], correctIndex:1, explanation: '개인 트레이 본인상/바이트 채득.', sourcePage:'26' },
  { question: '보험 임플란트 부담', options: ['10%','20%','30%','50%'], correctIndex:2, explanation: '가입자 30% 본인 부담.', sourcePage:'28' },
  { question: '임플란트 음식물', options: ['전방 이동','자연 이동','마모','인대 증식'], correctIndex:1, explanation: '자연치가 이동하여 틈.', sourcePage:'31' },
  { question: '스케일링 주기', options: ['1년','6개월','2년','3개월'], correctIndex:1, explanation: '잇몸 안 좋으면 6개월.', sourcePage:'33' },
  { question: '출혈 원인', options: ['법랑질','모세혈관 확장','천공','응고'], correctIndex:1, explanation: '염증부 모세혈관 확장.', sourcePage:'36' },
  { question: '선행 단계', options: ['임플란트','스케일링','보철','미백'], correctIndex:1, explanation: '1차 스케일링 후 치주 치료.', sourcePage:'37' },
  { question: '각화 치은 증대', options: ['CTG','FGG','Bone','Sinus'], correctIndex:1, explanation: 'FGG로 각화 치은.', sourcePage:'39' },
  { question: '염증 마취 문제', options: ['알칼리화','산성화','확산 차단','저류'], correctIndex:1, explanation: '산성화되어 침투 어려움.', sourcePage:'42' },
  { question: '뼈 회복 기간', options: ['1-2주','1-3개월','6-1년','2년'], correctIndex:1, explanation: '1~3개월.', sourcePage:'43' },
  { question: '상악 최종 늦음', options: ['치밀골','해면골','혈류 부족','신경 위치'], correctIndex:1, explanation: '상악 해면골 구조로 치유 느림.', sourcePage:'45' },
  { question: 'NITI 와이어 말단', options: ['짧게','플라이어','고무','레진'], correctIndex:1, explanation: '씽치백 플라이어로 구부림.', sourcePage:'51' },
  { question: '와이어 교체 통증', options: ['제거','진통','냉수','중단'], correctIndex:1, explanation: '진통제 권장.', sourcePage:'52' },
  { question: '고정 유지장치 기간', options: ['1년','5년','평생','6개월'], correctIndex:2, explanation: '반영구적 유지.', sourcePage:'53' },
];

async function addInitialExamQuizzes() {
  console.log('🚀 예진/초기검진 문제 추가 시작...\\n');

  const poolRef = db.collection('quiz_pool');
  const metaRef = db.doc('quiz_meta/state');
  const now = admin.firestore.Timestamp.now();
  const existing = await poolRef.orderBy('order', 'desc').limit(1).get();
  let nextOrder = existing.empty ? 1 : existing.docs[0].data().order + 1;
  const startOrder = nextOrder;

  console.log(`🔍 현재 마지막 order: ${nextOrder - 1}, 새 시작 order: ${nextOrder}\\n`);
  console.log('📝 예진/초기검진 문제 저장 중...');

  for (let i = 0; i < examQuizzes.length; i++) {
    const quiz = examQuizzes[i];
    await poolRef.add({
      order:           nextOrder,
      question:        quiz.question,
      options:         quiz.options,
      correctIndex:    quiz.correctIndex,
      explanation:     quiz.explanation,
      category:        '예진',
      difficulty:      'advanced',
      sourceBook:      EXAM_BOOK,
      sourceFileName:  EXAM_FILE,
      sourcePage:      quiz.sourcePage,
      isActive:        true,
      lastCycleServed: 0,
      createdAt:       now,
      updatedAt:       now,
    });
    process.stdout.write(`   [${i + 1}/${examQuizzes.length}] ${quiz.question.substring(0, 35)}...\\r`);
    nextOrder++;
  }
  console.log(`\\n   ✅ 예진/초기검진 문제 ${examQuizzes.length}개 저장 완료\\n`);

  console.log('📊 quiz_meta/state 업데이트...');
  const metaSnap = await metaRef.get();
  const prevTotal = metaSnap.exists ? (metaSnap.data().totalActiveCount || 0) : 0;
  const newTotal = prevTotal + examQuizzes.length;
  const updateData = { totalActiveCount: newTotal, updatedAt: now };
  if (metaSnap.exists) {
    const rotation = metaSnap.data().bookRotation || [];
    if (!rotation.includes(EXAM_BOOK)) updateData.bookRotation = [...rotation, EXAM_BOOK];
  }
  await metaRef.update(updateData);
  console.log(`   이전 총 문제 수: ${prevTotal}`);
  console.log(`   추가 문제 수:    ${examQuizzes.length}`);
  console.log(`   새 총 문제 수:   ${newTotal}`);
  console.log('   ✅ quiz_meta/state 업데이트 완료\\n');

  console.log('═══════════════════════════════════════════');
  console.log(`✅ 완료! 예진/초기검진 30문제 추가`);
  console.log(`   order 범위: ${startOrder} ~ ${nextOrder - 1}`);
  console.log(`   카테고리: 예진`);
  console.log(`   소스 책: ${EXAM_BOOK}`);
  console.log(`   전체 풀 크기: ${newTotal}문제`);
  console.log('═══════════════════════════════════════════');

  process.exit(0);
}

addInitialExamQuizzes().catch((err) => {
  console.error('❌ 실패:', err);
  process.exit(1);
});






