/**
 * ads/orders.ts
 *
 * 광고 주문 라이프사이클 Callable.
 *
 *   createOrder(...)          → orders/{orderId} 생성 (가격 스냅샷, 공고권 등급 검증)
 *   confirmPayment(...)       → 결제 확인 후 jobs/{jobId} + campaigns/{campaignId} 생성
 *
 * 핵심 원칙(설계서 §2-2):
 *   - 결제 시점에 priceId / amountPaid / policySnapshot 을 캠페인에 박아 두고,
 *     이후 가격·정책 변경에 영향을 받지 않게 한다.
 *   - 공고권은 `productCatalog/{tierKey}` 키 단위로 사용 가능 여부를 검증한다 (C 전용 등).
 *   - 결제 동의(consents) 는 `orders.consentSnapshot` 으로 영구 보존.
 *
 * Toss 결제 자체의 위변조 검증(`paymentKey` → secretKey 인증)은 외주 어댑터가 도입되는
 * 시점(설계서 §M6)에 본 함수의 confirmPayment 내부 TODO 영역만 교체한다. 외부 인터페이스
 * 변경 없음.
 */

import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";

import {
  TierKey,
  getBillingPolicy,
  getActivePrice,
  getProductCatalog,
  isVoucherEligibleForTier,
  normalizeTierKey,
} from "./catalog";
import { verifyTossPayment } from "../billing/tossPaymentsAdapter";

const db = () => admin.firestore();

// ════════════════════════════════════════════════════════════════
// Helpers
// ════════════════════════════════════════════════════════════════

function requireAuth(
  context: functions.https.CallableContext
): {uid: string; email: string} {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "로그인이 필요합니다."
    );
  }
  return {
    uid: context.auth.uid,
    email: String(context.auth.token.email ?? "").trim().toLowerCase(),
  };
}

function trimStr(v: unknown): string {
  return String(v ?? "").trim();
}

function stringList(raw: unknown): string[] {
  return Array.isArray(raw) ?
    raw.filter((v): v is string => typeof v === "string") :
    [];
}

// ════════════════════════════════════════════════════════════════
// createOrder
// ════════════════════════════════════════════════════════════════

interface CreateOrderInput {
  draftId: string;
  clinicProfileId: string;
  /** "premium" | "standard" | "basic". 미지정 시 draft.productTier 또는 standard 폴백. */
  tierKey?: string;
  voucherId?: string;
  consents?: Record<string, unknown>;
}

interface CreateOrderOutput {
  orderId: string;
  amount: number;
  requiresPayment: boolean;
  tierKey: TierKey;
  priceId: string;
}

export const createOrder = functions
  .region("asia-northeast3")
  .https.onCall(
    async (data: CreateOrderInput, context): Promise<CreateOrderOutput> => {
      const { uid } = requireAuth(context);

      const draftId = trimStr(data?.draftId);
      const clinicProfileId = trimStr(data?.clinicProfileId);
      if (!draftId || !clinicProfileId) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "draftId와 clinicProfileId가 필요합니다."
        );
      }

      // 1) Draft 검증
      const draftRef = db().collection("jobDrafts").doc(draftId);
      const draftSnap = await draftRef.get();
      if (!draftSnap.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "공고 임시저장을 찾을 수 없습니다."
        );
      }
      const draft = draftSnap.data() ?? {};
      if (draft.ownerUid !== uid) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "본인 공고만 결제할 수 있습니다."
        );
      }

      // 2) Tier 결정 (입력 > draft > standard 폴백)
      const tierKey: TierKey = normalizeTierKey(
        data?.tierKey ?? draft.productTier ?? "standard"
      );

      // 3) Catalog & 가격 스냅샷
      const catalog = await getProductCatalog(tierKey);
      if (!catalog.isActive) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "현재 판매 중지된 상품입니다."
        );
      }
      const price = await getActivePrice(catalog);

      // 4) 공고권 검증 (C 전용 등 정책 적용)
      const policy = await getBillingPolicy();
      let appliedVoucher: FirebaseFirestore.DocumentSnapshot | null = null;
      const voucherId = trimStr(data?.voucherId);
      if (voucherId) {
        const voucherRef = db().collection("vouchers").doc(voucherId);
        const voucherSnap = await voucherRef.get();
        if (!voucherSnap.exists) {
          throw new functions.https.HttpsError(
            "not-found",
            "공고권을 찾을 수 없습니다.",
            { errorCode: "VOUCHER_NOT_FOUND" }
          );
        }
        const v = voucherSnap.data() ?? {};
        if (v.ownerUid !== uid) {
          throw new functions.https.HttpsError(
            "permission-denied",
            "본인 공고권만 사용할 수 있습니다.",
            { errorCode: "VOUCHER_NOT_OWNED" }
          );
        }
        if (v.status !== "active") {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "사용할 수 없는 공고권입니다.",
            { errorCode: "VOUCHER_NOT_ACTIVE" }
          );
        }
        if (v.expiresAt && (v.expiresAt as FirebaseFirestore.Timestamp)
          .toMillis() < Date.now()) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "만료된 공고권입니다.",
            { errorCode: "VOUCHER_EXPIRED" }
          );
        }
        if (!isVoucherEligibleForTier(v, policy, tierKey)) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "이 공고권은 선택한 등급에 사용할 수 없습니다. (C 일반에서만 사용 가능)",
            { errorCode: "VOUCHER_NOT_ELIGIBLE_FOR_TIER", tierKey }
          );
        }
        appliedVoucher = voucherSnap;
      }

      // 5) Order 문서 생성
      const orderRef = db().collection("orders").doc();
      const now = admin.firestore.Timestamp.now();
      const baseAmount = price.amount;
      const amount = appliedVoucher ? 0 : baseAmount;
      const requiresPayment = amount > 0;

      const orderDoc: FirebaseFirestore.DocumentData = {
        ownerUid: uid,
        draftId,
        clinicProfileId,
        status: requiresPayment ? "payment_pending" : "created",
        amount,
        currency: price.currency,
        tierKey,
        priceId: price.priceId,
        purpose: "create",
        parentCampaignId: null,
        discountRate: 0.0,
        exposureDays: catalog.exposureDays,
        voucherId: appliedVoucher ? appliedVoucher.id : null,
        voucherEligible: appliedVoucher !== null,
        paymentProvider: appliedVoucher ? "voucher_only" : "toss",
        providerTxId: null,
        jobId: null,
        consentSnapshot: sanitizeConsents(data?.consents),
        createdAt: now,
        updatedAt: now,
        // 정책 스냅샷 — 캠페인 생성 시점에 그대로 옮긴다
        policySnapshot: {
          pauseSaveRate: policy.pauseSaveRate,
          pauseMinDaysToAllow: policy.pauseMinDaysToAllow,
          pauseMaxCountPerCampaign: policy.pauseMaxCountPerCampaign,
          autoRenewLeadDays: policy.autoRenewLeadDays,
          refundWindowDays: policy.refundWindowDays,
          policyVersion: policy.policyVersion,
        },
      };

      await orderRef.set(orderDoc);

      functions.logger.info("createOrder", {
        uid,
        orderId: orderRef.id,
        tierKey,
        priceId: price.priceId,
        amount,
        voucherId: appliedVoucher?.id ?? null,
      });

      return {
        orderId: orderRef.id,
        amount,
        requiresPayment,
        tierKey,
        priceId: price.priceId,
      };
    }
  );

function sanitizeConsents(
  raw: Record<string, unknown> | undefined
): Record<string, unknown> | null {
  if (!raw || typeof raw !== "object") return null;
  // 임의 키를 그대로 허용하되, 깊이 1 단계만 보존 (firestore 스키마 안정성)
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(raw)) {
    if (typeof k !== "string" || k.length > 64) continue;
    if (
      v === null ||
      typeof v === "string" ||
      typeof v === "number" ||
      typeof v === "boolean"
    ) {
      out[k] = v;
    }
  }
  return out;
}

// ════════════════════════════════════════════════════════════════
// confirmPayment
// ════════════════════════════════════════════════════════════════

interface ConfirmPaymentInput {
  orderId: string;
  paymentKey?: string;
}

interface ConfirmPaymentOutput {
  jobId: string;
  campaignId: string;
  success: boolean;
  /** 'create' | 'extend' | 'upgrade' | 'auto_renew' */
  purpose: string;
}

export const confirmPayment = functions
  .region("asia-northeast3")
  .https.onCall(
    async (
      data: ConfirmPaymentInput,
      context
    ): Promise<ConfirmPaymentOutput> => {
      const { uid } = requireAuth(context);

      const orderId = trimStr(data?.orderId);
      if (!orderId) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "orderId가 필요합니다."
        );
      }
      const paymentKey = trimStr(data?.paymentKey) || null;

      const orderRef = db().collection("orders").doc(orderId);
      const orderSnap = await orderRef.get();
      if (!orderSnap.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "주문을 찾을 수 없습니다."
        );
      }
      const order = orderSnap.data() ?? {};
      if (order.ownerUid !== uid) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "본인 주문만 확인할 수 있습니다."
        );
      }

      const purpose = String(order.purpose ?? "create");

      // 멱등 처리: 이미 paid + jobId/campaignId 보유한 주문은 동일 결과 반환
      if (order.status === "paid" && order.jobId && order.campaignId) {
        return {
          jobId: order.jobId,
          campaignId: order.campaignId,
          success: true,
          purpose,
        };
      }
      if (order.status === "refunded" || order.status === "cancelled") {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "이미 종료된 주문입니다.",
          { errorCode: "ALREADY_TERMINATED", status: order.status }
        );
      }

      // ── PG 결제 위변조 검증 (G3) ──────────────────────────
      //    amount > 0 인 경우 paymentKey 필수 + Toss API 로 status/orderId/amount 일치 검증.
      if (order.amount > 0 && !paymentKey) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "결제 키가 누락됐습니다.",
          { errorCode: "PAYMENT_KEY_MISSING" }
        );
      }
      const tossResult = await verifyTossPayment({
        paymentKey: paymentKey ?? "",
        orderId: orderId,
        amount: Number(order.amount) || 0,
      });

      // 분기: 신규 vs 연장/등급변경/자동연장
      if (purpose === "extend" || purpose === "auto_renew") {
        return await _confirmExtend(uid, orderRef, order, paymentKey, tossResult.mode);
      }
      if (purpose === "upgrade") {
        return await _confirmUpgrade(uid, orderRef, order, paymentKey, tossResult.mode);
      }

      // ── 신규 결제(create): Draft → jobs + campaigns 트랜잭션 생성 ──
      const draftRef = db().collection("jobDrafts").doc(order.draftId);
      const draftSnap = await draftRef.get();
      if (!draftSnap.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "공고 임시저장을 찾을 수 없습니다."
        );
      }
      const draft = draftSnap.data() ?? {};
      const tierKey: TierKey = normalizeTierKey(
        order.tierKey ?? draft.productTier ?? "standard"
      );
      const catalog = await getProductCatalog(tierKey);

      const profileRef = db()
        .collection("clinics_accounts")
        .doc(uid)
        .collection("clinic_profiles")
        .doc(order.clinicProfileId);
      const profileSnap = await profileRef.get();
      const profile = profileSnap.exists ? profileSnap.data() ?? {} : {};

      const now = admin.firestore.Timestamp.now();
      const adEndAt = admin.firestore.Timestamp.fromMillis(
        now.toMillis() + catalog.exposureDays * 24 * 60 * 60 * 1000
      );

      const clinicName = trimStr(
        draft.clinicName ?? profile.displayName ?? profile.clinicName ?? ""
      );
      const registeredClinicName = trimStr(
        draft.registeredClinicName ??
        profile.clinicName ??
        profile?.businessVerification?.ocrResult?.clinicName ??
        ""
      );
      const address = trimStr(draft.address ?? profile.address ?? "");
      const phone = trimStr(draft.contact ?? profile.phone ?? "");

      const jobRef = db().collection("jobs").doc();
      const campaignRef = db().collection("campaigns").doc();

      const jobData: FirebaseFirestore.DocumentData = {
        ownerUid: uid,
        createdBy: uid,
        clinicId: uid,
        clinicProfileId: order.clinicProfileId,
        registeredClinicName,
        clinicName,
        title: trimStr(draft.title),
        role: trimStr(draft.role),
        type: trimStr(draft.role),
        career: trimStr(draft.career),
        education: trimStr(draft.education),
        employmentType: trimStr(draft.employmentType),
        workHours: trimStr(draft.workHours),
        salary: trimStr(draft.salary),
        salaryText: trimStr(draft.salary),
        benefits: stringList(draft.benefits),
        description: trimStr(draft.description),
        details: trimStr(draft.description),
        address,
        contact: phone,
        images: stringList(draft.imageUrls),
        rawImageUrls: stringList(draft.rawImageUrls),
        promotionalImageUrls: stringList(draft.promotionalImageUrls),
        logoUrl: typeof draft.logoUrl === "string" ? draft.logoUrl : null,
        hospitalType: draft.hospitalType ?? null,
        chairCount: draft.chairCount ?? null,
        staffCount: draft.staffCount ?? null,
        specialties: stringList(draft.specialties),
        workDays: stringList(draft.workDays),
        weekendWork: draft.weekendWork === true,
        nightShift: draft.nightShift === true,
        applyMethod: stringList(draft.applyMethod),
        requiredDocuments: stringList(draft.requiredDocuments),
        isAlwaysHiring: draft.isAlwaysHiring === true,
        transportation: draft.transportation ?? null,
        subwayLines: stringList(draft.subwayLines),
        tags: stringList(draft.tags),
        mainDutiesList: stringList(draft.mainDutiesList),
        productTier: tierKey,
        productLabel: catalog.name,
        tierKey,
        jobLevel: catalog.jobLevel,
        priorityScore: catalog.matchPriority,
        status: "active",
        paymentStatus: order.amount > 0 ? "paid" : "voucher_only",
        campaignId: campaignRef.id,
        postedAt: now,
        adStartAt: now,
        adEndAt,
        createdAt: now,
        updatedAt: now,
      };

      const campaignData: FirebaseFirestore.DocumentData = {
        ownerUid: uid,
        clinicProfileId: order.clinicProfileId,
        jobId: jobRef.id,
        orderId: orderRef.id,
        tierKey,
        priceId: order.priceId ?? catalog.activePriceId,
        amountPaid: order.amount,
        voucherId: order.voucherId ?? null,
        lifecycleStatus: "active",
        adStartAt: now,
        adEndAt,
        originalEndAt: adEndAt,
        pause: {
          count: 0,
          totalDaysOnPause: 0,
          totalDaysCredited: 0,
          currentPausedAt: null,
        },
        pauseHistory: [],
        autoRenew: {
          enabled: false,
          consentVersion: null,
          enabledAt: null,
          discountRateSnapshot: catalog.autoRenewDiscountRate,
          nextChargeAt: null,
          lastChargeStatus: "none",
          failedReason: null,
        },
        extensionHistory: [],
        policySnapshot: order.policySnapshot ?? {},
        notificationsSent: { national: 0, regional: 0, openRate: 0 },
        createdAt: now,
        updatedAt: now,
      };

      await db().runTransaction(async (tx) => {
        // 트랜잭션 내부에서 order 재조회로 동시성 보호 (멱등)
        const fresh = await tx.get(orderRef);
        const o = fresh.data() ?? {};
        if (o.status === "paid" && o.jobId) return; // 이미 처리됨
        if (o.status === "refunded" || o.status === "cancelled") {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "이미 종료된 주문입니다."
          );
        }

        tx.set(jobRef, jobData);
        tx.set(campaignRef, campaignData);
        tx.update(orderRef, {
          status: "paid",
          jobId: jobRef.id,
          campaignId: campaignRef.id,
          paidAt: now,
          providerTxId: paymentKey,
          updatedAt: now,
        });
        tx.update(draftRef, {
          currentStep: "published",
          publishedJobId: jobRef.id,
          campaignId: campaignRef.id,
          updatedAt: now,
        });

        // 공고권 사용 처리
        if (order.voucherId) {
          const voucherRef = db().collection("vouchers").doc(order.voucherId);
          tx.update(voucherRef, {
            status: "used",
            usedForOrderId: orderRef.id,
            usedAt: now,
          });
        }

        // 캠페인 audit log
        const auditRef = campaignRef.collection("auditLog").doc();
        tx.set(auditRef, {
          type: "created",
          actor: uid,
          before: null,
          after: {
            tierKey,
            adEndAt,
            amountPaid: order.amount,
          },
          note: "초기 결제 확정",
          at: now,
        });
      });

      // billingEvents 기록 (트랜잭션 외부 — 보조 로그)
      await db().collection("billingEvents").add({
        type: order.amount > 0 ? "order_paid" : "voucher_used",
        ownerUid: uid,
        campaignId: campaignRef.id,
        orderId: orderRef.id,
        jobId: jobRef.id,
        amount: order.amount,
        tierKey,
        priceId: order.priceId ?? catalog.activePriceId,
        discountRate: 0.0,
        happenedAt: now,
        meta: { providerTxId: paymentKey, tossMode: tossResult.mode },
      });

      functions.logger.info("confirmPayment", {
        uid,
        orderId,
        jobId: jobRef.id,
        campaignId: campaignRef.id,
        tierKey,
        amount: order.amount,
        tossMode: tossResult.mode,
      });

      return {
        jobId: jobRef.id,
        campaignId: campaignRef.id,
        success: true,
        purpose: "create",
      };
    }
  );

// ════════════════════════════════════════════════════════════════
// 확장 결제: 연장 (extend) / 자동연장 (auto_renew)
// ════════════════════════════════════════════════════════════════
async function _confirmExtend(
  uid: string,
  orderRef: FirebaseFirestore.DocumentReference,
  order: FirebaseFirestore.DocumentData,
  paymentKey: string | null,
  tossMode: string
): Promise<ConfirmPaymentOutput> {
  const campaignId = String(order.parentCampaignId ?? "");
  if (!campaignId) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "연장 대상 캠페인이 지정되지 않았습니다.",
      { errorCode: "MISSING_PARENT_CAMPAIGN" }
    );
  }
  const campaignRef = db().collection("campaigns").doc(campaignId);
  const campSnap = await campaignRef.get();
  if (!campSnap.exists) {
    throw new functions.https.HttpsError(
      "not-found",
      "연장 대상 캠페인을 찾을 수 없습니다."
    );
  }
  const camp = campSnap.data() ?? {};
  if (camp.ownerUid !== uid) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "본인 캠페인만 연장할 수 있습니다."
    );
  }
  if (camp.lifecycleStatus === "refunded" ||
      camp.lifecycleStatus === "ended") {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "이미 종료된 캠페인은 연장할 수 없습니다.",
      { errorCode: "CAMPAIGN_TERMINATED",
        lifecycleStatus: camp.lifecycleStatus }
    );
  }

  const addDays = Number(order.exposureDays) || 0;
  if (addDays <= 0) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "연장 일수가 잘못됐습니다.",
      { errorCode: "INVALID_EXTEND_DAYS" }
    );
  }

  const now = admin.firestore.Timestamp.now();
  const currentEnd = (camp.adEndAt as FirebaseFirestore.Timestamp) ?? now;
  // 이미 만료된 캠페인이라면 now 부터 연장 카운트
  const baseMs = Math.max(currentEnd.toMillis(), now.toMillis());
  const newEnd = admin.firestore.Timestamp.fromMillis(
    baseMs + addDays * 24 * 60 * 60 * 1000
  );

  await db().runTransaction(async (tx) => {
    const fresh = await tx.get(orderRef);
    const o = fresh.data() ?? {};
    if (o.status === "paid") return; // 멱등

    tx.update(orderRef, {
      status: "paid",
      jobId: camp.jobId,
      campaignId: campaignRef.id,
      paidAt: now,
      providerTxId: paymentKey,
      updatedAt: now,
    });
    tx.update(campaignRef, {
      adEndAt: newEnd,
      lifecycleStatus: camp.lifecycleStatus === "ended" ? "active" :
        camp.lifecycleStatus,
      extensionHistory: admin.firestore.FieldValue.arrayUnion({
        orderId: orderRef.id,
        addedDays: addDays,
        paidAmount: Number(order.amount) || 0,
        priceId: order.priceId ?? null,
        tierKey: order.tierKey ?? null,
        triggeredBy: order.purpose === "auto_renew" ? "auto" : "manual",
        at: now,
      }),
      updatedAt: now,
    });
    if (camp.jobId) {
      tx.update(db().collection("jobs").doc(camp.jobId), {
        adEndAt: newEnd,
        // 만료로 closed 였다면 active 복구
        status: "active",
        updatedAt: now,
      });
    }
    const auditRef = campaignRef.collection("auditLog").doc();
    tx.set(auditRef, {
      type: order.purpose === "auto_renew" ? "auto_renewed" : "extended",
      actor: uid,
      before: { adEndAt: currentEnd },
      after: { adEndAt: newEnd, addedDays: addDays },
      note: order.purpose === "auto_renew" ? "자동연장 결제 확정" : "연장 결제 확정",
      at: now,
    });
  });

  await db().collection("billingEvents").add({
    type: order.purpose === "auto_renew" ? "auto_renewed" : "order_paid_extend",
    ownerUid: uid,
    campaignId: campaignRef.id,
    orderId: orderRef.id,
    jobId: camp.jobId ?? null,
    amount: Number(order.amount) || 0,
    tierKey: order.tierKey ?? null,
    priceId: order.priceId ?? null,
    discountRate: Number(order.discountRate) || 0,
    happenedAt: now,
    meta: { providerTxId: paymentKey, tossMode, addedDays: addDays },
  });

  return {
    jobId: String(camp.jobId ?? ""),
    campaignId: campaignRef.id,
    success: true,
    purpose: order.purpose === "auto_renew" ? "auto_renew" : "extend",
  };
}

// ════════════════════════════════════════════════════════════════
// 등급 변경 결제 (upgrade)
// ════════════════════════════════════════════════════════════════
async function _confirmUpgrade(
  uid: string,
  orderRef: FirebaseFirestore.DocumentReference,
  order: FirebaseFirestore.DocumentData,
  paymentKey: string | null,
  tossMode: string
): Promise<ConfirmPaymentOutput> {
  const campaignId = String(order.parentCampaignId ?? "");
  if (!campaignId) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "변경 대상 캠페인이 지정되지 않았습니다.",
      { errorCode: "MISSING_PARENT_CAMPAIGN" }
    );
  }
  const campaignRef = db().collection("campaigns").doc(campaignId);
  const campSnap = await campaignRef.get();
  if (!campSnap.exists) {
    throw new functions.https.HttpsError(
      "not-found",
      "캠페인을 찾을 수 없습니다."
    );
  }
  const camp = campSnap.data() ?? {};
  if (camp.ownerUid !== uid) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "본인 캠페인만 변경할 수 있습니다."
    );
  }
  if (camp.lifecycleStatus !== "active" &&
      camp.lifecycleStatus !== "paused") {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "진행 중인 캠페인만 등급 변경할 수 있습니다.",
      { errorCode: "CAMPAIGN_NOT_LIVE" }
    );
  }

  const newTierKey = normalizeTierKey(order.tierKey ?? "standard");
  const newCatalog = await getProductCatalog(newTierKey);
  const now = admin.firestore.Timestamp.now();

  await db().runTransaction(async (tx) => {
    const fresh = await tx.get(orderRef);
    const o = fresh.data() ?? {};
    if (o.status === "paid") return;

    tx.update(orderRef, {
      status: "paid",
      jobId: camp.jobId,
      campaignId: campaignRef.id,
      paidAt: now,
      providerTxId: paymentKey,
      updatedAt: now,
    });
    tx.update(campaignRef, {
      tierKey: newTierKey,
      priceId: order.priceId ?? newCatalog.activePriceId,
      amountPaid: admin.firestore.FieldValue.increment(
        Number(order.amount) || 0
      ),
      extensionHistory: admin.firestore.FieldValue.arrayUnion({
        orderId: orderRef.id,
        kind: "upgrade",
        toTier: newTierKey,
        paidAmount: Number(order.amount) || 0,
        priceId: order.priceId ?? null,
        at: now,
      }),
      updatedAt: now,
    });
    if (camp.jobId) {
      tx.update(db().collection("jobs").doc(camp.jobId), {
        productTier: newTierKey,
        productLabel: newCatalog.name,
        tierKey: newTierKey,
        jobLevel: newCatalog.jobLevel,
        priorityScore: newCatalog.matchPriority,
        updatedAt: now,
      });
    }
    const auditRef = campaignRef.collection("auditLog").doc();
    tx.set(auditRef, {
      type: "tier_upgraded",
      actor: uid,
      before: { tierKey: camp.tierKey ?? null },
      after: { tierKey: newTierKey, paidAmount: Number(order.amount) || 0 },
      note: "등급 변경 결제 확정",
      at: now,
    });
  });

  await db().collection("billingEvents").add({
    type: "order_paid_upgrade",
    ownerUid: uid,
    campaignId: campaignRef.id,
    orderId: orderRef.id,
    jobId: camp.jobId ?? null,
    amount: Number(order.amount) || 0,
    tierKey: newTierKey,
    priceId: order.priceId ?? null,
    discountRate: Number(order.discountRate) || 0,
    happenedAt: now,
    meta: { providerTxId: paymentKey, tossMode, fromTier: camp.tierKey },
  });

  return {
    jobId: String(camp.jobId ?? ""),
    campaignId: campaignRef.id,
    success: true,
    purpose: "upgrade",
  };
}
