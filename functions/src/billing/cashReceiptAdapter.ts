import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {
  CashReceiptAdapter,
  CashReceiptRequestInput,
  BillingAdapterResult,
} from "./types";

/**
 * cashReceiptAdapter
 *
 * 현금영수증 외주 어댑터 (1차: 별도 외주 — 운영팀 수동 / 2차: 외주 API)
 *
 * 세금계산서와 동일한 1차/2차 운영 패턴을 따른다.
 * 자세한 내용은 tossInvoiceAdapter.ts 의 주석 참고.
 */
/** 외주 현금영수증 어댑터 구현체 */
class CashReceiptAdapterImpl implements CashReceiptAdapter {
  /**
   * 현금영수증 발급 요청을 처리한다.
   *
   * @param {CashReceiptRequestInput} input 발급 요청 입력
   * @return {Promise<BillingAdapterResult>} 처리 결과
   */
  async request(
    input: CashReceiptRequestInput
  ): Promise<BillingAdapterResult> {
    const db = admin.firestore();
    const ref = db.collection("cashReceiptRequests").doc();

    const doc = {
      ...input,
      // 보안 룰(cashReceiptRequests.ownerUid == auth.uid)과 정합
      ownerUid: input.uid,
      status: "queued" as const,
      provider: "outsourced",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    await ref.set(doc);

    // ── TODO(2차 운영): 외주 현금영수증 API 호출 ────────────────
    // const res = await axios.post('https://api.<provider>.com/...', {...});
    // await ref.update({ status: 'issued', externalId: res.data.receiptId });
    // ────────────────────────────────────────────────────────────

    // ── TODO(1차 운영): 운영팀 알림 (Slack / 이메일) ─────────────
    // await notifyOpsTeam(
    //   'cash_receipt_request', {requestId: ref.id, ...input},
    // );
    // ────────────────────────────────────────────────────────────

    functions.logger.info("[cashReceiptAdapter] queued", {
      requestId: ref.id,
      uid: input.uid,
      amount: input.amount,
    });

    return {
      status: "queued",
      requestId: ref.id,
      message: "현금영수증 발급을 접수했습니다. 영업일 1-2일 내 발급됩니다.",
    };
  }
}

export const cashReceiptAdapter = new CashReceiptAdapterImpl();

/**
 * Cloud Function: 사용자 호출용 엔드포인트
 */
export const requestCashReceipt = functions
  .region("asia-northeast3")
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "로그인이 필요합니다."
      );
    }
    const uid = context.auth.uid;

    const required: Array<keyof CashReceiptRequestInput> = [
      "clinicId", "orderRef", "receiptType", "identifier", "amount",
    ];
    for (const key of required) {
      if (data[key] === undefined || data[key] === null || data[key] === "") {
        throw new functions.https.HttpsError(
          "invalid-argument",
          `${String(key)} 필드가 비어있습니다.`
        );
      }
    }

    const receiptType = String(data.receiptType);
    if (receiptType !== "income" && receiptType !== "business") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "receiptType은 'income' 또는 'business' 여야 합니다."
      );
    }

    const input: CashReceiptRequestInput = {
      uid,
      clinicId: String(data.clinicId),
      orderRef: String(data.orderRef),
      receiptType: receiptType as "income" | "business",
      identifier: String(data.identifier).replace(/-/g, ""),
      amount: Number(data.amount),
    };

    return cashReceiptAdapter.request(input);
  });
