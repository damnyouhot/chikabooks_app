/**
 * billing/tossBillingAdapter.ts
 *
 * Toss Payments **빌링키(자동결제) 어댑터**.
 *
 * 자동연장(M5 — runAutoRenewals)이 호출하는 서버 전용 결제 모듈.
 * - 사용자가 카드 등록 시점에 받은 `billingKey` 와 `customerKey` 를 보관해 두고,
 *   본 어댑터로 정기 청구를 수행한다.
 * - secret key 는 결제 검증 어댑터(`tossPaymentsAdapter`) 와 동일 환경변수 사용.
 *
 * **주의**: 빌링키 등록 흐름(클라이언트 SDK + saveBillingKey Callable)은 별도 마일스톤
 * 에서 추가된다. 미등록 상태에서 본 어댑터를 호출하면 'no_billing_key' 폴백을 반환한다.
 *
 * 설정 방법:
 *   firebase functions:config:set toss.secret_key="test_sk_..." \
 *                                  toss.billing_url_template="https://api.tosspayments.com/v1/billing/{billingKey}"
 *
 * 또는 환경변수: TOSS_SECRET_KEY, TOSS_BILLING_URL.
 */

import axios, { AxiosError } from "axios";
import * as functions from "firebase-functions/v1";

const DEFAULT_BILLING_URL =
  "https://api.tosspayments.com/v1/billing/{billingKey}";
const DEFAULT_BILLING_AUTH_ISSUE_URL =
  "https://api.tosspayments.com/v1/billing/authorizations/issue";

interface BillingEnv {
  secretKey: string | null;
  billingUrlTemplate: string;
  billingAuthIssueUrl: string;
}

function readEnv(): BillingEnv {
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
  const billing =
    (process.env.TOSS_BILLING_URL ?? "").trim() ||
    (typeof cfg.billing_url_template === "string" ?
      cfg.billing_url_template.trim() :
      "") ||
    DEFAULT_BILLING_URL;
  const issueUrl =
    (process.env.TOSS_BILLING_AUTH_ISSUE_URL ?? "").trim() ||
    (typeof cfg.billing_auth_issue_url === "string" ?
      cfg.billing_auth_issue_url.trim() :
      "") ||
    DEFAULT_BILLING_AUTH_ISSUE_URL;
  return {
    secretKey: secret.length > 0 ? secret : null,
    billingUrlTemplate: billing,
    billingAuthIssueUrl: issueUrl,
  };
}

function authHeader(secret: string): string {
  const token = Buffer.from(`${secret}:`).toString("base64");
  return `Basic ${token}`;
}

export interface BillingChargeInput {
  /** 빌링키 발급 시 받은 키 (서버 보관) */
  billingKey: string;
  /** 카드 등록 시 사용한 customerKey (사용자 식별자, uid 기반 추천) */
  customerKey: string;
  /** 결제 식별자 (orders/{orderId}) — Toss orderId 와 동일하게 사용 */
  orderId: string;
  orderName: string;
  amount: number;
  /** 영수증 발송용 (선택) */
  customerEmail?: string;
  customerName?: string;
  /** 멱등성 키(미사용) */
  taxFreeAmount?: number;
}

export interface BillingChargeResult {
  /** 'charged' = 실제 결제 성공
   *  'mock' = secret 미설정 (개발/스테이징 우회)
   *  'no_billing_key' = billingKey 미등록 — 호출 측은 알림 폴백 처리 */
  mode: "charged" | "mock" | "no_billing_key";
  /** 성공 시 Toss 가 돌려준 paymentKey (이후 환불 등에 사용) */
  paymentKey?: string;
  status?: string;
  approvedAt?: string;
  raw?: Record<string, unknown>;
}

/**
 * 빌링키 자동 결제. 실패 시 HttpsError throw.
 *
 * billingKey 가 비어 있으면 호출 즉시 'no_billing_key' 모드로 종료해 호출 측이
 * 알림 폴백(수동 결제 유도)을 적재할 수 있게 한다.
 */
export async function chargeWithBillingKey(
  input: BillingChargeInput
): Promise<BillingChargeResult> {
  if (!input.billingKey || !input.customerKey) {
    return { mode: "no_billing_key" };
  }
  if (!Number.isFinite(input.amount) || input.amount <= 0) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "결제 금액이 잘못됐습니다.",
      { errorCode: "INVALID_AMOUNT" }
    );
  }
  if (!input.orderId || !input.orderName) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "주문 정보가 누락됐습니다.",
      { errorCode: "MISSING_ORDER_INFO" }
    );
  }

  const env = readEnv();
  if (!env.secretKey) {
    functions.logger.warn(
      "TOSS_SECRET_KEY 미설정 → 빌링키 자동결제를 mock 모드로 통과. 운영 배포 전에 반드시 설정하세요.",
      { orderId: input.orderId }
    );
    return { mode: "mock" };
  }

  const url = env.billingUrlTemplate.replace(
    "{billingKey}",
    encodeURIComponent(input.billingKey)
  );
  try {
    const res = await axios.post(
      url,
      {
        customerKey: input.customerKey,
        amount: input.amount,
        orderId: input.orderId,
        orderName: input.orderName,
        customerEmail: input.customerEmail,
        customerName: input.customerName,
        taxFreeAmount: input.taxFreeAmount,
      },
      {
        headers: {
          Authorization: authHeader(env.secretKey),
          "Content-Type": "application/json",
        },
        timeout: 20_000,
      }
    );
    const data = res.data as Record<string, unknown>;
    const status = String(data.status ?? "");
    if (status !== "DONE") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        `자동결제가 완료되지 않았습니다. (status=${status})`,
        { errorCode: "BILLING_NOT_DONE", status }
      );
    }
    return {
      mode: "charged",
      paymentKey: typeof data.paymentKey === "string" ?
        (data.paymentKey as string) :
        undefined,
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
      functions.logger.error("Toss billing charge error", {
        status,
        orderId: input.orderId,
        body,
      });
      throw new functions.https.HttpsError(
        "failed-precondition",
        String(body.message ?? "자동결제에 실패했습니다."),
        {
          errorCode: String(body.code ?? "TOSS_BILLING_FAILED"),
          httpStatus: status,
        }
      );
    }
    throw new functions.https.HttpsError(
      "internal",
      "자동결제 중 알 수 없는 오류가 발생했습니다.",
      { errorCode: "TOSS_BILLING_UNKNOWN" }
    );
  }
}

function pickAuditFields(
  data: Record<string, unknown>
): Record<string, unknown> {
  const keys = [
    "paymentKey",
    "orderId",
    "status",
    "method",
    "totalAmount",
    "approvedAt",
    "card",
    "currency",
  ];
  const out: Record<string, unknown> = {};
  for (const k of keys) {
    if (k in data) out[k] = data[k];
  }
  return out;
}

// ════════════════════════════════════════════════════════
// 빌링키 발급 (카드 등록 — authKey → billingKey 교환)
// ════════════════════════════════════════════════════════
//
// Toss 가 클라이언트 SDK billingAuth 성공 시 redirect 로 돌려준 authKey 를
// 서버에서 한 번 더 호출해 영구 billingKey 로 교환한다.
// authKey 는 단발성 / 짧은 만료 시간을 갖는다.

export interface IssueBillingKeyInput {
  authKey: string;
  customerKey: string;
}

export interface BillingKeyIssued {
  billingKey: string;
  customerKey: string;
  authenticatedAt?: string;
  method?: string;
  /** 카드사 정보 (영수증/표시용) */
  card?: {
    issuerCode?: string;
    acquirerCode?: string;
    number?: string;
    cardType?: string;
    ownerType?: string;
  };
  /** 카드사명 (있는 경우) */
  cardCompany?: string;
  raw?: Record<string, unknown>;
}

export interface IssueBillingKeyResult {
  /**
   *  'issued' = 실제 PG 응답으로 billingKey 발급됨.
   *  'mock'   = secret 미설정 — 운영전 폴백 (고정 mock billingKey 반환).
   */
  mode: "issued" | "mock";
  data: BillingKeyIssued;
}

/**
 * authKey + customerKey 로 Toss 빌링키를 발급(교환)한다.
 *
 * Toss API: POST /v1/billing/authorizations/issue
 * Body: { authKey, customerKey }
 * Response: { mId, customerKey, authenticatedAt, method, billingKey, card{...} }
 */
export async function issueBillingKey(
  input: IssueBillingKeyInput
): Promise<IssueBillingKeyResult> {
  const authKey = (input.authKey ?? "").trim();
  const customerKey = (input.customerKey ?? "").trim();
  if (!authKey || !customerKey) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "authKey / customerKey 가 필요합니다.",
      { errorCode: "MISSING_BILLING_AUTH_PARAMS" }
    );
  }
  const env = readEnv();
  if (!env.secretKey) {
    functions.logger.warn(
      "TOSS_SECRET_KEY 미설정 → 빌링키 발급을 mock 모드로 통과. 실제 자동결제는 동작하지 않습니다.",
      { customerKey }
    );
    return {
      mode: "mock",
      data: {
        billingKey: `mock_billing_${customerKey}_${Date.now()}`,
        customerKey,
        authenticatedAt: new Date().toISOString(),
        method: "CARD",
        card: {
          issuerCode: "MOCK",
          number: "1234********0000",
          cardType: "신용",
          ownerType: "개인",
        },
        cardCompany: "MOCK 카드사",
      },
    };
  }
  try {
    const res = await axios.post(
      env.billingAuthIssueUrl,
      { authKey, customerKey },
      {
        headers: {
          Authorization: authHeader(env.secretKey),
          "Content-Type": "application/json",
        },
        timeout: 20_000,
      }
    );
    const data = res.data as Record<string, unknown>;
    const billingKey = String(data.billingKey ?? "");
    if (!billingKey) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "빌링키가 발급되지 않았습니다.",
        { errorCode: "BILLING_KEY_NOT_ISSUED" }
      );
    }
    const card = (data.card as Record<string, unknown> | undefined) ?? undefined;
    const cardCompany = typeof card?.issuerCode === "string" ?
      mapCardIssuer(String(card.issuerCode)) :
      undefined;
    return {
      mode: "issued",
      data: {
        billingKey,
        customerKey: String(data.customerKey ?? customerKey),
        authenticatedAt: typeof data.authenticatedAt === "string" ?
          (data.authenticatedAt as string) :
          undefined,
        method: typeof data.method === "string" ?
          (data.method as string) :
          "CARD",
        card: card ? {
          issuerCode: typeof card.issuerCode === "string" ?
            (card.issuerCode as string) :
            undefined,
          acquirerCode: typeof card.acquirerCode === "string" ?
            (card.acquirerCode as string) :
            undefined,
          number: typeof card.number === "string" ?
            (card.number as string) :
            undefined,
          cardType: typeof card.cardType === "string" ?
            (card.cardType as string) :
            undefined,
          ownerType: typeof card.ownerType === "string" ?
            (card.ownerType as string) :
            undefined,
        } : undefined,
        cardCompany,
        raw: pickIssueAuditFields(data),
      },
    };
  } catch (e) {
    if (e instanceof functions.https.HttpsError) throw e;
    if (e instanceof AxiosError) {
      const status = e.response?.status ?? 0;
      const body = (e.response?.data as Record<string, unknown>) ?? {};
      functions.logger.error("Toss issueBillingKey error", {
        status,
        customerKey,
        body,
      });
      throw new functions.https.HttpsError(
        "failed-precondition",
        String(body.message ?? "빌링키 발급에 실패했습니다."),
        {
          errorCode: String(body.code ?? "TOSS_BILLING_AUTH_FAILED"),
          httpStatus: status,
        }
      );
    }
    throw new functions.https.HttpsError(
      "internal",
      "빌링키 발급 중 알 수 없는 오류가 발생했습니다.",
      { errorCode: "TOSS_BILLING_AUTH_UNKNOWN" }
    );
  }
}

function pickIssueAuditFields(
  data: Record<string, unknown>
): Record<string, unknown> {
  const keys = [
    "mId",
    "customerKey",
    "authenticatedAt",
    "method",
    "billingKey",
    "card",
  ];
  const out: Record<string, unknown> = {};
  for (const k of keys) {
    if (k in data) out[k] = data[k];
  }
  return out;
}

/** 토스 issuerCode → 사람이 읽는 카드사명 매핑 (대표 8개만, 나머지는 코드 그대로). */
function mapCardIssuer(code: string): string {
  switch (code) {
  case "61": return "BC카드";
  case "31": return "BC카드";
  case "11": return "KB국민카드";
  case "44": return "신한카드";
  case "36": return "씨티카드";
  case "33": return "우리카드";
  case "37": return "농협카드";
  case "34": return "하나카드";
  case "21": return "롯데카드";
  case "41": return "현대카드";
  case "71": return "삼성카드";
  default: return `카드(${code})`;
  }
}
