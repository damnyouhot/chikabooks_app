/**
 * ads/billingKeys.ts
 *
 * 빌링키(자동결제 카드) 등록 / 해지 Callable Functions.
 *
 * 흐름 (등록):
 *   1) 클라이언트가 Toss SDK `billing.requestBillingAuth({ method: 'CARD' })` 호출.
 *   2) successUrl 콜백에 `authKey`, `customerKey` 가 전달됨.
 *   3) 클라이언트가 본 Callable `registerBillingKey({ authKey, customerKey })` 호출.
 *   4) 서버가 Toss `/v1/billing/authorizations/issue` 로 영구 `billingKey` 교환.
 *   5) `billingKeys/{uid}` (서버 전용) + `users/{uid}/billingMeta/profile` (클라 read) 저장.
 *
 * 보안:
 *   - billingKey 자체는 절대 클라이언트에 노출하지 않음 (`billingKeys/*` 룰 거부).
 *   - 클라이언트는 `billingMeta/profile` 에서 hasBillingKey, 카드사, 마지막 4자리만 읽는다.
 *   - `customerKey` 는 항상 인증된 uid 로 강제 설정 — 클라가 다른 uid 로 위조 못 함.
 */

import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";

import {
  issueBillingKey,
  type BillingKeyIssued,
} from "../billing/tossBillingAdapter";

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = (): FirebaseFirestore.Firestore => admin.firestore();

// 한국어 메시지 + 영어 errorCode 패턴 통일
const REGION = "asia-northeast3";

interface RegisterInput {
  authKey?: unknown;
  customerKey?: unknown;
  customerEmail?: unknown;
  customerName?: unknown;
}

function mask(input: unknown): string {
  const s = String(input ?? "").trim();
  if (s.length <= 4) return "****";
  return `${s.substring(0, 2)}...${s.substring(s.length - 4)}`;
}

/**
 * 카드(빌링키) 등록.
 *
 * 입력:
 *   - authKey: Toss successUrl 에서 받은 1회용 키 (필수)
 *   - customerKey: 클라이언트가 사용한 customerKey — 반드시 인증 uid 와 일치 (필수)
 *   - customerEmail / customerName: 영수증/표시용 (선택)
 *
 * 반환: { mode, hasBillingKey: true, cardCompany, cardNumberMasked, cardType }
 */
export const registerBillingKey = functions
  .region(REGION)
  .https.onCall(async (data: RegisterInput, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "로그인이 필요합니다.",
        { errorCode: "AUTH_REQUIRED" }
      );
    }
    const uid = context.auth.uid;
    const authKey = String(data.authKey ?? "").trim();
    const customerKey = String(data.customerKey ?? "").trim();
    const customerEmail = String(data.customerEmail ?? "").trim();
    const customerName = String(data.customerName ?? "").trim();

    if (!authKey) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "authKey 가 필요합니다.",
        { errorCode: "MISSING_AUTH_KEY" }
      );
    }
    if (!customerKey) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "customerKey 가 필요합니다.",
        { errorCode: "MISSING_CUSTOMER_KEY" }
      );
    }
    // customerKey 는 반드시 uid 와 동일해야 한다 (위조 방지)
    if (customerKey !== uid) {
      functions.logger.warn("registerBillingKey customerKey mismatch", {
        uid,
        customerKey: mask(customerKey),
      });
      throw new functions.https.HttpsError(
        "permission-denied",
        "본인의 결제 식별자가 아닙니다.",
        { errorCode: "CUSTOMER_KEY_MISMATCH" }
      );
    }

    // ── 1. Toss 에 billingKey 발급 요청 ───────────────────
    const issued = await issueBillingKey({ authKey, customerKey });
    const billingKey = issued.data.billingKey;
    if (!billingKey) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "빌링키가 발급되지 않았습니다.",
        { errorCode: "BILLING_KEY_NOT_ISSUED" }
      );
    }

    const card = issued.data.card ?? {};
    const cardCompany = issued.data.cardCompany ??
      (typeof card.issuerCode === "string" ? card.issuerCode : "") ?? "";
    const cardNumberMasked = typeof card.number === "string" ?
      (card.number as string) :
      "";
    const cardType = typeof card.cardType === "string" ?
      (card.cardType as string) :
      "";
    const ownerType = typeof card.ownerType === "string" ?
      (card.ownerType as string) :
      "";

    const now = admin.firestore.Timestamp.now();
    const keyRef = db().collection("billingKeys").doc(uid);
    const metaRef = db()
      .collection("users")
      .doc(uid)
      .collection("billingMeta")
      .doc("profile");
    const eventRef = db().collection("billingEvents").doc();

    // ── 2. 트랜잭션: billingKeys + billingMeta + billingEvents 동시 기록 ──
    await db().runTransaction(async (tx) => {
      // 기존 빌링키가 있으면 audit 에 남기고 덮어씀 (가장 최근 카드만 유효)
      const prev = await tx.get(keyRef);
      tx.set(keyRef, {
        uid,
        tossBillingKey: billingKey,
        tossCustomerKey: customerKey,
        customerEmail: customerEmail || null,
        customerName: customerName || null,
        cardCompany,
        cardNumberMasked,
        cardType,
        ownerType,
        method: issued.data.method ?? "CARD",
        authenticatedAt: issued.data.authenticatedAt ?? null,
        issuedAt: now,
        status: "active",
        previousBillingKey: prev.exists ?
          (prev.data()?.tossBillingKey ?? null) :
          null,
        // 인증/디버깅용 안전 필드만 보존 (raw 응답 제외)
        adapterMode: issued.mode,
        updatedAt: now,
      });

      tx.set(metaRef, {
        hasBillingKey: true,
        cardCompany,
        cardNumberMasked,
        cardType,
        ownerType,
        method: issued.data.method ?? "CARD",
        registeredAt: now,
        deletedAt: null,
        status: "active",
        adapterMode: issued.mode,
        updatedAt: now,
      });

      tx.set(eventRef, {
        type: "billing_key_registered",
        actor: uid,
        ownerUid: uid,
        cardCompany,
        cardNumberMasked,
        adapterMode: issued.mode,
        createdAt: now,
      });
    });

    functions.logger.info("registerBillingKey OK", {
      uid,
      adapterMode: issued.mode,
      cardCompany,
    });

    return {
      mode: issued.mode,
      hasBillingKey: true,
      cardCompany,
      cardNumberMasked,
      cardType,
      ownerType,
    } as Record<string, unknown> & { data?: BillingKeyIssued };
  });

/**
 * 카드(빌링키) 해지.
 *
 * - billingKeys/{uid}.status = 'deleted', tossBillingKey 비움.
 * - 자동연장이 켜진 캠페인이 있으면 함께 OFF 로 전환 (안전을 위해 자동결제 차단).
 */
export const deleteBillingKey = functions
  .region(REGION)
  .https.onCall(async (_data: unknown, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "로그인이 필요합니다.",
        { errorCode: "AUTH_REQUIRED" }
      );
    }
    const uid = context.auth.uid;

    const now = admin.firestore.Timestamp.now();
    const keyRef = db().collection("billingKeys").doc(uid);
    const metaRef = db()
      .collection("users")
      .doc(uid)
      .collection("billingMeta")
      .doc("profile");
    const eventRef = db().collection("billingEvents").doc();

    // 자동연장 ON 캠페인 미리 조회 — 트랜잭션 밖에서 (large query 회피)
    const autoOnSnap = await db()
      .collection("campaigns")
      .where("ownerUid", "==", uid)
      .where("autoRenew.enabled", "==", true)
      .limit(50)
      .get();

    await db().runTransaction(async (tx) => {
      const prev = await tx.get(keyRef);
      const prevKey = prev.exists ?
        (prev.data()?.tossBillingKey ?? null) :
        null;

      tx.set(keyRef, {
        uid,
        tossBillingKey: null,
        previousBillingKey: prevKey,
        status: "deleted",
        deletedAt: now,
        updatedAt: now,
      }, { merge: true });

      tx.set(metaRef, {
        hasBillingKey: false,
        cardCompany: null,
        cardNumberMasked: null,
        status: "deleted",
        deletedAt: now,
        updatedAt: now,
      }, { merge: true });

      // 자동연장 강제 OFF (안전): 등록 카드 없는 상태에서 ON 유지하면
      // runAutoRenewals 가 매일 'no_billing_key' 알림을 적재함.
      for (const doc of autoOnSnap.docs) {
        tx.update(doc.ref, {
          "autoRenew.enabled": false,
          "autoRenew.disabledReason": "billing_key_deleted",
          "autoRenew.disabledAt": now,
          updatedAt: now,
        });
        const auditRef = doc.ref.collection("auditLog").doc();
        tx.set(auditRef, {
          type: "auto_renew_disabled",
          actor: uid,
          reason: "billing_key_deleted",
          at: now,
        });
      }

      tx.set(eventRef, {
        type: "billing_key_deleted",
        actor: uid,
        ownerUid: uid,
        affectedAutoRenewCampaigns: autoOnSnap.size,
        createdAt: now,
      });
    });

    functions.logger.info("deleteBillingKey OK", {
      uid,
      autoRenewDisabled: autoOnSnap.size,
    });

    return {
      hasBillingKey: false,
      autoRenewDisabledCount: autoOnSnap.size,
    };
  });
