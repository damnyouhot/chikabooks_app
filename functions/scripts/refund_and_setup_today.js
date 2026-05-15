/**
 * 오늘 부스트 정정:
 *   1) 활성 poll 의 totalEmpathyCount 에서 REFUND_FROM_TOTAL 만큼 차감 (옵션은 그대로 둠)
 *   2) 오늘(KST) EOD 목표가 TARGET_EOD 이 되도록 todayBoostMultiplier 설정
 *      - 봇이 시간대 가중치(HOURLY_WEIGHTS_KST)에 맞춰 자연스럽게 분포 증가시키도록.
 *
 * 실행:
 *   cd functions
 *   node scripts/refund_and_setup_today.js
 */

const admin = require('firebase-admin');
const path = require('path');

const serviceAccount = require(path.join(__dirname, '..', 'serviceAccountKey.json'));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

// ─── 설정 ───────────────────────────────────────────────────
const TARGET_EOD = 35;             // 오늘 KST 24:00 누적 목표
const REFUND_FROM_TOTAL = 23;      // 직전 부스트(+23) 환불 — totalEmpathyCount 만 -23
const DAILY_BASE_GROWTH = 8;       // poll-empathy-bot.ts 와 동일
const HOURLY_WEIGHTS_KST = [
  0.010, 0.010, 0.010, 0.010, 0.010, 0.010,
  0.010, 0.025, 0.050, 0.060, 0.065, 0.065,
  0.060, 0.055, 0.050, 0.050, 0.050, 0.055,
  0.075, 0.090, 0.095, 0.080, 0.060, 0.030,
];

function kstHourMinFrac(now = Date.now()) {
  const fmt = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Seoul',
    hour: 'numeric', minute: 'numeric', hour12: false,
  });
  const parts = fmt.formatToParts(new Date(now));
  const h = parseInt(parts.find(p => p.type === 'hour').value, 10);
  const m = parseInt(parts.find(p => p.type === 'minute').value, 10);
  return { hour: h, frac: m / 60 };
}

function kstYmdKey(now = Date.now()) {
  const fmt = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Seoul',
    year: 'numeric', month: 'numeric', day: 'numeric',
  });
  const parts = fmt.formatToParts(new Date(now));
  const y = parseInt(parts.find(p => p.type === 'year').value, 10);
  const m = parseInt(parts.find(p => p.type === 'month').value, 10);
  const d = parseInt(parts.find(p => p.type === 'day').value, 10);
  return `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
}

function remainingTodayWeight() {
  const { hour, frac } = kstHourMinFrac();
  let sum = HOURLY_WEIGHTS_KST[hour] * (1 - frac);
  for (let h = hour + 1; h < 24; h++) sum += HOURLY_WEIGHTS_KST[h];
  return sum;
}

async function pickActivePoll() {
  const nowTs = admin.firestore.Timestamp.now();
  const snap = await db
    .collection('polls')
    .where('endsAt', '>', nowTs)
    .orderBy('endsAt')
    .limit(50)
    .get();

  let best = null;
  let bestOrder = Number.MAX_SAFE_INTEGER;
  let bestStartMs = Number.MAX_SAFE_INTEGER;
  const nowMs = Date.now();

  for (const doc of snap.docs) {
    const d = doc.data();
    const startsAt = d.startsAt;
    if (!startsAt) continue;
    const startMs = startsAt.toMillis();
    if (startMs > nowMs) continue;
    const order = orderOf(d, doc.id);
    if (order < bestOrder || (order === bestOrder && startMs < bestStartMs)) {
      best = doc;
      bestOrder = order;
      bestStartMs = startMs;
    }
  }
  return best;
}

function orderOf(d, id) {
  if (typeof d.displayOrder === 'number') return d.displayOrder;
  if (typeof d.dayIndex === 'number') return d.dayIndex;
  const m = /^empathy_(\d+)$/.exec(id);
  return m ? parseInt(m[1], 10) : 1_000_000;
}

(async () => {
  const poll = await pickActivePoll();
  if (!poll) {
    console.log('진행 중 투표 없음 — 종료');
    process.exit(0);
  }
  const data = poll.data();
  const before = (data.totalEmpathyCount) || 0;
  const targetCurrent = Math.max(0, before - REFUND_FROM_TOTAL);
  const refundDelta = before - targetCurrent;

  const remW = remainingTodayWeight();
  const normalRemaining = DAILY_BASE_GROWTH * remW;
  const desiredRemaining = TARGET_EOD - targetCurrent;
  const mult = normalRemaining > 0
    ? Math.max(1.0, desiredRemaining / normalRemaining)
    : 1.0;

  const todayKey = kstYmdKey();

  console.log(
    `pollId=${poll.id} title="${data.question || ''}" ` +
    `before=${before} → after refund=${targetCurrent} ` +
    `(refund=${refundDelta}) | ` +
    `remainingWeight≈${remW.toFixed(3)} normalRemaining≈${normalRemaining.toFixed(2)} ` +
    `desiredRemaining=${desiredRemaining} → mult=${mult.toFixed(2)} todayKey=${todayKey}`
  );

  const batch = db.batch();
  if (refundDelta > 0) {
    batch.update(poll.ref, {
      totalEmpathyCount: admin.firestore.FieldValue.increment(-refundDelta),
    });
  }
  batch.update(poll.ref, {
    todayBoostKstKey: todayKey,
    todayBoostMultiplier: mult,
  });
  await batch.commit();

  console.log('✅ 적용 완료. tickFakePollEmpathy 가 매 30분 시간대 weight대로 자연 분포로 채웁니다.');
  process.exit(0);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
