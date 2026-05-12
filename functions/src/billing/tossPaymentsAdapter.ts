/**
 * billing/tossPaymentsAdapter.ts
 *
 * Toss Payments **결제 승인 / 환불** 서버 어댑터.
 *
 * - 운영 1차 (현재): functions config 또는 환경변수에 secret key 가 설정돼 있으면
 *   실제 Toss API 를 호출해 검증/환불을 수행한다.
 * - 운영 0차 (개발/스테이징, secret 미설정): API 호출을 건너뛰고 입력값을 그대로
 *   신뢰하는 mock 모드로 동작 — 단, 함수 로그에 강한 경고를 남긴다.
 *
 * 설정 방법:
 *   firebase functions:config:set toss.secret_key="test_sk_..." \
 *                                  toss.confirm_url="https://api.tosspayments.com/v1/payments/confirm" \
 *                                  toss.cancel_url="https://api.tosspayments.com/v1/payments/{paymentKey}/cancel"
 *
 * 또는 환경변수 (functions v2 환경에서 권장):
 *   TOSS_SECRET_KEY=test_sk_...
 */

import axios, { AxiosError } from "axios";
import * as functions from "firebase-functions/v1";

const DEFAULT_CONFIRM_URL =
  "https://api.tosspayments.com/v1/payments/confirm";
const DEFAULT_CANCEL_URL_TEMPLATE =
  "https://api.tosspayments.com/v1/payments/{paymentKey}/cancel";

interface TossEnv {
  secretKey: string | null;
  confirmUrl: string;
  cancelUrlTemplate: string;
}

function readEnv(): TossEnv {
  // firebase-functions v1 의 functions.config() 는 호출 시점에 lazy load 됨.
  // 미설정이면 throw 하지 않고 null 로 폴백하여 개발 모드를 유지.
  let cfg: Record<string, unknown> = {};
  try {
    const root = functions.config() as Record<string, unknown>;
    cfg = (root.toss as Record<string, unknown>) ?? {};
  } catch (_) {
    cfg = {};
  }

  const secret =
    (process.env.TOSS_SECRET_KEY ?? "").trim() ||
    (typeof cfg.secret_key === "string" ? cfg.secret_key.trim() : "");
  const confirm =
    (process.env.TOSS_CONFIRM_URL ?? "").trim() ||
    (typeof cfg.confirm_url === "string" ?
      cfg.confirm_url.trim() :
      "") ||
    DEFAULT_CONFIRM_URL;
  const cancel =
    (process.env.TOSS_CANCEL_URL ?? "").trim() ||
    (typeof cfg.cancel_url === "string" ? cfg.cancel_url.trim() : "") ||
    DEFAULT_CANCEL_URL_TEMPLATE;

  return {
    secretKey: secret.length > 0 ? secret : null,
    confirmUrl: confirm,
    cancelUrlTemplate: cancel,
  };
}

/** Toss 가 "Basic base64(secret + ':')" 형태를 요구한다. */
function authHeader(secret: string): string {
  const token = Buffer.from(`${secret}:`).toString("base64");
  return `Basic ${token}`;
}

// ════════════════════════════════════════════════════════
// 결제 승인 검증
// ════════════════════════════════════════════════════════

export interface ConfirmInput {
  paymentKey: string;
  orderId: string;
  amount: number;
}

export interface ConfirmResult {
  /** 'verified' = 실제 PG 응답 검증 / 'mock' = secret 미설정으로 우회 / 'skipped_zero_amount' = 0원 */
  mode: "verified" | "mock" | "skipped_zero_amount";
  status?: string;
  approvedAt?: string;
  /** Toss 가 돌려준 raw payment 객체 (감사 로그용, 일부 필드만 보존) */
  raw?: Record<string, unknown>;
}

/** Toss 결제 승인 검증. 실패 시 HttpsError 를 throw. */
export async function verifyTossPayment(
  input: ConfirmInput
): Promise<ConfirmResult> {
  if (!Number.isFinite(input.amount) || input.amount <= 0) {
    return { mode: "skipped_zero_amount" };
  }
  if (!input.paymentKey || !input.orderId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "paymentKey와 orderId가 필요합니다.",
      { errorCode: "MISSING_PAYMENT_PARAMS" }
    );
  }

  const env = readEnv();
  if (!env.secretKey) {
    functions.logger.warn(
      "TOSS_SECRET_KEY 미설정 → mock 모드로 결제 승인 통과. 운영 배포 전에 반드시 설정하세요.",
      { orderId: input.orderId }
    );
    return { mode: "mock" };
  }

  try {
    const res = await axios.post(
      env.confirmUrl,
      {
        paymentKey: input.paymentKey,
        orderId: input.orderId,
        amount: input.amount,
      },
      {
        headers: {
          Authorization: authHeader(env.secretKey),
          "Content-Type": "application/json",
        },
        timeout: 15_000,
      }
    );
    const data = res.data as Record<string, unknown>;
    const status = String(data.status ?? "");
    const totalAmount = Number(data.totalAmount ?? data.amount ?? -1);
    const respOrderId = String(data.orderId ?? "");

    if (status !== "DONE") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        `결제가 완료 상태가 아닙니다. (status=${status})`,
        { errorCode: "PAYMENT_NOT_DONE", status }
      );
    }
    if (respOrderId !== input.orderId) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "주문 ID가 일치하지 않습니다.",
        { errorCode: "ORDER_ID_MISMATCH" }
      );
    }
    if (totalAmount !== input.amount) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        `결제 금액이 일치하지 않습니다. expected=${input.amount}, actual=${totalAmount}`,
        { errorCode: "AMOUNT_MISMATCH" }
      );
    }
    return {
      mode: "verified",
      status,
      approvedAt: typeof data.approvedAt === "string" ?
        (data.approvedAt as string) :
        undefined,
      raw: pickAuditFields(data),
    };
  } catch (e) {
    if (e instanceof functions.https.HttpsError) throw e;
    if (e instanceof AxiosError) {
      const status = e.response?.status ?? 0;
      const body = (e.response?.data as Record<string, unknown>) ?? {};
      functions.logger.error("Toss confirm API error", {
        status,
        orderId: input.orderId,
        body,
      });
      throw new functions.https.HttpsError(
        "failed-precondition",
        String(body.message ?? "결제 승인에 실패했습니다."),
        {
          errorCode: String(body.code ?? "TOSS_CONFIRM_FAILED"),
          httpStatus: status,
        }
      );
    }
    throw new functions.https.HttpsError(
      "internal",
      "결제 승인 중 알 수 없는 오류가 발생했습니다.",
      { errorCode: "TOSS_CONFIRM_UNKNOWN" }
    );
  }
}

// ════════════════════════════════════════════════════════
// 결제 환불(취소)
// ════════════════════════════════════════════════════════

export interface RefundInput {
  paymentKey: string;
  cancelReason: string;
  /** 부분 환불 시 amount 지정. 미지정이면 전액. */
  cancelAmount?: number;
}

export interface RefundResult {
  mode: "refunded" | "mock" | "skipped_zero_amount";
  status?: string;
  cancelledAt?: string;
  raw?: Record<string, unknown>;
}

export async function refundTossPayment(
  input: RefundInput
): Promise<RefundResult> {
  if (!input.paymentKey) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "paymentKey가 필요합니다.",
      { errorCode: "MISSING_PAYMENT_KEY" }
    );
  }
  if (
    input.cancelAmount !== undefined &&
    (!Number.isFinite(input.cancelAmount) || input.cancelAmount <= 0)
  ) {
    return { mode: "skipped_zero_amount" };
  }

  const env = readEnv();
  if (!env.secretKey) {
    functions.logger.warn(
      "TOSS_SECRET_KEY 미설정 → mock 모드로 환불 통과. 운영 배포 전에 반드시 설정하세요.",
      { paymentKey: input.paymentKey }
    );
    return { mode: "mock" };
  }

  const url = env.cancelUrlTemplate.replace(
    "{paymentKey}",
    encodeURIComponent(input.paymentKey)
  );
  try {
    const body: Record<string, unknown> = {
      cancelReason: input.cancelReason || "관리자 취소",
    };
    if (input.cancelAmount !== undefined) {
      body.cancelAmount = input.cancelAmount;
    }
    const res = await axios.post(url, body, {
      headers: {
        Authorization: authHeader(env.secretKey),
        "Content-Type": "application/json",
      },
      timeout: 20_000,
    });
    const data = res.data as Record<string, unknown>;
    const cancels = Array.isArray(data.cancels) ?
      (data.cancels as Record<string, unknown>[]) :
      [];
    const lastCancel = cancels.length > 0 ? cancels[cancels.length - 1] : {};
    return {
      mode: "refunded",
      status: typeof data.status === "string" ?
        (data.status as string) :
        undefined,
      cancelledAt: typeof lastCancel.canceledAt === "string" ?
        (lastCancel.canceledAt as string) :
        undefined,
      raw: pickAuditFields(data),
    };
  } catch (e) {
    if (e instanceof AxiosError) {
      const status = e.response?.status ?? 0;
      const errBody = (e.response?.data as Record<string, unknown>) ?? {};
      functions.logger.error("Toss cancel API error", {
        status,
        paymentKey: input.paymentKey,
        errBody,
      });
      throw new functions.https.HttpsError(
        "failed-precondition",
        String(errBody.message ?? "환불에 실패했습니다."),
        {
          errorCode: String(errBody.code ?? "TOSS_REFUND_FAILED"),
          httpStatus: status,
        }
      );
    }
    throw new functions.https.HttpsError(
      "internal",
      "환불 중 알 수 없는 오류가 발생했습니다.",
      { errorCode: "TOSS_REFUND_UNKNOWN" }
    );
  }
}

// ── audit log 보존용 — Toss raw 응답에서 필요한 키만 발췌 ────
function pickAuditFields(
  data: Record<string, unknown>
): Record<string, unknown> {
  const keys = [
    "paymentKey",
    "orderId",
    "status",
    "method",
    "totalAmount",
    "balanceAmount",
    "approvedAt",
    "useEscrow",
    "currency",
    "country",
    "cancels",
  ];
  const out: Record<string, unknown> = {};
  for (const k of keys) {
    if (k in data) out[k] = data[k];
  }
  return out;
}
