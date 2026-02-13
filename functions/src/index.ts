import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

/**
 * 추대 트리거: enthrone 서브컬렉션에 문서 생성 시
 * 조건 충족 시 billboardPosts에 등재
 */
export const onEnthroneCreated = functions
  .region("asia-northeast3")
  .firestore.document("bondGroups/{bondId}/posts/{postId}/enthrones/{uid}")
  .onCreate(async (snap, context) => {
    const {bondId, postId} = context.params;

    try {
      // 1. 현재 추대 수 집계
      const enthronesSnap = await snap.ref.parent.get();
      const enthroneCount = enthronesSnap.size;

      // 2. Bond 그룹 멤버 수 확인
      const bondDoc = await db.doc(`bondGroups/${bondId}`).get();
      const bondData = bondDoc.data();
      const activeMemberUids = bondData?.activeMemberUids || [];
      const activeMemberCount = activeMemberUids.length;

      // 3. 필요 추대 수 (최소 2, 최대 3)
      const requiredCount = Math.max(2, activeMemberCount);

      // 4. 조건 충족 확인
      if (enthroneCount >= requiredCount) {
        // 5. 원본 게시물 가져오기
        const postDoc = await db
          .doc(`bondGroups/${bondId}/posts/${postId}`)
          .get();
        const postData = postDoc.data();

        // 6. 게시 조건 확인
        if (
          postData &&
          postData.publicEligible !== false &&
          !postData.isDeleted &&
          (postData.reports || 0) < 3
        ) {
          // 7. 전광판에 등재
          await db.collection("billboardPosts").add({
            sourceBondId: bondId,
            sourcePostId: postId,
            textSnapshot: postData.text || "",
            enthroneCount: enthroneCount,
            requiredCount: requiredCount,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            expiresAt: admin.firestore.Timestamp.fromMillis(
              Date.now() + 48 * 60 * 60 * 1000 // 48시간
            ),
            status: "confirmed",
            bondGroupName: bondData?.title || "결",
            isAnonymous: true,
          });

          console.log(
            `✅ Billboard post created: ${bondId}/${postId}`
          );
        }
      }
    } catch (error) {
      console.error("⚠️ onEnthroneCreated error:", error);
    }
  });

/**
 * 일일 요약 생성: 매일 19:00 KST에 실행
 */
export const generateDailySummary = functions
  .region("asia-northeast3")
  .pubsub.schedule("0 19 * * *") // 매일 19:00 (UTC+0 기준이므로 실제로는 10:00 UTC)
  .timeZone("Asia/Seoul")
  .onRun(async (context) => {
    try {
      const dateKey = getCurrentDateKey();

      // 모든 활성 파트너 그룹 가져오기
      const groupsSnap = await db
        .collection("partnerGroups")
        .where("isActive", "==", true)
        .get();

      for (const groupDoc of groupsSnap.docs) {
        const groupId = groupDoc.id;
        const groupData = groupDoc.data();
        const memberUids = groupData.activeMemberUids || [];

        // 각 멤버의 오늘 활동 집계
        const activityCounts: {[key: string]: number} = {};
        for (const uid of memberUids) {
          // TODO: 실제 활동 집계 로직
          // bondPosts, 투표, 리액션 등을 합산
          activityCounts[uid] = 0;
        }

        // 요약 메시지 생성
        const summaryMessage = generateSummaryMessage(activityCounts);
        const ctaMessage = "함께 마무리해볼까요?";

        // 저장
        await db
          .collection("partnerGroups")
          .doc(groupId)
          .collection("dailySummaries")
          .doc(dateKey)
          .set({
            dateKey,
            activityCounts,
            summaryMessage,
            ctaMessage,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
      }

      console.log(`✅ Daily summaries generated for ${dateKey}`);
    } catch (error) {
      console.error("⚠️ generateDailySummary error:", error);
    }
  });

/**
 * 전광판 만료 처리: 매시간 실행
 */
export const expireBillboardPosts = functions
  .region("asia-northeast3")
  .pubsub.schedule("0 * * * *") // 매시간 0분
  .timeZone("Asia/Seoul")
  .onRun(async (context) => {
    try {
      const now = admin.firestore.Timestamp.now();

      const expiredSnap = await db
        .collection("billboardPosts")
        .where("status", "==", "confirmed")
        .where("expiresAt", "<=", now)
        .get();

      const batch = db.batch();
      expiredSnap.docs.forEach((doc) => {
        batch.update(doc.ref, {status: "expired"});
      });

      await batch.commit();
      console.log(`✅ Expired ${expiredSnap.size} billboard posts`);
    } catch (error) {
      console.error("⚠️ expireBillboardPosts error:", error);
    }
  });

// ────────────────────────────────────────
// Helper Functions
// ────────────────────────────────────────

function getCurrentDateKey(): string {
  const now = new Date();
  const kst = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  const year = kst.getFullYear();
  const month = String(kst.getMonth() + 1).padStart(2, "0");
  const day = String(kst.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function generateSummaryMessage(
  activityCounts: {[key: string]: number}
): string {
  const activeMembers = Object.values(activityCounts).filter(
    (c) => c >= 1
  ).length;

  switch (activeMembers) {
  case 3:
    return "오늘 우리 셋 다 움직였다 ✨";
  case 2:
    return "오늘은 두 명이 함께했다 🌙";
  case 1:
    return "오늘은 한 사람이 버텼다";
  default:
    return "오늘은 조용한 날 (내일 한 칸만 채워도 충분해)";
  }
}
