import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {
  getMatchableUsers,
  mapCareerGroupToBucket,
} from "./partner-matching-utils";

const db = admin.firestore();

/**
 * 그룹 멤버 변화 감지 (주중 보충 트리거)
 * 멤버가 탈퇴하여 인원이 감소할 때 자동 실행
 */
export const onGroupMemberChanged = functions
  .firestore.document("partnerGroups/{groupId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    const beforeCount = (before.activeMemberUids || []).length;
    const afterCount = (after.activeMemberUids || []).length;

    // 멤버 감소 감지 && 그룹이 활성 상태
    if (afterCount < beforeCount && after.isActive) {
      console.log(
        `⚠️ 그룹 ${context.params.groupId} 인원 감소: ${beforeCount} → ${afterCount}명`
      );

      // 1명 이하로 떨어짐 → 긴급 보충 (즉시)
      if (afterCount <= 1) {
        console.log("🚨 긴급 보충 필요 (1명 이하)");
        await attemptImmediateSupplementation(context.params.groupId);
      }
      // 2명 유지 → 보충 플래그 설정 (완화 보충)
      else if (afterCount === 2) {
        console.log("📌 주중 보충 플래그 설정 (2명 상태)");
        await change.after.ref.update({
          needsSupplementation: true,
          supplementationMarkedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }
  });

/**
 * 긴급 보충 (즉시 실행)
 * 1명 이하로 떨어진 그룹에 즉시 멤버 추가
 */
async function attemptImmediateSupplementation(
  groupId: string
): Promise<void> {
  try {
    const users = await getMatchableUsers();

    if (users.length === 0) {
      console.log("⏭️ 보충 가능한 사용자 없음");
      return;
    }

    // 첫 번째 매칭 가능 사용자로 보충
    const newMember = users[0];

    await addMemberToGroup(groupId, newMember.uid);

    console.log(`✅ 긴급 보충 완료: ${newMember.uid} → ${groupId}`);
  } catch (error) {
    console.error(`❌ attemptImmediateSupplementation error:`, error);
  }
}

/**
 * 완화 보충 스케줄러 (매일 12:30, 19:00 KST 실행)
 * needsSupplementation=true인 그룹에 보충 멤버 추가
 */
export const scheduledSupplementation = functions
  .pubsub.schedule("30 12,19 * * *") // 매일 12:30, 19:00
  .timeZone("Asia/Seoul")
  .onRun(async () => {
    console.log("🔄 주중 보충 매칭 시작...");

    try {
      // needsSupplementation=true인 활성 그룹 조회
      const groupsSnapshot = await db
        .collection("partnerGroups")
        .where("isActive", "==", true)
        .where("needsSupplementation", "==", true)
        .get();

      console.log(`📊 보충 대상 그룹: ${groupsSnapshot.size}개`);

      for (const groupDoc of groupsSnapshot.docs) {
        const groupData = groupDoc.data();
        const currentMemberCount = (groupData.activeMemberUids || []).length;

        // 이미 3명이면 스킵
        if (currentMemberCount >= 3) {
          await groupDoc.ref.update({
            needsSupplementation: false,
          });
          continue;
        }

        // 매칭 가능 사용자 조회
        const users = await getMatchableUsers();

        if (users.length > 0) {
          await addMemberToGroup(groupDoc.id, users[0].uid);

          await groupDoc.ref.update({
            needsSupplementation: false,
            supplementedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          console.log(`✅ 주중 보충 완료: ${groupDoc.id}`);
        } else {
          console.log(`⏳ 보충 가능한 사용자 없음: ${groupDoc.id}`);
        }
      }

      console.log("✅ 주중 보충 매칭 완료!");
    } catch (error) {
      console.error("❌ scheduledSupplementation error:", error);
    }
  });

/**
 * 그룹에 멤버 추가 헬퍼 함수
 */
async function addMemberToGroup(
  groupId: string,
  newUid: string
): Promise<void> {
  const groupRef = db.collection("partnerGroups").doc(groupId);
  const groupDoc = await groupRef.get();

  if (!groupDoc.exists) {
    throw new Error(`그룹을 찾을 수 없습니다: ${groupId}`);
  }

  const groupData = groupDoc.data()!;
  const memberUids = groupData.memberUids || [];

  // 이미 멤버인지 확인
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
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // 멤버 메타 추가
  const userDoc = await db.collection("users").doc(newUid).get();
  const userData = userDoc.data() || {};

  batch.set(groupRef.collection("memberMeta").doc(newUid), {
    uid: newUid,
    region: userData.region || "",
    careerBucket:
      userData.careerBucket ||
      mapCareerGroupToBucket(userData.careerGroup || ""),
    careerGroup: userData.careerGroup || "",
    // 관심사 최대 2개 저장 (리스트) + 하위 호환용 첫 번째 항목
    mainConcerns: (userData.mainConcerns || []).slice(0, 2),
    mainConcernShown:
      userData.mainConcerns && userData.mainConcerns.length > 0
        ? userData.mainConcerns[0]
        : null,
    workplaceType: userData.workplaceType || null,
    joinedAt: admin.firestore.FieldValue.serverTimestamp(),
    isSupplemented: true, // 보충 멤버 표시
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

  console.log(`✅ 멤버 추가 완료: ${newUid} → ${groupId}`);
}










