import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

const db = admin.firestore();

/**
 * leavePartnerGroup
 *
 * 사용자가 현재 소모임(파트너 그룹)에서 자진 탈퇴한다.
 * 서버 단 transaction으로 users + partnerGroups 동시 업데이트.
 *
 * Input  : { reason?: string }
 * Output : { ok: true, groupDeleted: boolean, remainingMembers: number }
 */
export const leavePartnerGroup = functions
  .region("asia-northeast3")
  .https.onCall(async (data, context) => {
    // 1. 인증 체크
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "로그인이 필요합니다."
      );
    }

    const uid = context.auth.uid;
    const reason: string = data?.reason ?? "";

    console.log(`🚀 [leavePartnerGroup] uid=${uid}, reason="${reason}"`);

    try {
      // 2. users/{uid} 에서 partnerGroupId 조회
      const userRef = db.collection("users").doc(uid);
      const userDoc = await userRef.get();

      if (!userDoc.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "사용자 프로필을 찾을 수 없습니다."
        );
      }

      const userData = userDoc.data()!;
      const groupId = userData.partnerGroupId as string | undefined;

      if (!groupId) {
        // 이미 나간 상태 — 성공으로 처리 (idempotent)
        console.log("ℹ️ [leavePartnerGroup] 이미 그룹 없음, OK 반환");
        return {ok: true, groupDeleted: false, remainingMembers: -1};
      }

      // 3. partnerGroups/{groupId} 존재 확인
      const groupRef = db.collection("partnerGroups").doc(groupId);
      const groupDoc = await groupRef.get();

      if (!groupDoc.exists) {
        // 그룹 문서가 이미 삭제됨 — users만 정리
        console.log("ℹ️ [leavePartnerGroup] 그룹 문서 없음 → users 정리");
        await userRef.update({
          partnerGroupId: admin.firestore.FieldValue.delete(),
          partnerGroupEndsAt: admin.firestore.FieldValue.delete(),
          partnerStatus: "none",
          leftGroupAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return {ok: true, groupDeleted: true, remainingMembers: 0};
      }

      const groupData = groupDoc.data()!;

      // 4. batch 처리
      const batch = db.batch();

      // ── 4-1. users/{uid} 정리 ──
      batch.update(userRef, {
        partnerGroupId: admin.firestore.FieldValue.delete(),
        partnerGroupEndsAt: admin.firestore.FieldValue.delete(),
        partnerStatus: "none",
        leftGroupAt: admin.firestore.FieldValue.serverTimestamp(),
        leftGroupReason: reason || null,
      });

      // ── 4-2. partnerGroups 업데이트 ──
      // memberUids, activeMemberUids 에서 uid 제거
      const currentMemberUids: string[] = groupData.memberUids || [];
      const updatedMemberUids = currentMemberUids.filter((u: string) => u !== uid);

      // members 배열에서 해당 멤버의 status를 left로 변경
      const currentMembers: any[] = groupData.members || [];
      const updatedMembers = currentMembers.map((m: any) => {
        if (m.uid === uid) {
          return {
            ...m,
            status: "left",
            leftAt: admin.firestore.Timestamp.now(),
            leftReason: reason || null,
          };
        }
        return m;
      });

      // activeMemberUids 재계산 (status가 active인 것만)
      const updatedActiveMemberUids = updatedMembers
        .filter((m: any) => m.status === "active")
        .map((m: any) => m.uid);

      const remainingCount = updatedActiveMemberUids.length;

      if (remainingCount === 0) {
        // ── 0명 남음: 그룹 비활성화 ──
        batch.update(groupRef, {
          memberUids: updatedMemberUids,
          activeMemberUids: updatedActiveMemberUids,
          members: updatedMembers,
          isActive: false,
          deactivatedAt: admin.firestore.FieldValue.serverTimestamp(),
          deactivateReason: "all_members_left",
        });
        console.log("🗑️ [leavePartnerGroup] 0명 → 그룹 비활성화");
      } else {
        // ── 1~2명 남음: 그룹 유지 + 보충 플래그 ──
        batch.update(groupRef, {
          memberUids: updatedMemberUids,
          activeMemberUids: updatedActiveMemberUids,
          members: updatedMembers,
          needsSupplementation: true,
          supplementationMarkedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(
          `📌 [leavePartnerGroup] ${remainingCount}명 → 보충 플래그 설정`
        );
      }

      // ── 4-3. 매칭풀에서도 제거 (안전장치) ──
      batch.delete(db.collection("partnerMatchingPool").doc(uid));

      await batch.commit();

      console.log(
        `✅ [leavePartnerGroup] 완료: uid=${uid}, remaining=${remainingCount}`
      );

      return {
        ok: true,
        groupDeleted: remainingCount === 0,
        remainingMembers: remainingCount,
      };
    } catch (error: any) {
      console.error("❌ [leavePartnerGroup] error:", error);

      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      throw new functions.https.HttpsError(
        "internal",
        "소모임 나가기 처리 중 오류가 발생했습니다."
      );
    }
  });

