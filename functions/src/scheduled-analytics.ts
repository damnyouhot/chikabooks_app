import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

const db = admin.firestore();

// ── 정의: lib/core/analytics/event_catalog.dart 와 1:1 일치 ──
//
// ⚠️ 변경 시 반드시 클라이언트 카탈로그(event_catalog.dart)와 동시에 수정할 것.
// 두 정의가 어긋나면 Behavior 탭(클라 직접 계산)과 Trends 탭(서버 일별 집계)이
// 같은 이름의 지표인데 서로 다른 숫자를 보여주게 된다.
const MEANINGFUL_ACTIONS = new Set([
  // 나 탭
  "tap_character",
  "caring_feed_success",
  "tap_emotion_start",
  "tap_emotion_save",
  "emotion_save_success",
  // 프로필·커리어·구직
  "tap_profile_save",
  "tap_job_save",
  "tap_job_apply",
  "tap_career_edit",
  "view_job_detail",
  // 성장
  "quiz_completed",
  // 같이(공감투표)
  "poll_empathize",
  "poll_change_empathy",
  "poll_add_option",
]);

// EventCatalog.dailyFeatureUsageTypes 와 동일
const FEATURE_KEYS = [
  "emotion_save_success",
  "tap_character",
  "caring_feed_success",
  "view_job_detail",
  "quiz_completed",
];

const TAB_KEYS = ["view_home", "view_job", "view_growth", "view_bond"];

// kTabConversionRows 와 동일 (view_home → caring_feed_success 로 통일)
const CONVERSION_PAIRS: [string, string][] = [
  ["view_home", "caring_feed_success"],
  ["view_job", "view_job_detail"],
  ["view_growth", "quiz_completed"],
  ["view_bond", "poll_empathize"],
];

const GROWTH_EVENTS = new Set(["view_growth"]);
const EMOTION_EVENTS = new Set(["tap_character", "emotion_save_success"]);
const CAREER_EVENTS = new Set([
  "view_job_detail",
  "tap_job_save",
  "tap_job_apply",
]);
// kSegmentBondTypes 와 동일 — 기존엔 누락되어 segments.bond 가 항상 0이었음
const BOND_EVENTS = new Set([
  "view_bond",
  "poll_empathize",
  "poll_change_empathy",
  "poll_add_option",
]);

/**
 * 매일 KST 01:00에 어제의 activityLogs를 집계하여
 * analytics_daily/{dateKey} 문서를 생성한다.
 */
export const aggregateAnalyticsDaily = functions
  .pubsub.schedule("0 1 * * *")
  .timeZone("Asia/Seoul")
  .onRun(async () => {
    // 어제 + 그 이전 6일(총 최근 7일) 중 누락분을 함께 채운다.
    // 함수 배포가 일시 중단됐던 구간이 자동 복구되도록 안전 장치.
    // 활동이 0건인 날도 generateForDate가 0으로 채워 문서를 만들어
    // Trends 차트가 끊겨 보이지 않게 한다.
    const now = new Date();
    for (let offset = 1; offset <= 7; offset++) {
      const target = new Date(now);
      target.setDate(target.getDate() - offset);
      const dateKey = formatDateKey(target);
      try {
        const existing = await db
          .collection("analytics_daily")
          .doc(dateKey)
          .get();
        if (existing.exists) {
          if (offset === 1) {
            console.log(`📊 [AnalyticsDaily] ${dateKey} 이미 존재 → 스킵`);
          }
          continue;
        }
        await generateForDate(target);
        console.log(`✅ [AnalyticsDaily] ${dateKey} 집계 완료`);
      } catch (error) {
        console.error(`❌ [AnalyticsDaily] ${dateKey} 실패:`, error);
      }
    }
  });

/**
 * 특정 날짜의 집계를 생성하여 analytics_daily에 저장
 */
async function generateForDate(date: Date): Promise<void> {
  const dayStart = new Date(
    date.getFullYear(),
    date.getMonth(),
    date.getDate()
  );
  const dayEnd = new Date(dayStart);
  dayEnd.setDate(dayEnd.getDate() + 1);
  const dateKey = formatDateKey(date);

  // Step 1: validUserIds 확보
  const usersSnap = await db
    .collection("users")
    .where("excludeFromStats", "==", false)
    .get();
  const validUserIds = new Set<string>();
  for (const doc of usersSnap.docs) {
    validUserIds.add(doc.id);
  }
  const total = validUserIds.size;

  // Step 2: 해당 날짜의 activityLogs 읽기
  const logsSnap = await db
    .collection("activityLogs")
    .where("timestamp", ">=", admin.firestore.Timestamp.fromDate(dayStart))
    .where("timestamp", "<", admin.firestore.Timestamp.fromDate(dayEnd))
    .orderBy("timestamp")
    .limit(5000)
    .get();

  // Step 3: 필터링 + 그룹화
  const userEvents: Map<string, string[]> = new Map();
  const eventCounts: Record<string, number> = {};
  const activeUserIds = new Set<string>();

  for (const doc of logsSnap.docs) {
    const data = doc.data();
    if (data.isFunnel === true) continue;
    if (data.accountType === "publisher") continue;

    const uid = (data.userId as string) || "";
    const type = (data.type as string) || "";
    if (!uid || !type) continue;
    if (!validUserIds.has(uid)) continue;

    activeUserIds.add(uid);
    if (!userEvents.has(uid)) userEvents.set(uid, []);
    userEvents.get(uid)!.push(type);
    eventCounts[type] = (eventCounts[type] || 0) + 1;
  }

  // Step 4: 지표 계산
  const featureUsage: Record<string, number> = {};
  for (const key of FEATURE_KEYS) {
    let count = 0;
    for (const [, events] of userEvents) {
      if (events.includes(key)) count++;
    }
    featureUsage[key] = count;
  }

  const tabViews: Record<string, number> = {};
  for (const key of TAB_KEYS) {
    let count = 0;
    for (const [, events] of userEvents) {
      if (events.includes(key)) count++;
    }
    tabViews[key] = count;
  }

  const tabConversions: Record<string, number> = {};
  for (const [tab, action] of CONVERSION_PAIRS) {
    const convKey = `${tab}__${action}`;
    let count = 0;
    for (const [, events] of userEvents) {
      if (events.includes(tab) && events.includes(action)) count++;
    }
    tabConversions[convKey] = count;
  }

  let loginOnly = 0;
  let oneAction = 0;
  let twoToFour = 0;
  let fivePlus = 0;
  for (const [, events] of userEvents) {
    const meaningful = events.filter((t) => MEANINGFUL_ACTIONS.has(t)).length;
    if (meaningful === 0) loginOnly++;
    else if (meaningful === 1) oneAction++;
    else if (meaningful <= 4) twoToFour++;
    else fivePlus++;
  }
  let noEventUsers = 0;
  for (const uid of validUserIds) {
    if (!userEvents.has(uid)) noEventUsers++;
  }
  loginOnly += noEventUsers;

  let growth = 0;
  let emotion = 0;
  let career = 0;
  let bond = 0;
  let ghost = 0;
  for (const [, events] of userEvents) {
    const typeSet = new Set(events);
    const isGrowth = [...typeSet].some((t) => GROWTH_EVENTS.has(t));
    const isEmotion = [...typeSet].some((t) => EMOTION_EVENTS.has(t));
    const isCareer = [...typeSet].some((t) => CAREER_EVENTS.has(t));
    const isBond = [...typeSet].some((t) => BOND_EVENTS.has(t));
    if (isGrowth) growth++;
    if (isEmotion) emotion++;
    if (isCareer) career++;
    if (isBond) bond++;
    if (!isGrowth && !isEmotion && !isCareer && !isBond) {
      const hasMeaningful = [...typeSet].some((t) =>
        MEANINGFUL_ACTIONS.has(t)
      );
      if (!hasMeaningful) ghost++;
    }
  }
  ghost += noEventUsers;

  // Step 5: Firestore 저장
  await db
    .collection("analytics_daily")
    .doc(dateKey)
    .set({
      dateKey,
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      totalValidUsers: total,
      activeUsers: activeUserIds.size,
      featureUsage,
      tabViews,
      tabConversions,
      depthBuckets: {loginOnly, oneAction, twoToFour, fivePlus},
      segments: {growth, emotion, career, bond, ghost},
      retention: {d3: 0, d7: 0},
      eventCounts,
    });

  console.log(
    `📊 [AnalyticsDaily] ${dateKey}: ` +
      `total=${total}, active=${activeUserIds.size}, ` +
      `logs=${logsSnap.docs.length}`
  );
}

function formatDateKey(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}
