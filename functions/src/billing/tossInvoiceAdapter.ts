import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {
  TaxInvoiceAdapter,
  TaxInvoiceRequestInput,
  BillingAdapterResult,
} from "./types";

/**
 * tossInvoiceAdapter
 *
 * 세금계산서 외주 어댑터 (1차: Toss 외주 — 운영팀 수동 / 2차: Toss 세금계산서 API)
 *
 * ## 1차 운영 (현재)
 *  - `taxRequests/{autoId}` 문서를 status='queued' 로 적재
 *  - 운영팀에게 알림 (TODO: Slack 웹훅 / 이메일) → 운영팀이 Toss 콘솔에서 수동 발급
 *  - 발급 완료 후 운영팀이 admin 화면에서 status='issued' 로 변경
 *
 * ## 2차 운영 (외주 API 발급 후)
 *  - `request()` 내부 TODO 블록을 Toss 세금계산서 API 호출로 교체
 *  - 사용자 화면(`/me/billing/tax`) 변경 없음
 */
/** Toss 세금계산서 어댑터 구현체 */
class TossInvoiceAdapterImpl implements TaxInvoiceAdapter {
  /**
   * 세금계산서 발급 요청을 처리한다.
   *
   * @param {TaxInvoiceRequestInput} input 발급 요청 입력
   * @return {Promise<BillingAdapterResult>} 처리 결과
   */
  async request(
    input: TaxInvoiceRequestInput
  ): Promise<BillingAdapterResult> {
    const db = admin.firestore();
    const ref = db.collection("taxRequests").doc();

    const doc = {
      ...input,
      // 보안 룰(taxRequests.ownerUid == auth.uid)과 정합 — uid 와 동일하게 둠
      ownerUid: input.uid,
      status: "queued" as const,
      provider: "toss",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    await ref.set(doc);

    // ── TODO(2차 운영): Toss 세금계산서 API 호출 ─────────────────
    // const tossRes = await axios.post(
    //   'https://api.tosspayments.com/...', {...},
    // );
    // await ref.update({
    //   status: 'issued',
    //   externalId: tossRes.data.invoiceId,
    // });
    // ────────────────────────────────────────────────────────────

    // ── TODO(1차 운영): 운영팀 알림 (Slack / 이메일) ─────────────
    // await notifyOpsTeam(
    //   'tax_invoice_request', {requestId: ref.id, ...input},
    // );
    // ────────────────────────────────────────────────────────────

    functions.logger.info("[tossInvoiceAdapter] queued", {
      requestId: ref.id,
      uid: input.uid,
      amount: input.amount,
    });

    return {
      status: "queued",
      requestId: ref.id,
      message: "세금계산서 발급을 접수했습니다. 영업일 1-2일 내 발급됩니다.",
    };
  }
}

export const tossInvoiceAdapter = new TossInvoiceAdapterImpl();

/**
 * Cloud Function: 사용자 호출용 엔드포인트
 *
 * 클라이언트에서 호출:
 * ```dart
 * await FirebaseFunctions.instance
 *   .httpsCallable('requestTaxInvoice')
 *   .call({...input});
 * ```
 */
export const requestTaxInvoice = functions
  .region("asia-northeast3")
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "로그인이 필요합니다."
      );
    }
    const uid = context.auth.uid;

    const required: Array<keyof TaxInvoiceRequestInput> = [
      "clinicId", "orderRef", "bizNo", "clinicName",
      "ownerName", "address", "amount", "email",
    ];
    for (const key of required) {
      if (data[key] === undefined || data[key] === null || data[key] === "") {
        throw new functions.https.HttpsError(
          "invalid-argument",
          `${String(key)} 필드가 비어있습니다.`
        );
      }
    }

    const input: TaxInvoiceRequestInput = {
      uid,
      clinicId: String(data.clinicId),
      orderRef: String(data.orderRef),
      bizNo: String(data.bizNo).replace(/-/g, ""),
      clinicName: String(data.clinicName),
      ownerName: String(data.ownerName),
      address: String(data.address),
      bizType: data.bizType ? String(data.bizType) : undefined,
      bizItem: data.bizItem ? String(data.bizItem) : undefined,
      amount: Number(data.amount),
      email: String(data.email),
    };

    return tossInvoiceAdapter.request(input);
  });
