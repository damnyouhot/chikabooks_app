import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

const db = admin.firestore();

interface PollRowDoc {
  id: string;
  displayOrder: number;
  startsAtMs: number;
  endsAtMs: number;
  status: string;
  doc: FirebaseFirestore.QueryDocumentSnapshot;
}

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

    // status 가 'active' 뿐 아니라 'scheduled' 인 채로 endsAt 만 지나간 케이스도
    // 함께 종료한다(과거에 scheduled 로만 등록되고 자동 활성화가 누락된 데이터 보정).
    const expiredSnap = await db
      .collection("polls")
      .where("status", "in", ["active", "scheduled"])
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

function displayOrderFromPollData(d: FirebaseFirestore.DocumentData, docId: string): number {
  const raw = d.displayOrder;
  if (typeof raw === "number" && Number.isFinite(raw)) return raw;
  const di = d.dayIndex;
  if (typeof di === "number" && Number.isFinite(di)) return di;
  const m = /^empathy_(\d+)$/.exec(docId);
  return m ? parseInt(m[1], 10) : 1_000_000;
}

function pollDocToRow(doc: FirebaseFirestore.QueryDocumentSnapshot): PollRowDoc | null {
  const d = doc.data();
  const st = d.startsAt as admin.firestore.Timestamp | undefined;
  const en = d.endsAt as admin.firestore.Timestamp | undefined;
  if (!st || !en) return null;
  return {
    id: doc.id,
    displayOrder: displayOrderFromPollData(d, doc.id),
    startsAtMs: st.toMillis(),
    endsAtMs: en.toMillis(),
    status: String(d.status ?? ""),
    doc,
  };
}

/**
 * 진행 중 투표 1건을 종료(closePoll)한 뒤, displayOrder 기준 다음 미종료 투표를 즉시 진행으로 올림.
 */
export const adminAdvancePollQueue = functions
  .region("us-central1")
  .https.onCall(async (_data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "로그인 필요");
    }
    const callerDoc = await db.collection("users").doc(context.auth.uid).get();
    if (callerDoc.data()?.isAdmin !== true) {
      throw new functions.https.HttpsError("permission-denied", "어드민 권한 필요");
    }

    const snap = await db.collection("polls").get();
    const rows: PollRowDoc[] = [];
    for (const doc of snap.docs) {
      const r = pollDocToRow(doc);
      if (r) rows.push(r);
    }

    const nowMs = Date.now();
    const votingOpen = (r: PollRowDoc) => r.startsAtMs <= nowMs && r.endsAtMs > nowMs;
    const candidates = rows.filter((r) => r.endsAtMs > nowMs && votingOpen(r));
    candidates.sort((a, b) => {
      if (a.displayOrder !== b.displayOrder) return a.displayOrder - b.displayOrder;
      if (a.startsAtMs !== b.startsAtMs) return a.startsAtMs - b.startsAtMs;
      return a.id.localeCompare(b.id);
    });

    const current = candidates[0];
    if (!current) {
      return {
        success: false,
        message: "진행 중인 투표가 없습니다. (시작~종료 시각이 현재와 겹치는 문서 없음)",
      };
    }

    const sortedNonClosed = rows
      .filter((r) => r.status !== "closed")
      .sort((a, b) => {
        if (a.displayOrder !== b.displayOrder) return a.displayOrder - b.displayOrder;
        return a.id.localeCompare(b.id);
      });

    const idx = sortedNonClosed.findIndex((r) => r.id === current.id);
    const next = idx >= 0 && idx + 1 < sortedNonClosed.length ? sortedNonClosed[idx + 1] : null;
    if (!next) {
      return { success: false, message: "대기 중인 다음 투표(미종료)가 없습니다." };
    }

    await closePoll(current.doc);

    const nowTs = admin.firestore.Timestamp.now();
    const duration = Math.max(next.endsAtMs - next.startsAtMs, 24 * 3600 * 1000);
    const newEndsMs = nowMs + duration;

    await next.doc.ref.update({
      status: "active",
      startsAt: nowTs,
      endsAt: admin.firestore.Timestamp.fromMillis(newEndsMs),
    });

    functions.logger.info(
      `adminAdvancePollQueue: closed ${current.id}, activated ${next.id}`,
    );

    return {
      success: true,
      closedPollId: current.id,
      activatedPollId: next.id,
      message: `투표 ${current.id} 을(를) 종료하고 ${next.id} 를 진행 중으로 올렸습니다.`,
    };
  });

/** 서브컬렉션 문서를 배치 단위로 반복 삭제 */
async function deleteCollectionInChunks(
  col: FirebaseFirestore.CollectionReference,
  batchSize = 400,
): Promise<number> {
  let total = 0;
  while (true) {
    const snap = await col.limit(batchSize).get();
    if (snap.empty) break;
    const b = db.batch();
    for (const doc of snap.docs) {
      b.delete(doc.ref);
    }
    await b.commit();
    total += snap.docs.length;
  }
  return total;
}

/**
 * 공감투표 및 하위: options(각 option 의 reports 포함) · votes · pollComments 전부 삭제
 */
async function deletePollSubtreeCompletely(pollId: string): Promise<void> {
  const pollRef = db.collection("polls").doc(pollId);
  const pollSnap = await pollRef.get();
  if (!pollSnap.exists) {
    throw new functions.https.HttpsError("not-found", "투표를 찾을 수 없습니다.");
  }

  const optionsSnap = await pollRef.collection("options").get();
  for (const opt of optionsSnap.docs) {
    await deleteCollectionInChunks(opt.ref.collection("reports"));
    await opt.ref.delete();
  }
  await deleteCollectionInChunks(pollRef.collection("votes"));
  await deleteCollectionInChunks(pollRef.collection("pollComments"));
  await pollRef.delete();
}

/**
 * 공감투표 완전 삭제 (어드민)
 *
 * 삭제 후 displayOrder 기준 다음 미종료 투표를 즉시 활성화한다.
 * 2단계 확인: [confirmPollId] 가 [pollId] 와 동일해야 함 (클라 1차 확인 + ID 재입력).
 */
export const adminDeletePoll = functions
  .region("us-central1")
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "로그인 필요");
    }

    const callerDoc = await db.collection("users").doc(context.auth.uid).get();
    if (callerDoc.data()?.isAdmin !== true) {
      throw new functions.https.HttpsError("permission-denied", "어드민 권한 필요");
    }

    const pollId = typeof data.pollId === "string" ? data.pollId.trim() : "";
    const confirmPollId =
      typeof data.confirmPollId === "string" ? data.confirmPollId.trim() : "";

    if (!pollId) {
      throw new functions.https.HttpsError("invalid-argument", "pollId 필수");
    }
    if (!confirmPollId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "confirmPollId 필수 — 삭제 확인용으로 문서 ID를 정확히 입력하세요.",
      );
    }
    if (pollId !== confirmPollId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "확인용 문서 ID가 대상과 일치하지 않습니다.",
      );
    }

    // 삭제 전에 다음 투표 후보를 미리 찾아 둠 (삭제 대상 제외)
    const allSnap = await db.collection("polls").get();
    const rows: PollRowDoc[] = [];
    for (const doc of allSnap.docs) {
      if (doc.id === pollId) continue;
      const r = pollDocToRow(doc);
      if (r) rows.push(r);
    }
    const sortedNonClosed = rows
      .filter((r) => r.status !== "closed")
      .sort((a, b) => {
        if (a.displayOrder !== b.displayOrder) return a.displayOrder - b.displayOrder;
        return a.id.localeCompare(b.id);
      });
    const nextCandidate = sortedNonClosed.length > 0 ? sortedNonClosed[0] : null;

    await deletePollSubtreeCompletely(pollId);

    let activatedPollId: string | null = null;
    if (nextCandidate) {
      const nowMs = Date.now();
      const nowTs = admin.firestore.Timestamp.now();
      const duration = Math.max(nextCandidate.endsAtMs - nextCandidate.startsAtMs, 24 * 3600 * 1000);
      const newEndsMs = nowMs + duration;
      await nextCandidate.doc.ref.update({
        status: "active",
        startsAt: nowTs,
        endsAt: admin.firestore.Timestamp.fromMillis(newEndsMs),
      });
      activatedPollId = nextCandidate.id;
    }

    functions.logger.info(`adminDeletePoll: 삭제 ${pollId}, 활성화 ${activatedPollId ?? "(없음)"}`);
    return {
      success: true,
      pollId,
      activatedPollId,
      message: activatedPollId
        ? `투표 ${pollId} 삭제 완료. 다음 투표 ${activatedPollId} 를 즉시 활성화했습니다.`
        : `투표 ${pollId} 삭제 완료. 대기 중인 다음 투표가 없습니다.`,
    };
  });
