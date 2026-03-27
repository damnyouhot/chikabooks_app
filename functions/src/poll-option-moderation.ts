import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

const db = admin.firestore();

const REGION = "us-central1";

/**
 * 해당 보기를 선택한 votes 정리 + 신고 삭제 + 옵션 삭제 + poll.totalEmpathyCount 보정
 */
async function purgeUserPollOption(
  pollId: string,
  optionId: string
): Promise<{ deletedVotes: number }> {
  const optionRef = db
    .collection("polls")
    .doc(pollId)
    .collection("options")
    .doc(optionId);
  const optSnap = await optionRef.get();
  if (!optSnap.exists) {
    return { deletedVotes: 0 };
  }
  const data = optSnap.data()!;
  if (data.isSystem === true) {
    return { deletedVotes: 0 };
  }

  const votesCol = db.collection("polls").doc(pollId).collection("votes");
  let deletedVotes = 0;

  // eslint-disable-next-line no-constant-condition
  while (true) {
    const q = await votesCol.where("optionId", "==", optionId).limit(450).get();
    if (q.empty) break;
    const batch = db.batch();
    for (const d of q.docs) {
      batch.delete(d.ref);
      deletedVotes++;
    }
    await batch.commit();
  }

  if (deletedVotes > 0) {
    const pollRef = db.collection("polls").doc(pollId);
    await db.runTransaction(async (tx) => {
      const pollSnap = await tx.get(pollRef);
      const total = (pollSnap.data()?.totalEmpathyCount as number) ?? 0;
      const next = Math.max(0, total - deletedVotes);
      tx.update(pollRef, { totalEmpathyCount: next });
    });
  }

  const reportsSnap = await optionRef.collection("reports").get();
  let rb = db.batch();
  let c = 0;
  for (const d of reportsSnap.docs) {
    rb.delete(d.ref);
    c++;
    if (c >= 450) {
      await rb.commit();
      rb = db.batch();
      c = 0;
    }
  }
  if (c > 0) await rb.commit();

  await optionRef.delete();
  return { deletedVotes };
}

/**
 * 신고 5건 이상: 보기 및 관련 votes·집계 정리 (클라이언트가 신고 트랜잭션 직후 호출)
 */
export const purgePollOptionAfterReports = functions
  .region(REGION)
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "로그인이 필요합니다."
      );
    }

    const pollId = String(data?.pollId ?? "").trim();
    const optionId = String(data?.optionId ?? "").trim();
    if (!pollId || !optionId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "pollId, optionId가 필요합니다."
      );
    }

    const optionRef = db
      .collection("polls")
      .doc(pollId)
      .collection("options")
      .doc(optionId);
    const optSnap = await optionRef.get();
    if (!optSnap.exists) {
      return { ok: true, alreadyRemoved: true };
    }

    const d = optSnap.data()!;
    if (d.isSystem === true) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "시스템 보기는 제거 대상이 아닙니다."
      );
    }

    const rc = (d.reportCount as number) ?? 0;
    if (rc < 5) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "신고 수가 임계값에 도달하지 않았습니다."
      );
    }

    const { deletedVotes } = await purgeUserPollOption(pollId, optionId);
    return { ok: true, deletedVotes };
  });

/**
 * 작성자가 본인 보기 삭제 — 공감 0~5명까지 허용, votes·집계 정리
 */
export const authorDeletePollOptionWithVote = functions
  .region(REGION)
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "로그인이 필요합니다."
      );
    }

    const uid = context.auth.uid;
    const pollId = String(data?.pollId ?? "").trim();
    const optionId = String(data?.optionId ?? "").trim();
    if (!pollId || !optionId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "pollId, optionId가 필요합니다."
      );
    }

    const optionRef = db
      .collection("polls")
      .doc(pollId)
      .collection("options")
      .doc(optionId);

    const optSnap = await optionRef.get();
    if (!optSnap.exists) {
      return { ok: true, alreadyRemoved: true };
    }
    const od = optSnap.data()!;

    if (od.isSystem === true) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "기본 보기는 삭제할 수 없습니다."
      );
    }
    if (od.authorUid !== uid) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "본인이 추가한 보기만 삭제할 수 있습니다."
      );
    }
    const ec = (od.empathyCount as number) ?? 0;
    if (ec > 5) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "공감 인원이 많아 삭제할 수 없어요."
      );
    }

    const { deletedVotes } = await purgeUserPollOption(pollId, optionId);
    return { ok: true, deletedVotes };
  });

/**
 * 신고 5회 도달 후 클라이언트 호출 실패 대비 백업
 */
export const onPollOptionReportThreshold = functions
  .region(REGION)
  .firestore.document("polls/{pollId}/options/{optionId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data() ?? {};
    const after = change.after.data() ?? {};
    if (after.isSystem === true) return null;

    const prev = (before.reportCount as number) ?? 0;
    const next = (after.reportCount as number) ?? 0;
    if (next < 5 || prev >= 5) return null;

    const pollId = context.params.pollId as string;
    const optionId = context.params.optionId as string;

    try {
      const optSnap = await db
        .collection("polls")
        .doc(pollId)
        .collection("options")
        .doc(optionId)
        .get();
      if (!optSnap.exists) return null;
      const rc = (optSnap.data()?.reportCount as number) ?? 0;
      if (rc < 5) return null;
      await purgeUserPollOption(pollId, optionId);
      functions.logger.info(
        `onPollOptionReportThreshold: purged ${pollId}/${optionId}`
      );
    } catch (err) {
      functions.logger.error(
        `onPollOptionReportThreshold: failed ${pollId}/${optionId}`,
        err
      );
    }
    return null;
  });
