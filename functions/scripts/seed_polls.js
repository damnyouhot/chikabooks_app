/**
 * 공감투표 시드 데이터 등록 스크립트
 *
 * 퀴즈 스케줄과 동일한 방식으로 polls를 미리 등록하고,
 * startsAt/endsAt를 설정하여 하루 1개씩 자동 등장하게 한다.
 *
 * 실행:
 *   cd functions
 *   node scripts/seed_polls.js
 *
 * 옵션:
 *   node scripts/seed_polls.js --start 2026-03-20   (시작일 지정)
 *   node scripts/seed_polls.js --clear               (기존 데이터 삭제 후 재등록)
 */

const admin = require('firebase-admin');
const path = require('path');

const serviceAccount = require(path.join(__dirname, '..', '..', 'tools', 'serviceAccountKey.json'));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

// ═══════════════════════════════════════════════════════════════
// 투표 데이터 — 치과위생사 일상/공감 주제
// ═══════════════════════════════════════════════════════════════
const POLLS = [
  {
    question: '요즘 가장 힘든 순간은?',
    category: '일상',
    options: [
      '환자 컴플레인 받을 때',
      '야근이 길어질 때',
      '동료와 의견이 다를 때',
      '체력이 바닥날 때',
    ],
  },
  {
    question: '퇴근 후 가장 하고 싶은 건?',
    category: '일상',
    options: [
      '아무것도 안 하고 누워있기',
      '맛있는 거 먹으러 가기',
      '운동하기',
      '넷플릭스/유튜브 보기',
    ],
  },
  {
    question: '신입 시절 가장 힘들었던 건?',
    category: '커리어',
    options: [
      '환자 응대가 어려웠다',
      '기구/재료 이름 외우기',
      '선배 눈치 보기',
      '체력 적응',
    ],
  },
  {
    question: '점심시간에 주로 뭐 해?',
    category: '일상',
    options: [
      '밥 먹고 낮잠',
      '핸드폰 보기',
      '동료랑 수다',
      '밖에 나가서 산책',
    ],
  },
  {
    question: '스케일링할 때 가장 신경 쓰이는 건?',
    category: '임상',
    options: [
      '환자가 아프다고 할 때',
      '치석이 너무 많을 때',
      '혀가 계속 올라올 때',
      '출혈이 많을 때',
    ],
  },
  {
    question: '이직을 고민하게 되는 이유는?',
    category: '커리어',
    options: [
      '연봉이 낮아서',
      '인간관계가 힘들어서',
      '성장이 안 되는 느낌',
      '워라밸이 안 맞아서',
    ],
  },
  {
    question: '환자한테 가장 듣기 싫은 말은?',
    category: '임상',
    options: [
      '"안 아프게 해주세요"',
      '"왜 이렇게 오래 걸려요?"',
      '"간호사님~"',
      '"저번에 다른 분이 더 잘했는데"',
    ],
  },
  {
    question: '주말에 주로 뭐 하고 지내?',
    category: '일상',
    options: [
      '집에서 쉬기',
      '카페 가기',
      '친구 만나기',
      '자기계발/공부',
    ],
  },
  {
    question: '치과위생사 하면서 가장 보람 있을 때는?',
    category: '커리어',
    options: [
      '환자가 고마워할 때',
      '실력이 늘었다고 느낄 때',
      '월급날',
      '후배한테 가르쳐줄 때',
    ],
  },
  {
    question: '직장에서 가장 스트레스 받는 관계는?',
    category: '일상',
    options: [
      '원장님',
      '선배 위생사',
      '까다로운 환자',
      '다른 부서 직원',
    ],
  },
  {
    question: '연봉 협상할 때 가장 어려운 건?',
    category: '커리어',
    options: [
      '말 꺼내기가 어렵다',
      '내 가치를 증명하기 어렵다',
      '비교할 기준이 없다',
      '거절당할까 봐 무섭다',
    ],
  },
  {
    question: '출근길 기분을 한 마디로?',
    category: '일상',
    options: [
      '오늘도 화이팅',
      '벌써 퇴근하고 싶다',
      '그냥 무념무상',
      '오늘 스케줄 뭐였지...',
    ],
  },
  {
    question: '가장 자신 있는 업무는?',
    category: '임상',
    options: [
      '스케일링',
      '환자 상담/응대',
      '인상 채득',
      '차트 정리/보험 청구',
    ],
  },
  {
    question: '업무 중 가장 긴장되는 순간은?',
    category: '임상',
    options: [
      '첫 환자 볼 때',
      '원장님이 지켜볼 때',
      '복잡한 시술 어시스트',
      '컴플레인 환자 올 때',
    ],
  },
  {
    question: '치위생과 후배들에게 해주고 싶은 말은?',
    category: '커리어',
    options: [
      '체력 관리가 제일 중요해',
      '사람 관계가 핵심이야',
      '실력은 시간이 해결해줘',
      '자기 기준을 꼭 가져',
    ],
  },
  {
    question: '가장 선호하는 근무 형태는?',
    category: '커리어',
    options: [
      '주 5일 정시 출퇴근',
      '주 4.5일 (토요일 반일)',
      '격주 토요일 근무',
      '연봉 높으면 상관없다',
    ],
  },
  {
    question: '치과 장비 중 가장 다루기 어려운 건?',
    category: '임상',
    options: [
      '초음파 스케일러',
      'X-ray / 파노라마',
      '인상재 믹싱',
      'CAD/CAM 장비',
    ],
  },
  {
    question: '동료 위생사에게 가장 고마운 순간은?',
    category: '일상',
    options: [
      '바쁠 때 도와줄 때',
      '힘들 때 공감해줄 때',
      '맛있는 거 나눠줄 때',
      '환자 인수인계 깔끔할 때',
    ],
  },
  {
    question: '지금 가장 배우고 싶은 분야는?',
    category: '커리어',
    options: [
      '심미/미백',
      '교정 어시스트',
      '임플란트 관리',
      '보험 청구/경영',
    ],
  },
  {
    question: '나만의 스트레스 해소법은?',
    category: '일상',
    options: [
      '먹기 (폭식 포함)',
      '잠자기',
      '운동/산책',
      '쇼핑',
    ],
  },
  {
    question: '치과 근무하면서 가장 많이 바뀐 습관은?',
    category: '일상',
    options: [
      '칫솔질이 꼼꼼해졌다',
      '손 씻는 횟수가 늘었다',
      '마스크 없이 못 나간다',
      '목/허리 스트레칭을 자주 한다',
    ],
  },
  {
    question: '5년 후 나는 어디에?',
    category: '커리어',
    options: [
      '같은 치과에서 베테랑으로',
      '더 좋은 조건의 치과로',
      '다른 직종으로 전직',
      '아직 잘 모르겠다',
    ],
  },
  {
    question: '원장님에게 가장 듣고 싶은 말은?',
    category: '일상',
    options: [
      '"수고했어, 오늘도 고마워"',
      '"연봉 올려줄게"',
      '"내일 쉬어"',
      '"네 의견대로 해보자"',
    ],
  },
  {
    question: '환자에게 가장 감동받은 순간은?',
    category: '임상',
    options: [
      '선물/음식 가져왔을 때',
      '"덕분에 이 안 아파요" 할 때',
      '이름 기억해주고 인사할 때',
      '다른 사람한테 추천해줬을 때',
    ],
  },
  {
    question: '치과위생사의 가장 큰 장점은?',
    category: '커리어',
    options: [
      '전문직이라 취업이 쉽다',
      '실력 쌓으면 대우가 좋다',
      '어디서든 일할 수 있다',
      '사람을 도울 수 있다',
    ],
  },
  {
    question: '월요일 아침, 나의 상태는?',
    category: '일상',
    options: [
      '좀비 모드',
      '의외로 괜찮다',
      '커피 없이는 못 산다',
      '이미 금요일이 기다려진다',
    ],
  },
  {
    question: '가장 기억에 남는 환자 유형은?',
    category: '임상',
    options: [
      '매번 감사 인사하는 분',
      '무서워서 떠는 성인 환자',
      '말 잘 듣는 어린이 환자',
      '단골인데 이름 모르는 분',
    ],
  },
  {
    question: '치과에서 일하면서 얻은 최고의 스킬은?',
    category: '커리어',
    options: [
      '인내심',
      '멀티태스킹',
      '커뮤니케이션',
      '위기 대응력',
    ],
  },
  {
    question: '가장 좋아하는 계절에 하고 싶은 건?',
    category: '일상',
    options: [
      '봄 — 벚꽃 구경',
      '여름 — 바다/물놀이',
      '가을 — 단풍 산책',
      '겨울 — 따뜻한 집에서 코코아',
    ],
  },
  {
    question: '후배 위생사에게 꼭 알려주고 싶은 팁은?',
    category: '임상',
    options: [
      '손목 보호 습관 들이기',
      '환자 이름 꼭 외우기',
      '모르면 바로 물어보기',
      '기록은 바로바로 하기',
    ],
  },
];

// ═══════════════════════════════════════════════════════════════
// 실행
// ═══════════════════════════════════════════════════════════════
async function main() {
  const args = process.argv.slice(2);
  const clearFlag = args.includes('--clear');

  // 시작일 파싱
  let startDate;
  const startIdx = args.indexOf('--start');
  if (startIdx !== -1 && args[startIdx + 1]) {
    startDate = new Date(args[startIdx + 1] + 'T00:00:00+09:00');
  } else {
    // 오늘 KST 00:00 기준
    const now = new Date();
    const kstOffset = 9 * 60 * 60 * 1000;
    const kstNow = new Date(now.getTime() + kstOffset);
    startDate = new Date(
      Date.UTC(kstNow.getUTCFullYear(), kstNow.getUTCMonth(), kstNow.getUTCDate()) - kstOffset
    );
  }

  console.log(`📅 시작일: ${startDate.toISOString()}`);
  console.log(`📊 투표 수: ${POLLS.length}개`);

  if (clearFlag) {
    console.log('🗑️  기존 polls 데이터 삭제 중...');
    const existing = await db.collection('polls').get();
    const batch = db.batch();
    for (const doc of existing.docs) {
      // 서브컬렉션(options, votes)도 삭제
      const optionsSnap = await doc.ref.collection('options').get();
      for (const opt of optionsSnap.docs) {
        batch.delete(opt.ref);
      }
      const votesSnap = await doc.ref.collection('votes').get();
      for (const vote of votesSnap.docs) {
        batch.delete(vote.ref);
      }
      batch.delete(doc.ref);
    }
    await batch.commit();
    console.log(`   ✅ ${existing.size}개 투표 삭제 완료`);
  }

  // 각 투표를 하루씩 배분
  let created = 0;
  for (let i = 0; i < POLLS.length; i++) {
    const poll = POLLS[i];
    const dayOffset = i;

    // KST 기준 startsAt = startDate + i일 00:00, endsAt = startDate + (i+1)일 00:00
    const startsAt = new Date(startDate.getTime() + dayOffset * 24 * 60 * 60 * 1000);
    const endsAt = new Date(startsAt.getTime() + 24 * 60 * 60 * 1000);

    // 이미 동일 시간대에 존재하는지 확인
    const dateKey = formatDate(startsAt);
    const existCheck = await db.collection('polls')
      .where('startsAt', '==', admin.firestore.Timestamp.fromDate(startsAt))
      .limit(1)
      .get();

    if (!existCheck.empty) {
      console.log(`   ⏭️  ${dateKey} 이미 존재 → 스킵`);
      continue;
    }

    // poll 문서 생성
    const pollRef = await db.collection('polls').add({
      question: poll.question,
      status: 'active',
      startsAt: admin.firestore.Timestamp.fromDate(startsAt),
      endsAt: admin.firestore.Timestamp.fromDate(endsAt),
      totalEmpathyCount: 0,
      category: poll.category,
    });

    // options 서브컬렉션 생성
    const optBatch = db.batch();
    for (const optContent of poll.options) {
      const optRef = pollRef.collection('options').doc();
      optBatch.set(optRef, {
        content: optContent,
        authorUid: null,
        isSystem: true,
        createdAt: admin.firestore.Timestamp.fromDate(startsAt),
        empathyCount: 0,
        reportCount: 0,
        isHidden: false,
      });
    }
    await optBatch.commit();

    console.log(`   ✅ [${dateKey}] "${poll.question}" (${poll.options.length}개 보기)`);
    created++;
  }

  console.log(`\n🎉 완료: ${created}개 투표 등록 (${POLLS.length - created}개 스킵)`);
  console.log(`📅 기간: ${formatDate(startDate)} ~ ${formatDate(new Date(startDate.getTime() + (POLLS.length - 1) * 24 * 60 * 60 * 1000))}`);
  process.exit(0);
}

function formatDate(d) {
  const kst = new Date(d.getTime() + 9 * 60 * 60 * 1000);
  return `${kst.getUTCFullYear()}-${String(kst.getUTCMonth() + 1).padStart(2, '0')}-${String(kst.getUTCDate()).padStart(2, '0')}`;
}

main().catch(err => {
  console.error('❌ 오류:', err);
  process.exit(1);
});
