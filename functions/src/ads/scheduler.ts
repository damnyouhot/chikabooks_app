/**
 * ads/scheduler.ts
 *
 * 광고 캠페인 라이프사이클 자동화 스케줄러 (M5).
 *
 *   expireCampaigns      매일 KST 00:10 — adEndAt 지난 active/paused 캠페인 자동 종료
 *   adEndingReminder     매일 KST 09:00 — D-7 / D-3 / D-1 만료 임박 알림 적재
 *   runAutoRenewals      매일 KST 09:30 — 자동연장 ON & nextChargeAt <= now 캠페인 결제 시도
 *
 * 알림 적재 위치: users/{ownerUid}/clinicInbox/{noticeId}
 *   - 보안 룰: 본인 읽기 / 서버만 쓰기 (firestore.rules 에 추가).
 *   - 클라이언트(웹/앱)는 본 인박스만 구독해서 만료/연장/실패 알림을 표시.
 *
 * 빌링키 결제는 `billing/tossBillingAdapter.ts` 의 `chargeWithBillingKey` 가 담당.
 * 빌링키 미등록 캠페인은 알림으로 폴백한다 (수동 결제 유도).
 */

import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";

import {
  TierKey,
  getActivePrice,
  getProductCatalog,
  normalizeTierKey,
} from "./catalog";
import { chargeWithBillingKey } from "../billing/tossBillingAdapter";

const db = () => admin.firestore();
const MS_PER_DAY = 24 * 60 * 60 * 1000;

// 한 회 실행에서 처리하는 최대 캠페인 수 — Firestore 트랜잭션 한도/메모리 보호
const BATCH_LIMIT_EXPIRE = 200;
const BATCH_LIMIT_REMIND = 500;
const BATCH_LIMIT_RENEW = 200;

const REMINDER_DAYS = [7, 3, 1];

function tsNow(): admin.firestore.Timestamp {
  return admin.firestore.Timestamp.now();
}

function dateOnlyKey(ts: admin.firestore.Timestamp): string {
  // KST 기준이 아닌 UTC 기준 yyyy-mm-dd — 멱등키 용도로만 사용 (스케줄이 KST 1회/일).
  const d = ts.toDate();
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = String(d.getUTCDate()).padStart(2, "0");
  return `${y}${m}${day}`;
}

async function appendInboxNotice(
  ownerUid: string,
  payload: {
    type: string;
    title: string;
    body: string;
    severity?: "info" | "warning" | "error" | "success";
    campaignId?: string;
    jobId?: string;
    orderId?: string;
    deepLink?: string;
    /** 같은 캠페인 + 같은 dedupeKey 로 적재된 알림이 이미 있으면 스킵 (멱등성) */
    dedupeKey?: string;
    meta?: Record<string, unknown>;
  }
): Promise<void> {
  const inboxCol = db()
    .collection("users")
    .doc(ownerUid)
    .collection("clinicInbox");

  if (payload.dedupeKey) {
    // dedupeKey 중복 검사 — 1회만, indexless equality 가능 (서브컬렉션 작은 사이즈 가정)
    const dup = await inboxCol
      .where("dedupeKey", "==", payload.dedupeKey)
      .limit(1)
      .get();
    if (!dup.empty) return;
  }

  await inboxCol.add({
    type: payload.type,
    title: payload.title,
    body: payload.body,
    severity: payload.severity ?? "info",
    campaignId: payload.campaignId ?? null,
    jobId: payload.jobId ?? null,
    orderId: payload.orderId ?? null,
    deepLink: payload.deepLink ?? null,
    dedupeKey: payload.dedupeKey ?? null,
    read: false,
    createdAt: tsNow(),
    meta: payload.meta ?? {},
  });
}

// ════════════════════════════════════════════════════════════════
// expireCampaigns — adEndAt 지난 캠페인 자동 종료
// ════════════════════════════════════════════════════════════════
export const expireCampaigns = functions
  .region("asia-northeast3")
  .pubsub.schedule("10 0 * * *") // 매일 KST 00:10
  .timeZone("Asia/Seoul")
  .onRun(async () => {
    const now = tsNow();
    const snap = await db()
      .collection("campaigns")
      .where("lifecycleStatus", "in", ["active", "paused"])
      .where("adEndAt", "<=", now)
      .limit(BATCH_LIMIT_EXPIRE)
      .get();

    if (snap.empty) {
      functions.logger.info("expireCampaigns: 만료할 캠페인 없음");
      return null;
    }

    let success = 0;
    let failed = 0;
    for (const docSnap of snap.docs) {
      const camp = docSnap.data();
      const ref = docSnap.ref;
      try {
        await db().runTransaction(async (tx) => {
          const fresh = await tx.get(ref);
          const c = fresh.data() ?? {};
          if (c.lifecycleStatus !== "active" &&
              c.lifecycleStatus !== "paused") {
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
              closedReason: "expired",
              updatedAt: now,
            });
          }
          const auditRef = ref.collection("auditLog").doc();
          tx.set(auditRef, {
            type: "expired",
            actor: "system",
            before: { lifecycleStatus: c.lifecycleStatus },
            after: { lifecycleStatus: "ended" },
            note: "노출기간 만료 — 자동 종료",
            at: now,
          });
        });

        await db().collection("billingEvents").add({
          type: "expired",
          ownerUid: camp.ownerUid,
          campaignId: ref.id,
          jobId: camp.jobId ?? null,
          amount: 0,
          tierKey: camp.tierKey ?? null,
          priceId: camp.priceId ?? null,
          discountRate: 0,
          happenedAt: now,
          meta: { reason: "scheduled_expire" },
        });

        await appendInboxNotice(camp.ownerUid, {
          type: "campaign_expired",
          title: "공고가 만료되었습니다",
          body:
            "광고 노출 기간이 종료되어 공고가 자동으로 마감되었습니다. " +
            "필요하시면 새 공고를 등록하거나 기존 공고를 다시 게시하세요.",
          severity: "warning",
          campaignId: ref.id,
          jobId: camp.jobId ?? undefined,
          dedupeKey: `expired:${ref.id}`,
        });

        success += 1;
      } catch (e) {
        failed += 1;
        functions.logger.error("expireCampaigns failed", {
          campaignId: ref.id,
          error: String(e),
        });
      }
    }

    functions.logger.info("expireCampaigns done", {
      total: snap.size,
      success,
      failed,
    });
    return null;
  });

// ════════════════════════════════════════════════════════════════
// adEndingReminder — D-7 / D-3 / D-1 만료 임박 알림
// ════════════════════════════════════════════════════════════════
export const adEndingReminder = functions
  .region("asia-northeast3")
  .pubsub.schedule("0 9 * * *") // 매일 KST 09:00
  .timeZone("Asia/Seoul")
  .onRun(async () => {
    const now = tsNow();

    let totalAppended = 0;
    for (const days of REMINDER_DAYS) {
      // window: now + days ~ now + days + 1day (24h 폭)
      const lower = admin.firestore.Timestamp.fromMillis(
        now.toMillis() + days * MS_PER_DAY
      );
      const upper = admin.firestore.Timestamp.fromMillis(
        now.toMillis() + (days + 1) * MS_PER_DAY
      );

      const snap = await db()
        .collection("campaigns")
        .where("lifecycleStatus", "==", "active")
        .where("adEndAt", ">=", lower)
        .where("adEndAt", "<", upper)
        .limit(BATCH_LIMIT_REMIND)
        .get();

      for (const docSnap of snap.docs) {
        const camp = docSnap.data();
        const ownerUid = String(camp.ownerUid ?? "");
        if (!ownerUid) continue;

        const dedupeKey =
          `reminder:d-${days}:${docSnap.id}:${dateOnlyKey(now)}`;

        try {
          await appendInboxNotice(ownerUid, {
            type: "campaign_ending_soon",
            title:
              days >= 7 ? "공고가 곧 만료됩니다 (7일 전)" :
                days >= 3 ? "공고 만료 3일 전입니다" :
                  "공고가 내일 만료됩니다",
            body:
              `현재 공고가 ${days}일 후 자동 마감됩니다. ` +
              (camp.autoRenew?.enabled === true ?
                "자동연장이 켜져 있어 만료 직전에 자동으로 결제됩니다." :
                "연장 또는 자동연장 설정을 확인해 보세요."),
            severity: days <= 1 ? "warning" : "info",
            campaignId: docSnap.id,
            jobId: camp.jobId ?? undefined,
            dedupeKey,
            meta: {
              daysUntilExpire: days,
              autoRenewEnabled: camp.autoRenew?.enabled === true,
            },
          });
          totalAppended += 1;
        } catch (e) {
          functions.logger.error("adEndingReminder append failed", {
            campaignId: docSnap.id,
            days,
            error: String(e),
          });
        }
      }
    }

    functions.logger.info("adEndingReminder done", { totalAppended });
    return null;
  });

// ════════════════════════════════════════════════════════════════
// runAutoRenewals — 자동연장 결제 시도
//
// 대상: lifecycleStatus = active|paused & autoRenew.enabled=true &
//      autoRenew.nextChargeAt <= now & autoRenew.lastChargeStatus != 'in_progress'
//
// 흐름:
//   1) 등급/가격 조회 → 연장 1주기 분 amount 산출 (catalog.exposureDays × 가격)
//      자동연장 할인율(catalog.autoRenewDiscountRate) 적용.
//   2) orders 생성 (purpose='auto_renew', parentCampaignId).
//   3) 빌링키 결제 시도.
//      - 미등록 → orders.status='pending' 그대로 두고 inbox 폴백 + nextChargeAt = adEndAt-leadDays.
//      - 결제 실패 → orders.status='failed' + lastChargeStatus='failed' + inbox 알림.
//      - 결제 성공 → confirmPayment 와 동일한 후처리 (jobs.adEndAt 연장, billingEvents 등)
//        를 위해 본 함수가 직접 트랜잭션으로 처리 (confirmPayment 재호출 안 함).
// ════════════════════════════════════════════════════════════════
export const runAutoRenewals = functions
  .region("asia-northeast3")
  .pubsub.schedule("30 9 * * *") // 매일 KST 09:30
  .timeZone("Asia/Seoul")
  .onRun(async () => {
    const now = tsNow();

    const snap = await db()
      .collection("campaigns")
      .where("autoRenew.enabled", "==", true)
      .where("autoRenew.nextChargeAt", "<=", now)
      .limit(BATCH_LIMIT_RENEW)
      .get();

    if (snap.empty) {
      functions.logger.info("runAutoRenewals: 대상 없음");
      return null;
    }

    let attempted = 0;
    let charged = 0;
    let fallback = 0;
    let failed = 0;

    for (const docSnap of snap.docs) {
      const camp = docSnap.data();
      const ref = docSnap.ref;
      const ownerUid = String(camp.ownerUid ?? "");
      if (!ownerUid) continue;

      // 종료된 캠페인은 스킵
      if (camp.lifecycleStatus !== "active" &&
          camp.lifecycleStatus !== "paused") {
        await ref.update({
          "autoRenew.enabled": false,
          "autoRenew.lastChargeStatus": "skipped_terminated",
          "autoRenew.nextChargeAt": null,
          updatedAt: now,
        });
        continue;
      }
      // 동시 실행 가드
      if (camp.autoRenew?.lastChargeStatus === "in_progress") continue;

      attempted += 1;
      try {
        await ref.update({
          "autoRenew.lastChargeStatus": "in_progress",
          updatedAt: now,
        });

        const tierKey: TierKey = normalizeTierKey(
          camp.tierKey ?? "standard"
        );
        const catalog = await getProductCatalog(tierKey);
        const price = await getActivePrice(catalog);
        const discountRate = Math.max(
          0,
          Math.min(0.9, Number(catalog.autoRenewDiscountRate) || 0)
        );
        const amount = Math.round(
          (Number(price.amount) || 0) * (1 - discountRate)
        );
        const exposureDays = Math.max(1, catalog.exposureDays);

        // orders/{orderId} 생성 (멱등키 = campaignId+nextChargeAt date)
        const orderId =
          `auto_${ref.id}_${dateOnlyKey(now)}`.slice(0, 80);
        const orderRef = db().collection("orders").doc(orderId);
        const existing = await orderRef.get();
        if (existing.exists && existing.data()?.status === "paid") {
          // 이미 처리됨 — 스킵
          await ref.update({
            "autoRenew.lastChargeStatus": "charged",
            updatedAt: now,
          });
          continue;
        }
        if (!existing.exists) {
          await orderRef.set({
            ownerUid,
            draftId: null,
            clinicProfileId: camp.clinicProfileId ?? null,
            tierKey,
            priceId: price.priceId,
            purpose: "auto_renew",
            parentCampaignId: ref.id,
            voucherId: null,
            voucherEligible: false,
            amount,
            currency: price.currency || "KRW",
            exposureDays,
            paymentProvider: "toss",
            status: "pending",
            jobId: camp.jobId ?? null,
            campaignId: null,
            consentSnapshot: { autoRenew: true,
              consentVersion: camp.autoRenew?.consentVersion ?? null },
            policySnapshot: camp.policySnapshot ?? {},
            discountRate,
            createdAt: now,
            updatedAt: now,
          });
        }

        // billingKey 조회 (신규 위치: billingKeys/{uid}, 서버 전용)
        // status='active' 인 경우만 결제 시도 — deleted 면 no_billing_key 폴백.
        const billingDoc = await db()
          .collection("billingKeys")
          .doc(ownerUid)
          .get();
        const billingData = billingDoc.exists ? (billingDoc.data() ?? {}) : {};
        const billingActive = String(billingData.status ?? "") === "active";
        const billingKey = billingActive ?
          String(billingData.tossBillingKey ?? "") :
          "";
        const customerKey = String(
          billingData.tossCustomerKey ?? ownerUid
        );
        const customerEmail = String(billingData.customerEmail ?? "");

        const result = await chargeWithBillingKey({
          billingKey,
          customerKey,
          orderId,
          orderName: `[자동연장] ${catalog.name} ${exposureDays}일`,
          amount,
          customerEmail: customerEmail || undefined,
        });

        if (result.mode === "no_billing_key") {
          fallback += 1;
          // 다음 결제일을 한 번 더 조정 (재시도 지연) — adEndAt 까지 무한루프 방지
          const adEndAt =
            camp.adEndAt as FirebaseFirestore.Timestamp | undefined;
          const nextRetry = adEndAt && adEndAt.toMillis() > now.toMillis() ?
            admin.firestore.Timestamp.fromMillis(
              Math.max(now.toMillis() + 1 * MS_PER_DAY, adEndAt.toMillis() - 1 * MS_PER_DAY)
            ) :
            null;
          await ref.update({
            "autoRenew.lastChargeStatus": "no_billing_key",
            "autoRenew.failedReason": "빌링키 미등록",
            "autoRenew.nextChargeAt": nextRetry,
            updatedAt: now,
          });
          await appendInboxNotice(ownerUid, {
            type: "auto_renew_billing_required",
            title: "자동연장을 위해 카드 등록이 필요합니다",
            body:
              "자동연장이 켜져 있지만 결제 카드가 등록되지 않아 청구하지 못했습니다. " +
              "카드 등록 후 다시 시도하거나, 수동 연장 결제로 진행해 주세요.",
            severity: "warning",
            campaignId: ref.id,
            jobId: camp.jobId ?? undefined,
            orderId,
            dedupeKey: `autorenew_no_key:${ref.id}:${dateOnlyKey(now)}`,
          });
          continue;
        }

        if (result.mode === "mock") {
          // mock: 운영전 폴백. 실제 청구가 안 됐으므로 결제 성공 처리하지 않고 알림만.
          fallback += 1;
          await ref.update({
            "autoRenew.lastChargeStatus": "mock",
            updatedAt: now,
          });
          functions.logger.warn(
            "runAutoRenewals: TOSS_SECRET_KEY 미설정으로 mock 모드 — 실청구 미실행",
            { campaignId: ref.id }
          );
          continue;
        }

        // 결제 성공 → confirmPayment(extend) 와 동일 후처리
        const adEndAt =
          camp.adEndAt as FirebaseFirestore.Timestamp | undefined;
        const baseEndMs = Math.max(
          adEndAt?.toMillis() ?? now.toMillis(),
          now.toMillis()
        );
        const newEnd = admin.firestore.Timestamp.fromMillis(
          baseEndMs + exposureDays * MS_PER_DAY
        );
        const policy = camp.policySnapshot ?? {};
        const leadDays = Math.max(
          0,
          Number((policy as Record<string, unknown>).autoRenewLeadDays) || 1
        );
        const nextChargeAt = admin.firestore.Timestamp.fromMillis(
          newEnd.toMillis() - leadDays * MS_PER_DAY
        );

        await db().runTransaction(async (tx) => {
          tx.update(orderRef, {
            status: "paid",
            jobId: camp.jobId ?? null,
            campaignId: ref.id,
            paidAt: now,
            providerTxId: result.paymentKey ?? null,
            updatedAt: now,
          });
          tx.update(ref, {
            adEndAt: newEnd,
            "autoRenew.lastChargeStatus": "charged",
            "autoRenew.failedReason": null,
            "autoRenew.nextChargeAt": nextChargeAt,
            extensionHistory: admin.firestore.FieldValue.arrayUnion({
              orderId,
              addedDays: exposureDays,
              paidAmount: amount,
              priceId: price.priceId,
              tierKey,
              triggeredBy: "auto",
              at: now,
            }),
            updatedAt: now,
          });
          if (camp.jobId) {
            tx.update(db().collection("jobs").doc(camp.jobId), {
              adEndAt: newEnd,
              status: "active",
              updatedAt: now,
            });
          }
          const auditRef = ref.collection("auditLog").doc();
          tx.set(auditRef, {
            type: "auto_renewed",
            actor: "system",
            before: { adEndAt },
            after: { adEndAt: newEnd, addedDays: exposureDays, amount },
            note: "자동연장 결제 성공",
            at: now,
          });
        });

        await db().collection("billingEvents").add({
          type: "auto_renewed",
          ownerUid,
          campaignId: ref.id,
          orderId,
          jobId: camp.jobId ?? null,
          amount,
          tierKey,
          priceId: price.priceId,
          discountRate,
          happenedAt: now,
          meta: {
            providerTxId: result.paymentKey ?? null,
            tossMode: result.mode,
          },
        });

        await appendInboxNotice(ownerUid, {
          type: "auto_renew_success",
          title: "자동연장 결제 완료",
          body:
            `자동연장이 성공적으로 처리되어 공고가 ${exposureDays}일 연장되었습니다.`,
          severity: "success",
          campaignId: ref.id,
          jobId: camp.jobId ?? undefined,
          orderId,
          dedupeKey: `autorenew_ok:${ref.id}:${dateOnlyKey(now)}`,
          meta: { amount, exposureDays },
        });

        charged += 1;
      } catch (e) {
        failed += 1;
        const reason = String(e);
        functions.logger.error("runAutoRenewals failed", {
          campaignId: ref.id,
          error: reason,
        });
        try {
          await ref.update({
            "autoRenew.lastChargeStatus": "failed",
            "autoRenew.failedReason": reason.slice(0, 300),
            updatedAt: tsNow(),
          });
          await appendInboxNotice(ownerUid, {
            type: "auto_renew_failed",
            title: "자동연장 결제에 실패했습니다",
            body:
              "이번 자동연장 청구가 실패했습니다. 카드 정보를 확인하거나 " +
              "수동 연장 결제로 진행해 주세요.",
            severity: "error",
            campaignId: ref.id,
            jobId: camp.jobId ?? undefined,
            dedupeKey: `autorenew_fail:${ref.id}:${dateOnlyKey(now)}`,
            meta: { reason: reason.slice(0, 300) },
          });
        } catch (e2) {
          functions.logger.error("runAutoRenewals: post-failure update failed", {
            campaignId: ref.id,
            error: String(e2),
          });
        }
      }
    }

    functions.logger.info("runAutoRenewals done", {
      total: snap.size,
      attempted,
      charged,
      fallback,
      failed,
    });
    return null;
  });
