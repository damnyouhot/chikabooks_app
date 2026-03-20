import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

const db = admin.firestore();

/**
 * 공감투표 자동 종료 + 순위 확정
 *
 * 매 시간 실행: endsAt이 지났지만 status가 아직 'active'인 투표를 찾아 종료한다.
 *
 * 종료 시 수행:
 *   1) 보기를 empathyCount 내림차순으로 정렬
 *   2) 상위 3개 보기에 rank 1/2/3 기록
 *   3) poll.status → 'closed', poll.closedAt 설정
 */
export const closeExpiredPolls = functions
  .pubsub.schedule("0 * * * *") // 매시 정각
  .timeZone("Asia/Seoul")
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();

    const expiredSnap = await db
      .collection("polls")
      .where("status", "==", "active")
      .where("endsAt", "<=", now)
      .get();

    if (expiredSnap.empty) {
      functions.logger.info("closeExpiredPolls: 종료할 투표 없음");
      return null;
    }

    functions.logger.info(
      `closeExpiredPolls: ${expiredSnap.size}개 투표 종료 처리 시작`
    );

    for (const pollDoc of expiredSnap.docs) {
      try {
        await closePoll(pollDoc);
      } catch (err) {
        functions.logger.error(
          `closeExpiredPolls: 투표 ${pollDoc.id} 종료 실패`,
          err
        );
      }
    }

    return null;
  });

async function closePoll(pollDoc: FirebaseFirestore.QueryDocumentSnapshot) {
  const pollId = pollDoc.id;
  const pollRef = db.collection("polls").doc(pollId);

  // 보기 전체 조회 (숨김 포함, empathyCount 내림차순)
  const optionsSnap = await pollRef
    .collection("options")
    .orderBy("empathyCount", "desc")
    .get();

  const batch = db.batch();

  // 상위 3개에 rank 부여
  let rank = 0;
  for (const optDoc of optionsSnap.docs) {
    if (rank < 3 && !optDoc.data().isHidden) {
      rank++;
      batch.update(optDoc.ref, { rank });
    }
  }

  // 투표 상태 변경
  batch.update(pollRef, {
    status: "closed",
    closedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await batch.commit();

  functions.logger.info(`✅ 투표 종료: ${pollId} (보기 ${optionsSnap.size}개, 순위 ${rank}위까지)`);
}

/**
 * 수동 투표 종료 (관리자용)
 *
 * Input: { pollId: string }
 */
export const manualClosePoll = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "로그인 필요");
    }

    const callerDoc = await db.collection("users").doc(context.auth.uid).get();
    if (callerDoc.data()?.isAdmin !== true) {
      throw new functions.https.HttpsError("permission-denied", "어드민 권한 필요");
    }

    const pollId = data.pollId as string | undefined;
    if (!pollId) {
      throw new functions.https.HttpsError("invalid-argument", "pollId 필수");
    }

    const pollDoc = await db.collection("polls").doc(pollId).get();
    if (!pollDoc.exists) {
      throw new functions.https.HttpsError("not-found", "투표를 찾을 수 없습니다.");
    }

    if (pollDoc.data()?.status === "closed") {
      return { success: false, message: "이미 종료된 투표입니다." };
    }

    await closePoll(pollDoc as FirebaseFirestore.QueryDocumentSnapshot);

    return { success: true, message: `투표 ${pollId} 종료 완료` };
  }
);
