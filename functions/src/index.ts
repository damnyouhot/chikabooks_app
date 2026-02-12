import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {logger} from "firebase-functions";
import * as admin from "firebase-admin";
import {DateTime} from "luxon";

admin.initializeApp();
const db = admin.firestore();

// ═══════════════════════════════════════════════════════════
// 기존: growthEvent → 유저 스탯 업데이트
// ═══════════════════════════════════════════════════════════

export const onGrowthEventCreated = onDocumentCreated(
  "growthEvents/{eventId}",
  (event) => {
    const snap = event.data;
    if (!snap) {
      logger.error("No data associated with the event", event);
      return;
    }
    const eventData = snap.data();
    const {userId, type, value} = eventData;

    if (!userId || !type || value === undefined) {
      logger.error("Missing fields in event data", eventData);
      return;
    }

    const userRef = db.doc(`users/${userId}`);
    const updates: {[key: string]: unknown} = {};

    switch (type) {
    case "exercise":
      updates["stats.stepCount"] =
          admin.firestore.FieldValue.increment(value);
      updates["stats.emotionPoints"] =
          admin.firestore.FieldValue.increment(Math.round(value / 100));
      break;
    case "sleep":
      updates["stats.sleepHours"] =
          admin.firestore.FieldValue.increment(value);
      updates["stats.emotionPoints"] =
          admin.firestore.FieldValue.increment(Math.round(value * 5));
      break;
    case "study":
      updates["stats.studyMinutes"] =
          admin.firestore.FieldValue.increment(value);
      updates["stats.emotionPoints"] =
          admin.firestore.FieldValue.increment(Math.round(value / 10));
      break;
    case "emotion":
    case "interaction":
      updates["stats.emotionPoints"] =
          admin.firestore.FieldValue.increment(value);
      break;
    case "quiz":
      updates["stats.quizCount"] =
          admin.firestore.FieldValue.increment(value);
      updates["stats.emotionPoints"] =
          admin.firestore.FieldValue.increment(10);
      break;
    default:
      logger.log(`Unhandled event type: ${type}`);
      return;
    }

    try {
      userRef.set({stats: updates}, {merge: true});
      logger.log(`User ${userId} stats updated:`, updates);
    } catch (error) {
      logger.error(`Failed to update stats for user ${userId}`, error);
    }
  }
);

// ═══════════════════════════════════════════════════════════
// 파트너 매칭: requestPartnerMatching (v2 Callable)
// ═══════════════════════════════════════════════════════════

type CareerBucket = "0-2" | "3-5" | "6+";

interface PoolEntry {
  uid: string;
  region: string;
  careerBucket: CareerBucket;
  workplaceType?: string | null;
  mainConcerns: string[];
  status: string;
}

/** 배열 교집합 */
function intersect(a: string[], b: string[]): string[] {
  const s = new Set(a);
  return b.filter((x) => s.has(x));
}

/**
 * Tier 기반 후보 필터
 * T1: 주 고민 ∩ ≥1 + 연차 동일
 * T2: 주 고민 ∩ ≥1
 * T3: 연차 동일
 * T4: 전체 (아무나)
 */
function pickTierCandidates(me: PoolEntry, candidates: PoolEntry[]):
    PoolEntry[] {
  const meConcerns = me.mainConcerns ?? [];

  const tier1 = candidates.filter((c) =>
    intersect(meConcerns, c.mainConcerns ?? []).length > 0 &&
    c.careerBucket === me.careerBucket
  );
  if (tier1.length >= 2) return tier1;

  const tier2 = candidates.filter((c) =>
    intersect(meConcerns, c.mainConcerns ?? []).length > 0
  );
  if (tier2.length >= 2) return tier2;

  const tier3 = candidates.filter((c) =>
    c.careerBucket === me.careerBucket
  );
  if (tier3.length >= 2) return tier3;

  return candidates; // Tier4: 아무나
}

/** 전역 락 획득 (15초 TTL) */
async function acquireGlobalLock(
  lockId: string,
  owner: string
): Promise<void> {
  const lockRef = db.collection("partnerMatchingLocks").doc(lockId);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(lockRef);
    const now = admin.firestore.Timestamp.now();
    const expiresAt = admin.firestore.Timestamp.fromMillis(
      now.toMillis() + 15_000
    );

    if (!snap.exists) {
      tx.set(lockRef, {lockedAt: now, lockedBy: owner, expiresAt});
      return;
    }

    const data = snap.data()!;
    const currentExpires =
        data.expiresAt as admin.firestore.Timestamp | undefined;

    // 만료된 락이면 재획득
    if (!currentExpires || currentExpires.toMillis() < now.toMillis()) {
      tx.set(lockRef, {lockedAt: now, lockedBy: owner, expiresAt},
        {merge: true});
      return;
    }

    throw new HttpsError(
      "resource-exhausted",
      "매칭이 진행 중이에요. 잠시 후 다시 시도해주세요."
    );
  });
}

/** 전역 락 해제 */
async function releaseGlobalLock(
  lockId: string,
  owner: string
): Promise<void> {
  const lockRef = db.collection("partnerMatchingLocks").doc(lockId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(lockRef);
    if (!snap.exists) return;
    if (snap.data()?.lockedBy === owner) {
      tx.delete(lockRef);
    }
  });
}

/**
 * requestPartnerMatching
 *
 * 1. 유저 프로필 검증
 * 2. 이미 활성 그룹이 있으면 반환
 * 3. 매칭 풀에 등록
 * 4. 전역 락 획득 → 3명 매칭 시도
 * 5. 성공: 그룹 생성 + pool 업데이트 + users 업데이트
 * 6. 실패: "대기 중" 반환
 */
export const requestPartnerMatching = onCall(
  {region: "asia-northeast3"},
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }

    // ── 1. 유저 프로필 로드 + 필수 필드 검증 ──
    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "유저 정보가 없습니다.");
    }
    const me = userSnap.data()!;

    const requiredFields = [
      "nickname", "region", "careerBucket", "mainConcerns",
    ];
    for (const k of requiredFields) {
      if (!me[k] || (Array.isArray(me[k]) && me[k].length === 0)) {
        throw new HttpsError(
          "failed-precondition",
          `프로필 입력이 필요합니다: ${k}`
        );
      }
    }

    // ── 2. 이미 활성 그룹이 있으면 반환 (중복 매칭 방지) ──
    // 먼저 매칭 풀 상태 확인 (가장 최신 상태)
    const poolSnap = await db.collection("partnerMatchingPool").doc(uid).get();
    if (poolSnap.exists && poolSnap.data()?.status === "matched") {
      const existingGroupId = poolSnap.data()?.matchedGroupId as string | undefined;
      if (existingGroupId) {
        // 매칭 풀에 이미 matched 상태로 있으면 바로 반환
        return {status: "matched", groupId: existingGroupId};
      }
    }

    // users 문서의 partnerGroupId도 체크
    if (me.partnerGroupId) {
      const gSnap = await db
        .collection("partnerGroups")
        .doc(me.partnerGroupId)
        .get();

      if (gSnap.exists) {
        const gData = gSnap.data()!;
        const endsAt = gData.endsAt as admin.firestore.Timestamp | undefined;
        const isActive =
            gData.status === "active" &&
            endsAt &&
            endsAt.toMillis() > Date.now();

        if (isActive) {
          return {status: "matched", groupId: me.partnerGroupId};
        }
      }
      // 만료/깨진 그룹 → 클리어
      await userRef.update({
        partnerGroupId: admin.firestore.FieldValue.delete(),
        partnerGroupEndsAt: admin.firestore.FieldValue.delete(),
      });
    }

    // ── 3. 매칭 풀에 등록 (upsert) ──
    const poolRef = db.collection("partnerMatchingPool").doc(uid);
    await poolRef.set({
      uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      region: me.region,
      careerBucket: me.careerBucket as CareerBucket,
      workplaceType: me.workplaceType ?? null,
      mainConcerns: me.mainConcerns ?? [],
      status: "waiting",
    }, {merge: true});

    // ── 4. 전역 락 획득 ──
    const lockOwner = `${uid}_${Date.now()}`;
    await acquireGlobalLock("global", lockOwner);

    try {
      // ── 5. waiting 후보 읽기 (본인 제외, 최대 30명) ──
      const qs = await db.collection("partnerMatchingPool")
        .where("status", "==", "waiting")
        .orderBy("createdAt", "asc")
        .limit(30)
        .get();

      const waiting: PoolEntry[] = qs.docs
        .map((d) => d.data() as PoolEntry)
        .filter((d) => d.uid !== uid);

      // 나 자신도 PoolEntry로 변환
      const mePool: PoolEntry = {
        uid,
        region: me.region,
        careerBucket: me.careerBucket as CareerBucket,
        workplaceType: me.workplaceType ?? null,
        mainConcerns: me.mainConcerns ?? [],
        status: "waiting",
      };

      // ── 6. Tier 기반 후보 필터 ──
      const tierCandidates = pickTierCandidates(mePool, waiting);

      if (tierCandidates.length < 2) {
        // 후보 부족 → 대기
        return {
          status: "waiting",
          message: "아직 함께할 사람이 부족해요. 조금만 기다려주세요.",
        };
      }

      // 가점 정렬: region 같으면 +1, workplaceType 같으면 +0.2
      tierCandidates.sort((a, b) => {
        const aScore =
            (a.region === mePool.region ? 1 : 0) +
            (a.workplaceType === mePool.workplaceType ? 0.2 : 0);
        const bScore =
            (b.region === mePool.region ? 1 : 0) +
            (b.workplaceType === mePool.workplaceType ? 0.2 : 0);
        return bScore - aScore;
      });

      const picked2 = tierCandidates.slice(0, 2);
      const memberUids = [uid, picked2[0].uid, picked2[1].uid];

      // ── 7. 트랜잭션: 그룹 생성 + pool 업데이트 + users 업데이트 ──
      const groupRef = db.collection("partnerGroups").doc();
      const now = admin.firestore.Timestamp.now();
      const endsAt = admin.firestore.Timestamp.fromMillis(
        now.toMillis() + 7 * 24 * 60 * 60 * 1000 // +7일
      );

      await db.runTransaction(async (tx) => {
        // pool 상태 재확인 (동시성 방어)
        const poolSnaps = await Promise.all(
          memberUids.map((u) =>
            tx.get(db.collection("partnerMatchingPool").doc(u))
          )
        );

        for (const s of poolSnaps) {
          if (!s.exists) {
            throw new HttpsError(
              "failed-precondition",
              "매칭 풀에서 제외된 유저가 있습니다."
            );
          }
          if (s.data()!.status !== "waiting") {
            throw new HttpsError(
              "aborted",
              "이미 매칭된 유저가 포함되어 있습니다."
            );
          }
        }

        // 공통 고민 추출 (matchingMeta용)
        const commonConcern =
            intersect(
              mePool.mainConcerns,
              picked2[0].mainConcerns ?? []
            )[0] ?? mePool.mainConcerns[0] ?? "unknown";

        // partnerGroups 생성
        tx.set(groupRef, {
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          startedAt: admin.firestore.FieldValue.serverTimestamp(),
          endsAt,
          status: "active",
          memberUids,
          matchingMeta: {
            mainConcern: commonConcern,
            regionMix: memberUids.map((u) => {
              if (u === uid) return mePool.region;
              const p = picked2.find((c) => c.uid === u);
              return p?.region ?? "";
            }),
            careerMix: memberUids.map((u) => {
              if (u === uid) return mePool.careerBucket;
              const p = picked2.find((c) => c.uid === u);
              return p?.careerBucket ?? "";
            }),
          },
          extensionVotes: {},
        });

        // memberMeta 생성
        for (const u of memberUids) {
          const uData = u === uid ? me : picked2.find((p) => p.uid === u);
          if (!uData) continue;

          tx.set(groupRef.collection("memberMeta").doc(u), {
            region: uData.region ?? "",
            careerBucket: uData.careerBucket ?? "",
            workplaceType: uData.workplaceType ?? null,
            mainConcernShown:
                (uData.mainConcerns ?? [])[0] ?? "unknown",
            joinedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        // users/{uid} 업데이트
        for (const u of memberUids) {
          tx.set(db.collection("users").doc(u), {
            partnerGroupId: groupRef.id,
            partnerGroupEndsAt: endsAt,
          }, {merge: true});
        }

        // pool 문서 → matched
        for (const u of memberUids) {
          tx.set(db.collection("partnerMatchingPool").doc(u), {
            status: "matched",
            matchedGroupId: groupRef.id,
          }, {merge: true});
        }
      });

      logger.info(
        `Partner group created: ${groupRef.id}`,
        {memberUids}
      );

      return {status: "matched", groupId: groupRef.id};
    } finally {
      await releaseGlobalLock("global", lockOwner);
    }
  }
);

// ═══════════════════════════════════════════════════════════
// 슬롯 시스템: 서버 시간 기준 슬롯 상태 + 한마디 + 리액션
// ═══════════════════════════════════════════════════════════

/**
 * 서버 시간 기준 슬롯 상태 반환
 * 슬롯: 12:30~12:59, 19:00~19:29 (KST 기준)
 */
export const getSlotStatus = onCall(
  {region: "asia-northeast3"},
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }

    const {groupId} = request.data;
    if (!groupId) {
      throw new HttpsError("invalid-argument", "groupId가 필요합니다.");
    }

    // 서버 시간 기준 KST
    const nowKst = DateTime.now().setZone("Asia/Seoul");
    const hour = nowKst.hour;
    const minute = nowKst.minute;
    const dateKey = nowKst.toFormat("yyyy-MM-dd");

    let isOpen = false;
    let slotKey: string | null = null;
    let windowEndsAt: string | null = null;
    let nextOpensAt: string | null = null;

    // 12:30~12:59
    if (hour === 12 && minute >= 30 && minute < 60) {
      isOpen = true;
      slotKey = "1230";
      windowEndsAt = nowKst.set({hour: 13, minute: 0, second: 0}).toISO();
      nextOpensAt = nowKst.set({hour: 19, minute: 0, second: 0}).toISO();
    }
    // 19:00~19:29
    else if (hour === 19 && minute >= 0 && minute < 30) {
      isOpen = true;
      slotKey = "1900";
      windowEndsAt = nowKst.set({hour: 19, minute: 30, second: 0}).toISO();
      nextOpensAt = nowKst.plus({days: 1}).set({
        hour: 12,
        minute: 30,
        second: 0,
      }).toISO();
    }
    // 닫혀 있음
    else {
      isOpen = false;
      // 다음 슬롯 계산
      if (hour < 12 || (hour === 12 && minute < 30)) {
        nextOpensAt = nowKst.set({hour: 12, minute: 30, second: 0}).toISO();
      } else if (hour < 19) {
        nextOpensAt = nowKst.set({hour: 19, minute: 0, second: 0}).toISO();
      } else {
        nextOpensAt = nowKst.plus({days: 1}).set({
          hour: 12,
          minute: 30,
          second: 0,
        }).toISO();
      }
    }

    const slotId = slotKey ? `${dateKey}_${slotKey}` : null;

    return {
      nowKst: nowKst.toISO(),
      isOpen,
      slotId,
      slotKey,
      windowEndsAt,
      nextOpensAt,
    };
  }
);

/**
 * 슬롯 한마디 작성 (60자 제한, 1인만 작성 가능)
 */
export const submitSlotMessage = onCall(
  {region: "asia-northeast3"},
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }

    const {groupId, message} = request.data;
    if (!groupId || !message) {
      throw new HttpsError(
        "invalid-argument",
        "groupId와 message가 필요합니다."
      );
    }

    // 메시지 길이 검증
    if (message.length > 60) {
      throw new HttpsError(
        "invalid-argument",
        "메시지는 60자 이하여야 합니다."
      );
    }

    // 그룹 멤버 확인
    const groupDoc = await db.collection("partnerGroups").doc(groupId).get();
    if (!groupDoc.exists) {
      throw new HttpsError("not-found", "그룹을 찾을 수 없습니다.");
    }
    const groupData = groupDoc.data()!;
    if (!groupData.memberUids.includes(uid)) {
      throw new HttpsError(
        "permission-denied",
        "그룹 멤버만 작성할 수 있습니다."
      );
    }

    // 서버 시간 기준 슬롯 상태 확인
    const nowKst = DateTime.now().setZone("Asia/Seoul");
    const hour = nowKst.hour;
    const minute = nowKst.minute;
    const dateKey = nowKst.toFormat("yyyy-MM-dd");

    let slotKey: string | null = null;
    if (hour === 12 && minute >= 30 && minute < 60) {
      slotKey = "1230";
    } else if (hour === 19 && minute >= 0 && minute < 30) {
      slotKey = "1900";
    }

    if (!slotKey) {
      throw new HttpsError(
        "failed-precondition",
        "지금은 말할 수 있는 시간이 아닙니다."
      );
    }

    const slotId = `${dateKey}_${slotKey}`;
    const slotRef = db
      .collection("partnerGroups")
      .doc(groupId)
      .collection("slots")
      .doc(slotId);

    // 트랜잭션: 이미 작성된 슬롯인지 확인
    await db.runTransaction(async (tx) => {
      const slotSnap = await tx.get(slotRef);
      if (slotSnap.exists && slotSnap.data()?.authorUid) {
        throw new HttpsError(
          "already-exists",
          "이 슬롯은 이미 한마디가 올라왔어요. 리액션만 가능해요."
        );
      }

      // 슬롯 문서 생성/업데이트
      tx.set(slotRef, {
        slotKey,
        date: dateKey,
        groupId,
        message,
        authorUid: uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        reactions: {},
      });

      // 이벤트 로그 생성
      const eventRef = db
        .collection("partnerGroups")
        .doc(groupId)
        .collection("events")
        .doc();
      const targetUids = groupData.memberUids.filter((u: string) => u !== uid);
      tx.set(eventRef, {
        type: "slot_message",
        actorUid: uid,
        targetUids,
        slotId,
        payload: {message: message.substring(0, 20)},
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    // 인박스 요약 카드 업데이트 (비동기)
    await updateInboxCards(groupId, uid, "slot_message", dateKey);

    return {success: true, slotId};
  }
);

/**
 * 슬롯 리액션 작성
 */
export const submitSlotReaction = onCall(
  {region: "asia-northeast3"},
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }

    const {groupId, slotId, emoji, phraseId, phraseText} = request.data;
    if (!groupId || !slotId || !emoji || !phraseId || !phraseText) {
      throw new HttpsError(
        "invalid-argument",
        "필수 파라미터가 누락되었습니다."
      );
    }

    // 그룹 멤버 확인
    const groupDoc = await db.collection("partnerGroups").doc(groupId).get();
    if (!groupDoc.exists) {
      throw new HttpsError("not-found", "그룹을 찾을 수 없습니다.");
    }
    const groupData = groupDoc.data()!;
    if (!groupData.memberUids.includes(uid)) {
      throw new HttpsError(
        "permission-denied",
        "그룹 멤버만 리액션할 수 있습니다."
      );
    }

    // 슬롯 문서 확인
    const slotRef = db
      .collection("partnerGroups")
      .doc(groupId)
      .collection("slots")
      .doc(slotId);
    const slotSnap = await slotRef.get();
    if (!slotSnap.exists || !slotSnap.data()?.message) {
      throw new HttpsError(
        "failed-precondition",
        "한마디가 있어야 리액션할 수 있습니다."
      );
    }

    // 리액션 저장
    await slotRef.update({
      [`reactions.${uid}`]: {
        emoji,
        phraseId,
        phraseText,
        reactedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    });

    // 이벤트 로그 생성
    const eventRef = db
      .collection("partnerGroups")
      .doc(groupId)
      .collection("events")
      .doc();
    const targetUids = groupData.memberUids.filter((u: string) => u !== uid);
    await eventRef.set({
      type: "reaction",
      actorUid: uid,
      targetUids,
      slotId,
      payload: {emoji, phraseText},
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 인박스 요약 카드 업데이트
    const dateKey = slotId.split("_")[0];
    await updateInboxCards(groupId, uid, "reaction", dateKey);

    return {success: true};
  }
);

/**
 * 인박스 요약 카드 읽음 처리
 */
export const markInboxRead = onCall(
  {region: "asia-northeast3"},
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }

    const {inboxId} = request.data;
    if (!inboxId) {
      throw new HttpsError("invalid-argument", "inboxId가 필요합니다.");
    }

    await db
      .collection("users")
      .doc(uid)
      .collection("partnerInbox")
      .doc(inboxId)
      .update({
        unread: false,
        readAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    return {success: true};
  }
);

// ═══════════════════════════════════════════════════════════
// 이번 주 우리 스탬프 (합산형)
// ═══════════════════════════════════════════════════════════

/**
 * KST 기준 ISO weekKey 계산 ("2026-W07")
 */
function kstWeekKey(kst: DateTime): string {
  return kst.toFormat("kkkk-'W'WW");
}

/**
 * KST 기준 요일 인덱스 (0=월 ~ 6=일)
 */
function kstDayOfWeek(kst: DateTime): number {
  return kst.weekday - 1; // luxon: 1=Mon ~ 7=Sun
}

/**
 * onPartnerActivityForStamp
 *
 * 파트너 활동(투표/리액션/목표체크/문장작성) 보고 시
 * Firestore Transaction으로 daily 로그에 기록 → 조건 충족 시 스탬프 채움.
 *
 * activityType: 'poll_vote' | 'sentence_reaction' | 'goal_check' | 'sentence_write'
 */
export const onPartnerActivityForStamp = onCall(
  {region: "asia-northeast3"},
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }

    const {groupId, activityType} = request.data;
    if (!groupId || !activityType) {
      throw new HttpsError(
        "invalid-argument",
        "groupId와 activityType이 필요합니다."
      );
    }

    const validTypes = [
      "poll_vote",
      "sentence_reaction",
      "goal_check",
      "sentence_write",
    ];
    if (!validTypes.includes(activityType)) {
      throw new HttpsError(
        "invalid-argument",
        `유효하지 않은 activityType: ${activityType}`
      );
    }

    // 그룹 멤버 확인
    const groupDoc = await db.collection("partnerGroups").doc(groupId).get();
    if (!groupDoc.exists) {
      throw new HttpsError("not-found", "그룹을 찾을 수 없습니다.");
    }
    const groupData = groupDoc.data()!;
    if (!groupData.memberUids?.includes(uid)) {
      throw new HttpsError(
        "permission-denied",
        "그룹 멤버만 스탬프 활동을 보고할 수 있습니다."
      );
    }

    // KST 기준 날짜/주차 계산
    const nowKst = DateTime.now().setZone("Asia/Seoul");
    const dateKey = nowKst.toFormat("yyyy-MM-dd");
    const weekKey = kstWeekKey(nowKst);
    const dayIdx = kstDayOfWeek(nowKst);

    // Firestore 참조
    const stampRef = db
      .collection("partnerGroups")
      .doc(groupId)
      .collection("weeklyStamps")
      .doc(weekKey);

    const dailyRef = stampRef.collection("daily").doc(dateKey);

    // ── 트랜잭션: daily 로그 업데이트 + 스탬프 판정 ──
    const result = await db.runTransaction(async (tx) => {
      const dailySnap = await tx.get(dailyRef);
      const stampSnap = await tx.get(stampRef);

      // daily 로그 읽기 (없으면 초기값)
      const dailyData = dailySnap.exists ? dailySnap.data()! : {
        dateKey,
        dayOfWeek: dayIdx,
        pollVoters: [],
        sentenceReactors: [],
        goalCheckers: [],
        sentenceWriters: [],
        stampFilled: false,
      };

      // 활동 유형에 따라 uid 추가 (중복 방지)
      const fieldMap: {[key: string]: string} = {
        "poll_vote": "pollVoters",
        "sentence_reaction": "sentenceReactors",
        "goal_check": "goalCheckers",
        "sentence_write": "sentenceWriters",
      };

      const field = fieldMap[activityType];
      const currentList: string[] = dailyData[field] ?? [];
      if (!currentList.includes(uid)) {
        currentList.push(uid);
        dailyData[field] = currentList;
      }

      // 스탬프 조건 판정: (A or B) + (C or D) — 그룹 합산
      const hasAorB =
        (dailyData.pollVoters?.length ?? 0) > 0 ||
        (dailyData.sentenceReactors?.length ?? 0) > 0;
      const hasCorD =
        (dailyData.goalCheckers?.length ?? 0) > 0 ||
        (dailyData.sentenceWriters?.length ?? 0) > 0;
      const meetsCondition = hasAorB && hasCorD;

      const wasAlreadyFilled = dailyData.stampFilled === true;
      let justFilled = false;

      if (meetsCondition && !wasAlreadyFilled) {
        dailyData.stampFilled = true;
        justFilled = true;
      }

      // daily 로그 저장
      dailyData.updatedAt = admin.firestore.FieldValue.serverTimestamp();
      tx.set(dailyRef, dailyData, {merge: true});

      // 스탬프가 방금 채워졌으면 주간 상태도 업데이트
      if (justFilled) {
        const stampData = stampSnap.exists ? stampSnap.data()! : {
          weekKey,
          filledDays: {},
          filledCount: 0,
        };

        const filledDays = stampData.filledDays ?? {};
        filledDays[`${dayIdx}`] = true;

        // filledCount 재계산
        let count = 0;
        for (let i = 0; i < 7; i++) {
          if (filledDays[`${i}`] === true) count++;
        }

        tx.set(stampRef, {
          weekKey,
          filledDays,
          filledCount: count,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
      }

      return {justFilled, meetsCondition};
    });

    logger.info(
      `Stamp activity: ${activityType} by ${uid} in ${groupId}`,
      {dateKey, weekKey, ...result}
    );

    return {
      success: true,
      stampFilled: result.justFilled,
    };
  }
);

/**
 * 인박스 요약 카드 업데이트 (내부 헬퍼)
 */
async function updateInboxCards(
  groupId: string,
  actorUid: string,
  actionType: string,
  dateKey: string
) {
  try {
    // 그룹 멤버 가져오기
    const groupDoc = await db.collection("partnerGroups").doc(groupId).get();
    if (!groupDoc.exists) return;
    const groupData = groupDoc.data()!;
    const memberUids = groupData.memberUids as string[];

    // 행동한 사람의 프로필 가져오기
    const actorDoc = await db.collection("users").doc(actorUid).get();
    const actorData = actorDoc.data();
    const actorRegion = actorData?.region ?? "";
    const actorCareerBucket = actorData?.careerBucket ?? "";

    // 나머지 멤버들의 인박스 업데이트
    const targetUids = memberUids.filter((u) => u !== actorUid);
    const inboxId = `${groupId}_${dateKey}`;

    for (const targetUid of targetUids) {
      const inboxRef = db
        .collection("users")
        .doc(targetUid)
        .collection("partnerInbox")
        .doc(inboxId);

      await db.runTransaction(async (tx) => {
        const inboxSnap = await tx.get(inboxRef);
        let items: any[] = [];

        if (inboxSnap.exists) {
          items = inboxSnap.data()?.items ?? [];
        }

        // 같은 actorUid가 있는지 찾기
        const existingIndex = items.findIndex(
          (item) => item.actorUid === actorUid
        );

        const actionLabel =
          actionType === "slot_message" ? "한마디 1개" : "리액션 1개";

        if (existingIndex >= 0) {
          // 기존 항목 업데이트
          const lines = items[existingIndex].lines ?? [];
          lines.push(actionLabel);
          items[existingIndex].lines = lines;
          items[existingIndex].lastAt =
            admin.firestore.FieldValue.serverTimestamp();
        } else {
          // 새 항목 추가
          items.push({
            actorUid,
            actorRegion,
            actorCareerBucket,
            lines: [actionLabel],
            lastAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        tx.set(
          inboxRef,
          {
            groupId,
            date: dateKey,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            items,
            unread: true,
          },
          {merge: true}
        );
      });
    }
  } catch (e) {
    logger.error("updateInboxCards error:", e);
  }
}
