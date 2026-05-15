/**
 * 활성 공감투표 1건의 오늘(KST) 마감시 누적이 약 TARGET_EOD 이 되도록 일회성 부스트.
 *
 * 동작
 *   1) 활성 poll(현재 시각이 startsAt~endsAt 사이) 1건 선택
 *   2) totalEmpathyCount(now) 와 봇이 오늘 남은 시간 동안 자연 증가시킬 평균치 계산
 *   3) TARGET_EOD - (now + remainingAvg) 만큼 즉시 분배(여러 옵션에 나눠서 +1)
 *   4) activityLogs / votes 서브컬렉션은 절대 안 건드림 (대시보드 통계 영향 0)
 *
 * 실행:
 *   cd functions
 *   node scripts/boost_active_poll_today.js
 */

const admin = require('firebase-admin');
const path = require('path');

const serviceAccount = require(path.join(__dirname, '..', 'serviceAccountKey.json'));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

// ─── 설정 ───────────────────────────────────────────────────
const TARGET_EOD = 35;            // 오늘 마감(KST 24:00) 시 누적 목표
const DAILY_BASE_GROWTH = 8;      // poll-empathy-bot 과 동일
const HOURLY_WEIGHTS_KST = [
  0.010, 0.010, 0.010, 0.010, 0.010, 0.010,
  0.010, 0.025, 0.050, 0.060, 0.065, 0.065,
  0.060, 0.055, 0.050, 0.050, 0.050, 0.055,
  0.075, 0.090, 0.095, 0.080, 0.060, 0.030,
];

const USER_OPTION_PROB_MIN = 0.90;
const USER_OPTION_PROB_MAX = 0.98;
const USER_LENGTH_POWER = 1.3;

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

function expectedRemainingTodayAdds() {
  const { hour, frac } = kstHourMinFrac();
  let sum = HOURLY_WEIGHTS_KST[hour] * (1 - frac);
  for (let h = hour + 1; h < 24; h++) sum += HOURLY_WEIGHTS_KST[h];
  return DAILY_BASE_GROWTH * sum;
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

function pickTarget(userOpts, sysOpts) {
  if (userOpts.length === 0 && sysOpts.length === 0) return null;
  if (userOpts.length === 0) {
    return { ref: sysOpts[Math.floor(Math.random() * sysOpts.length)].ref, kind: 'sys' };
  }
  const pUser =
    USER_OPTION_PROB_MIN + Math.random() * (USER_OPTION_PROB_MAX - USER_OPTION_PROB_MIN);
  const goUser = sysOpts.length === 0 || Math.random() < pUser;
  if (goUser) {
    const weights = userOpts.map(d => {
      const len = ((d.data().content) || '').length;
      return Math.pow(Math.max(1, len), USER_LENGTH_POWER);
    });
    const sum = weights.reduce((a, b) => a + b, 0);
    let r = Math.random() * sum;
    for (let i = 0; i < userOpts.length; i++) {
      r -= weights[i];
      if (r <= 0) return { ref: userOpts[i].ref, kind: 'user' };
    }
    return { ref: userOpts[userOpts.length - 1].ref, kind: 'user' };
  }
  return { ref: sysOpts[Math.floor(Math.random() * sysOpts.length)].ref, kind: 'sys' };
}

async function distribute(pollRef, count) {
  const optsSnap = await pollRef
    .collection('options')
    .where('isHidden', '==', false)
    .get();

  const userOpts = [];
  const sysOpts = [];
  for (const d of optsSnap.docs) {
    if (d.data().isSystem === false) userOpts.push(d);
    else sysOpts.push(d);
  }
  if (userOpts.length === 0 && sysOpts.length === 0) {
    return { added: 0, userAdded: 0, sysAdded: 0 };
  }

  const incByRef = new Map();
  let userAdded = 0;
  let sysAdded = 0;
  for (let i = 0; i < count; i++) {
    const t = pickTarget(userOpts, sysOpts);
    if (!t) break;
    incByRef.set(t.ref, (incByRef.get(t.ref) || 0) + 1);
    if (t.kind === 'user') userAdded++; else sysAdded++;
  }
  const added = userAdded + sysAdded;
  if (added === 0) return { added: 0, userAdded: 0, sysAdded: 0 };

  const batch = db.batch();
  for (const [ref, n] of incByRef.entries()) {
    batch.update(ref, { empathyCount: admin.firestore.FieldValue.increment(n) });
  }
  batch.update(pollRef, {
    totalEmpathyCount: admin.firestore.FieldValue.increment(added),
  });
  await batch.commit();
  return { added, userAdded, sysAdded };
}

(async () => {
  const poll = await pickActivePoll();
  if (!poll) {
    console.log('진행 중 투표가 없습니다.');
    process.exit(0);
  }
  const data = poll.data();
  const current = (data.totalEmpathyCount) || 0;
  const remainingAvg = expectedRemainingTodayAdds();
  const desired = TARGET_EOD - remainingAvg;
  const need = Math.max(0, Math.round(desired - current));

  console.log(
    `pollId=${poll.id} title="${data.question || ''}" ` +
    `current=${current} remainingAvg≈${remainingAvg.toFixed(2)} ` +
    `desiredNow=${desired.toFixed(2)} → boost=${need}`
  );

  if (need === 0) {
    console.log('이미 충분합니다. 변경 없음.');
    process.exit(0);
  }

  const r = await distribute(poll.ref, need);
  console.log(`✅ +${r.added} 추가 (user=${r.userAdded}/sys=${r.sysAdded}). 새 총합=${current + r.added}`);
  process.exit(0);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
