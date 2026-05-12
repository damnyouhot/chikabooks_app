/**
 * ads/migrate.ts
 *
 * 일회성 백필 — 기존 `jobs/{jobId}` 를 새 `campaigns/{campaignId}` 컬렉션으로 옮긴다.
 *
 * 멱등(idempotent) 동작:
 *   - jobs.campaignId 가 이미 있으면 skip
 *   - jobs.testBypass=true 또는 paymentStatus='test_bypassed' 도 모두 캠페인 생성
 *   - 동일 jobId 에 대해 캠페인이 이미 존재하면 jobs 만 jobs.campaignId 로 연결
 *
 * 호출 권한: 관리자(`users/{uid}.isAdmin == true`) 만.
 *
 * 입력:
 *   { dryRun?: boolean, limit?: number }
 *
 * 출력:
 *   { totalScanned, created, linked, skipped, errors: [{jobId, message}] }
 *
 * 운영 가이드:
 *   - 첫 실행 시 dryRun=true 로 검증 → 결과 확인 → dryRun=false 로 실집행
 *   - 대용량(수천건) 환경이면 limit 으로 페이징하여 분할 실행
 */

import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";

import {
  getBillingPolicy,
  getProductCatalog,
  normalizeTierKey,
} from "./catalog";

const dbRef = () => admin.firestore();

interface MigrateInput {
  dryRun?: boolean;
  limit?: number;
}

interface MigrateOutput {
  totalScanned: number;
  created: number;
  linked: number;
  skipped: number;
  errors: { jobId: string; message: string }[];
}

export const migrateExistingJobsToCampaigns = functions
  .region("asia-northeast3")
  .runWith({ timeoutSeconds: 540 })
  .https.onCall(async (data: MigrateInput, context): Promise<MigrateOutput> => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "로그인이 필요합니다."
      );
    }

    const adminCheck = await dbRef()
      .collection("users")
      .doc(context.auth.uid)
      .get();
    if (!(adminCheck.exists && adminCheck.data()?.isAdmin === true)) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "관리자만 실행할 수 있습니다."
      );
    }

    const dryRun = data?.dryRun !== false; // 디폴트 dryRun=true (안전)
    const limit = Math.min(Math.max(Number(data?.limit) || 500, 1), 2000);

    const jobsSnap = await dbRef()
      .collection("jobs")
      .orderBy("createdAt", "asc")
      .limit(limit)
      .get();

    const result: MigrateOutput = {
      totalScanned: jobsSnap.size,
      created: 0,
      linked: 0,
      skipped: 0,
      errors: [],
    };

    if (jobsSnap.empty) return result;

    // 정책 스냅샷은 모든 백필 캠페인에 동일하게 박힌다 (현재 정책 = 백필 시점 정책)
    const policy = await getBillingPolicy();

    for (const jobDoc of jobsSnap.docs) {
      const job = jobDoc.data() ?? {};
      const jobId = jobDoc.id;
      try {
        // 1) 이미 campaignId 가 있고 캠페인 문서도 존재하면 skip
        if (job.campaignId) {
          const exists = await dbRef()
            .collection("campaigns")
            .doc(job.campaignId)
            .get();
          if (exists.exists) {
            result.skipped++;
            continue;
          }
        }

        // 2) 동일 jobId 에 대한 캠페인이 이미 있는지 확인 (다른 ID 로 만들어졌을 수 있음)
        const existingByJob = await dbRef()
          .collection("campaigns")
          .where("jobId", "==", jobId)
          .limit(1)
          .get();
        if (!existingByJob.empty) {
          if (!dryRun) {
            await jobDoc.ref.update({
              campaignId: existingByJob.docs[0].id,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
          result.linked++;
          continue;
        }

        // 3) 신규 캠페인 생성 — orders 매칭으로 가격/주문 ID 추론
        const tierKey = normalizeTierKey(job.productTier ?? job.tierKey);
        const catalog = await getProductCatalog(tierKey);

        // jobs.adStartAt/adEndAt 보존, 없으면 createdAt + exposureDays 로 재구성
        const now = admin.firestore.Timestamp.now();
        const createdAt =
          (job.createdAt as FirebaseFirestore.Timestamp) ?? now;
        const adStartAt =
          (job.adStartAt as FirebaseFirestore.Timestamp) ?? createdAt;
        const adEndAt =
          (job.adEndAt as FirebaseFirestore.Timestamp) ??
          admin.firestore.Timestamp.fromMillis(
            adStartAt.toMillis() +
              catalog.exposureDays * 24 * 60 * 60 * 1000
          );

        // orders 매칭 시도 (있으면 priceId/amount 추론)
        let orderId: string | null = null;
        let priceId: string | null = catalog.activePriceId;
        let amountPaid = 0;
        let voucherId: string | null = null;
        if (job.ownerUid) {
          const orderSnap = await dbRef()
            .collection("orders")
            .where("ownerUid", "==", job.ownerUid)
            .where("draftId", "==", job.draftId ?? "")
            .where("status", "==", "paid")
            .limit(1)
            .get();
          if (!orderSnap.empty) {
            const o = orderSnap.docs[0].data();
            orderId = orderSnap.docs[0].id;
            priceId = (o.priceId as string) ?? priceId;
            amountPaid = Number(o.amount) || 0;
            voucherId = (o.voucherId as string) ?? null;
          }
        }

        // 라이프사이클 상태 추론: jobs.status 기반
        let lifecycleStatus = "active";
        const jobStatus = String(job.status ?? "").toLowerCase();
        if (jobStatus === "closed") lifecycleStatus = "ended";
        else if (jobStatus === "paused") lifecycleStatus = "paused";
        else if (jobStatus === "rejected") lifecycleStatus = "ended";
        else if (adEndAt.toMillis() < Date.now()) lifecycleStatus = "ended";

        const campaignData: FirebaseFirestore.DocumentData = {
          ownerUid: job.ownerUid ?? job.createdBy ?? job.clinicId ?? null,
          clinicProfileId: job.clinicProfileId ?? null,
          jobId,
          orderId,
          tierKey,
          priceId,
          amountPaid,
          voucherId,
          lifecycleStatus,
          adStartAt,
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
          policySnapshot: {
            pauseSaveRate: policy.pauseSaveRate,
            pauseMinDaysToAllow: policy.pauseMinDaysToAllow,
            pauseMaxCountPerCampaign: policy.pauseMaxCountPerCampaign,
            autoRenewLeadDays: policy.autoRenewLeadDays,
            refundWindowDays: policy.refundWindowDays,
            policyVersion: policy.policyVersion,
          },
          notificationsSent: { national: 0, regional: 0, openRate: 0 },
          backfilled: true,
          backfillNote:
            "migrateExistingJobsToCampaigns: jobs → campaigns 이전",
          createdAt: createdAt,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        if (dryRun) {
          result.created++;
          continue;
        }

        const campaignRef = dbRef().collection("campaigns").doc();
        const batch = dbRef().batch();
        batch.set(campaignRef, campaignData);
        batch.set(campaignRef.collection("auditLog").doc(), {
          type: "backfilled",
          actor: "system:migrate",
          before: null,
          after: { tierKey, jobId, lifecycleStatus },
          note: "migrateExistingJobsToCampaigns",
          at: admin.firestore.FieldValue.serverTimestamp(),
        });
        batch.update(jobDoc.ref, {
          campaignId: campaignRef.id,
          tierKey,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        if (orderId) {
          batch.update(dbRef().collection("orders").doc(orderId), {
            campaignId: campaignRef.id,
            jobId,
            tierKey,
            priceId,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
        result.created++;
      } catch (e) {
        functions.logger.error("migrate failure", { jobId, err: String(e) });
        result.errors.push({ jobId, message: String(e) });
      }
    }

    functions.logger.info("migrateExistingJobsToCampaigns done", {
      dryRun,
      ...result,
      errorsCount: result.errors.length,
    });

    return result;
  });
