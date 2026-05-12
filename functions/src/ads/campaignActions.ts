/**
 * ads/campaignActions.ts
 *
 * 캠페인 운영(결제 무관/유관) Callable 모음.
 *
 *   pauseCampaign({ campaignId })             — 진행 중 캠페인 일시정지
 *   resumeCampaign({ campaignId })            — 일시정지 캠페인 재개 (세이브율 만큼 adEndAt 연장)
 *   closeCampaign({ campaignId })             — 캠페인 종료(조기 마감) — 환불 없음
 *   deleteCampaign({ campaignId })            — soft delete(=closed). hard delete 는 운영툴 전용.
 *   setAutoRenew({ campaignId, enabled, consentVersion? })
 *                                              — 자동연장 토글 (동의 스냅샷 보존)
 *   createExtendOrder({ campaignId, addDays })
 *                                              — 연장용 주문 생성 (purpose=extend, parentCampaignId)
 *   createUpgradeOrder({ campaignId, newTierKey })
 *                                              — 등급 변경용 주문 생성 (purpose=upgrade)
 *
 * 환불(cancelAndRefund) 은 별도 파일 `cancelRefund.ts` 에 둔다.
 *
 * 모든 함수는 본인 캠페인만 변경하며, 결제가 필요한 동작은 orders 레코드만 만들고
 * 실제 jobs/campaigns 변경은 confirmPayment 에서 일어난다.
 */

import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";

import {
  TierKey,
  getBillingPolicy,
  getActivePrice,
  getProductCatalog,
  normalizeTierKey,
} from "./catalog";

const db = () => admin.firestore();

const MS_PER_DAY = 24 * 60 * 60 * 1000;

// ════════════════════════════════════════════════════════════════
// Helpers
// ════════════════════════════════════════════════════════════════
function requireAuth(
  context: functions.https.CallableContext
): { uid: string } {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "로그인이 필요합니다."
    );
  }
  return { uid: context.auth.uid };
}

function trimStr(v: unknown): string {
  return String(v ?? "").trim();
}

async function loadCampaignForOwner(
  uid: string,
  campaignId: string
): Promise<{
  ref: FirebaseFirestore.DocumentReference;
  data: FirebaseFirestore.DocumentData;
}> {
  if (!campaignId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "campaignId가 필요합니다."
    );
  }
  const ref = db().collection("campaigns").doc(campaignId);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new functions.https.HttpsError(
      "not-found",
      "캠페인을 찾을 수 없습니다."
    );
  }
  const data = snap.data() ?? {};
  if (data.ownerUid !== uid) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "본인 캠페인만 변경할 수 있습니다."
    );
  }
  return { ref, data };
}

function tsNow(): admin.firestore.Timestamp {
  return admin.firestore.Timestamp.now();
}

function diffDaysCeil(fromMs: number, toMs: number): number {
  if (toMs <= fromMs) return 0;
  return Math.ceil((toMs - fromMs) / MS_PER_DAY);
}

// ════════════════════════════════════════════════════════════════
// pauseCampaign
// ════════════════════════════════════════════════════════════════
export const pauseCampaign = functions
  .region("asia-northeast3")
  .https.onCall(async (data, context) => {
    const { uid } = requireAuth(context);
    const campaignId = trimStr(data?.campaignId);
    const reason = trimStr(data?.reason).slice(0, 200);

    const { ref, data: camp } = await loadCampaignForOwner(uid, campaignId);
    if (camp.lifecycleStatus !== "active") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "진행 중인 캠페인만 일시정지할 수 있습니다.",
        { errorCode: "NOT_ACTIVE", lifecycleStatus: camp.lifecycleStatus }
      );
    }

    const now = tsNow();
    const adEndAt = camp.adEndAt as FirebaseFirestore.Timestamp;
    if (!adEndAt || adEndAt.toMillis() <= now.toMillis()) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "이미 만료된 캠페인은 일시정지할 수 없습니다.",
        { errorCode: "ALREADY_EXPIRED" }
      );
    }

    await db().runTransaction(async (tx) => {
      const fresh = await tx.get(ref);
      const c = fresh.data() ?? {};
      if (c.lifecycleStatus !== "active") return; // 멱등

      tx.update(ref, {
        lifecycleStatus: "paused",
        "pause.currentPausedAt": now,
        updatedAt: now,
      });
      if (c.jobId) {
        tx.update(db().collection("jobs").doc(c.jobId), {
          status: "paused",
          updatedAt: now,
        });
      }
      const auditRef = ref.collection("auditLog").doc();
      tx.set(auditRef, {
        type: "paused",
        actor: uid,
        before: { lifecycleStatus: "active" },
        after: { lifecycleStatus: "paused" },
        note: reason || "사용자 일시정지",
        at: now,
      });
    });

    return { ok: true, lifecycleStatus: "paused" };
  });

// ════════════════════════════════════════════════════════════════
// resumeCampaign — 세이브율(pauseSaveRate) 만큼 adEndAt 연장
// ════════════════════════════════════════════════════════════════
export const resumeCampaign = functions
  .region("asia-northeast3")
  .https.onCall(async (data, context) => {
    const { uid } = requireAuth(context);
    const campaignId = trimStr(data?.campaignId);

    const { ref, data: camp } = await loadCampaignForOwner(uid, campaignId);
    if (camp.lifecycleStatus !== "paused") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "일시정지 상태인 캠페인만 재개할 수 있습니다.",
        { errorCode: "NOT_PAUSED", lifecycleStatus: camp.lifecycleStatus }
      );
    }
    const pausedAt =
      (camp.pause?.currentPausedAt as FirebaseFirestore.Timestamp) ?? null;
    if (!pausedAt) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "일시정지 시작 시각을 확인할 수 없습니다.",
        { errorCode: "MISSING_PAUSE_START" }
      );
    }

    const policy = await getBillingPolicy();
    const saveRate = Math.max(
      0,
      Math.min(1, Number(policy.pauseSaveRate) || 0.5)
    );

    const now = tsNow();
    const daysOnPause = diffDaysCeil(pausedAt.toMillis(), now.toMillis());
    const daysCredited = Math.floor(daysOnPause * saveRate);
    const adEndAt = camp.adEndAt as FirebaseFirestore.Timestamp;
    const baseEndMs = adEndAt?.toMillis() ?? now.toMillis();
    const newEnd = admin.firestore.Timestamp.fromMillis(
      baseEndMs + daysCredited * MS_PER_DAY
    );

    await db().runTransaction(async (tx) => {
      const fresh = await tx.get(ref);
      const c = fresh.data() ?? {};
      if (c.lifecycleStatus !== "paused") return;

      tx.update(ref, {
        lifecycleStatus: "active",
        adEndAt: newEnd,
        "pause.currentPausedAt": null,
        "pause.count": admin.firestore.FieldValue.increment(1),
        "pause.totalDaysOnPause":
          admin.firestore.FieldValue.increment(daysOnPause),
        "pause.totalDaysCredited":
          admin.firestore.FieldValue.increment(daysCredited),
        pauseHistory: admin.firestore.FieldValue.arrayUnion({
          pausedAt,
          resumedAt: now,
          daysOnPause,
          daysCredited,
          saveRateApplied: saveRate,
        }),
        updatedAt: now,
      });
      if (c.jobId) {
        tx.update(db().collection("jobs").doc(c.jobId), {
          status: "active",
          adEndAt: newEnd,
          updatedAt: now,
        });
      }
      const auditRef = ref.collection("auditLog").doc();
      tx.set(auditRef, {
        type: "resumed",
        actor: uid,
        before: { adEndAt },
        after: {
          adEndAt: newEnd,
          daysOnPause,
          daysCredited,
          saveRateApplied: saveRate,
        },
        note: "사용자 재개 — 세이브율 적용",
        at: now,
      });
    });

    await db().collection("billingEvents").add({
      type: "resumed",
      ownerUid: uid,
      campaignId: ref.id,
      jobId: camp.jobId ?? null,
      amount: 0,
      tierKey: camp.tierKey ?? null,
      priceId: camp.priceId ?? null,
      discountRate: 0,
      happenedAt: now,
      meta: { daysOnPause, daysCredited, saveRateApplied: saveRate },
    });

    return {
      ok: true,
      lifecycleStatus: "active",
      adEndAt: newEnd.toMillis(),
      daysOnPause,
      daysCredited,
      saveRateApplied: saveRate,
    };
  });

// ════════════════════════════════════════════════════════════════
// closeCampaign — 조기 마감 (환불 없음)
// ════════════════════════════════════════════════════════════════
export const closeCampaign = functions
  .region("asia-northeast3")
  .https.onCall(async (data, context) => {
    const { uid } = requireAuth(context);
    const campaignId = trimStr(data?.campaignId);
    const reason = trimStr(data?.reason).slice(0, 200);

    const { ref, data: camp } = await loadCampaignForOwner(uid, campaignId);
    if (camp.lifecycleStatus === "ended" ||
        camp.lifecycleStatus === "refunded") {
      return { ok: true, lifecycleStatus: camp.lifecycleStatus };
    }

    const now = tsNow();
    await db().runTransaction(async (tx) => {
      const fresh = await tx.get(ref);
      const c = fresh.data() ?? {};
      if (c.lifecycleStatus === "ended" || c.lifecycleStatus === "refunded") {
        return;
      }
      tx.update(ref, {
        lifecycleStatus: "ended",
        endedAt: now,
        updatedAt: now,
      });
      if (c.jobId) {
        tx.update(db().collection("jobs").doc(c.jobId), {
          status: "closed",
          updatedAt: now,
        });
      }
      const auditRef = ref.collection("auditLog").doc();
      tx.set(auditRef, {
        type: "closed",
        actor: uid,
        before: { lifecycleStatus: c.lifecycleStatus },
        after: { lifecycleStatus: "ended" },
        note: reason || "사용자 조기 마감",
        at: now,
      });
    });

    await db().collection("billingEvents").add({
      type: "closed",
      ownerUid: uid,
      campaignId: ref.id,
      jobId: camp.jobId ?? null,
      amount: 0,
      tierKey: camp.tierKey ?? null,
      priceId: camp.priceId ?? null,
      discountRate: 0,
      happenedAt: now,
      meta: { reason },
    });

    return { ok: true, lifecycleStatus: "ended" };
  });

// ════════════════════════════════════════════════════════════════
// deleteCampaign — soft delete (lifecycleStatus = ended + deletedAt)
//   hard delete 는 보관 정책상 운영 어드민 전용으로만 두며 본 Callable 에선
//   campaign / jobs / orders 등을 실제로 지우지 않는다 (회계·감사 추적성 보장).
// ════════════════════════════════════════════════════════════════
export const deleteCampaign = functions
  .region("asia-northeast3")
  .https.onCall(async (data, context) => {
    const { uid } = requireAuth(context);
    const campaignId = trimStr(data?.campaignId);

    const { ref } = await loadCampaignForOwner(uid, campaignId);
    const now = tsNow();

    await db().runTransaction(async (tx) => {
      const fresh = await tx.get(ref);
      const c = fresh.data() ?? {};
      tx.update(ref, {
        lifecycleStatus: "ended",
        endedAt: c.endedAt ?? now,
        deletedAt: now,
        deletedBy: uid,
        updatedAt: now,
      });
      if (c.jobId) {
        tx.update(db().collection("jobs").doc(c.jobId), {
          status: "deleted",
          deletedAt: now,
          updatedAt: now,
        });
      }
      const auditRef = ref.collection("auditLog").doc();
      tx.set(auditRef, {
        type: "deleted",
        actor: uid,
        before: { lifecycleStatus: c.lifecycleStatus },
        after: { lifecycleStatus: "ended", deletedAt: now },
        note: "사용자 캠페인 삭제(soft)",
        at: now,
      });
    });

    return { ok: true, lifecycleStatus: "ended", deleted: true };
  });

// ════════════════════════════════════════════════════════════════
// setAutoRenew — 자동연장 토글
// ════════════════════════════════════════════════════════════════
export const setAutoRenew = functions
  .region("asia-northeast3")
  .https.onCall(async (data, context) => {
    const { uid } = requireAuth(context);
    const campaignId = trimStr(data?.campaignId);
    const enabled = data?.enabled === true;
    const consentVersion = trimStr(data?.consentVersion) || null;

    const { ref, data: camp } = await loadCampaignForOwner(uid, campaignId);
    if (camp.lifecycleStatus !== "active" &&
        camp.lifecycleStatus !== "paused") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "진행 중 또는 일시정지 캠페인만 자동연장 설정이 가능합니다.",
        { errorCode: "CAMPAIGN_NOT_LIVE" }
      );
    }
    if (enabled && !consentVersion) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "자동연장 활성화에는 동의 버전 정보가 필요합니다.",
        { errorCode: "MISSING_CONSENT_VERSION" }
      );
    }

    const policy = await getBillingPolicy();
    const leadDays = Math.max(0, Number(policy.autoRenewLeadDays) || 1);
    const adEndAt = camp.adEndAt as FirebaseFirestore.Timestamp;
    const nextChargeAt = enabled && adEndAt ?
      admin.firestore.Timestamp.fromMillis(
        adEndAt.toMillis() - leadDays * MS_PER_DAY
      ) :
      null;

    // 빌링키 등록 여부 확인 (운영 단계 — 클라이언트가 카드 등록 안내에 사용)
    let hasBillingKey = false;
    try {
      const billingDoc = await admin.firestore()
        .collection("billingKeys")
        .doc(uid)
        .get();
      const bd = billingDoc.exists ? (billingDoc.data() ?? {}) : {};
      hasBillingKey = String(bd.status ?? "") === "active" &&
        typeof bd.tossBillingKey === "string" &&
        (bd.tossBillingKey as string).length > 0;
    } catch (e) {
      functions.logger.warn("setAutoRenew: billingKeys read failed", {
        err: String(e),
      });
    }

    const now = tsNow();
    await ref.update({
      "autoRenew.enabled": enabled,
      "autoRenew.consentVersion": enabled ? consentVersion : null,
      "autoRenew.enabledAt": enabled ? now : null,
      "autoRenew.nextChargeAt": nextChargeAt,
      "autoRenew.lastChargeStatus": enabled ?
        (camp.autoRenew?.lastChargeStatus ?? "none") :
        "disabled",
      "autoRenew.failedReason": null,
      updatedAt: now,
    });

    await ref.collection("auditLog").add({
      type: enabled ? "auto_renew_enabled" : "auto_renew_disabled",
      actor: uid,
      before: { enabled: camp.autoRenew?.enabled === true },
      after: { enabled, consentVersion, nextChargeAt, hasBillingKey },
      note: enabled ?
        (hasBillingKey ? "자동연장 활성화" : "자동연장 활성화 (카드 등록 필요)") :
        "자동연장 비활성화",
      at: now,
    });

    return {
      ok: true,
      enabled,
      consentVersion: enabled ? consentVersion : null,
      nextChargeAt: nextChargeAt?.toMillis() ?? null,
      autoRenewLeadDays: leadDays,
      hasBillingKey,
    };
  });

// ════════════════════════════════════════════════════════════════
// createExtendOrder — 연장용 주문 생성 (결제는 클라가 Toss 호출 → confirmPayment)
// ════════════════════════════════════════════════════════════════
export const createExtendOrder = functions
  .region("asia-northeast3")
  .https.onCall(async (data, context) => {
    const { uid } = requireAuth(context);
    const campaignId = trimStr(data?.campaignId);
    const addDays = Number(data?.addDays);

    if (!Number.isFinite(addDays) || addDays <= 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "연장 일수가 잘못됐습니다. (addDays > 0)",
        { errorCode: "INVALID_ADD_DAYS" }
      );
    }
    const { ref, data: camp } = await loadCampaignForOwner(uid, campaignId);
    if (camp.lifecycleStatus === "refunded") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "환불된 캠페인은 연장할 수 없습니다.",
        { errorCode: "CAMPAIGN_REFUNDED" }
      );
    }

    const tierKey: TierKey = normalizeTierKey(camp.tierKey ?? "standard");
    const catalog = await getProductCatalog(tierKey);
    const price = await getActivePrice(catalog);
    const policy = await getBillingPolicy();

    // 연장 단가 = 기본가 × (addDays / catalog.exposureDays)
    const baseDays = Math.max(1, catalog.exposureDays);
    const unitAmount = Math.round(
      (Number(price.amount) || 0) * (addDays / baseDays)
    );

    const now = tsNow();
    const orderRef = db().collection("orders").doc();
    await orderRef.set({
      ownerUid: uid,
      draftId: null,
      clinicProfileId: camp.clinicProfileId ?? null,
      tierKey,
      priceId: price.priceId,
      purpose: "extend",
      parentCampaignId: ref.id,
      voucherId: null,
      voucherEligible: false,
      amount: unitAmount,
      currency: price.currency || "KRW",
      exposureDays: addDays,
      paymentProvider: "toss",
      status: unitAmount > 0 ? "pending" : "paid",
      jobId: camp.jobId ?? null,
      campaignId: null,
      consentSnapshot: null,
      policySnapshot: {
        pauseSaveRate: policy.pauseSaveRate,
        autoRenewLeadDays: policy.autoRenewLeadDays,
        refundWindowDays: policy.refundWindowDays,
      },
      createdAt: now,
      updatedAt: now,
    });

    return {
      orderId: orderRef.id,
      amount: unitAmount,
      currency: price.currency || "KRW",
      tierKey,
      priceId: price.priceId,
      requiresPayment: unitAmount > 0,
      addDays,
    };
  });

// ════════════════════════════════════════════════════════════════
// createUpgradeOrder — 등급 변경용 주문 생성
//   업그레이드 차액 = (newPrice − currentPrice) × (남은일수 / catalog.exposureDays)
//   기준은 신규 등급의 catalog.exposureDays.
//   다운그레이드는 차액 환불이 필요해 별도 정책 — 본 Callable 은 'newTier 가
//   현재보다 같거나 높은 등급' 일 때만 허용한다.
// ════════════════════════════════════════════════════════════════
const TIER_RANK: Record<TierKey, number> = {
  basic: 1,
  standard: 2,
  premium: 3,
};

export const createUpgradeOrder = functions
  .region("asia-northeast3")
  .https.onCall(async (data, context) => {
    const { uid } = requireAuth(context);
    const campaignId = trimStr(data?.campaignId);
    const newTierKey: TierKey = normalizeTierKey(data?.newTierKey ?? "");

    const { ref, data: camp } = await loadCampaignForOwner(uid, campaignId);
    if (camp.lifecycleStatus !== "active" &&
        camp.lifecycleStatus !== "paused") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "진행 중인 캠페인만 등급 변경할 수 있습니다.",
        { errorCode: "CAMPAIGN_NOT_LIVE" }
      );
    }

    const currentTier: TierKey = normalizeTierKey(
      camp.tierKey ?? "standard"
    );
    if (currentTier === newTierKey) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "이미 같은 등급입니다.",
        { errorCode: "SAME_TIER" }
      );
    }
    if (TIER_RANK[newTierKey] < TIER_RANK[currentTier]) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "다운그레이드는 별도 환불 정책으로 진행해 주세요.",
        { errorCode: "DOWNGRADE_NOT_SUPPORTED" }
      );
    }

    const newCatalog = await getProductCatalog(newTierKey);
    const currentCatalog = await getProductCatalog(currentTier);
    const newPrice = await getActivePrice(newCatalog);
    const currentPrice = await getActivePrice(currentCatalog);
    const policy = await getBillingPolicy();

    const adEndAt = camp.adEndAt as FirebaseFirestore.Timestamp | undefined;
    const now = tsNow();
    const remainingMs = adEndAt ?
      Math.max(0, adEndAt.toMillis() - now.toMillis()) :
      0;
    const remainingDays = Math.ceil(remainingMs / MS_PER_DAY);
    const baseDays = Math.max(1, newCatalog.exposureDays);
    const ratio = Math.min(1, remainingDays / baseDays);

    const diff = Math.max(
      0,
      Math.round(
        (Number(newPrice.amount) - Number(currentPrice.amount)) * ratio
      )
    );

    const orderRef = db().collection("orders").doc();
    await orderRef.set({
      ownerUid: uid,
      draftId: null,
      clinicProfileId: camp.clinicProfileId ?? null,
      tierKey: newTierKey,
      priceId: newPrice.priceId,
      purpose: "upgrade",
      parentCampaignId: ref.id,
      voucherId: null,
      voucherEligible: false,
      amount: diff,
      currency: newPrice.currency || "KRW",
      exposureDays: 0,
      paymentProvider: "toss",
      status: diff > 0 ? "pending" : "paid",
      jobId: camp.jobId ?? null,
      campaignId: null,
      consentSnapshot: null,
      policySnapshot: {
        pauseSaveRate: policy.pauseSaveRate,
        autoRenewLeadDays: policy.autoRenewLeadDays,
        refundWindowDays: policy.refundWindowDays,
        fromTier: currentTier,
        proratedRatio: ratio,
        remainingDays,
      },
      createdAt: now,
      updatedAt: now,
    });

    return {
      orderId: orderRef.id,
      amount: diff,
      currency: newPrice.currency || "KRW",
      fromTier: currentTier,
      toTier: newTierKey,
      priceId: newPrice.priceId,
      requiresPayment: diff > 0,
      proratedRatio: ratio,
      remainingDays,
    };
  });
