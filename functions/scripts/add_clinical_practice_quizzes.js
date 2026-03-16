/**
 * 임상 실무 심화 30문항 추가 스크립트
 *
 * 실행:
 *   cd functions
 *   node scripts/add_clinical_practice_quizzes.js
 */

const admin = require('firebase-admin');
const path = require('path');

const serviceAccount = require(path.join(__dirname, '..', '..', 'tools', 'serviceAccountKey.json'));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const PRACTICE_BOOK = '임상실무_심화';
const PRACTICE_FILE = '일주일_만에_따라잡는_신입_치과임상.pdf';

const practiceQuizzes = [
  { question: '정적 영역(12시~2시)의 기능은?', options:['술자 직접 공간','기구 전달','보조자 장비','환자 하악 비추기'], correctIndex:1, explanation:'12시~2시는 기구가 놓이며 환자 머리 뒤로 전달되는 정적 영역입니다.', sourcePage:'10,11'},
  { question: '파노라마 V-shape 왜곡은?', options:['하악 전치 확대','과도한 스마일 라인','구치부 겹침','상악동 차단'], correctIndex:1, explanation:'턱을 들이면 스마일라인 과도하게 휘어짐.', sourcePage:'15'},
  { question: 'CBCT 보험 적용 가능한 상황은?', options:['임플란트 전','교정 진단','완전 매복 신경관 중첩','단순 파절'], correctIndex:2, explanation:'완전 매복치와 신경 중첩 시 보험 적용.', sourcePage:'17'},
  { question: '소구치 등각 촬영 방향', options:['코 중앙 세로','코 측 면 세로','코측-눈앞머리 가로','동공 중앙 가로'], correctIndex:2, explanation:'코 측면~눈 앞머리에서 가로로 위치.', sourcePage:'18'},
  { question: 'Abr vs Att 병태생리 차이', options:['Abr 교모/Att 마모','Abr 마모/Att 교모','둘다 우식','Abr 파절/Att 동요'], correctIndex:1, explanation:'Abr은 마모, Att는 교모.', sourcePage:'22'},
  { question: '스케일러 팁 마모 한계', options:['0.5mm','1mm','2mm 이상','1년 주기'], correctIndex:2, explanation:'2mm 이상 마모 시 교체.', sourcePage:'26'},
  { question: '헥사메딘 장기간 부작용', options:['법랑질 부식','2주 착색','미각 상실','잇몸 증식'], correctIndex:1, explanation:'2주 이상 사용 시 착색 유발.', sourcePage:'27,28'},
  { question: 'Size1 러버댐 펀치 대상', options:['상악 전치','유구치 소구치','유전치 하악 전치','대구치'], correctIndex:2, explanation:'가장 작은 구멍은 유전치/하악 전치.', sourcePage:'38'},
  { question: 'Outer nut 역할', options:['밴드 크기','밴드 고정','쐐기 압박','접촉점'], correctIndex:1, explanation:'Outer nut은 밴드를 슬롯에 고정.', sourcePage:'43,44'},
  { question: 'Etching 영향/시간', options:['재생/60s 이상','민감도 증가/15-30s','연화/1분','세균억제/10s 미만'], correctIndex:1, explanation:'15~30초로 민감도 증가 가능.', sourcePage:'50'},
  { question: 'GI 혼합 외관/시간', options:['무광/1분','광택/30초','가루/10초','투명액/2분'], correctIndex:1, explanation:'광택나면 접착력 좋으며 30초 유지.', sourcePage:'54'},
  { question: '상악 대구치 근관 수', options:['1','3','4','2'], correctIndex:2, explanation:'보통 MB2 포함 4개.', sourcePage:'63'},
  { question: 'Endo-Z 특징', options:['끝만 날','옆면 날','다이아몬드 없음','짧음'], correctIndex:1, explanation:'옆면에만 날 있어 치수저 보호.', sourcePage:'62'},
  { question: 'Root ZX 접촉 고리 위치', options:['치아 측면','입꼬리','반대 입꼬리','엄지'], correctIndex:2, explanation:'반대 편 입꼬리에 고리를 걸어 회로.', sourcePage:'70'},
  { question: '교합면 삭제 이유', options:['입구 확보','외상 방지','마취 증대','비용 절감'], correctIndex:1, explanation:'저작 시 파절/통증 막기 위해.', sourcePage:'69'},
  { question: '캐비톤 경화/지도', options:['광중합','수분 접촉/30분','열 가압','공기 노출'], correctIndex:1, explanation:'타액과 만나 굳으며 30분까지 주의.', sourcePage:'67,70'},
  { question: '치근단 엑스레이 목적', options:['우식','충전재 도달','골 밀도','마취'], correctIndex:1, explanation:'충전재가 뿌리 끝까지 도달했는지 확인.', sourcePage:'74'},
  { question: 'Light body 에어', options:['경화 촉진','기포 제거','타액 억제','구역질 방지'], correctIndex:1, explanation:'기포 제거와 마진 재현.', sourcePage:'78'},
  { question: '지르코니아 장점', options:['삭제 최소','금속 없는 심미/강도','투명도','저비용'], correctIndex:1, explanation:'금속 없지만 강도/심미 우수.', sourcePage:'83'},
  { question: '알지네이트 경화 조절', options:['분말2배','찬물 사용','천천히 혼합','트레이 가열'], correctIndex:1, explanation:'찬물로 경화 지연.', sourcePage:'94'},
  { question: 'Block out 목적', options:['색상','인상재 추출 방지','마취 흡수','출혈 유도'], correctIndex:1, explanation:'인상재가 동요 치아에 끼는 것을 방지.', sourcePage:'95'},
  { question: '석고 주입 원칙', options:['중앙','한쪽 끝','뜨거운 물','불기'], correctIndex:1, explanation:'한쪽 끝에서 천천히 흐르게.', sourcePage:'103'},
  { question: 'No.12 블레이드 특징', options:['둥근','갈고리','삼각형','직선'], correctIndex:1, explanation:'갈고리 형태로 후방 접근 용이.', sourcePage:'106'},
  { question: '상악 대구치 포셉 구분', options:['갈퀴 방향','길이','색','번호'], correctIndex:0, explanation:'갈퀴가 협측으로 향함.', sourcePage:'107'},
  { question: 'Bone File 조작 방향', options:['밀기/증식','당기기/골연 제거','회전/신경','두드림/혈전'], correctIndex:1, explanation:'당기는 힘으로 골연 제거.', sourcePage:'108'},
  { question: '복잡 매복 정의', options:['잇몸만','분할','골 삭제','CT 없이'], correctIndex:1, explanation:'치아 분할 후 발치하는 경우.', sourcePage:'113'},
  { question: 'Elevator 비유', options:['망치','지렛대','가위','붓'], correctIndex:1, explanation:'지렛대 원리로 탈구.', sourcePage:'115'},
  { question: 'Saline Syringe 이유', options:['갈증','열 억제','마취 유지','인상재'], correctIndex:1, explanation:'버 열을 줄여 골 괴사 방지.', sourcePage:'109,119'},
  { question: 'Dean Scissors 조작', options:['날 열고','구각 평면','설측 향','세 손가락'], correctIndex:1, explanation:'평평한 면으로 구각 지지하여 자름.', sourcePage:'120'},
  { question: '거즈 가습 이유', options:['감염','혈병 유착','마취','미백'], correctIndex:1, explanation:'물에 적셔 혈병 재출혈 방지.', sourcePage:'121'},
];

async function addClinicalPracticeQuizzes() {
  console.log('🚀 임상 실무 문제 추가 시작...\\n');

  const poolRef = db.collection('quiz_pool');
  const metaRef = db.doc('quiz_meta/state');
  const now = admin.firestore.Timestamp.now();

  const existing = await poolRef.orderBy('order', 'desc').limit(1).get();
  let nextOrder = existing.empty ? 1 : existing.docs[0].data().order + 1;
  const startOrder = nextOrder;

  console.log(`🔍 현재 마지막 order: ${nextOrder - 1}, 새 시작 order: ${nextOrder}\\n`);
  console.log('📝 임상 실무 문제 저장 중...');

  for (let i = 0; i < practiceQuizzes.length; i++) {
    const quiz = practiceQuizzes[i];
    await poolRef.add({
      order:           nextOrder,
      question:        quiz.question,
      options:         quiz.options,
      correctIndex:    quiz.correctIndex,
      explanation:     quiz.explanation,
      category:        '임상',
      difficulty:      'advanced',
      sourceBook:      PRACTICE_BOOK,
      sourceFileName:  PRACTICE_FILE,
      sourcePage:      quiz.sourcePage,
      isActive:        true,
      lastCycleServed: 0,
      createdAt:       now,
      updatedAt:       now,
    });
    process.stdout.write(`   [${i + 1}/${practiceQuizzes.length}] ${quiz.question.substring(0, 35)}...\\r`);
    nextOrder++;
  }
  console.log(`\\n   ✅ 임상 실무 문제 ${practiceQuizzes.length}개 저장 완료\\n`);

  console.log('📊 quiz_meta/state 업데이트...');
  const metaSnap = await metaRef.get();
  const prevTotal = metaSnap.exists ? (metaSnap.data().totalActiveCount || 0) : 0;
  const newTotal = prevTotal + practiceQuizzes.length;
  const updateData = { totalActiveCount: newTotal, updatedAt: now };
  if (metaSnap.exists) {
    const rotation = metaSnap.data().bookRotation || [];
    if (!rotation.includes(PRACTICE_BOOK)) updateData.bookRotation = [...rotation, PRACTICE_BOOK];
  }
  await metaRef.update(updateData);
  console.log(`   이전 총 문제 수: ${prevTotal}`);
  console.log(`   추가 문제 수:    ${practiceQuizzes.length}`);
  console.log(`   새 총 문제 수:   ${newTotal}`);
  console.log('   ✅ quiz_meta/state 업데이트 완료\\n');

  console.log('═══════════════════════════════════════════');
  console.log(`✅ 완료! 임상 실무 심화 30문제 추가`);
  console.log(`   order 범위: ${startOrder} ~ ${nextOrder - 1}`);
  console.log(`   카테고리: 임상`);
  console.log(`   소스 책: ${PRACTICE_BOOK}`);
  console.log(`   전체 풀 크기: ${newTotal}문제`);
  console.log('═══════════════════════════════════════════');

  process.exit(0);
}

addClinicalPracticeQuizzes().catch((err) => {
  console.error('❌ 실패:', err);
  process.exit(1);
});



