import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

/**
 * billingOps.ts
 *
 * 세금계산서 / 현금영수증 큐의 운영팀(admin) 처리 Callable.
 *  - markTaxIssued        : taxRequests/{id} 를 status='issued' 로 변경
 *  - markCashReceiptIssued: cashReceiptRequests/{id} 를 status='issued' 로 변경
 *
 * 1차 운영에서는 외주(Toss / 현금영수증 외주) 콘솔에서 발급 후
 * 운영팀이 admin 화면에서 "발급 완료" 버튼을 누르면 호출된다.
 */

/**
 * 호출자가 admin 인지 검사 (users/{uid}.isAdmin === true).
 *
 * @param {functions.https.CallableContext} context Callable 컨텍스트
 * @return {Promise<string>} 검증된 admin 의 uid
 */
async function assertAdmin(
  context: functions.https.CallableContext
): Promise<string> {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "로그인이 필요합니다."
    );
  }
  const callerSnap = await admin
    .firestore()
    .collection("users")
    .doc(context.auth.uid)
    .get();
  if (callerSnap.data()?.isAdmin !== true) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "어드민 권한이 필요합니다."
    );
  }
  return context.auth.uid;
}

/**
 * 큐에 적재된 세금계산서 요청을 발급 완료(issued)로 마킹.
 *  - data: { requestId, externalId?, note? }
 */
export const markTaxIssued = functions
  .region("asia-northeast3")
  .https.onCall(async (data, context) => {
    const adminUid = await assertAdmin(context);
    const requestId = String(data?.requestId ?? "");
    if (!requestId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "requestId 가 필요합니다."
      );
    }
    const ref = admin.firestore()
      .collection("taxRequests").doc(requestId);
    const snap = await ref.get();
    if (!snap.exists) {
      throw new functions.https.HttpsError(
        "not-found", "요청을 찾을 수 없습니다."
      );
    }
    const cur = snap.data() as Record<string, unknown> | undefined;
    if (cur?.status === "issued") {
      throw new functions.https.HttpsError(
        "failed-precondition", "이미 발급 완료된 요청입니다."
      );
    }
    const update: Record<string, unknown> = {
      status: "issued" as const,
      issuedAt: admin.firestore.FieldValue.serverTimestamp(),
      issuedBy: adminUid,
    };
    if (data?.externalId) update.externalId = String(data.externalId);
    if (data?.note) update.opsNote = String(data.note);
    await ref.update(update);
    functions.logger.info("[markTaxIssued]", {requestId, adminUid});
    return {ok: true};
  });

/**
 * 큐에 적재된 현금영수증 요청을 발급 완료(issued)로 마킹.
 *  - data: { requestId, externalId?, note? }
 */
export const markCashReceiptIssued = functions
  .region("asia-northeast3")
  .https.onCall(async (data, context) => {
    const adminUid = await assertAdmin(context);
    const requestId = String(data?.requestId ?? "");
    if (!requestId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "requestId 가 필요합니다."
      );
    }
    const ref = admin.firestore()
      .collection("cashReceiptRequests").doc(requestId);
    const snap = await ref.get();
    if (!snap.exists) {
      throw new functions.https.HttpsError(
        "not-found", "요청을 찾을 수 없습니다."
      );
    }
    const cur = snap.data() as Record<string, unknown> | undefined;
    if (cur?.status === "issued") {
      throw new functions.https.HttpsError(
        "failed-precondition", "이미 발급 완료된 요청입니다."
      );
    }
    const update: Record<string, unknown> = {
      status: "issued" as const,
      issuedAt: admin.firestore.FieldValue.serverTimestamp(),
      issuedBy: adminUid,
    };
    if (data?.externalId) update.externalId = String(data.externalId);
    if (data?.note) update.opsNote = String(data.note);
    await ref.update(update);
    functions.logger.info("[markCashReceiptIssued]", {requestId, adminUid});
    return {ok: true};
  });
