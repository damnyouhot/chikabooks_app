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
// 통계 분리 (아주 중요 — poll-empathy-bot.ts 와 동일 원칙)
//   관리자 대시보드 일별 집계(aggregateAnalyticsDaily)는 activityLogs 만 읽는다.
//   본 봇은 seniorQuestions / comments / replies 의 likeCount·cheerCount 만
//   admin SDK 로 FieldValue.increment 하며,
//   activityLogs / likes·cheers 서브컬렉션(유저 uid 문서) / CaringTreatService 는
//   절대 건드리지 않는다.
//   → whisper_reaction 통계는 실제 유저가 앱에서 반응할 때만 기록된다.
//
// 정책 (사용자 확정)
//   - 본문 한 편당: 좋아요·힘내요 각각 같은 일간 곡선(첫날 끝 7 → 매일 +2 → 상한 70)을 기준으로 하되,
//     서로 꼭 같을 필요 없음 — 글·KST일별 해시 비율 + 매 틱 독립 소량 지터로 목표를 달리 잡는다.
//   - KST 하루 안에서는 투표 봇과 같은 시간대 가중치로 천천히 올라가고,
//     그날 자정 직전에는 그날 목표치에 도달하도록 deficit 기반 포아송.
//   - 70 도달 후에는 60~80 구간에서만 아주 작은 증가(진동, poll 의 band 와 유사).
//   - 댓글·답글은 본문 목표의 일정 비율(댓글 35%, 답글 28%)로 적게; 답글은 좋아요만.
// ─────────────────────────────────────────────────────────────

/** 투표 봇과 동일한 KST 시간대 가중치 (합 ≈ 1.0) */
const HOURLY_WEIGHTS_KST: number[] = [
  0.005, 0.005, 0.005, 0.005, 0.005, 0.005,
  0.010, 0.025, 0.050, 0.060, 0.065, 0.065,
  0.060, 0.055, 0.050, 0.050, 0.050, 0.055,
  0.075, 0.090, 0.095, 0.080, 0.060, 0.030,
];

const PLATEAU = 70;
const BAND = 10;
const RAMP_START = 7;
const RAMP_STEP = 2;

/** 본문 대비 댓글 좋아요 목표 비율 */
const COMMENT_LIKE_RATIO = 0.35;
/** 본문 대비 답글 좋아요 목표 비율 */
const REPLY_LIKE_RATIO = 0.28;

const MAX_QUESTIONS_PER_RUN = 24;
const MAX_COMMENTS_PER_QUESTION = 14;
const MAX_REPLIES_PER_COMMENT = 8;

const HARD_CEILING = PLATEAU + BAND; // 80 — 봇이 increment 로 올릴 상한

// ═══════════════════════════════════════════════════════════
// KST (Asia/Seoul) — Intl 로 일·시간만 구함 (luxon 미사용)
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

/** 현재 KST 일 안에서 0..1 (자정 직후 0, 다음 자정 직전 1에 가깝게) */
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

/** 그날 KST 자정 기준 목표 누적(좋아요 또는 힘내요 한 축) */
function endOfDayTarget(dayIndex: number): number {
  return Math.min(RAMP_START + RAMP_STEP * dayIndex, PLATEAU);
}

function startOfDayTarget(dayIndex: number): number {
  if (dayIndex <= 0) return 0;
  return Math.min(RAMP_START + RAMP_STEP * (dayIndex - 1), PLATEAU);
}

/**
 * 지금 이 순간까지 이상이어야 하는 기대 누적(선형 보간).
 * T_prev → T_today 사이를 하루 동안 균등 진행.
 */
function linearExpectedNow(dayIndex: number, phi: number): number {
  const t0 = startOfDayTarget(dayIndex);
  const t1 = endOfDayTarget(dayIndex);
  return t0 + (t1 - t0) * phi;
}

/** 0 이상 1 미만 — 동일 입력이면 재현되는 난수(일·축별 편차용) */
function hash01(s: string): number {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return (h >>> 0) / 4294967296;
}

/** 좋아요·힘내요 각각 다른 목표 기대값 (상한 PLATEAU, 통계 필드 미작성 유지) */
function bodyExpectedAxes(
  questionId: string,
  dayIndex: number,
  phi: number,
  kstDayKey: string,
): { expLike: number; expCheer: number } {
  const base = linearExpectedNow(dayIndex, phi);
  const likeAxis = 0.82 + 0.36 * hash01(`${questionId}|like|${kstDayKey}`);
  const cheerAxis = 0.82 + 0.36 * hash01(`${questionId}|cheer|${kstDayKey}`);
  const jL = 0.88 + 0.24 * Math.random();
  const jC = 0.88 + 0.24 * Math.random();
  return {
    expLike: Math.min(PLATEAU, base * likeAxis * jL),
    expCheer: Math.min(PLATEAU, base * cheerAxis * jC),
  };
}

/**
 * 플래토 70 ± 10 — poll 의 bandScale 과 동형.
 *   ≥80 : 정지
 *   ≥70 : 약한 진동
 *   ≥60 : 감속
 *   <60 : 정상 추격
 */
function bandScaleCounter(count: number): number {
  if (count >= PLATEAU + BAND) return 0.0;
  if (count >= PLATEAU) return 0.15;
  if (count >= PLATEAU - BAND) return 0.45;
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

/**
 * deficit = 기대값 − 현재값. 남은 30분 슬롯에 나눠 포아송 강도 산출.
 */
function plannedAdds(
  current: number,
  expectedFloat: number,
  phi: number,
  hourW: number,
  enablePlateauJitter: boolean,
): number {
  const deficit = expectedFloat - current;
  if (deficit > 0.001) {
    const remSlots = Math.max(1, Math.ceil((1 - phi) * 48));
    let lambda = (deficit / remSlots) * hourW * 8;
    lambda *= bandScaleCounter(current);
    lambda = Math.min(lambda, 3.2);
    let raw = poissonSample(lambda);
    const ceiling = enablePlateauJitter ? HARD_CEILING : Math.ceil(expectedFloat) + 5;
    raw = Math.min(raw, Math.ceil(deficit), Math.max(0, ceiling - current));
    return Math.max(0, raw);
  }
  if (
    enablePlateauJitter &&
    current >= PLATEAU &&
    current < HARD_CEILING
  ) {
    const p = 0.035 * bandScaleCounter(current) * Math.max(0.15, hourW);
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
    const hourW = HOURLY_WEIGHTS_KST[hour] ?? 0.04;
    const phi = fracKstDayElapsed(nowMs);
    const { y, m, d } = kstYmdParts(nowMs);
    const kstDayKey = `${y}-${String(m).padStart(2, "0")}-${String(d).padStart(2, "0")}`;

    const snap = await db
      .collection("seniorQuestions")
      .orderBy("createdAt", "desc")
      .limit(120)
      .get();

    const candidates = snap.docs.filter((d) => {
      const x = d.data();
      return x.isDeleted !== true && x.isHidden !== true;
    });

    let bodyLike = 0;
    let bodyCheer = 0;
    let commentLike = 0;
    let replyLike = 0;
    let qProcessed = 0;

    for (const qDoc of candidates) {
      if (qProcessed >= MAX_QUESTIONS_PER_RUN) break;
      const created = (qDoc.data().createdAt as admin.firestore.Timestamp | undefined)?.toMillis();
      if (!created) continue;

      const dayIdx = kstCalendarDayIndex(created, nowMs);
      if (dayIdx < 0) continue;

      qProcessed++;

      const { expLike, expCheer } = bodyExpectedAxes(
        qDoc.id,
        dayIdx,
        phi,
        kstDayKey,
      );

      const like0 = (qDoc.data().likeCount as number) ?? 0;
      const cheer0 = (qDoc.data().cheerCount as number) ?? 0;

      const addL = plannedAdds(like0, expLike, phi, hourW, true);
      const addC = plannedAdds(cheer0, expCheer, phi, hourW, true);

      const batch = db.batch();
      let ops = 0;

      if (addL > 0) {
        batch.update(qDoc.ref, { likeCount: admin.firestore.FieldValue.increment(addL) });
        bodyLike += addL;
        ops++;
      }
      if (addC > 0) {
        batch.update(qDoc.ref, { cheerCount: admin.firestore.FieldValue.increment(addC) });
        bodyCheer += addC;
        ops++;
      }

      if (ops > 0) {
        await batch.commit();
      }

      // ── 댓글·답글 (한 루프에서 처리, 본문보다 낮은 목표) ──
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
        const cCreated = (cd.createdAt as admin.firestore.Timestamp | undefined)?.toMillis();
        if (!cCreated) continue;
        const cDay = kstCalendarDayIndex(cCreated, nowMs);
        const expCL = linearExpectedNow(cDay, phi) * COMMENT_LIKE_RATIO;
        const cl0 = (cd.likeCount as number) ?? 0;
        const addCL = plannedAdds(cl0, expCL, phi, hourW, false);
        if (addCL > 0) {
          subBatch.update(cDoc.ref, { likeCount: admin.firestore.FieldValue.increment(addCL) });
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
          const rCreated = (rd.createdAt as admin.firestore.Timestamp | undefined)?.toMillis();
          if (!rCreated) continue;
          const rDay = kstCalendarDayIndex(rCreated, nowMs);
          const expRL = linearExpectedNow(rDay, phi) * REPLY_LIKE_RATIO;
          const rl0 = (rd.likeCount as number) ?? 0;
          const addRL = plannedAdds(rl0, expRL, phi, hourW, false);
          if (addRL > 0) {
            subBatch.update(rDoc.ref, { likeCount: admin.firestore.FieldValue.increment(addRL) });
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
        `commentLike+=${commentLike} replyLike+=${replyLike} hour=${hour} phi=${phi.toFixed(3)}`,
    );
    return null;
  });
