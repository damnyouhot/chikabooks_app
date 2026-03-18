/**
 * 임상 기구/술식 공학 심화 30문항 추가 스크립트
 *
 * 실행:
 *   cd functions
 *   node scripts/add_engineering_quizzes.js
 */

const admin = require('firebase-admin');
const path = require('path');

const serviceAccount = require(path.join(__dirname, '..', '..', 'tools', 'serviceAccountKey.json'));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const ENGINEERING_BOOK = '기구술식_공학';
const ENGINEERING_FILE = '나에게_힘이_되는_치과_임상_기구_술식.pdf';

const engineeringQuizzes = [
  { question: 'RP vs CU 마취 차이', options:['RP 필수','CU 필수','RP 큐렛 금지','CU 탐침 생략'], correctIndex:1, explanation:'CU는 염증 제거 때문에 마취 필수, RP는 선택.', sourcePage:'5'},
  { question: '치은박리소파술 보조 핵심', options:['석션 방향','블레이드 교체','포대 부착','큐렛 확인'], correctIndex:0, explanation:'출혈 막기 위해 술자 방향으로 메탈 석션 유지.', sourcePage:'6'},
  { question: '#12 vs #15 블레이드', options:['12 섬세','12 깊숙','15 성형','15 기공'], correctIndex:1, explanation:'#12는 깊숙한 절개용, #15는 일반 절개.', sourcePage:'7'},
  { question: '포대 혼합 팁', options:['베이스2배','셀라인','공기건조','뜨거운물'], correctIndex:1, explanation:'셀라인 담가 끈기 제거.', sourcePage:'6,8'},
  { question: '골이식 석션 주의', options:['이식 후 석션 금지','이식 전 중단','강한 음압','설석션만'], correctIndex:0, explanation:'이식 후 석션 피해야 입자 유실.', sourcePage:'9'},
  { question: 'GTR vs GBR 차이', options:['골이식 여부','치주인대재생','막 사용','봉합사'], correctIndex:1, explanation:'GTR은 치주인대 세포 재생 목적.', sourcePage:'10'},
  { question: '골이식재 최고', options:['합성','자가골','동종','이종'], correctIndex:1, explanation:'자가골은 면역 거부 없고 골성능 모두.', sourcePage:'11'},
  { question: 'Kirkland vs Orban 용도', options:['Orban 치간','Kirkland 치간','Orban 마진','Kirkland 천공'], correctIndex:0, explanation:'Orban은 치간 유두 제거.', sourcePage:'12'},
  { question: 'Bovie 안내사항', options:['미각 상실','타는 냄새','변색','마비'], correctIndex:1, explanation:'전기소작 시 타는 냄새 유발.', sourcePage:'13'},
  { question: 'CLP vs GGV', options:['치주 상병 금지','잇몸 부기','치석 목적','비급여'], correctIndex:0, explanation:'CLP는 보철 목적이라 치주 상병 낮음.', sourcePage:'14'},
  { question: 'Utility wax 역할', options:['마진 재현','교합 확인','경화 단축','지혈'], correctIndex:1, explanation:'왁스로 교합 고경 확인.', sourcePage:'19,20'},
  { question: '유지놀 주의', options:['금 부식','레진 방해','세라믹 저하','인상재 변형'], correctIndex:1, explanation:'레진 시멘트 경화 방해.', sourcePage:'22'},
  { question: '픽업 인상 정밀 이유', options:['코핑 고정','알지 변형','드라이버','힐링'], correctIndex:0, explanation:'코핑이 인상체에 고정되어 변형 없음.', sourcePage:'33,34'},
  { question: 'Long copings 기준', options:['힐링 >=7mm','직경<=3','개구장애','비보험'], correctIndex:0, explanation:'힐링 높이 7mm 이상 시 Long.', sourcePage:'35'},
  { question: 'SCRP 장점', options:['무 Hole','분리 용이','접착제','지르코전용'], correctIndex:1, explanation:'나사 분리로 보철 수리 간편.', sourcePage:'40'},
  { question: 'Zirconia 폴리싱 순서', options:['노랑>빨강>파랑','파랑>빨강>노랑','빨강>파랑>노랑','흰>회>녹'], correctIndex:1, explanation:'입자 크기 따라 파랑→빨강→노랑.', sourcePage:'27'},
  { question: '덴쳐 알지네이트', options:['뜨거운','차가운','여름','과 믹싱'], correctIndex:1, explanation:'차가운 물로 경화 지연.', sourcePage:'28'},
  { question: 'Border molding 명칭', options:['Block out','Border molding','Wax rim','Pick up'], correctIndex:1, explanation:'왁스로 변연 인기.', sourcePage:'29'},
  { question: 'SE Bond 법랑질', options:['에칭','프라이머','과산화','생략'], correctIndex:0, explanation:'법랑질은 별도 에칭.', sourcePage:'42'},
  { question: '골드 인레이 추천', options:['레진','골드','세라믹','하이브리드'], correctIndex:1, explanation:'연성·적합도 뛰어나.', sourcePage:'44'},
  { question: 'Barbed broach 용도', options:['Barbed broach','GG','Paper','Plugger'], correctIndex:0, explanation:'치수 조직 걸어 제거.', sourcePage:'48'},
  { question: 'NaOCl 안전', options:['삼키','석션','고온','에어'], correctIndex:1, explanation:'메탈 석션으로 흡입.', sourcePage:'48,49'},
  { question: 'Caviton 경화', options:['광중합','수분','24h','열'], correctIndex:1, explanation:'타액과 접촉해 경화.', sourcePage:'48'},
  { question: 'Sealer 역할', options:['Sealer','Etchant','Vitapex','MTA'], correctIndex:0, explanation:'GP와 벽 밀봉.', sourcePage:'51'},
  { question: 'Pulpotomy 이유', options:['근단 성장','미백','탈락','박멸'], correctIndex:0, explanation:'근단 성장 유지.', sourcePage:'54'},
  { question: 'FC 대체 이유', options:['Formocresol','Saline','NaOCl','ZOE'], correctIndex:0, explanation:'FC 발암 우려로 MTA 증가.', sourcePage:'55'},
  { question: '드릴링 순서 최초 표시', options:['Twist','Guide','Taper','Sidecut'], correctIndex:1, explanation:'Guide drill이 위치 마킹.', sourcePage:'57'},
  { question: 'Cover screw 목적', options:['Healing','Cover screw','Transfer','Analog'], correctIndex:1, explanation:'픽스쳐 보호 및 묻기.', sourcePage:'58'},
  { question: 'Tissue punch 사용', options:['치은 절개','골이식','봉합 제거','인상'], correctIndex:0, explanation:'절개 없이 조직만 천공.', sourcePage:'59'},
  { question: 'Healing abutment 높이', options:['1~2mm 노출','강하게 교합','3mm 함몰','무관 7mm'], correctIndex:0, explanation:'치은 위로 약 1~2mm.', sourcePage:'60'},
];

async function addEngineeringQuizzes() {
  console.log('🚀 기구술식 공학 문제 추가 시작...\\n');

  const poolRef = db.collection('quiz_pool');
  const metaRef = db.doc('quiz_meta/state');
  const now = admin.firestore.Timestamp.now();
  const existing = await poolRef.orderBy('order', 'desc').limit(1).get();
  let nextOrder = existing.empty ? 1 : existing.docs[0].data().order + 1;
  const startOrder = nextOrder;

  console.log(`🔍 현재 마지막 order: ${nextOrder - 1}, 새 시작 order: ${nextOrder}\\n`);
  console.log('📝 기구술식 공학 문제 저장 중...');

  for (let i = 0; i < engineeringQuizzes.length; i++) {
    const quiz = engineeringQuizzes[i];
    await poolRef.add({
      order:           nextOrder,
      question:        quiz.question,
      options:         quiz.options,
      correctIndex:    quiz.correctIndex,
      explanation:     quiz.explanation,
      category:        '기구술식',
      difficulty:      'advanced',
      sourceBook:      ENGINEERING_BOOK,
      sourceFileName:  ENGINEERING_FILE,
      sourcePage:      quiz.sourcePage,
      isActive:        true,
      lastCycleServed: 0,
      createdAt:       now,
      updatedAt:       now,
    });
    process.stdout.write(`   [${i + 1}/${engineeringQuizzes.length}] ${quiz.question.substring(0, 35)}...\\r`);
    nextOrder++;
  }
  console.log(`\\n   ✅ 기구술식 공학 문제 ${engineeringQuizzes.length}개 저장 완료\\n`);

  console.log('📊 quiz_meta/state 업데이트...');
  const metaSnap = await metaRef.get();
  const prevTotal = metaSnap.exists ? (metaSnap.data().totalActiveCount || 0) : 0;
  const newTotal = prevTotal + engineeringQuizzes.length;
  const updateData = { totalActiveCount: newTotal, updatedAt: now };
  if (metaSnap.exists) {
    const rotation = metaSnap.data().bookRotation || [];
    if (!rotation.includes(ENGINEERING_BOOK)) updateData.bookRotation = [...rotation, ENGINEERING_BOOK];
  }
  await metaRef.update(updateData);
  console.log(`   이전 총 문제 수: ${prevTotal}`);
  console.log(`   추가 문제 수:    ${engineeringQuizzes.length}`);
  console.log(`   새 총 문제 수:   ${newTotal}`);
  console.log('   ✅ quiz_meta/state 업데이트 완료\\n');

  console.log('═══════════════════════════════════════════');
  console.log(`✅ 완료! 기구/술식 공학 30문제 추가`);
  console.log(`   order 범위: ${startOrder} ~ ${nextOrder - 1}`);
  console.log(`   카테고리: 기구술식`);
  console.log(`   소스 책: ${ENGINEERING_BOOK}`);
  console.log(`   전체 풀 크기: ${newTotal}문제`);
  console.log('═══════════════════════════════════════════');

  process.exit(0);
}

addEngineeringQuizzes().catch((err) => {
  console.error('❌ 실패:', err);
  process.exit(1);
});






