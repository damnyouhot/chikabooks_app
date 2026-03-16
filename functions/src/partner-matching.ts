import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {
  getMatchableUsers,
  findBest3PersonGroups,
  findBest2PersonGroups,
  mapCareerGroupToBucket,
  getCurrentWeekKey,
  getDefaultPreferences,
  calculateMatchScore,
} from "./partner-matching-utils";

const db = admin.firestore();

// ========== Cloud Functions ==========

/**
 * 수동 매칭 요청 (사용자가 "추천으로 찾기" 클릭 시)
 * InviteCard에서 호출
 */
export const requestPartnerMatching = functions
  .region("asia-northeast3")
  .https.onCall(async (data, context) => {
    console.log("🚀 [requestPartnerMatching] 함수 시작");

    // 1. 인증 체크
    if (!context.auth) {
      console.warn("⚠️ [requestPartnerMatching] 인증 실패");
      throw new functions.https.HttpsError(
        "unauthenticated",
        "로그인이 필요합니다."
      );
    }

    const uid = context.auth.uid;
    console.log(`🔍 [requestPartnerMatching] UID: ${uid}`);

    try {
      // 2. 사용자 프로필 확인
      console.log(`🔍 [requestPartnerMatching] 사용자 프로필 조회 중...`);
      const userDoc = await db.collection("users").doc(uid).get();
      if (!userDoc.exists) {
        console.warn(`⚠️ [requestPartnerMatching] 사용자 문서 없음: ${uid}`);
        throw new functions.https.HttpsError(
          "not-found",
          "사용자 프로필을 찾을 수 없습니다."
        );
      }

      const userData = userDoc.data()!;
      console.log(`🔍 [requestPartnerMatching] 프로필 필드:`, {
        isProfileCompleted: userData.isProfileCompleted,
        nickname: userData.nickname,
        careerGroup: userData.careerGroup,
        region: userData.region,
        mainConcerns: userData.mainConcerns?.length,
        partnerStatus: userData.partnerStatus,
        partnerGroupId: userData.partnerGroupId,
      });

      // 3. 이미 활성 그룹이 있는지 확인
      if (userData.partnerGroupId && userData.partnerGroupEndsAt) {
        const endsAt = userData.partnerGroupEndsAt.toDate();
        if (endsAt > new Date()) {
          console.log(`ℹ️ [requestPartnerMatching] 이미 활성 그룹 있음: ${userData.partnerGroupId}`);
          return {
            status: "already_in_group",
            message: "이미 활성 파트너 그룹이 있습니다.",
            groupId: userData.partnerGroupId,
          };
        }
      }

      // 본인 프로필 객체 구성
      const myProfile = {
        uid,
        nickname: userData.nickname,
        region: userData.region || "",
        careerGroup: userData.careerGroup || "",
        careerBucket: userData.careerBucket || mapCareerGroupToBucket(userData.careerGroup || ""),
        mainConcerns: userData.mainConcerns || [],
        partnerStatus: userData.partnerStatus || "active",
        willMatchNextWeek: userData.willMatchNextWeek !== false,
        partnerPreferences: userData.partnerPreferences || getDefaultPreferences(),
      };

      // 4. 매칭 가능한 사용자 목록 조회 (본인 제외)
      console.log(`🔍 [requestPartnerMatching] 매칭 가능 사용자 조회 중...`);
      const allUsers = await getMatchableUsers();
      const otherUsers = allUsers.filter((u) => u.uid !== uid);

      console.log(`🔍 [requestPartnerMatching] 매칭 가능 사용자: ${otherUsers.length + 1}명 (본인 포함)`);
      console.log(`🔍 [requestPartnerMatching] 매칭 가능 사용자 UID 목록:`, [uid, ...otherUsers.map((u) => u.uid)]);

      // ──────────────────────────────────────────────────────────────
      // 5-A. 새 3인 그룹 생성 시도 (본인 + 매칭 가능한 2명)
      // findBest3PersonGroups 대신 본인을 고정하고 최적 2명을 직접 탐색
      // ──────────────────────────────────────────────────────────────
      if (otherUsers.length >= 2) {
        let bestScore = -1;
        let bestPair: [typeof otherUsers[0], typeof otherUsers[0]] | null = null;

        const myPref = myProfile.partnerPreferences || getDefaultPreferences();

        for (let i = 0; i < otherUsers.length - 1; i++) {
          for (let j = i + 1; j < otherUsers.length; j++) {
            const userB = otherUsers[i];
            const userC = otherUsers[j];

            const prefB = userB.partnerPreferences || getDefaultPreferences();
            const prefC = userC.partnerPreferences || getDefaultPreferences();

            // 세 쌍의 양방향 점수 평균
            const score =
              (calculateMatchScore(myProfile, userB, myPref) +
                calculateMatchScore(userB, myProfile, prefB) +
                calculateMatchScore(myProfile, userC, myPref) +
                calculateMatchScore(userC, myProfile, prefC) +
                calculateMatchScore(userB, userC, prefB) +
                calculateMatchScore(userC, userB, prefC)) /
              6;

            if (score > bestScore) {
              bestScore = score;
              bestPair = [userB, userC];
            }
          }
        }

        if (bestPair) {
          const groupId = await createPartnerGroup([uid, bestPair[0].uid, bestPair[1].uid]);
          console.log(`✅ 3인 그룹 매칭 성공 (score: ${bestScore.toFixed(1)}): ${groupId}`);
          return {
            status: "matched",
            groupId,
            message: "파트너를 찾았어요!",
          };
        }
      }

      // ──────────────────────────────────────────────────────────────
      // 5-B. 새 2인 그룹 생성 시도 (본인 + 최적 1명)
      // ──────────────────────────────────────────────────────────────
      if (otherUsers.length >= 1) {
        const myPref = myProfile.partnerPreferences || getDefaultPreferences();

        let bestScore = -1;
        let bestPartner: typeof otherUsers[0] | null = null;

        for (const candidate of otherUsers) {
          const prefB = candidate.partnerPreferences || getDefaultPreferences();
          const score =
            (calculateMatchScore(myProfile, candidate, myPref) +
              calculateMatchScore(candidate, myProfile, prefB)) /
            2;

          if (score > bestScore) {
            bestScore = score;
            bestPartner = candidate;
          }
        }

        if (bestPartner) {
          const groupId = await createPartnerGroup([uid, bestPartner.uid], {
            needsSupplementation: true,
          });
          console.log(`✅ 2인 그룹 매칭 성공 (주중 보충 예정, score: ${bestScore.toFixed(1)}): ${groupId}`);
          return {
            status: "matched",
            groupId,
            message: "파트너를 찾았어요! (2인 시작, 주중 보충 예정)",
          };
        }
      }

      // ──────────────────────────────────────────────────────────────
      // 5-C. 새 그룹 없음 → 기존 2인팀에 합류 가능 여부 탐색
      // needsSupplementation=true 이거나, activeMemberUids가 2인 활성 그룹 모두 대상
      // ──────────────────────────────────────────────────────────────
      console.log(`🔍 [requestPartnerMatching] 신규 매칭 불가 → 기존 2인팀 합류 탐색`);
      const now = admin.firestore.Timestamp.now();

      // needsSupplementation=true인 그룹 조회
      const supplementSnap = await db
        .collection("partnerGroups")
        .where("isActive", "==", true)
        .where("needsSupplementation", "==", true)
        .get();

      // 모든 활성 그룹 추가 조회 (needsSupplementation 필드가 없거나 false인 경우 대비)
      const allActiveSnap = await db
        .collection("partnerGroups")
        .where("isActive", "==", true)
        .get();

      // 두 결과 합치기 (중복 제거)
      const seenIds = new Set<string>();
      const candidateDocs: FirebaseFirestore.QueryDocumentSnapshot[] = [];
      for (const doc of [...supplementSnap.docs, ...allActiveSnap.docs]) {
        if (!seenIds.has(doc.id)) {
          seenIds.add(doc.id);
          candidateDocs.push(doc);
        }
      }

      console.log(`🔍 [requestPartnerMatching] 활성 그룹 후보: ${candidateDocs.length}개`);

      // 조건 검증 및 필터
      const validTwoPersonGroups = candidateDocs.filter((doc) => {
        const d = doc.data();
        const endsAt = d.endsAt?.toDate();
        const memberUidsList: string[] = d.activeMemberUids || [];
        const memberCount = memberUidsList.length;
        const isExpired = !endsAt || endsAt <= now.toDate();
        const alreadyMember = memberUidsList.includes(uid);

        // 상세 탈락 로그
        if (isExpired) {
          console.log(`  ❌ [${doc.id}] 탈락 - 만료됨 (endsAt: ${endsAt?.toISOString()})`);
          return false;
        }
        if (memberCount !== 2) {
          console.log(`  ❌ [${doc.id}] 탈락 - 2인 아님 (현재: ${memberCount}명)`);
          return false;
        }
        if (!d.isActive) {
          console.log(`  ❌ [${doc.id}] 탈락 - 비활성 그룹`);
          return false;
        }
        if (alreadyMember) {
          console.log(`  ❌ [${doc.id}] 탈락 - 이미 멤버`);
          return false;
        }

        console.log(`  ✅ [${doc.id}] 합류 가능 (members: ${memberUidsList.join(", ")})`);
        return true;
      });

      console.log(`🔍 [requestPartnerMatching] 합류 가능한 2인팀: ${validTwoPersonGroups.length}개`);

      if (validTwoPersonGroups.length > 0) {
        // 가장 먼저 만들어진 팀에 합류 (FIFO)
        const targetGroup = validTwoPersonGroups.sort(
          (a, b) =>
            (a.data().createdAt?.toMillis() || 0) -
            (b.data().createdAt?.toMillis() || 0)
        )[0];

        await addMemberToExistingGroup(targetGroup.id, uid, userData);
        console.log(`✅ 기존 2인팀 합류 성공: ${uid} → ${targetGroup.id}`);
        return {
          status: "matched",
          groupId: targetGroup.id,
          message: "파트너를 찾았어요! (기존 팀 합류)",
        };
      }

      // ──────────────────────────────────────────────────────────────
      // 5-D. 모든 경로 실패 → 매칭풀 등록
      // ──────────────────────────────────────────────────────────────
      await db.collection("partnerMatchingPool").doc(uid).set({
        region: userData.region || "",
        careerBucket: userData.careerBucket || mapCareerGroupToBucket(userData.careerGroup || ""),
        mainConcerns: userData.mainConcerns || [],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`⏳ 매칭풀 등록: ${uid}`);

      return {
        status: "waiting",
        message: "아직 함께할 사람이 부족해요. 곧 알려드릴게요!",
      };
    } catch (error: any) {
      console.error("⚠️ requestPartnerMatching error:", error);
      throw new functions.https.HttpsError(
        "internal",
        error.message || "매칭 처리 중 오류가 발생했습니다."
      );
    }
  });

/**
 * 사용자가 기존 활성 그룹에 속해 있으면 해당 그룹에서 제거
 * 중복 그룹 방지를 위해 createPartnerGroup / addMemberToExistingGroup 호출 전에 실행
 */
async function removeFromExistingGroups(uid: string): Promise<void> {
  const now = new Date();
  const groupsSnap = await db.collection("partnerGroups")
    .where("isActive", "==", true)
    .get();

  for (const doc of groupsSnap.docs) {
    const d = doc.data();
    const endsAt = d.endsAt?.toDate();
    if (!endsAt || endsAt <= now) continue;

    const inMembers = (d.activeMemberUids || []).includes(uid);
    if (!inMembers) continue;

    const newMemberUids = (d.memberUids || []).filter((u: string) => u !== uid);
    const newActiveMemberUids = (d.activeMemberUids || []).filter((u: string) => u !== uid);

    const updateData: Record<string, any> = {
      memberUids: newMemberUids,
      activeMemberUids: newActiveMemberUids,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (newActiveMemberUids.length <= 1) {
      updateData.needsSupplementation = true;
    }
    if (newActiveMemberUids.length === 0) {
      updateData.isActive = false;
      updateData.deactivatedAt = admin.firestore.FieldValue.serverTimestamp();
      updateData.deactivateReason = "member_moved_to_new_group";
    }

    await doc.ref.update(updateData);

    // memberMeta에서도 제거
    try {
      await doc.ref.collection("memberMeta").doc(uid).delete();
    } catch (_) { /* 없으면 무시 */ }

    console.log(`🔄 [removeFromExistingGroups] ${uid} → ${doc.id} 에서 제거 (남은: ${newActiveMemberUids.length}명)`);
  }
}

/**
 * 기존 2인 그룹에 신규 멤버 추가 (수동 매칭 경로)
 * partner-supplementation.ts의 addMemberToGroup과 동일한 역할
 */
async function addMemberToExistingGroup(
  groupId: string,
  newUid: string,
  userData: FirebaseFirestore.DocumentData
): Promise<void> {
  // 기존 그룹에서 먼저 제거 (중복 방지)
  await removeFromExistingGroups(newUid);

  const groupRef = db.collection("partnerGroups").doc(groupId);
  const groupDoc = await groupRef.get();

  if (!groupDoc.exists) {
    throw new Error(`그룹을 찾을 수 없습니다: ${groupId}`);
  }

  const groupData = groupDoc.data()!;
  const memberUids: string[] = [...(groupData.memberUids || [])];

  if (memberUids.includes(newUid)) {
    console.log(`⚠️ 이미 그룹 멤버: ${newUid}`);
    return;
  }

  memberUids.push(newUid);

  const batch = db.batch();

  // 그룹 업데이트
  batch.update(groupRef, {
    memberUids,
    activeMemberUids: memberUids,
    needsSupplementation: false,
    supplementedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // 멤버 메타 추가
  batch.set(groupRef.collection("memberMeta").doc(newUid), {
    uid: newUid,
    nickname: userData.nickname || null,
    region: userData.region || "",
    careerBucket: userData.careerBucket || mapCareerGroupToBucket(userData.careerGroup || ""),
    careerGroup: userData.careerGroup || "",
    mainConcerns: (userData.mainConcerns || []).slice(0, 2),
    mainConcernShown:
      userData.mainConcerns && userData.mainConcerns.length > 0
        ? userData.mainConcerns[0]
        : null,
    workplaceType: userData.workplaceType || null,
    joinedAt: admin.firestore.FieldValue.serverTimestamp(),
    isSupplemented: true,
  });

  // users 문서 업데이트
  batch.update(db.collection("users").doc(newUid), {
    partnerGroupId: groupId,
    partnerGroupEndsAt: groupData.endsAt,
    partnerStatus: "active",
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // 매칭풀에서 제거
  batch.delete(db.collection("partnerMatchingPool").doc(newUid));

  await batch.commit();

  console.log(`✅ [addMemberToExistingGroup] ${newUid} → ${groupId} 합류 완료`);
}

/**
 * 파트너 그룹 생성 헬퍼 함수
 * PartnerService.createGroup과 동일한 로직 + 메타데이터 지원
 */
async function createPartnerGroup(
  memberUids: string[],
  metadata?: {
    isPairContinued?: boolean;
    previousPair?: string[];
    weekNumber?: number;
    needsSupplementation?: boolean;
  }
): Promise<string> {
  if (memberUids.length < 2 || memberUids.length > 3) {
    throw new Error(`그룹 인원이 유효하지 않습니다: ${memberUids.length}명`);
  }

  // 0. 각 멤버가 기존 활성 그룹에 속해있으면 먼저 제거 (중복 방지)
  for (const uid of memberUids) {
    await removeFromExistingGroups(uid);
  }

  const now = new Date();
  const startedAt = now;
  const endsAt = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000); // 7일 후
  const weekKey = getCurrentWeekKey();

  const groupRef = db.collection("partnerGroups").doc();
  const groupId = groupRef.id;

  const batch = db.batch();

  // 1. 그룹 문서 생성
  batch.set(groupRef, {
    ownerId: memberUids[0],
    title: `결 ${Math.floor(Math.random() * 100)}`, // 임시 타이틀
    createdAt: admin.firestore.Timestamp.fromDate(now),
    startedAt: admin.firestore.Timestamp.fromDate(startedAt),
    endsAt: admin.firestore.Timestamp.fromDate(endsAt),
    memberUids,
    activeMemberUids: memberUids,
    isActive: true,
    weekKey,
    maxMembers: 3,
    minMembers: 1,
    // 메타데이터 추가
    isPairContinued: metadata?.isPairContinued || false,
    previousPair: metadata?.previousPair || null,
    weekNumber: metadata?.weekNumber || 1,
    // 2인 그룹은 무조건 보충 대상 (3인이 정원)
    needsSupplementation: memberUids.length === 2 ? true : (metadata?.needsSupplementation || false),
  });

  // 2. 각 멤버 메타 생성 + users 업데이트
  for (const uid of memberUids) {
    const userDoc = await db.collection("users").doc(uid).get();
    const userData = userDoc.data() || {};

    const memberRef = groupRef.collection("memberMeta").doc(uid);
    batch.set(memberRef, {
      uid,
      nickname: userData.nickname || null,
      region: userData.region || "",
      careerBucket: userData.careerBucket || mapCareerGroupToBucket(userData.careerGroup || ""),
      careerGroup: userData.careerGroup || "",
      // 관심사 최대 2개 저장 (리스트) + 하위 호환용 첫 번째 항목
      mainConcerns: (userData.mainConcerns || []).slice(0, 2),
      mainConcernShown:
        userData.mainConcerns && userData.mainConcerns.length > 0
          ? userData.mainConcerns[0]
          : null,
      workplaceType: userData.workplaceType || null,
      joinedAt: admin.firestore.Timestamp.fromDate(now),
    });

    // users 문서 업데이트
    batch.update(db.collection("users").doc(uid), {
      partnerGroupId: groupId,
      partnerGroupEndsAt: admin.firestore.Timestamp.fromDate(endsAt),
      partnerStatus: "active", // 그룹 생성 시 active로 변경
      willMatchNextWeek: false, // 그룹에 속하면 이 설정은 무시됨
      continueWithPartner: null, // 이어가기 초기화
      bondScore: admin.firestore.FieldValue.increment(0), // 없으면 생성
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();

  // 3. 매칭풀에서 제거
  const poolBatch = db.batch();
  for (const uid of memberUids) {
    poolBatch.delete(db.collection("partnerMatchingPool").doc(uid));
  }
  await poolBatch.commit();

  console.log(`✅ 그룹 생성 완료: ${groupId} (${memberUids.length}명)`);

  return groupId;
}

/**
 * 주간 자동 매칭 (매주 월요일 09:00 KST 실행)
 * 1. 이어가기 페어 우선 처리 (2명 + 보충 1명 = 3명 그룹)
 * 2. 일반 매칭 (나머지 사용자)
 */
export const weeklyPartnerMatching = functions
  .pubsub.schedule("0 9 * * 1") // 매주 월요일 09:00 (UTC 기준은 00:00)
  .timeZone("Asia/Seoul")
  .onRun(async () => {
    console.log("🚀 주간 자동 매칭 시작...");

    try {
      const matchedUids = new Set<string>();

      // 1. 이어가기 페어 우선 처리
      const pairsSnapshot = await db
        .collection("partnerContinuePairs")
        .where("usedForMatching", "==", false)
        .get();

      console.log(`💛 이어가기 페어: ${pairsSnapshot.size}개`);

      for (const pairDoc of pairsSnapshot.docs) {
        const pairData = pairDoc.data();
        const pairMemberUids: string[] = pairData.memberUids || [];
        const weekNumber = pairData.weekNumber || 2;

        if (pairMemberUids.length === 0) {
          await pairDoc.ref.update({usedForMatching: true});
          continue;
        }

        // 페어 멤버가 이미 다른 곳에 매칭됐는지 확인
        if (pairMemberUids.some((uid) => matchedUids.has(uid))) {
          console.log(`⏭️ 페어 스킵 (이미 매칭됨): ${pairMemberUids}`);
          await pairDoc.ref.update({usedForMatching: true});
          continue;
        }

        if (pairMemberUids.length === 3) {
          // ── 3인 이어가기 그룹: 그대로 재생성 ──
          await createPartnerGroup(pairMemberUids, {
            isPairContinued: true,
            previousPair: pairMemberUids,
            weekNumber,
          });
          console.log(`💛 3인 이어가기 그룹 재생성: ${pairMemberUids}`);
          pairMemberUids.forEach((uid) => matchedUids.add(uid));
        } else {
          // ── 2인 이어가기 페어: 보충 멤버 1명 찾기 ──
          const [uidA, uidB] = pairMemberUids;

          // 보충 멤버 1명 찾기
          const allUsers = await getMatchableUsers();
          const availableUsers = allUsers.filter(
            (u) => u.uid !== uidA && u.uid !== uidB && !matchedUids.has(u.uid)
          );

          if (availableUsers.length > 0) {
            const userA = allUsers.find((u) => u.uid === uidA);
            const userB = allUsers.find((u) => u.uid === uidB);

            if (!userA || !userB) {
              console.log(`⚠️ 페어 멤버 프로필 없음: ${uidA}, ${uidB}`);
              await pairDoc.ref.update({usedForMatching: true});
              continue;
            }

            let bestMatch = availableUsers[0];
            let bestScore = 0;

            const prefA = userA.partnerPreferences || getDefaultPreferences();
            const prefB = userB.partnerPreferences || getDefaultPreferences();

            for (const candidate of availableUsers) {
              const scoreA = calculateMatchScore(userA, candidate, prefA);
              const scoreB = calculateMatchScore(userB, candidate, prefB);
              const avgScore = (scoreA + scoreB) / 2;

              if (avgScore > bestScore) {
                bestScore = avgScore;
                bestMatch = candidate;
              }
            }

            // 그룹 생성 (페어 + 보충 1명)
            await createPartnerGroup(
              [uidA, uidB, bestMatch.uid],
              {
                isPairContinued: true,
                previousPair: [uidA, uidB],
                weekNumber,
              }
            );

            console.log(`💛 이어가기 그룹 생성 (2+1명)`);

            matchedUids.add(uidA);
            matchedUids.add(uidB);
            matchedUids.add(bestMatch.uid);
          } else {
            // 보충 불가 시 2명만으로 그룹 생성
            await createPartnerGroup(
              [uidA, uidB],
              {
                isPairContinued: true,
                previousPair: [uidA, uidB],
                needsSupplementation: true,
                weekNumber,
              }
            );

            console.log(`💛 이어가기 2인 그룹 생성 (보충 대기)`);

            matchedUids.add(uidA);
            matchedUids.add(uidB);
          }
        }

        // 페어 문서 사용 완료 처리
        await pairDoc.ref.update({usedForMatching: true});
      }

      // 2. 매칭 가능한 사용자 목록 조회 (이어가기 페어 제외)
      const allUsers = await getMatchableUsers();
      const users = allUsers.filter((u) => !matchedUids.has(u.uid));
      
      console.log(`📊 일반 매칭 대상: ${users.length}명`);

      if (users.length === 0) {
        console.log("⏭️ 일반 매칭 대상이 없습니다.");
        return;
      }

      // 3. 3명 그룹 최대한 생성
      const groups3 = findBest3PersonGroups(users);
      console.log(`✅ 3인 그룹 ${groups3.length}개 생성 예정`);

      for (const group of groups3) {
        await createPartnerGroup(group.map((u) => u.uid));
        group.forEach((u) => matchedUids.add(u.uid));
      }

      // 4. 남은 사용자로 2명 그룹 생성
      const remainingUsers = users.filter((u) => !matchedUids.has(u.uid));

      if (remainingUsers.length >= 2) {
        const pairs = findBest2PersonGroups(remainingUsers);
        console.log(`✅ 2인 그룹 ${pairs.length}개 생성 예정 (주중 보충)`);

        for (const pair of pairs) {
          await createPartnerGroup(
            pair.map((u) => u.uid),
            {needsSupplementation: true}
          );
          pair.forEach((u) => matchedUids.add(u.uid));
        }
      }

      // 5. 최종 남은 1명은 매칭풀에 대기
      const leftAlone = users.filter((u) => !matchedUids.has(u.uid));

      if (leftAlone.length > 0) {
        console.log(`⏳ 매칭풀 대기: ${leftAlone.length}명`);
        for (const user of leftAlone) {
          await db.collection("partnerMatchingPool").doc(user.uid).set({
            region: user.region,
            careerBucket: user.careerBucket,
            mainConcerns: user.mainConcerns,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }

      console.log("✅ 주간 자동 매칭 완료!");
      console.log(`  - 이어가기 페어: ${pairsSnapshot.size}개`);
      console.log(`  - 총 매칭: ${matchedUids.size}명`);
      console.log(`  - 대기: ${leftAlone.length}명`);
    } catch (error) {
      console.error("❌ weeklyPartnerMatching error:", error);
    }
  });

/**
 * 그룹 만료 처리 (매주 월요일 08:59 KST 실행)
 * 다음 주 매칭 전에 기존 그룹을 정리하고 이어가기 페어 추출
 */
export const expirePartnerGroups = functions
  .pubsub.schedule("59 8 * * 1")
  .timeZone("Asia/Seoul")
  .onRun(async () => {
    console.log("🔄 그룹 만료 처리 시작...");

    try {
      const now = admin.firestore.Timestamp.now();

      // 만료된 그룹 조회
      const expiredSnapshot = await db
        .collection("partnerGroups")
        .where("endsAt", "<=", now)
        .where("isActive", "==", true)
        .get();

      console.log(`📊 만료 대상 그룹: ${expiredSnapshot.size}개`);

      // 이어가기 그룹 추출
      // - 2인 그룹: A→B && B→A 상호 선택 시 페어로 저장
      // - 3인 그룹: 전원(3명 모두)이 나머지 2명을 선택해야 성사
      const continuePairs: Array<{
        memberUids: string[];
        weekNumber: number;
      }> = [];

      for (const doc of expiredSnapshot.docs) {
        const data = doc.data();
        const memberUids: string[] = data.memberUids || data.activeMemberUids || [];
        const currentWeekNumber: number = data.weekNumber || 1;

        if (memberUids.length === 0) continue;

        // 각 멤버의 continueWithPartners(리스트) 또는 continueWithPartner(구버전) 조회
        const selectionsByUid: Record<string, string[]> = {};

        for (const uid of memberUids) {
          const userDoc = await db.collection("users").doc(uid).get();
          const userData = userDoc.data() || {};

          // 신버전: continueWithPartners 리스트
          const newList: string[] = userData.continueWithPartners || [];
          if (newList.length > 0) {
            // 그룹 멤버만 필터
            selectionsByUid[uid] = newList.filter((u: string) => memberUids.includes(u));
          } else if (userData.continueWithPartner && memberUids.includes(userData.continueWithPartner)) {
            // 구버전 단일 필드 호환
            selectionsByUid[uid] = [userData.continueWithPartner];
          }
        }

        if (memberUids.length === 3) {
          // ── 3인 그룹: 전원이 나머지 2명 모두 선택해야 성사 ──
          const allAgree = memberUids.every((uid) => {
            const othersInGroup = memberUids.filter((u) => u !== uid);
            const selected = selectionsByUid[uid] || [];
            return othersInGroup.every((other) => selected.includes(other));
          });

          if (allAgree) {
            continuePairs.push({
              memberUids,
              weekNumber: currentWeekNumber + 1,
            });
            console.log(`💛 3인 이어가기 전원 동의: ${memberUids} (주차 ${currentWeekNumber + 1})`);
          } else {
            console.log(`⏭️ 3인 이어가기 미성사 (전원 동의 불충족): ${memberUids}`);
          }
        } else if (memberUids.length === 2) {
          // ── 2인 그룹: A→B && B→A 상호 선택 ──
          const [uidA, uidB] = memberUids;
          const aSelectedB = (selectionsByUid[uidA] || []).includes(uidB);
          const bSelectedA = (selectionsByUid[uidB] || []).includes(uidA);

          if (aSelectedB && bSelectedA) {
            continuePairs.push({
              memberUids: [uidA, uidB],
              weekNumber: currentWeekNumber + 1,
            });
            console.log(`💛 2인 이어가기 상호 선택: ${uidA} ↔ ${uidB} (주차 ${currentWeekNumber + 1})`);
          }
        }
      }

      // 그룹 비활성화
      const batch = db.batch();

      for (const doc of expiredSnapshot.docs) {
        const data = doc.data();
        const memberUids = data.memberUids || data.activeMemberUids || [];

        batch.update(doc.ref, {
          isActive: false,
          expiredAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // 멤버들의 partnerGroupId 초기화 (continueWithPartner는 유지)
        for (const uid of memberUids) {
          batch.update(db.collection("users").doc(uid), {
            partnerGroupId: null,
            partnerGroupEndsAt: null,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();

      // 이어가기 페어 정보 저장 (매칭 시 우선 묶기용)
      if (continuePairs.length > 0) {
        const pairBatch = db.batch();
        for (const pair of continuePairs) {
          const pairRef = db.collection("partnerContinuePairs").doc();
          pairBatch.set(pairRef, {
            memberUids: pair.memberUids,
            weekNumber: pair.weekNumber,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            usedForMatching: false,
          });
        }
        await pairBatch.commit();
        console.log(`💾 ${continuePairs.length}개 이어가기 그룹 저장 완료`);
      }

      console.log(`✅ ${expiredSnapshot.size}개 그룹 만료 처리 완료`);
    } catch (error) {
      console.error("❌ expirePartnerGroups error:", error);
    }
  });

