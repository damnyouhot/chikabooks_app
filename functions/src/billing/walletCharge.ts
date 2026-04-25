import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

import {
  chargeVouchers,
  chargeCredit,
} from "./walletOps";

/**
 * walletCharge.ts
 *
 * 클라이언트가 호출하는 패키지 충전 Callable 2종.
 *  - chargeVoucherPackage : 공고권 패키지 (qty x 가격)
 *  - chargeCreditPackage  : 충전 잔액 패키지 (amount + bonus)
 *
 * ## 1차 운영 (현재)
 *   - 결제 위젯(Toss)이 아직 미연동 → 즉시 결제 불가
 *   - `paymentRequests/{autoId}` 에 적재(상태=pending_manual) 후 운영팀이
 *     입금 확인 → admin 화면에서 `applyPendingPayment(reqId)` 실행
 *   - 응답으로는 orderId(=요청 ID) + checkoutUrl: null 반환
 *
 * ## 2차 운영 (Toss 위젯 연동 후)
 *   - `applyPendingPayment` 분기 제거, 곧바로 trans + chargeVouchers/Credit
 *     실행 → 응답에 Toss 위젯 redirect URL 포함
 *   - 클라이언트 화면 변경 없음 (checkoutUrl 이 null 이면 안내, 있으면 새 창 열기)
 */

interface BillingPolicy {
  mode: "voucher" | "credit" | "both";
  voucher?: {
    expiryMonths?: number;
    packages?: Array<{ id: string; qty: number; price: number }>;
  };
  credit?: {
    expiryMonthsFromLastUse?: number;
    packages?: Array<{ id: string; amount: number; bonus?: number }>;
  };
}

const FALLBACK: BillingPolicy = {
  mode: "both",
  voucher: {
    expiryMonths: 12,
    packages: [
      {id: "v1", qty: 1, price: 88000},
      {id: "v3", qty: 3, price: 240000},
      {id: "v10", qty: 10, price: 700000},
    ],
  },
  credit: {
    expiryMonthsFromLastUse: 24,
    packages: [
      {id: "c10", amount: 100000, bonus: 0},
      {id: "c30", amount: 300000, bonus: 15000},
      {id: "c100", amount: 1000000, bonus: 120000},
    ],
  },
};

/**
 * `config/billingPolicy` 문서를 읽어 정책을 로드.
 * 문서가 없으면 안전한 fallback 사용.
 *
 * @return {Promise<BillingPolicy>}
 */
async function loadPolicy(): Promise<BillingPolicy> {
  const snap = await admin.firestore().doc("config/billingPolicy").get();
  if (!snap.exists) return FALLBACK;
  return {...FALLBACK, ...(snap.data() as BillingPolicy)};
}

/**
 * 운영팀 수동 처리 큐에 적재 — 1차 운영 공통 로직.
 *
 * @param {object} input 큐 적재 파라미터
 * @return {Promise<string>} 생성된 paymentRequest 문서 ID
 */
async function queuePaymentRequest(input: {
  uid: string;
  kind: "voucher_package" | "credit_package";
  packageId: string;
  amount: number;
  metadata: Record<string, unknown>;
}): Promise<string> {
  const ref = admin.firestore().collection("paymentRequests").doc();
  await ref.set({
    ownerUid: input.uid,
    kind: input.kind,
    packageId: input.packageId,
    amount: input.amount,
    status: "pending_manual" as const,
    metadata: input.metadata,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  functions.logger.info("[walletCharge] queued", {
    requestId: ref.id,
    uid: input.uid,
    kind: input.kind,
    packageId: input.packageId,
    amount: input.amount,
  });
  return ref.id;
}

// ── Public Callable: 공고권 패키지 충전 ─────────────────────
export const chargeVoucherPackage = functions
  .region("asia-northeast3")
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "로그인이 필요합니다."
      );
    }
    const uid = context.auth.uid;
    const packageId = String(data?.packageId ?? "");
    if (!packageId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "packageId 가 필요합니다."
      );
    }

    const policy = await loadPolicy();
    if (policy.mode === "credit") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "현재 정책이 충전 잔액 전용입니다. 공고권 충전을 사용할 수 없습니다."
      );
    }

    const pkg = (policy.voucher?.packages ?? [])
      .find((p) => p.id === packageId);
    if (!pkg) {
      throw new functions.https.HttpsError(
        "not-found",
        `존재하지 않는 공고권 패키지: ${packageId}`
      );
    }

    const orderId = await queuePaymentRequest({
      uid,
      kind: "voucher_package",
      packageId,
      amount: pkg.price,
      metadata: {qty: pkg.qty},
    });

    return {
      orderId,
      checkoutUrl: null, // 1차 운영: 결제 위젯 미연동
      message: "충전 요청을 접수했습니다. 운영팀이 입금 확인 후 잔액에 반영합니다.",
    };
  });

// ── Public Callable: 충전 잔액 패키지 충전 ──────────────────
export const chargeCreditPackage = functions
  .region("asia-northeast3")
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "로그인이 필요합니다."
      );
    }
    const uid = context.auth.uid;
    const packageId = String(data?.packageId ?? "");
    if (!packageId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "packageId 가 필요합니다."
      );
    }

    const policy = await loadPolicy();
    if (policy.mode === "voucher") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "현재 정책이 공고권 전용입니다. 잔액 충전을 사용할 수 없습니다."
      );
    }

    const pkg = (policy.credit?.packages ?? []).find((p) => p.id === packageId);
    if (!pkg) {
      throw new functions.https.HttpsError(
        "not-found",
        `존재하지 않는 충전 패키지: ${packageId}`
      );
    }

    const orderId = await queuePaymentRequest({
      uid,
      kind: "credit_package",
      packageId,
      amount: pkg.amount,
      metadata: {bonus: pkg.bonus ?? 0},
    });

    return {
      orderId,
      checkoutUrl: null,
      message: "충전 요청을 접수했습니다. 운영팀이 입금 확인 후 잔액에 반영합니다.",
    };
  });

// ── Admin Callable: 운영팀이 입금 확인 후 잔액 적용 ──────────
//
// 1차 운영에서 운영팀이 admin 화면 또는 콘솔에서 호출.
// `paymentRequests/{requestId}` 를 status='applied' 로 변경하면서
// 동시에 wallets/{uid} 잔액을 트랜잭션으로 증액한다.
export const applyPendingPayment = functions
  .region("asia-northeast3")
  .https.onCall(async (data, context) => {
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

    const requestId = String(data?.requestId ?? "");
    if (!requestId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "requestId 가 필요합니다."
      );
    }

    const reqRef = admin.firestore()
      .collection("paymentRequests").doc(requestId);
    const reqSnap = await reqRef.get();
    if (!reqSnap.exists) {
      throw new functions.https.HttpsError(
        "not-found", "요청을 찾을 수 없습니다."
      );
    }
    const req = reqSnap.data() as Record<string, unknown> | undefined;
    if (!req) {
      throw new functions.https.HttpsError(
        "internal", "요청 데이터가 비어있습니다."
      );
    }
    if (req.status !== "pending_manual") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        `이미 처리된 요청입니다 (status=${req.status})`
      );
    }

    const policy = await loadPolicy();
    const uid = req.ownerUid as string;
    const packageId = req.packageId as string;

    if (req.kind === "voucher_package") {
      const pkg = (policy.voucher?.packages ?? []).find(
        (p) => p.id === packageId
      );
      if (!pkg) {
        throw new functions.https.HttpsError(
          "not-found",
          `정책에서 공고권 패키지를 찾지 못함: ${packageId}`
        );
      }
      const result = await chargeVouchers({
        uid,
        qty: pkg.qty,
        expiryMonths: policy.voucher?.expiryMonths ?? 12,
        source: "purchase",
        orderId: requestId,
        label: `공고권 ${pkg.qty}장 패키지 충전`,
      });
      await reqRef.update({
        status: "applied" as const,
        appliedAt: admin.firestore.FieldValue.serverTimestamp(),
        appliedBy: context.auth.uid,
        balanceAfter: result.balanceAfter,
      });
      return {ok: true, kind: "voucher", balanceAfter: result.balanceAfter};
    }

    if (req.kind === "credit_package") {
      const pkg = (policy.credit?.packages ?? []).find(
        (p) => p.id === packageId
      );
      if (!pkg) {
        throw new functions.https.HttpsError(
          "not-found",
          `정책에서 충전 패키지를 찾지 못함: ${packageId}`
        );
      }
      const result = await chargeCredit({
        uid,
        amount: pkg.amount,
        bonus: pkg.bonus ?? 0,
        orderId: requestId,
        label: `${pkg.amount.toLocaleString()}원 패키지 충전`,
      });
      await reqRef.update({
        status: "applied" as const,
        appliedAt: admin.firestore.FieldValue.serverTimestamp(),
        appliedBy: context.auth.uid,
        balanceAfter: result.balanceAfter,
      });
      return {ok: true, kind: "credit", balanceAfter: result.balanceAfter};
    }

    throw new functions.https.HttpsError(
      "invalid-argument",
      `지원하지 않는 kind: ${req.kind}`
    );
  });
