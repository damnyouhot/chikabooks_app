/**
 * ads/cancelRefund.ts
 *
 * cancelAndRefund — 사용자/관리자가 캠페인을 환불 취소.
 *
 * 정책:
 *   - 본인 캠페인만 환불 가능. 관리자는 모든 캠페인 가능.
 *   - 환불 가능 윈도우: appConfig.billingPolicy.refundWindowDays (default 7일).
 *     사용일이 윈도우 내라도, 사용 비율(이미 노출된 일수 / 총 노출일수) 만큼은 차감되지 않고
 *     '전액 환불' 으로 진행한다 (정책 v1).
 *     → 운영 정책 변경시 비례 환불(prorated)로 확장 예정 (TODO marked below).
 *   - cancellable 한 paymentKey 가 orders.providerTxId 에 보관돼 있어야 한다.
 *   - 환불 성공 시:
 *     - campaigns.lifecycleStatus = 'refunded'
 *     - jobs.status = 'closed'
 *     - orders.status = 'refunded'
 *     - billingEvents (type='order_refunded') 1건
 *     - voucher 사용분이 있다면 환원(restored) — 추후 voucherRestore 정책 확정 후 활성화.
 */

import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";

import { getBillingPolicy } from "./catalog";
import { refundTossPayment } from "../billing/tossPaymentsAdapter";

const db = () => admin.firestore();
const MS_PER_DAY = 24 * 60 * 60 * 1000;

function trimStr(v: unknown): string {
  return String(v ?? "").trim();
}

async function isAdmin(uid: string): Promise<boolean> {
  try {
    const u = await admin.auth().getUser(uid);
    return u.customClaims?.admin === true;
  } catch (_) {
    return false;
  }
}

export const cancelAndRefund = functions
  .region("asia-northeast3")
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "로그인이 필요합니다."
      );
    }
    const uid = context.auth.uid;
    const campaignId = trimStr(data?.campaignId);
    const reason = trimStr(data?.reason).slice(0, 500) || "사용자 요청 환불";
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
    const camp = snap.data() ?? {};

    const requesterIsAdmin = await isAdmin(uid);
    if (camp.ownerUid !== uid && !requesterIsAdmin) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "본인 캠페인만 환불 신청할 수 있습니다."
      );
    }
    if (camp.lifecycleStatus === "refunded") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "이미 환불된 캠페인입니다.",
        { errorCode: "ALREADY_REFUNDED" }
      );
    }

    const policy = await getBillingPolicy();
    const refundWindowDays = Math.max(0, Number(policy.refundWindowDays) || 0);

    // 윈도우 검사 (관리자는 윈도우 무시)
    const adStartAt = camp.adStartAt as FirebaseFirestore.Timestamp | undefined;
    if (!requesterIsAdmin && refundWindowDays > 0 && adStartAt) {
      const startMs = adStartAt.toMillis();
      const elapsedDays = Math.floor(
        (Date.now() - startMs) / MS_PER_DAY
      );
      if (elapsedDays > refundWindowDays) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          `환불 가능 기간(${refundWindowDays}일)이 지났습니다.`,
          { errorCode: "REFUND_WINDOW_EXPIRED", refundWindowDays }
        );
      }
    }

    // 환불 가능 amount = 최초 결제 amountPaid (정책 v1: 전액 / 부분환불 X)
    const orderId = String(camp.orderId ?? "");
    const refundAmount = Math.max(0, Number(camp.amountPaid) || 0);

    let paymentKey: string | null = null;
    if (orderId) {
      const orderSnap = await db().collection("orders").doc(orderId).get();
      if (orderSnap.exists) {
        const o = orderSnap.data() ?? {};
        paymentKey = trimStr(o.providerTxId) || null;
      }
    }

    // 결제건이 있으면 PG 환불 호출
    let refundResult: Awaited<ReturnType<typeof refundTossPayment>> | null =
      null;
    if (refundAmount > 0 && paymentKey) {
      refundResult = await refundTossPayment({
        paymentKey,
        cancelReason: reason,
        // TODO(prorated): 비례 환불 적용 시 cancelAmount 지정.
      });
    } else {
      functions.logger.info("cancelAndRefund: skip PG (no amount or paymentKey)", {
        orderId,
        refundAmount,
      });
    }

    const now = admin.firestore.Timestamp.now();
    await db().runTransaction(async (tx) => {
      const fresh = await tx.get(ref);
      const c = fresh.data() ?? {};
      if (c.lifecycleStatus === "refunded") return;

      tx.update(ref, {
        lifecycleStatus: "refunded",
        refundedAt: now,
        refundedBy: uid,
        refundReason: reason,
        refundAmount,
        updatedAt: now,
      });
      if (c.jobId) {
        tx.update(db().collection("jobs").doc(c.jobId), {
          status: "closed",
          closedReason: "refunded",
          updatedAt: now,
        });
      }
      if (orderId) {
        tx.update(db().collection("orders").doc(orderId), {
          status: "refunded",
          refundedAt: now,
          refundAmount,
          refundReason: reason,
          updatedAt: now,
        });
      }
      const auditRef = ref.collection("auditLog").doc();
      tx.set(auditRef, {
        type: "refunded",
        actor: uid,
        before: { lifecycleStatus: c.lifecycleStatus },
        after: { lifecycleStatus: "refunded", refundAmount },
        note: reason,
        at: now,
        meta: { isAdmin: requesterIsAdmin, tossMode: refundResult?.mode },
      });
    });

    await db().collection("billingEvents").add({
      type: "order_refunded",
      ownerUid: camp.ownerUid,
      campaignId: ref.id,
      orderId,
      jobId: camp.jobId ?? null,
      amount: -refundAmount,
      tierKey: camp.tierKey ?? null,
      priceId: camp.priceId ?? null,
      discountRate: 0,
      happenedAt: now,
      meta: {
        reason,
        actorUid: uid,
        actorIsAdmin: requesterIsAdmin,
        tossMode: refundResult?.mode ?? "none",
        paymentKey,
      },
    });

    return {
      ok: true,
      lifecycleStatus: "refunded",
      refundAmount,
      tossMode: refundResult?.mode ?? "none",
    };
  });
