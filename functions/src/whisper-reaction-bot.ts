import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

const REGION = "us-central1";

// ─────────────────────────────────────────────────────────────
// 속닥속닥(궁금해요 선배 / seniorQuestions) 좋아요·힘내요 자연 증가 봇
//
// 통계 분리 (poll-empathy-bot.ts 와 동일 원칙)
//   관리자 대시보드 일별 집계(aggregateAnalyticsDaily)는 activityLogs 만 읽는다.
//   본 봇은 seniorQuestions / comments / replies 의 likeCount·cheerCount 만
//   admin SDK 로 FieldValue.increment 하며,
//   activityLogs / likes·cheers 서브컬렉션(유저 uid 문서) / CaringTreatService 는
//   절대 건드리지 않는다.
//
// 정책 (사용자 확정 — 2026-05 개편)
//   본문 좋아요
//     · 글마다 상한(플래토) = 60..75 해시 고정
//     · 0일째 끝 = min(상한, 9 + 글 작성 KST일의 앵커 대비 일수)
//         → "하루마다 첫날 끝 기준이 +1" 을 앵커일수에 녹임
//     · 1일째 이후 매일 끝 = 이전 끝 + (5..8, 글ID·일번호 해시) → 상한에서 멈춤
//   힘내요(본문) = 본문 좋아요 × 0.8..0.9 (글ID 해시)  → 항상 좋아요보다 10~20% 낮음
//   댓글 좋아요 = 본문 좋아요 × 0.8..0.9 (글ID|댓글ID 해시) → 본문보다 10~20% 낮음
//   답글 좋아요 = 댓글 좋아요 × 0.8..0.9 (글ID|댓글ID|답글ID 해시) → 댓글보다 10~20% 낮음
//
//   - 이미 목표보다 높으면 더 올리지 않음; 감소는 하지 않음.
//   - KST 시간대 가중치 + 자정 수렴 포아송; 플래토 근처는 약한 진동.
// ─────────────────────────────────────────────────────────────

/** 투표 봇과 동일한 KST 시간대 가중치 (합 ≈ 1.0) */
const HOURLY_WEIGHTS_KST: number[] = [
  0.005, 0.005, 0.005, 0.005, 0.005, 0.005,
  0.010, 0.025, 0.050, 0.060, 0.065, 0.065,
  0.060, 0.055, 0.050, 0.050, 0.050, 0.055,
  0.075, 0.090, 0.095, 0.080, 0.060, 0.030,
];

/** 0일째(작성일 당일) 끝 목표 — 글 작성일과 무관하게 고정 */
const BASE_DAY0 = 9;

const DAILY_INC_MIN = 5;
const DAILY_INC_SPAN = 4; // 5 + [0..3] = 5..8

const PLATEAU_MIN = 60;
const PLATEAU_SPAN = 16; // 60 + [0..15] = 60..75

/** 80~90% 비율 (force 1.0 - ratio = 10~20% 낮음) */
const RATIO_MIN = 0.8;
const RATIO_SPAN = 0.1;

const BAND = 10;

const MAX_QUESTIONS_PER_RUN = 24;
const MAX_COMMENTS_PER_QUESTION = 14;
const MAX_REPLIES_PER_COMMENT = 8;

// ═══════════════════════════════════════════════════════════
// KST (Asia/Seoul)
// ═══════════════════════════════════════════════════════════

function kstYmdParts(ms: number): { y: number; m: number; d: number } {
  const fmt = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Seoul",
    year: "numeric",
    month: "numeric",
    day: "numeric",
  });
  const parts = fmt.formatToParts(new Date(ms));
  const num = (t: string) =>
    parseInt(parts.find((p) => p.type === t)?.value ?? "0", 10);
  return { y: num("year"), m: num("month"), d: num("day") };
}

/** 해당 KST 달력일 00:00 의 epoch ms */
function kstStartOfCalendarDayUtc(ms: number): number {
  const { y, m, d } = kstYmdParts(ms);
  const mm = String(m).padStart(2, "0");
  const dd = String(d).padStart(2, "0");
  return Date.parse(`${y}-${mm}-${dd}T00:00:00+09:00`);
}

/** 게시 시각 ~ 현재까지 KST 자정 기준으로 며칠 지났는지 (첫날 = 0) */
function kstCalendarDayIndex(createdMs: number, nowMs: number): number {
  const a = kstStartOfCalendarDayUtc(createdMs);
  const b = kstStartOfCalendarDayUtc(nowMs);
  return Math.round((b - a) / 86400000);
}

/** 현재 KST 일 안에서 0..1 */
function fracKstDayElapsed(nowMs: number): number {
  const start = kstStartOfCalendarDayUtc(nowMs);
  const elapsed = Math.max(0, nowMs - start);
  return Math.min(1, elapsed / 86400000);
}

function kstHour(nowMs: number): number {
  const fmt = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Seoul",
    hour: "numeric",
    hour12: false,
  });
  return parseInt(fmt.format(new Date(nowMs)), 10);
}

/** 0 이상 1 미만 — 동일 입력이면 재현 */
function hash01(s: string): number {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return (h >>> 0) / 4294967296;
}

function ratio80to90(key: string): number {
  return RATIO_MIN + RATIO_SPAN * hash01(key);
}

/** 본문 좋아요 상한(플래토): 글마다 60..75 */
function likePlateauForQuestion(questionId: string): number {
  return PLATEAU_MIN +
    Math.floor(hash01(`${questionId}|likePlateau`) * PLATEAU_SPAN);
}

/** d일째→d일째 끝 사이 일일 증가분 5..8 (d >= 1) */
function dailyLikeIncrement(
  questionId: string,
  dayNumberFrom1: number,
): number {
  const u = hash01(`${questionId}|likeStep|${dayNumberFrom1}`);
  return DAILY_INC_MIN + Math.floor(u * DAILY_INC_SPAN);
}

/**
 * 본문 좋아요: 각 KST일 끝 누적 목표 T[0..dayIndex].
 * T[0] = min(plateau, BASE_DAY0)  — 작성일 기준 고정
 * T[d] = min(plateau, T[d-1] + dailyLikeIncrement(d))
 */
function buildBodyLikeEodChain(
  questionId: string,
  createdMs: number,
  plateau: number,
  upToDayInclusive: number,
): number[] {
  const t: number[] = [];
  void createdMs; // 작성일은 dayIdx 계산에만 사용; T[0] 은 BASE_DAY0 고정
  const day0End = Math.min(plateau, BASE_DAY0);
  t[0] = day0End;
  for (let d = 1; d <= upToDayInclusive; d++) {
    const inc = dailyLikeIncrement(questionId, d);
    t[d] = Math.min(plateau, t[d - 1] + inc);
  }
  return t;
}

/** 그 시점 기대값(선형 보간): T[d-1] → T[d] 를 phi 로 보간 (T[-1]=0) */
function linearExpectedFromEodChain(
  chain: number[],
  dayIndex: number,
  phi: number,
): number {
  if (dayIndex < 0) return 0;
  const end = chain[dayIndex] ?? chain[chain.length - 1] ?? 0;
  const start = dayIndex === 0 ? 0 : (chain[dayIndex - 1] ?? 0);
  return start + (end - start) * phi;
}

function eodLikeFromChain(chain: number[], dayIndex: number): number {
  if (dayIndex < 0) return 0;
  return chain[dayIndex] ?? chain[chain.length - 1] ?? 0;
}

function bandScaleCounter(count: number, plateau: number): number {
  if (count >= plateau + BAND) return 0.0;
  if (count >= plateau) return 0.15;
  if (count >= plateau - BAND) return 0.45;
  return 1.0;
}

function poissonSample(lambda: number): number {
  if (lambda <= 0) return 0;
  const L = Math.exp(-lambda);
  let k = 0;
  let p = 1;
  // eslint-disable-next-line no-constant-condition
  while (true) {
    k++;
    p *= Math.random();
    if (p < L) return k - 1;
  }
}

/**
 * 남은 EOD 목표를 남은 시간 가중치 비율로 분배해 포아송 강도 산출.
 * remaining × (이번 틱 가중치 / 자정까지 남은 가중치 합) → 자정 수렴.
 */
function plannedAdds(
  current: number,
  expectedFloat: number,
  eodTarget: number,
  hour: number,
  minFrac: number,
  enablePlateauJitter: boolean,
  plateauForBand: number,
  hardCeiling: number,
): number {
  const deficit = expectedFloat - current;
  if (deficit > 0.001) {
    const remaining = Math.max(0, eodTarget - current);
    const hourW = HOURLY_WEIGHTS_KST[hour] ?? 0.04;

    let remainingWeight = hourW * (1 - minFrac);
    for (let h = hour + 1; h < 24; h++) {
      remainingWeight += HOURLY_WEIGHTS_KST[h] ?? 0;
    }
    remainingWeight = Math.max(0.001, remainingWeight);

    const tickWeight = hourW / 2;
    let lambda = remaining * (tickWeight / remainingWeight);
    lambda *= bandScaleCounter(current, plateauForBand);
    lambda = Math.min(lambda, 3.2);

    let raw = poissonSample(lambda);
    const ceiling = enablePlateauJitter ?
      hardCeiling :
      Math.ceil(expectedFloat) + 5;
    raw = Math.min(raw, Math.ceil(deficit), Math.max(0, ceiling - current));
    return Math.max(0, raw);
  }
  if (
    enablePlateauJitter &&
    current >= plateauForBand &&
    current < hardCeiling
  ) {
    const hourW = HOURLY_WEIGHTS_KST[hour] ?? 0.04;
    const p =
      0.035 * bandScaleCounter(current, plateauForBand) *
      Math.max(0.15, hourW);
    return Math.random() < p ? 1 : 0;
  }
  return 0;
}

// ═══════════════════════════════════════════════════════════
// 스케줄러
// ═══════════════════════════════════════════════════════════

export const tickWhisperReactionBot = functions
  .region(REGION)
  .pubsub.schedule("*/30 * * * *")
  .timeZone("Asia/Seoul")
  .onRun(async () => {
    const nowMs = Date.now();
    const hour = kstHour(nowMs);
    const phi = fracKstDayElapsed(nowMs);
    const minFrac = Math.max(0, Math.min(1, phi * 24 - hour));
    const { y, m, d } = kstYmdParts(nowMs);
    const kstDayKey =
      `${y}-${String(m).padStart(2, "0")}-${String(d).padStart(2, "0")}`;

    const snap = await db
      .collection("seniorQuestions")
      .orderBy("createdAt", "desc")
      .limit(120)
      .get();

    const candidates = snap.docs.filter((doc) => {
      const x = doc.data();
      return x.isDeleted !== true && x.isHidden !== true;
    });

    let bodyLike = 0;
    let bodyCheer = 0;
    let commentLike = 0;
    let replyLike = 0;
    let qProcessed = 0;

    for (const qDoc of candidates) {
      if (qProcessed >= MAX_QUESTIONS_PER_RUN) break;
      const created =
        (qDoc.data().createdAt as admin.firestore.Timestamp | undefined)
          ?.toMillis();
      if (!created) continue;

      const dayIdx = kstCalendarDayIndex(created, nowMs);
      if (dayIdx < 0) continue;

      qProcessed++;

      const qid = qDoc.id;
      const plateauLike = likePlateauForQuestion(qid);
      const likeChain = buildBodyLikeEodChain(
        qid,
        created,
        plateauLike,
        dayIdx,
      );

      const expLike = linearExpectedFromEodChain(likeChain, dayIdx, phi);
      const eodLike = eodLikeFromChain(likeChain, dayIdx);

      const cheerR = ratio80to90(`${qid}|cheerVsLike`);
      const expCheer = expLike * cheerR;
      const eodCheer = eodLike * cheerR;
      const plateauCheer = plateauLike * cheerR;

      const hardCeilLike = plateauLike + BAND;
      const hardCeilCheer = Math.ceil(plateauCheer) + BAND;

      const like0 = (qDoc.data().likeCount as number) ?? 0;
      const cheer0 = (qDoc.data().cheerCount as number) ?? 0;

      const addL = plannedAdds(
        like0, expLike, eodLike, hour, minFrac,
        true, plateauLike, hardCeilLike,
      );
      const addC = plannedAdds(
        cheer0, expCheer, eodCheer, hour, minFrac,
        true, plateauCheer, hardCeilCheer,
      );

      const batch = db.batch();
      let ops = 0;

      if (addL > 0) {
        batch.update(qDoc.ref, {
          likeCount: admin.firestore.FieldValue.increment(addL),
        });
        bodyLike += addL;
        ops++;
      }
      if (addC > 0) {
        batch.update(qDoc.ref, {
          cheerCount: admin.firestore.FieldValue.increment(addC),
        });
        bodyCheer += addC;
        ops++;
      }
      if (ops > 0) {
        await batch.commit();
      }

      // ── 댓글·답글: 본문 좋아요 기대치에서 80~90% 씩 곱해 내려감 ──
      const comSnap = await qDoc.ref
        .collection("comments")
        .orderBy("createdAt", "desc")
        .limit(MAX_COMMENTS_PER_QUESTION)
        .get();

      const subBatch = db.batch();
      let subOps = 0;
      for (const cDoc of comSnap.docs) {
        const cd = cDoc.data();
        if (cd.isDeleted === true || cd.isHidden === true) continue;
        if (!(cd.createdAt instanceof admin.firestore.Timestamp)) continue;

        const comR = ratio80to90(`${qid}|${cDoc.id}|commentVsBody`);
        const expCL = expLike * comR;
        const eodCL = eodLike * comR;
        const plateauC = plateauLike * comR;
        const cl0 = (cd.likeCount as number) ?? 0;
        const addCL = plannedAdds(
          cl0, expCL, eodCL, hour, minFrac,
          false, plateauC, Math.ceil(plateauC) + BAND,
        );
        if (addCL > 0) {
          subBatch.update(cDoc.ref, {
            likeCount: admin.firestore.FieldValue.increment(addCL),
          });
          commentLike += addCL;
          subOps++;
        }

        const repSnap = await cDoc.ref
          .collection("replies")
          .orderBy("createdAt", "desc")
          .limit(MAX_REPLIES_PER_COMMENT)
          .get();

        for (const rDoc of repSnap.docs) {
          const rd = rDoc.data();
          if (rd.isDeleted === true) continue;
          if (!(rd.createdAt instanceof admin.firestore.Timestamp)) continue;

          const repR = ratio80to90(
            `${qid}|${cDoc.id}|${rDoc.id}|replyVsComment`,
          );
          const expRL = expCL * repR;
          const eodRL = eodCL * repR;
          const plateauR = plateauC * repR;
          const rl0 = (rd.likeCount as number) ?? 0;
          const addRL = plannedAdds(
            rl0, expRL, eodRL, hour, minFrac,
            false, plateauR, Math.ceil(plateauR) + BAND,
          );
          if (addRL > 0) {
            subBatch.update(rDoc.ref, {
              likeCount: admin.firestore.FieldValue.increment(addRL),
            });
            replyLike += addRL;
            subOps++;
          }
          if (subOps >= 450) break;
        }
        if (subOps >= 450) break;
      }
      if (subOps > 0) await subBatch.commit();
    }

    functions.logger.info(
      `tickWhisperReactionBot: questions=${qProcessed} ` +
        `bodyLike+=${bodyLike} bodyCheer+=${bodyCheer} ` +
        `commentLike+=${commentLike} replyLike+=${replyLike} ` +
        `hour=${hour} phi=${phi.toFixed(3)} kst=${kstDayKey}`,
    );
    return null;
  });
