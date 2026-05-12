import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

const REGION = "us-central1";

// ─────────────────────────────────────────────────────────────
// 공감투표 자연 증가 봇
//
// 목적
//   "X명 참여" 카운트를 사람이 참여하는 것처럼 자연스럽게 늘린다.
//
// 통계 분리 (중요)
//   대시보드(analytics_daily)는 activityLogs 컬렉션만 집계한다
//   (functions/src/scheduled-analytics.ts).
//   본 봇은 polls/{id}.totalEmpathyCount 와
//   polls/{id}/options/{id}.empathyCount 만 직접 +1 하고
//   activityLogs / votes 서브컬렉션은 절대 건드리지 않는다.
//   → 대시보드 통계에는 잡히지 않음
//   → 다음날에도 polls 카운트는 그대로 보존됨
//
// 익명 보기 분배 정책
//   - 익명 보기(isSystem=false)가 0개면 시스템 보기에만 균등 분배
//   - 1개 이상이면 90~98% 익명 보기로 가고, 나머지만 시스템 보기로
//   - 익명 보기끼리는 content.length^1.3 가중치 (긴 보기일수록 많이)
//
// 자정 직후에 익명 보기가 등록되는 케이스가 흔하다.
//   → 시간(hour) 기반 분기는 의도적으로 두지 않고, 매 tick에서
//     options 컬렉션을 다시 읽어 "지금 시점의" 익명 보기 유무로 판단한다.
// ─────────────────────────────────────────────────────────────

/**
 * KST 시간대별 활동 가중치 (24시간, 합 ≈ 1.0).
 * tick 당 평균 증가 = DAILY_BASE_GROWTH × HOURLY_WEIGHTS_KST[h] / TICKS_PER_HOUR
 */
const HOURLY_WEIGHTS_KST: number[] = [
  0.005, 0.005, 0.005, 0.005, 0.005, 0.005, // 00~05 (잠)
  0.010, 0.025, 0.050, 0.060, 0.065, 0.065, // 06~11 (출근·오전 피크)
  0.060, 0.055, 0.050, 0.050, 0.050, 0.055, // 12~17 (점심·오후)
  0.075, 0.090, 0.095, 0.080, 0.060, 0.030, // 18~23 (저녁 피크)
];

const DAILY_BASE_GROWTH = 15;       // 하루 평균 +15명
const TARGET_TOTAL = 500;           // 목표 평균 누적 인원
const BAND = 50;                    // ±50명에서 진동
const TICKS_PER_HOUR = 2;           // 30분 cron → 시간당 2 tick

// 보기 분배
const USER_OPTION_PROB_MIN = 0.90;  // 익명 보기로 가는 확률 하한
const USER_OPTION_PROB_MAX = 0.98;  // 익명 보기로 가는 확률 상한
const USER_LENGTH_POWER = 1.3;      // 익명 보기 가중치: length^1.3

interface ActivePollPick {
  ref: FirebaseFirestore.DocumentReference;
  data: FirebaseFirestore.DocumentData;
}

/**
 * 매 30분 실행 — 진행 중 투표 1건의 카운트를 자연 증가시킨다.
 */
export const tickFakePollEmpathy = functions
  .region(REGION)
  .pubsub.schedule("*/30 * * * *")
  .timeZone("Asia/Seoul")
  .onRun(async () => {
    const kstHour = new Date(Date.now() + 9 * 3600 * 1000).getUTCHours();
    const hourW = HOURLY_WEIGHTS_KST[kstHour] ?? 0.04;

    const poll = await pickActivePoll();
    if (!poll) {
      functions.logger.info("tickFakePollEmpathy: 진행 중 투표 없음");
      return null;
    }

    const total = (poll.data.totalEmpathyCount as number) ?? 0;
    const scale = bandScale(total);

    // tick 당 평균 (포아송 lambda)
    const lambda = (DAILY_BASE_GROWTH * hourW * scale) / TICKS_PER_HOUR;
    const adds = poissonSample(lambda);
    if (adds <= 0) {
      functions.logger.info(
        `tickFakePollEmpathy: skip poll=${poll.ref.id} hour=${kstHour} ` +
        `total=${total} hourW=${hourW.toFixed(3)} scale=${scale.toFixed(2)} ` +
        `lambda=${lambda.toFixed(3)}`,
      );
      return null;
    }

    const result = await distributeFakeEmpathy(poll, adds);
    functions.logger.info(
      `tickFakePollEmpathy: poll=${poll.ref.id} hour=${kstHour} ` +
      `total=${total} +${result.added} ` +
      `(user=${result.userAdded}/sys=${result.sysAdded})`,
    );
    return null;
  });

/**
 * 운영자가 즉시 N명 부어주고 싶을 때 (어드민 onCall).
 *
 * Input: { pollId?: string, count: number }
 *   - pollId 미지정 시 현재 진행 중 투표 1건 자동 선택
 *   - count: 1~100
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
    const pollIdRaw = typeof data?.pollId === "string" ? data.pollId.trim() : "";
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
      throw new functions.https.HttpsError("failed-precondition", "진행 중 투표가 없습니다.");
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
// 분배 로직
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

  // 옵션별 +N 누적 (한 옵션에 여러 표 박힐 수 있음)
  const incByRef = new Map<FirebaseFirestore.DocumentReference, number>();
  let userAdded = 0;
  let sysAdded = 0;

  for (let i = 0; i < count; i++) {
    const target = pickTarget(userOpts, sysOpts);
    if (!target) break;
    incByRef.set(target.ref, (incByRef.get(target.ref) ?? 0) + 1);
    if (target.kind === "user") {
      userAdded++;
    } else {
      sysAdded++;
    }
  }

  const added = userAdded + sysAdded;
  if (added === 0) return { added: 0, userAdded: 0, sysAdded: 0 };

  const batch = db.batch();
  for (const [ref, n] of incByRef.entries()) {
    batch.update(ref, {
      empathyCount: admin.firestore.FieldValue.increment(n),
    });
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

/**
 * 한 표가 들어갈 보기 1개를 선택.
 *
 * 정책
 *   - 익명 보기 0개 → 시스템 보기 균등
 *   - 익명 보기 ≥1 → USER_OPTION_PROB_MIN~MAX (기본 90~98%) 확률로 익명 보기
 *   - 익명 보기 가중치 = max(1, content.length)^USER_LENGTH_POWER
 *     긴 보기일수록 더 많은 표가 모인다.
 */
function pickTarget(
  userOpts: FirebaseFirestore.QueryDocumentSnapshot[],
  sysOpts: FirebaseFirestore.QueryDocumentSnapshot[],
): TargetPick | null {
  if (userOpts.length === 0 && sysOpts.length === 0) return null;

  // 익명 보기 없으면 시스템 보기 균등
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

// ─────────────────────────────────────────────────────────────
// 보조 함수
// ─────────────────────────────────────────────────────────────

/**
 * 누적 인원이 목표 밴드(500±50)에 가까워질수록 증가량을 부드럽게 줄여
 * 자연스러운 진동을 만든다.
 *
 *   total ≥ 550        : 0   (정지)
 *   500 ≤ total < 550  : 0.15 (약한 위쪽 진동)
 *   450 ≤ total < 500  : 0.45 (감속)
 *   total < 450        : 1.0  (정상 성장)
 */
function bandScale(total: number): number {
  if (total >= TARGET_TOTAL + BAND) return 0.0;
  if (total >= TARGET_TOTAL) return 0.15;
  if (total >= TARGET_TOTAL - BAND) return 0.45;
  return 1.0;
}

/**
 * 작은 lambda에 적합한 Knuth 포아송 샘플링.
 */
function poissonSample(lambda: number): number {
  if (lambda <= 0) return 0;
  const L = Math.exp(-lambda);
  let k = 0;
  let p = 1;
  // 평균값이 작으므로 보통 0~3 범위에서 종료
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

/**
 * 진행 중인 투표 1건 선택.
 * empathy_poll_service.dart의 getActivePoll()과 동일한 정책:
 *   startsAt ≤ now < endsAt 인 후보 중 displayOrder 최소.
 */
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
    if (
      order < bestOrder ||
      (order === bestOrder && startMs < bestStartMs)
    ) {
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
