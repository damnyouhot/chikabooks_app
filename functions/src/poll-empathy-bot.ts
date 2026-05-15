import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

const REGION = "us-central1";

// ─────────────────────────────────────────────────────────────
// 공감투표 자연 증가 봇 (v3 — 일별 누적 곡선)
//
// 동작
//   - 매일 KST 자정 새 투표 1건이 활성화 (0명에서 시작).
//   - config/pollBot 에 오늘 EOD 목표(todayTarget)를 기억.
//     새날이 되면 전날 목표에 DAILY_INCREMENT_MIN~MAX 를 더해 오늘 목표 확정.
//   - 하루 안에서 HOURLY_WEIGHTS_KST 누적 가중치 비율로 기대값을 보간하고,
//     deficit 를 포아송으로 분배 → 시간대에 맞게 자연 증가.
//   - todayTarget 이 TARGET_TOTAL(500) 에 근접하면 bandScale 로 감속·정지.
//
// 통계 분리 (중요)
//   대시보드(analytics_daily)는 activityLogs 컬렉션만 집계한다.
//   본 봇은 polls/{id}.totalEmpathyCount 와 options/{id}.empathyCount 만 +N 하고
//   activityLogs / votes 서브컬렉션은 절대 건드리지 않는다.
//   → 대시보드 통계에는 잡히지 않음.
//
// 익명 보기 분배
//   - 익명 보기(isSystem=false) ≥1 → 평균 85% (0.80~0.90 구간 균등)
//   - 익명 보기끼리는 content.length^1.3 가중치 (긴 보기에 몰표)
//   - 시스템 보기에 ~15% 자연 분산
// ─────────────────────────────────────────────────────────────

/** KST 시간대별 활동 가중치 (24시간, 합 ≈ 1.085) */
const HOURLY_WEIGHTS_KST: number[] = [
  0.010, 0.010, 0.010, 0.010, 0.010, 0.010, // 00~05
  0.010, 0.025, 0.050, 0.060, 0.065, 0.065, // 06~11
  0.060, 0.055, 0.050, 0.050, 0.050, 0.055, // 12~17
  0.075, 0.090, 0.095, 0.080, 0.060, 0.030, // 18~23
];
const WEIGHT_TOTAL = HOURLY_WEIGHTS_KST.reduce((a, b) => a + b, 0);

/** 하루 EOD 목표 증가량 */
const DAILY_INCREMENT_MIN = 8;
const DAILY_INCREMENT_MAX = 11;

const TARGET_TOTAL = 500; // 글로벌 플래토
const BAND = 50;

const USER_OPTION_PROB_MIN = 0.80;
const USER_OPTION_PROB_MAX = 0.90;
const USER_LENGTH_POWER = 1.3;

const CONFIG_REF = db.collection("config").doc("pollBot");

interface ActivePollPick {
  ref: FirebaseFirestore.DocumentReference;
  data: FirebaseFirestore.DocumentData;
}

// ═══════════════════════════════════════════════════════════
// KST 시간 유틸
// ═══════════════════════════════════════════════════════════

function kstStartOfDayUtc(nowMs: number): number {
  const fmt = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Seoul",
    year: "numeric",
    month: "numeric",
    day: "numeric",
  });
  const parts = fmt.formatToParts(new Date(nowMs));
  const num = (t: string) =>
    parseInt(parts.find((p) => p.type === t)?.value ?? "0", 10);
  const y = num("year");
  const m = num("month");
  const d = num("day");
  return Date.parse(
    `${y}-${String(m).padStart(2, "0")}-${String(d).padStart(2, "0")}T00:00:00+09:00`,
  );
}

function kstHourAndMinFrac(nowMs: number): { hour: number; minFrac: number } {
  const start = kstStartOfDayUtc(nowMs);
  const elapsedSec = Math.max(0, nowMs - start) / 1000;
  const hour = Math.min(23, Math.floor(elapsedSec / 3600));
  const minFrac = (elapsedSec % 3600) / 3600;
  return { hour, minFrac };
}


function kstYmdKey(nowMs: number): string {
  const fmt = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Seoul",
    year: "numeric",
    month: "numeric",
    day: "numeric",
  });
  const parts = fmt.formatToParts(new Date(nowMs));
  const num = (t: string) =>
    parseInt(parts.find((p) => p.type === t)?.value ?? "0", 10);
  const y = num("year");
  const m = num("month");
  const d = num("day");
  return `${y}-${String(m).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
}

/** 지금 KST 시각까지 소비된 가중치 비율 (0..1) */
function fracWeightElapsed(hour: number, minFrac: number): number {
  let cumulative = 0;
  for (let h = 0; h < hour; h++) {
    cumulative += HOURLY_WEIGHTS_KST[h] ?? 0;
  }
  cumulative += (HOURLY_WEIGHTS_KST[hour] ?? 0) * minFrac;
  return Math.min(1, cumulative / WEIGHT_TOTAL);
}

// ═══════════════════════════════════════════════════════════
// 스케줄러
// ═══════════════════════════════════════════════════════════

/**
 * 매 30분 실행.
 * config/pollBot 에서 오늘 EOD 목표를 읽고,
 * 지금 이 시각까지 있어야 할 기대값 − 현재값(deficit)을 포아송으로 분배.
 */
export const tickFakePollEmpathy = functions
  .region(REGION)
  .pubsub.schedule("*/30 * * * *")
  .timeZone("Asia/Seoul")
  .onRun(async () => {
    const nowMs = Date.now();
    const { hour, minFrac } = kstHourAndMinFrac(nowMs);
    const todayKey = kstYmdKey(nowMs);

    // ── config/pollBot 읽기 + 새날 처리 ──
    const cfg = await CONFIG_REF.get();
    const cfgData = cfg.exists ? (cfg.data() ?? {}) : {};

    let todayTarget: number = (cfgData.todayTarget as number | undefined) ?? 34;
    const lastEodTarget: number =
      (cfgData.lastEodTarget as number | undefined) ?? todayTarget;

    if ((cfgData.todayKstKey as string | undefined) !== todayKey) {
      const inc =
        DAILY_INCREMENT_MIN +
        Math.floor(
          Math.random() * (DAILY_INCREMENT_MAX - DAILY_INCREMENT_MIN + 1),
        );
      todayTarget = Math.min(TARGET_TOTAL, lastEodTarget + inc);
      await CONFIG_REF.set(
        { todayKstKey: todayKey, todayTarget, lastEodTarget: todayTarget },
        { merge: true },
      );
      functions.logger.info(
        `tickFakePollEmpathy: new day todayKey=${todayKey} ` +
          `todayTarget=${todayTarget} lastEodTarget=${lastEodTarget} inc=${inc}`,
      );
    }

    // ── 활성 투표 ──
    const poll = await pickActivePoll();
    if (!poll) {
      functions.logger.info("tickFakePollEmpathy: 진행 중 투표 없음");
      return null;
    }

    const current = (poll.data.totalEmpathyCount as number) ?? 0;
    const globalScale = bandScale(current);

    // ── 기대값 보간 ──
    const expectedNow = todayTarget * fracWeightElapsed(hour, minFrac);
    const deficit = expectedNow - current;

    if (deficit <= 0.001 || globalScale === 0) {
      functions.logger.info(
        `tickFakePollEmpathy: skip poll=${poll.ref.id} hour=${hour} ` +
          `current=${current} expected=${expectedNow.toFixed(2)} ` +
          `deficit=${deficit.toFixed(2)} scale=${globalScale}`,
      );
      return null;
    }

    // ── deficit → 포아송 → 분배 ──
    //
    // 공식: (todayTarget - current) × (이번 30분 틱 가중치 / 자정까지 남은 가중치 합)
    // → 목표 잔량을 남은 시간 가중치에 비례해 분배하므로,
    //   오전에 deficit이 크게 벌어져도 자정까지 정확히 수렴한다.
    const hourW = HOURLY_WEIGHTS_KST[hour] ?? 0.04;
    const remaining = Math.max(0, todayTarget - current);

    let remainingWeight = hourW * (1 - minFrac);
    for (let h = hour + 1; h < 24; h++) {
      remainingWeight += HOURLY_WEIGHTS_KST[h] ?? 0;
    }
    remainingWeight = Math.max(0.001, remainingWeight);

    const tickWeight = hourW / 2; // 시간당 2틱(30분) 기준 이번 틱의 가중치

    let lambda = remaining * (tickWeight / remainingWeight);
    lambda *= globalScale;
    lambda = Math.min(lambda, 3.2);

    const raw = poissonSample(lambda);
    const ceiling = todayTarget + 5 - current;
    const safeAdds = Math.min(raw, Math.ceil(deficit), Math.max(0, ceiling));

    if (safeAdds <= 0) {
      functions.logger.info(
        `tickFakePollEmpathy: skip(0) poll=${poll.ref.id} ` +
          `lambda=${lambda.toFixed(3)} raw=${raw} ceiling=${ceiling} ` +
          `remaining=${remaining.toFixed(1)} remW=${remainingWeight.toFixed(3)}`,
      );
      return null;
    }

    const result = await distributeFakeEmpathy(poll, safeAdds);
    functions.logger.info(
      `tickFakePollEmpathy: poll=${poll.ref.id} hour=${hour} ` +
        `current=${current} target=${todayTarget} expected=${expectedNow.toFixed(2)} ` +
        `deficit=${deficit.toFixed(2)} remaining=${remaining.toFixed(1)} ` +
        `lambda=${lambda.toFixed(3)} +${result.added} (user=${result.userAdded}/sys=${result.sysAdded})`,
    );
    return null;
  });

/**
 * 운영자가 즉시 N명 부어주고 싶을 때 (어드민 onCall).
 * Input: { pollId?: string, count: number }  — count: 1~100
 */
export const adminBoostPollEmpathy = functions
  .region(REGION)
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "로그인 필요");
    }
    const callerDoc = await db.collection("users").doc(context.auth.uid).get();
    if (callerDoc.data()?.isAdmin !== true) {
      throw new functions.https.HttpsError("permission-denied", "어드민 권한 필요");
    }

    const rawCount = Number(data?.count ?? 0);
    const count = Math.floor(rawCount);
    if (!Number.isFinite(count) || count < 1 || count > 100) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "count는 1~100 사이의 정수여야 합니다.",
      );
    }

    let poll: ActivePollPick | null;
    const pollIdRaw =
      typeof data?.pollId === "string" ? data.pollId.trim() : "";
    if (pollIdRaw) {
      const snap = await db.collection("polls").doc(pollIdRaw).get();
      if (!snap.exists) {
        throw new functions.https.HttpsError("not-found", "투표를 찾을 수 없습니다.");
      }
      poll = { ref: snap.ref, data: snap.data() ?? {} };
    } else {
      poll = await pickActivePoll();
    }
    if (!poll) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "진행 중 투표가 없습니다.",
      );
    }

    const result = await distributeFakeEmpathy(poll, count);
    return {
      success: true,
      pollId: poll.ref.id,
      added: result.added,
      userAdded: result.userAdded,
      sysAdded: result.sysAdded,
    };
  });

// ─────────────────────────────────────────────────────────────
// 분배·보조 함수
// ─────────────────────────────────────────────────────────────

interface DistributeResult {
  added: number;
  userAdded: number;
  sysAdded: number;
}

async function distributeFakeEmpathy(
  poll: ActivePollPick,
  count: number,
): Promise<DistributeResult> {
  const optsSnap = await poll.ref
    .collection("options")
    .where("isHidden", "==", false)
    .get();

  const userOpts: FirebaseFirestore.QueryDocumentSnapshot[] = [];
  const sysOpts: FirebaseFirestore.QueryDocumentSnapshot[] = [];
  for (const d of optsSnap.docs) {
    if (d.data().isSystem === false) {
      userOpts.push(d);
    } else {
      sysOpts.push(d);
    }
  }

  if (userOpts.length === 0 && sysOpts.length === 0) {
    return { added: 0, userAdded: 0, sysAdded: 0 };
  }

  const incByRef = new Map<FirebaseFirestore.DocumentReference, number>();
  let userAdded = 0;
  let sysAdded = 0;

  for (let i = 0; i < count; i++) {
    const target = pickTarget(userOpts, sysOpts);
    if (!target) break;
    incByRef.set(target.ref, (incByRef.get(target.ref) ?? 0) + 1);
    if (target.kind === "user") userAdded++;
    else sysAdded++;
  }

  const added = userAdded + sysAdded;
  if (added === 0) return { added: 0, userAdded: 0, sysAdded: 0 };

  const batch = db.batch();
  for (const [ref, n] of incByRef.entries()) {
    batch.update(ref, { empathyCount: admin.firestore.FieldValue.increment(n) });
  }
  batch.update(poll.ref, {
    totalEmpathyCount: admin.firestore.FieldValue.increment(added),
  });
  await batch.commit();

  return { added, userAdded, sysAdded };
}

interface TargetPick {
  ref: FirebaseFirestore.DocumentReference;
  kind: "user" | "sys";
}

function pickTarget(
  userOpts: FirebaseFirestore.QueryDocumentSnapshot[],
  sysOpts: FirebaseFirestore.QueryDocumentSnapshot[],
): TargetPick | null {
  if (userOpts.length === 0 && sysOpts.length === 0) return null;

  if (userOpts.length === 0) {
    const pick = sysOpts[Math.floor(Math.random() * sysOpts.length)];
    return { ref: pick.ref, kind: "sys" };
  }

  const pUser =
    USER_OPTION_PROB_MIN +
    Math.random() * (USER_OPTION_PROB_MAX - USER_OPTION_PROB_MIN);
  const goUser = sysOpts.length === 0 || Math.random() < pUser;

  if (goUser) {
    const weights = userOpts.map((d) => {
      const len = ((d.data().content as string) ?? "").length;
      return Math.pow(Math.max(1, len), USER_LENGTH_POWER);
    });
    const pick = sampleWeighted(userOpts, weights);
    return { ref: pick.ref, kind: "user" };
  }

  const pick = sysOpts[Math.floor(Math.random() * sysOpts.length)];
  return { ref: pick.ref, kind: "sys" };
}

/**
 * 누적 인원 기반 증가량 감속.
 *   ≥550: 0 (정지)  ≥500: 0.15  ≥450: 0.45  <450: 1.0
 */
function bandScale(total: number): number {
  if (total >= TARGET_TOTAL + BAND) return 0.0;
  if (total >= TARGET_TOTAL) return 0.15;
  if (total >= TARGET_TOTAL - BAND) return 0.45;
  return 1.0;
}

function poissonSample(lambda: number): number {
  if (lambda <= 0) return 0;
  const L = Math.exp(-lambda);
  let k = 0;
  let p = 1;
  while (true) {
    k++;
    p *= Math.random();
    if (p < L) return k - 1;
  }
}

function sampleWeighted<T>(items: T[], weights: number[]): T {
  const sum = weights.reduce((a, b) => a + b, 0);
  if (sum <= 0) return items[Math.floor(Math.random() * items.length)];
  let r = Math.random() * sum;
  for (let i = 0; i < items.length; i++) {
    r -= weights[i];
    if (r <= 0) return items[i];
  }
  return items[items.length - 1];
}

async function pickActivePoll(): Promise<ActivePollPick | null> {
  const nowTs = admin.firestore.Timestamp.now();
  const snap = await db
    .collection("polls")
    .where("endsAt", ">", nowTs)
    .orderBy("endsAt")
    .limit(50)
    .get();

  let best: FirebaseFirestore.QueryDocumentSnapshot | null = null;
  let bestOrder = Number.MAX_SAFE_INTEGER;
  let bestStartMs = Number.MAX_SAFE_INTEGER;
  const nowMs = Date.now();

  for (const doc of snap.docs) {
    const d = doc.data();
    const startsAt = d.startsAt as admin.firestore.Timestamp | undefined;
    if (!startsAt) continue;
    const startMs = startsAt.toMillis();
    if (startMs > nowMs) continue;
    const order = displayOrderFromPollData(d, doc.id);
    if (order < bestOrder || (order === bestOrder && startMs < bestStartMs)) {
      best = doc;
      bestOrder = order;
      bestStartMs = startMs;
    }
  }

  if (!best) return null;
  return { ref: best.ref, data: best.data() };
}

function displayOrderFromPollData(
  d: FirebaseFirestore.DocumentData,
  docId: string,
): number {
  const raw = d.displayOrder;
  if (typeof raw === "number" && Number.isFinite(raw)) return raw;
  const di = d.dayIndex;
  if (typeof di === "number" && Number.isFinite(di)) return di;
  const m = /^empathy_(\d+)$/.exec(docId);
  return m ? parseInt(m[1], 10) : 1_000_000;
}
