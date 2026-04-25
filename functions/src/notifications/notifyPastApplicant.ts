import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

/**
 * notifyPastApplicant
 *
 * 운영자(병원) 가 본인 인재풀에서 다중 선택한 지원자들에게 새 공고 안내
 * 이메일을 발송하기 위한 큐 적재 Callable.
 *
 * 정책 결정사항(2026-04):
 *   1. 채널: **이메일만** (1차)
 *   2. 발송 주체: 운영자가 ⭐ 등록한 사람만 풀에 들어오므로, 풀에서만 다중 선택 가능
 *   3. 스팸 방지: 같은 (ownerUid, applicantUid, jobId) 조합에 대해 24시간 내
 *      재발송 차단
 *   4. 실제 발송: 본 함수는 큐(notifyQueue)만 적재한다. 워커(SES / 외주
 *      이메일 게이트웨이) 가 큐를 폴링/트리거 처리.
 *
 * Input:
 *   - branchId: string  (보통 ownerUid 와 동일)
 *   - jobId: string     (안내할 공고)
 *   - applicantUids: string[]
 *   - message?: string  (운영자가 추가로 적은 메모, 선택)
 *
 * Output:
 *   - { queued: number, skipped: number }
 */
export const notifyPastApplicant = functions
  .region("asia-northeast3")
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "로그인이 필요합니다."
      );
    }
    const ownerUid = context.auth.uid;
    const branchId = String(data?.branchId ?? ownerUid);
    const jobId = String(data?.jobId ?? "");
    const applicantUids: string[] = Array.isArray(data?.applicantUids) ?
      (data.applicantUids as unknown[]).map(String) :
      [];
    const message =
      typeof data?.message === "string" ? String(data.message) : null;

    if (!jobId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "jobId 는 필수입니다."
      );
    }
    if (applicantUids.length === 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "applicantUids 가 비어 있습니다."
      );
    }
    if (applicantUids.length > 200) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "한 번에 200명까지만 발송 가능합니다."
      );
    }

    const db = admin.firestore();

    // 공고 검증 — 본인이 만든 공고만 허용
    const jobSnap = await db.collection("jobs").doc(jobId).get();
    if (!jobSnap.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "공고를 찾을 수 없습니다."
      );
    }
    const job = jobSnap.data() || {};
    if (job.createdBy !== ownerUid) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "본인이 발행한 공고로만 안내할 수 있습니다."
      );
    }

    // 24시간 룰 검증 — notifyQueue 에서 같은 조합 최근 발송 확인
    const dayAgo = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 24 * 60 * 60 * 1000)
    );

    let queued = 0;
    let skipped = 0;
    const batch = db.batch();
    const poolCol = db
      .collection("clinics_accounts")
      .doc(ownerUid)
      .collection("branches")
      .doc(branchId)
      .collection("applicantPool");

    for (const auid of applicantUids) {
      // 풀에 없으면 skip (보안 + 정책: 풀 등록자만 발송 가능)
      const poolDoc = await poolCol.doc(auid).get();
      if (!poolDoc.exists) {
        skipped++;
        continue;
      }

      // 24시간 내 동일 (jobId, applicantUid) 발송 이력 확인
      const recentSnap = await db
        .collection("notifyQueue")
        .where("ownerUid", "==", ownerUid)
        .where("applicantUid", "==", auid)
        .where("jobId", "==", jobId)
        .where("createdAt", ">=", dayAgo)
        .limit(1)
        .get();
      if (!recentSnap.empty) {
        skipped++;
        continue;
      }

      // 지원자 이메일 lookup — users/{uid}.email 우선, 없으면 resumes/{}.profile.email
      let email = "";
      const userSnap = await db.collection("users").doc(auid).get();
      if (userSnap.exists) {
        email = String(userSnap.data()?.email ?? "");
      }

      const queueRef = db.collection("notifyQueue").doc();
      batch.set(queueRef, {
        type: "past_applicant_new_job",
        channel: "email",
        ownerUid,
        branchId,
        applicantUid: auid,
        recipientEmail: email,
        jobId,
        jobTitle: String(job.title ?? ""),
        clinicName: String(job.clinicName ?? ""),
        message: message ?? null,
        status: email ? "queued" : "skipped_no_email",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 풀 엔트리에도 마지막 알림 시점 기록
      batch.update(poolCol.doc(auid), {
        lastContactedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastContactedJobId: jobId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      if (email) {
        queued++;
      } else {
        skipped++;
      }
    }

    if (queued > 0 || skipped > 0) {
      await batch.commit();
    }

    functions.logger.info("[notifyPastApplicant]", {
      ownerUid,
      jobId,
      requested: applicantUids.length,
      queued,
      skipped,
    });

    return {queued, skipped};
  });
