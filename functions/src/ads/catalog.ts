/**
 * ads/catalog.ts
 *
 * 광고 상품 카탈로그(`productCatalog/{tierKey}`) + 결제 정책(`appConfig/billingPolicy`)
 * 조회·검증 헬퍼.
 *
 * 모든 가격·기간·정책 상수는 Firestore 단일 출처에서 읽고, 미존재 시 안전한 폴백을
 * 사용한다. 이로써 가격이 바뀌어도 함수 재배포 없이 카탈로그만 갱신하면 된다.
 *
 * 설계서 §1, §2-1, §2-2 참고.
 */

import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";

const db = admin.firestore;

/** 등급 키 정규화 (premium|standard|basic). 레거시 a/b/c 도 흡수. */
export function normalizeTierKey(raw: unknown): TierKey {
  const t = String(raw ?? "").trim().toLowerCase();
  switch (t) {
  case "premium":
  case "a":
  case "a_class":
  case "tier_a":
    return "premium";
  case "standard":
  case "b":
  case "b_class":
  case "tier_b":
    return "standard";
  case "basic":
  case "c":
  case "c_class":
  case "tier_c":
    return "basic";
  default:
    // 미지정/알 수 없음 → 안전하게 standard 폴백 (현재 publishTestJobWithoutPayment 와 동일)
    return "standard";
  }
}

export type TierKey = "premium" | "standard" | "basic";

export interface ProductCatalogEntry {
  tierKey: TierKey;
  name: string;
  jobLevel: 1 | 2 | 3;
  exposureDays: number;
  pushAudience: "national" | "region" | "none";
  matchPriority: number;
  autoRenewDiscountRate: number;
  activePriceId: string;
  isActive: boolean;
  raw: FirebaseFirestore.DocumentData; // 모든 원본 필드 (UI 라벨 등)
}

export interface ProductPriceEntry {
  priceId: string;
  amount: number;
  currency: string;
  effectiveFrom: FirebaseFirestore.Timestamp;
  effectiveTo: FirebaseFirestore.Timestamp | null;
}

export interface BillingPolicy {
  pauseSaveRate: number;
  pauseMinDaysToAllow: number;
  pauseMaxCountPerCampaign: number;
  autoRenewDefault: boolean;
  autoRenewLeadDays: number;
  voucherEligibleTiers: TierKey[];
  refundWindowDays: number;
  upgradeAllowed: boolean;
  downgradeAllowed: boolean;
  extensionMinDays: number;
  extensionMaxDays: number;
  policyVersion: string;
}

/** 카탈로그 미존재/오류 시 사용하는 폴백 — 현재 하드코딩된 값과 1:1 동일하게 유지. */
const FALLBACK_PRICE_BY_TIER: Record<TierKey, number> = {
  premium: 880000,
  standard: 440000,
  basic: 110000,
};
const FALLBACK_DAYS_BY_TIER: Record<TierKey, number> = {
  premium: 60,
  standard: 30,
  basic: 14,
};
const FALLBACK_POLICY: BillingPolicy = {
  pauseSaveRate: 0.5,
  pauseMinDaysToAllow: 1,
  pauseMaxCountPerCampaign: 3,
  autoRenewDefault: false,
  autoRenewLeadDays: 1,
  voucherEligibleTiers: ["basic"],
  refundWindowDays: 7,
  upgradeAllowed: true,
  downgradeAllowed: false,
  extensionMinDays: 7,
  extensionMaxDays: 90,
  policyVersion: "fallback",
};

/** `productCatalog/{tierKey}` 조회. 미존재 시 폴백 entry 반환. */
export async function getProductCatalog(
  tierKey: TierKey
): Promise<ProductCatalogEntry> {
  const ref = db().collection("productCatalog").doc(tierKey);
  const snap = await ref.get();
  if (!snap.exists) {
    functions.logger.warn("productCatalog missing → fallback", { tierKey });
    return fallbackCatalog(tierKey);
  }
  const data = snap.data() ?? {};
  return {
    tierKey,
    name: String(data.name ?? defaultName(tierKey)),
    jobLevel: (Number(data.jobLevel) || defaultJobLevel(tierKey)) as 1 | 2 | 3,
    exposureDays: Number(data.exposureDays) || FALLBACK_DAYS_BY_TIER[tierKey],
    pushAudience: (data.pushAudience ??
      defaultPushAudience(tierKey)) as ProductCatalogEntry["pushAudience"],
    matchPriority: Number(data.matchPriority) || defaultMatchPriority(tierKey),
    autoRenewDiscountRate: Number(data.autoRenewDiscountRate) || 0.0,
    activePriceId:
      String(data.activePriceId || `price_${tierKey}_fallback`),
    isActive: data.isActive !== false,
    raw: data,
  };
}

/** 활성 가격(`productCatalog/{tier}/prices/{activePriceId}`) 조회. 미존재 시 폴백. */
export async function getActivePrice(
  catalog: ProductCatalogEntry
): Promise<ProductPriceEntry> {
  const ref = db()
    .collection("productCatalog")
    .doc(catalog.tierKey)
    .collection("prices")
    .doc(catalog.activePriceId);
  const snap = await ref.get();
  if (!snap.exists) {
    functions.logger.warn("activePrice missing → fallback", {
      tierKey: catalog.tierKey,
      activePriceId: catalog.activePriceId,
    });
    return {
      priceId: `price_${catalog.tierKey}_fallback`,
      amount: FALLBACK_PRICE_BY_TIER[catalog.tierKey],
      currency: "KRW",
      effectiveFrom: admin.firestore.Timestamp.now(),
      effectiveTo: null,
    };
  }
  const data = snap.data() ?? {};
  return {
    priceId: catalog.activePriceId,
    amount: Number(data.amount) || FALLBACK_PRICE_BY_TIER[catalog.tierKey],
    currency: String(data.currency ?? "KRW"),
    effectiveFrom:
      (data.effectiveFrom as FirebaseFirestore.Timestamp) ??
      admin.firestore.Timestamp.now(),
    effectiveTo: (data.effectiveTo as FirebaseFirestore.Timestamp) ?? null,
  };
}

/** `appConfig/billingPolicy` 조회. 미존재 시 폴백. */
export async function getBillingPolicy(): Promise<BillingPolicy> {
  const ref = db().collection("appConfig").doc("billingPolicy");
  const snap = await ref.get();
  if (!snap.exists) {
    functions.logger.warn("billingPolicy missing → fallback");
    return { ...FALLBACK_POLICY };
  }
  const data = snap.data() ?? {};
  const tiers = Array.isArray(data.voucherEligibleTiers)
    ? (data.voucherEligibleTiers
      .map((t: unknown) => normalizeTierKey(t))
      .filter((t: TierKey, idx: number, arr: TierKey[]) =>
        arr.indexOf(t) === idx) as TierKey[])
    : FALLBACK_POLICY.voucherEligibleTiers;
  return {
    pauseSaveRate: clamp01(data.pauseSaveRate, FALLBACK_POLICY.pauseSaveRate),
    pauseMinDaysToAllow: nonNegInt(
      data.pauseMinDaysToAllow,
      FALLBACK_POLICY.pauseMinDaysToAllow
    ),
    pauseMaxCountPerCampaign: nonNegInt(
      data.pauseMaxCountPerCampaign,
      FALLBACK_POLICY.pauseMaxCountPerCampaign
    ),
    autoRenewDefault: data.autoRenewDefault === true,
    autoRenewLeadDays: nonNegInt(
      data.autoRenewLeadDays,
      FALLBACK_POLICY.autoRenewLeadDays
    ),
    voucherEligibleTiers: tiers,
    refundWindowDays: nonNegInt(
      data.refundWindowDays,
      FALLBACK_POLICY.refundWindowDays
    ),
    upgradeAllowed: data.upgradeAllowed !== false,
    downgradeAllowed: data.downgradeAllowed === true,
    extensionMinDays: nonNegInt(
      data.extensionMinDays,
      FALLBACK_POLICY.extensionMinDays
    ),
    extensionMaxDays: nonNegInt(
      data.extensionMaxDays,
      FALLBACK_POLICY.extensionMaxDays
    ),
    policyVersion: String(data.policyVersion ?? FALLBACK_POLICY.policyVersion),
  };
}

/**
 * 공고권 사용 가능 여부 검증.
 *
 * 우선순위:
 *   1) voucher.eligibleTiers 가 명시되어 있으면 그것을 따른다 (발급 시점 정책 보존).
 *   2) 없으면 정책(`billingPolicy.voucherEligibleTiers`)을 따른다.
 */
export function isVoucherEligibleForTier(
  voucher: FirebaseFirestore.DocumentData | null | undefined,
  policy: BillingPolicy,
  tierKey: TierKey
): boolean {
  if (!voucher) return false;
  const explicit = Array.isArray(voucher.eligibleTiers) ?
    (voucher.eligibleTiers
      .map((t: unknown) => normalizeTierKey(t))
      .filter((t: TierKey, idx: number, arr: TierKey[]) =>
        arr.indexOf(t) === idx) as TierKey[]) :
    [];
  const allowed = explicit.length > 0 ? explicit : policy.voucherEligibleTiers;
  return allowed.includes(tierKey);
}

// ── 폴백 헬퍼 ────────────────────────────────────────────────
function fallbackCatalog(tierKey: TierKey): ProductCatalogEntry {
  return {
    tierKey,
    name: defaultName(tierKey),
    jobLevel: defaultJobLevel(tierKey),
    exposureDays: FALLBACK_DAYS_BY_TIER[tierKey],
    pushAudience: defaultPushAudience(tierKey),
    matchPriority: defaultMatchPriority(tierKey),
    autoRenewDiscountRate: 0.10,
    activePriceId: `price_${tierKey}_fallback`,
    isActive: true,
    raw: {},
  };
}
function defaultName(tierKey: TierKey): string {
  return tierKey === "premium" ?
    "A 프리미엄" :
    tierKey === "standard" ?
      "B 추천" :
      "C 일반";
}
function defaultJobLevel(tierKey: TierKey): 1 | 2 | 3 {
  return tierKey === "premium" ? 1 : tierKey === "standard" ? 2 : 3;
}
function defaultPushAudience(
  tierKey: TierKey
): ProductCatalogEntry["pushAudience"] {
  return tierKey === "premium" ?
    "national" :
    tierKey === "standard" ?
      "region" :
      "none";
}
function defaultMatchPriority(tierKey: TierKey): number {
  return tierKey === "premium" ? 100 : tierKey === "standard" ? 50 : 0;
}
function clamp01(raw: unknown, fallback: number): number {
  const n = typeof raw === "number" ? raw : Number(raw);
  if (!Number.isFinite(n)) return fallback;
  if (n < 0) return 0;
  if (n > 1) return 1;
  return n;
}
function nonNegInt(raw: unknown, fallback: number): number {
  const n = typeof raw === "number" ? raw : Number(raw);
  if (!Number.isFinite(n) || n < 0) return fallback;
  return Math.floor(n);
}
