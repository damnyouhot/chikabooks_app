/**
 * 약리학 심화 30문항 추가 스크립트
 *
 * 실행:
 *   cd functions
 *   node scripts/add_pharmacology_quizzes.js
 */

const admin = require('firebase-admin');
const path = require('path');

const serviceAccount = require(path.join(__dirname, '..', '..', 'tools', 'serviceAccountKey.json'));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const PHARM_BOOK = '임상약리';
const PHARM_FILE = '치과책방_치과_처방약_바로_알기.pdf';

const pharmQuizzes = [
  { question: 'DUR 지침에서 틀린 항목', options:['NSAIDs 포함','고가약 지양','부작용 설명 생략','문진 필수'], correctIndex:2, explanation:'부작용 설명은 반드시 해야 함.', sourcePage:'8' },
  { question: '아세트아미노펜 특성', options:['말초 PG 차단','중추 작용 공복','NSAID 교차','최대 2,000mg'], correctIndex:1, explanation:'중추 작용, 공복 가능.', sourcePage:'11' },
  { question: '트라마돌 복용 주의', options:['비마약','전문의약품','간부전 조절','음주 가능'], correctIndex:3, explanation:'술과 함께 복용 금지.', sourcePage:'12' },
  { question: '울트라셋 복용법', options:['12시간','16알','6시간','분쇄'], correctIndex:0, explanation:'ER 제제 12시간 간격.', sourcePage:'13,76' },
  { question: 'NSAIDs 부작용', options:['위 보호','혈압 상승','간 우위','호흡기 확장'], correctIndex:1, explanation:'심혈관 위험/혈압 상승.', sourcePage:'14' },
  { question: '덱시부프로펜 장점', options:['동일','70% 용량','3,200mg','500mg'], correctIndex:1, explanation:'70% 용량으로 효과.', sourcePage:'16' },
  { question: '록소프로펜 특징', options:['프로드럭','마약','1일1회','스테로이드'], correctIndex:0, explanation:'전구약물 형태.', sourcePage:'17,76' },
  { question: '나프록센 전략', options:['3회 항생제','나트륨염','2회 항생제','3,000mg'], correctIndex:2, explanation:'1일2회 항생제 병용 적합.', sourcePage:'18' },
  { question: '아세클로페낙 지식', options:['8시간','최단용량','분쇄','200mg'], correctIndex:1, explanation:'최소/최단.', sourcePage:'20' },
  { question: '프레드니솔론 확인', options:['당뇨','저혈압','포진','위염'], correctIndex:0, explanation:'혈당 상승 위해 당뇨 확인.', sourcePage:'23' },
  { question: '오구멘틴 근거', options:['알레르기','효소 억제','임산부','2g 단회'], correctIndex:1, explanation:'클라불란산으로 효소 억제.', sourcePage:'29' },
  { question: '메트로니다졸 금기', options:['알코올','응고','효과','동일'], correctIndex:0, explanation:'알코올 분해 억제.', sourcePage:'31' },
  { question: '클린다마이신 용도', options:['골 침투','세팔로 실패','1회','청소년'], correctIndex:0, explanation:'골 침투력 높음.', sourcePage:'33' },
  { question: '세팔로스포린 특징', options:['교차','저렴','안전','음성 효과'], correctIndex:1, explanation:'페니실린보다 비쌈.', sourcePage:'34' },
  { question: '레보플록사신 금기', options:['18세/NSAID','임산부/제산','고혈압','신부전'], correctIndex:0, explanation:'18세 이하/NSAID 주의.', sourcePage:'35' },
  { question: '록시트로마이신 조합', options:['3회/이부','2회/나프록센','1회/아스','우유'], correctIndex:1, explanation:'1일2회, 나프록센 병용.', sourcePage:'36' },
  { question: '미노사이클린 정책', options:['비급여','2회','가글','부작용'], correctIndex:0, explanation:'2018년 비급여.', sourcePage:'37' },
  { question: '감염성 심내막염 예방', options:['진료1h전2g','직후1g','전날500mg','30분500mg'], correctIndex:0, explanation:'2g 단회.', sourcePage:'62' },
  { question: '알마게이트 금기', options:['테트라','아목','메트로','록시'], correctIndex:0, explanation:'테트라 흡수 저해.', sourcePage:'41' },
  { question: '에스오메프라졸 특징', options:['상병 필요','3회','임부금기','가루'], correctIndex:0, explanation:'추가 상병 없이 인정.', sourcePage:'42' },
  { question: '라푸티딘 장점', options:['야간 억제','식후','임부','투석'], correctIndex:0, explanation:'야간 위산 억제.', sourcePage:'43' },
  { question: '애엽 주의', options:['유당','고혈압','갑상선','천식'], correctIndex:0, explanation:'유당 포함.', sourcePage:'44' },
  { question: '슈도에페드린 부작용', options:['두근/불면','서맥','근 이완','마비'], correctIndex:0, explanation:'교감 흥분.', sourcePage:'51' },
  { question: '가바펜린 상병', options:['턱관절/졸음','근육/공복','유당/활동','100mg/운전'], correctIndex:0, explanation:'턱관절/졸음 주의.', sourcePage:'54' },
  { question: '카르바마제핀 용도', options:['삼차/1,200','재생/2,000','변색/500','지혈/100'], correctIndex:0, explanation:'삼차신경통, 1,200mg.', sourcePage:'57' },
  { question: '가바펜틴 증량', options:['3일','고용량','제산','소아'], correctIndex:0, explanation:'3일 간 서서히.', sourcePage:'58-59' },
  { question: '프레가발린 장점', options:['흡수','부종','3,600','면제'], correctIndex:0, explanation:'흡수 빠름.', sourcePage:'60' },
  { question: '임산부 안전 조합', options:['리도카인/아세','아티카인/이부','에피네프린/테트라','프릴로카인/아세'], correctIndex:0, explanation:'안전 조합.', sourcePage:'63-64' },
  { question: '소아 시럽 공식', options:['몸무게','몸무게','몸무게','나이'], correctIndex:0, explanation:'1ml=32mg.', sourcePage:'78' },
  { question: '오구멘틴 보관', options:['냉장7일','실온14일','햇빛','몸무게'], correctIndex:0, explanation:'냉장 7일.', sourcePage:'74,80' },
];

async function addPharmacologyQuizzes() {
  console.log('🚀 약리학 문제 추가 시작...\\n');
  const poolRef = db.collection('quiz_pool');
  const metaRef = db.doc('quiz_meta/state');
  const now = admin.firestore.Timestamp.now();
  const existing = await poolRef.orderBy('order', 'desc').limit(1).get();
  let nextOrder = existing.empty ? 1 : existing.docs[0].data().order + 1;
  const startOrder = nextOrder;

  console.log(`🔍 현재 마지막 order: ${nextOrder - 1}, 새 시작 order: ${nextOrder}\\n`);
  console.log('📝 약리학 문제 저장 중...');

  for (let i = 0; i < pharmQuizzes.length; i++) {
    const quiz = pharmQuizzes[i];
    await poolRef.add({
      order:           nextOrder,
      question:        quiz.question,
      options:         quiz.options,
      correctIndex:    quiz.correctIndex,
      explanation:     quiz.explanation,
      category:        '약리학',
      difficulty:      'advanced',
      sourceBook:      PHARM_BOOK,
      sourceFileName:  PHARM_FILE,
      sourcePage:      quiz.sourcePage,
      isActive:        true,
      lastCycleServed: 0,
      createdAt:       now,
      updatedAt:       now,
    });
    process.stdout.write(`   [${i + 1}/${pharmQuizzes.length}] ${quiz.question.substring(0, 35)}...\\r`);
    nextOrder++;
  }
  console.log(`\\n   ✅ 약리학 문제 ${pharmQuizzes.length}개 저장 완료\\n`);

  console.log('📊 quiz_meta/state 업데이트...');
  const metaSnap = await metaRef.get();
  const prevTotal = metaSnap.exists ? (metaSnap.data().totalActiveCount || 0) : 0;
  const newTotal = prevTotal + pharmQuizzes.length;
  const updateData = { totalActiveCount: newTotal, updatedAt: now };
  if (metaSnap.exists) {
    const rotation = metaSnap.data().bookRotation || [];
    if (!rotation.includes(PHARM_BOOK)) updateData.bookRotation = [...rotation, PHARM_BOOK];
  }
  await metaRef.update(updateData);
  console.log(`   이전 총 문제 수: ${prevTotal}`);
  console.log(`   추가 문제 수:    ${pharmQuizzes.length}`);
  console.log(`   새 총 문제 수:   ${newTotal}`);
  console.log('   ✅ quiz_meta/state 업데이트 완료\\n');

  console.log('═══════════════════════════════════════════');
  console.log(`✅ 완료! 약리학 30문제 추가`);
  console.log(`   order 범위: ${startOrder} ~ ${nextOrder - 1}`);
  console.log(`   카테고리: 약리학`);
  console.log(`   소스 책: ${PHARM_BOOK}`);
  console.log(`   전체 풀 크기: ${newTotal}문제`);
  console.log('═══════════════════════════════════════════');

  process.exit(0);
}

addPharmacologyQuizzes().catch((err) => {
  console.error('❌ 실패:', err);
  process.exit(1);
});






