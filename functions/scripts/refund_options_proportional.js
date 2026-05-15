/**
 * 옵션별 empathyCount 비례 환불:
 *   현재 활성 poll 의 option.empathyCount 합이 totalEmpathyCount 보다 많으면,
 *   초과분(excess) 만큼 각 익명(isSystem=false) 옵션에서 비례적으로 차감.
 *   익명만으로 부족하면 시스템 옵션에서 마저 차감.
 *
 *   → 화면의 "X명 참여"(옵션 합 또는 totalEmpathyCount 둘 다) 가 같은 값으로 정렬됨.
 *
 * 실행:
 *   cd functions
 *   node scripts/refund_options_proportional.js
 */

const admin = require('firebase-admin');
const path = require('path');

const serviceAccount = require(path.join(__dirname, '..', 'serviceAccountKey.json'));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

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

/**
 * 비례 정수 차감을 만들기 위한 라운드 분배.
 *   excess: 빼야 할 총량 (양의 정수)
 *   weights: 각 옵션의 현재 empathyCount (>=0)
 *   각 옵션의 차감량 <= 그 옵션의 weight 가 되도록 클램프.
 *   비례 분배 결과를 floor 한 뒤 잔여를 큰 잔차 순으로 +1 씩 분배.
 */
function distributeIntegerProportional(excess, weights) {
  const totalW = weights.reduce((a, b) => a + b, 0);
  if (totalW <= 0) return weights.map(() => 0);
  const raw = weights.map((w) => (excess * w) / totalW);
  const floors = raw.map((x) => Math.floor(x));
  const residuals = raw.map((x, i) => ({ i, frac: x - Math.floor(x) }));
  let allocated = floors.reduce((a, b) => a + b, 0);
  // 잔여 = excess - allocated, residual frac 큰 순으로 +1
  residuals.sort((a, b) => b.frac - a.frac);
  let leftover = excess - allocated;
  for (const r of residuals) {
    if (leftover <= 0) break;
    if (floors[r.i] + 1 <= weights[r.i]) {
      floors[r.i] += 1;
      leftover -= 1;
    }
  }
  // 그래도 남으면 남은 capacity 있는 곳에 +1 더(이론상 보통 0)
  if (leftover > 0) {
    for (let i = 0; i < weights.length && leftover > 0; i++) {
      const headroom = weights[i] - floors[i];
      const give = Math.min(headroom, leftover);
      floors[i] += give;
      leftover -= give;
    }
  }
  return floors;
}

(async () => {
  const poll = await pickActivePoll();
  if (!poll) {
    console.log('진행 중 투표 없음 — 종료');
    process.exit(0);
  }
  const data = poll.data();
  const total = (data.totalEmpathyCount) || 0;

  const optsSnap = await poll.ref
    .collection('options')
    .get();

  const opts = optsSnap.docs.map((d) => ({
    ref: d.ref,
    id: d.id,
    isSystem: d.data().isSystem === true,
    empathyCount: (d.data().empathyCount) || 0,
    isHidden: d.data().isHidden === true,
  }));

  const optionSum = opts.reduce((s, o) => s + o.empathyCount, 0);
  const excess = optionSum - total;

  console.log(
    `pollId=${poll.id} title="${data.question || ''}" ` +
    `total=${total} optionSum=${optionSum} excess=${excess}`,
  );

  if (excess <= 0) {
    console.log('차감할 초과분 없음 — 종료');
    process.exit(0);
  }

  // 1) 익명(isSystem=false, isHidden=false) 옵션에서 먼저 비례 차감
  const userOpts = opts.filter((o) => !o.isSystem && !o.isHidden && o.empathyCount > 0);
  const userWeights = userOpts.map((o) => o.empathyCount);
  const userCap = userWeights.reduce((a, b) => a + b, 0);
  let remaining = excess;

  const decByRef = new Map();
  if (userCap > 0) {
    const take = Math.min(remaining, userCap);
    const decs = distributeIntegerProportional(take, userWeights);
    for (let i = 0; i < userOpts.length; i++) {
      if (decs[i] > 0) decByRef.set(userOpts[i].ref, (decByRef.get(userOpts[i].ref) || 0) + decs[i]);
    }
    remaining -= take;
  }

  // 2) 그래도 남으면 시스템 옵션에서 마저 차감
  if (remaining > 0) {
    const sysOpts = opts.filter((o) => o.isSystem && !o.isHidden && o.empathyCount > 0);
    const sysWeights = sysOpts.map((o) => o.empathyCount);
    const sysCap = sysWeights.reduce((a, b) => a + b, 0);
    if (sysCap > 0) {
      const take = Math.min(remaining, sysCap);
      const decs = distributeIntegerProportional(take, sysWeights);
      for (let i = 0; i < sysOpts.length; i++) {
        if (decs[i] > 0) decByRef.set(sysOpts[i].ref, (decByRef.get(sysOpts[i].ref) || 0) + decs[i]);
      }
      remaining -= take;
    }
  }

  if (remaining > 0) {
    console.log(`⚠️ 옵션 capacity 부족 — 남은 차감 ${remaining} 적용 불가. 작업 중단.`);
    process.exit(1);
  }

  console.log('차감 계획:');
  for (const [ref, n] of decByRef.entries()) {
    console.log(`  ${ref.id}  -=${n}`);
  }

  const batch = db.batch();
  for (const [ref, n] of decByRef.entries()) {
    batch.update(ref, { empathyCount: admin.firestore.FieldValue.increment(-n) });
  }
  await batch.commit();

  // 검증: 옵션 합 재계산
  const optsAfter = await poll.ref.collection('options').get();
  const sumAfter = optsAfter.docs.reduce(
    (s, d) => s + ((d.data().empathyCount) || 0),
    0,
  );
  console.log(`✅ 적용 완료. 옵션 합 ${optionSum} → ${sumAfter} (목표 = totalEmpathyCount = ${total})`);
  process.exit(0);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
