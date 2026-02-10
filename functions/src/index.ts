import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {logger} from "firebase-functions";
import * as admin from "firebase-admin";

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
