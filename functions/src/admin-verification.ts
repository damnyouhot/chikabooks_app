/**
 * 운영자(어드민) 전용 — 조건부 승인(provisional) 프로필 검토 함수.
 *
 * /admin/verify 탭에서 사용한다. provisional 상태(자동 1~4단계 통과)
 * 프로필을 운영자가 직접 verified 또는 rejected 로 승격/거절한다.
 */
import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";

// admin.initializeApp() 은 index.ts 에서 호출됨. db 는 호출 시점에 lazy 하게 가져옴.
const getDb = (): admin.firestore.Firestore => admin.firestore();

interface AdminProvisionalProfile {
  uid: string;
  profileId: string;
  clinicName: string;
  displayName: string;
  address: string;
  ownerName: string;
  bizNo: string;
  bizRegImageUrl: string | null;
  hiraMatched: boolean | null;
  hiraMatchLevel: string | null;
  hiraNote: string | null;
  checkMethod: string | null;
  lastCheckAt: number | null;
}

interface AdminVerificationHistoryItem {
  id: string;
  type: "profile_verification" | "business_name_review";
  status: string;
  uid: string;
  profileId: string;
  clinicName: string;
  displayName: string;
  ownerName: string;
  address: string;
  bizNo: string;
  adminNote: string | null;
  reviewedBy: string | null;
  reviewedAt: number | null;
  updatedAt: number | null;
}

function timestampToMillis(value: unknown): number | null {
  if (
    value &&
    typeof (value as admin.firestore.Timestamp).toMillis === "function"
  ) {
    return (value as admin.firestore.Timestamp).toMillis();
  }
  return null;
}

async function requireAdmin(
  context: functions.https.CallableContext
): Promise<string> {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "로그인 필요");
  }
  const callerDoc = await getDb()
    .collection("users")
    .doc(context.auth.uid)
    .get();
  if (callerDoc.data()?.isAdmin !== true) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "어드민 권한 필요"
    );
  }
  return context.auth.uid;
}

async function upsertAdminNotification(
  notificationId: string,
  data: Record<string, unknown>
): Promise<void> {
  const ref = getDb().collection("adminNotifications").doc(notificationId);
  const snap = await ref.get();
  await ref.set(
    {
      ...data,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(snap.exists ? {} : {
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }),
    },
    {merge: true}
  );
}

async function resolveAdminNotification(
  notificationId: string,
  adminUid: string
): Promise<void> {
  const ref = getDb().collection("adminNotifications").doc(notificationId);
  const snap = await ref.get();
  if (!snap.exists) return;
  await ref.set(
    {
      status: "resolved",
      resolvedBy: adminUid,
      resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true}
  );
}

export const adminListProvisionalProfiles = functions.https.onCall(
  async (_data, context) => {
    await requireAdmin(context);

    const snap = await getDb()
      .collectionGroup("clinic_profiles")
      .where("businessVerification.status", "==", "provisional")
      .limit(200)
      .get();

    const items: AdminProvisionalProfile[] = [];
    for (const doc of snap.docs) {
      const data = doc.data() ?? {};
      const bv = (data as Record<string, unknown>).businessVerification as
        | Record<string, unknown>
        | undefined ?? {};
      const parent = doc.ref.parent.parent;
      const uid = parent?.id ?? "";
      const lastCheckAtRaw = bv["lastCheckAt"] as
        | admin.firestore.Timestamp
        | undefined;
      const lastCheckAt = lastCheckAtRaw && typeof lastCheckAtRaw.toMillis === "function"
        ? lastCheckAtRaw.toMillis()
        : null;
      items.push({
        uid,
        profileId: doc.id,
        clinicName: String((data as Record<string, unknown>).clinicName ?? ""),
        displayName: String((data as Record<string, unknown>).displayName ?? ""),
        address: String((data as Record<string, unknown>).address ?? ""),
        ownerName: String((data as Record<string, unknown>).ownerName ?? ""),
        bizNo: String(bv["bizNo"] ?? ""),
        bizRegImageUrl: (data as Record<string, unknown>).bizRegImageUrl
          ? String((data as Record<string, unknown>).bizRegImageUrl)
          : null,
        hiraMatched:
          typeof bv["hiraMatched"] === "boolean"
            ? (bv["hiraMatched"] as boolean)
            : null,
        hiraMatchLevel: bv["hiraMatchLevel"]
          ? String(bv["hiraMatchLevel"])
          : null,
        hiraNote: bv["hiraNote"] ? String(bv["hiraNote"]) : null,
        checkMethod: bv["checkMethod"] ? String(bv["checkMethod"]) : null,
        lastCheckAt,
      });
    }

    return {items};
  }
);

export const adminListVerificationReviewHistory = functions.https.onCall(
  async (_data, context) => {
    await requireAdmin(context);
    const db = getDb();
    const items: AdminVerificationHistoryItem[] = [];

    const profileSnap = await db
      .collectionGroup("clinic_profiles")
      .where(
        "businessVerification.adminReviewedAt",
        ">",
        admin.firestore.Timestamp.fromMillis(0)
      )
      .orderBy("businessVerification.adminReviewedAt", "desc")
      .limit(100)
      .get();

    for (const doc of profileSnap.docs) {
      const data = doc.data() ?? {};
      const bv = (data as Record<string, unknown>).businessVerification as
        | Record<string, unknown>
        | undefined ?? {};
      const parent = doc.ref.parent.parent;
      const uid = parent?.id ?? "";
      items.push({
        id: `profile_${uid}_${doc.id}`,
        type: "profile_verification",
        status: String(bv["status"] ?? ""),
        uid,
        profileId: doc.id,
        clinicName: String((data as Record<string, unknown>).clinicName ?? ""),
        displayName: String((data as Record<string, unknown>).displayName ?? ""),
        ownerName: String((data as Record<string, unknown>).ownerName ?? ""),
        address: String((data as Record<string, unknown>).address ?? ""),
        bizNo: String(bv["bizNo"] ?? ""),
        adminNote: bv["adminNote"] ? String(bv["adminNote"]) : null,
        reviewedBy: bv["adminReviewedBy"] ?
          String(bv["adminReviewedBy"]) :
          null,
        reviewedAt: timestampToMillis(bv["adminReviewedAt"]),
        updatedAt: timestampToMillis((data as Record<string, unknown>).updatedAt),
      });
    }

    const requestSnaps = await Promise.all(
      ["approved", "rejected"].map((status) =>
        db
          .collection("adminVerificationRequests")
          .where("type", "==", "business_name_review")
          .where("status", "==", status)
          .orderBy("updatedAt", "desc")
          .limit(50)
          .get()
      )
    );

    for (const snap of requestSnaps) {
      for (const doc of snap.docs) {
        const data = doc.data() ?? {};
        items.push({
          id: `name_${doc.id}`,
          type: "business_name_review",
          status: String(data.status ?? ""),
          uid: String(data.uid ?? ""),
          profileId: String(data.profileId ?? ""),
          clinicName: String(data.registeredClinicName ?? ""),
          displayName: String(data.displayName ?? ""),
          ownerName: String(data.ownerName ?? ""),
          address: String(data.address ?? ""),
          bizNo: "",
          adminNote: data.adminNote ? String(data.adminNote) : null,
          reviewedBy: data.reviewedBy ? String(data.reviewedBy) : null,
          reviewedAt: timestampToMillis(data.reviewedAt),
          updatedAt: timestampToMillis(data.updatedAt),
        });
      }
    }

    items.sort((a, b) => {
      const left = a.reviewedAt ?? a.updatedAt ?? 0;
      const right = b.reviewedAt ?? b.updatedAt ?? 0;
      return right - left;
    });

    return {items: items.slice(0, 100)};
  }
);

export const adminSetProfileVerification = functions.https.onCall(
  async (data, context) => {
    const adminUid = await requireAdmin(context);
    const uid = String(data?.uid ?? "").trim();
    const profileId = String(data?.profileId ?? "").trim();
    const decision = String(data?.decision ?? "").trim();
    const note = String(data?.note ?? "").trim();
    if (
      !uid ||
      !profileId ||
      (decision !== "verified" && decision !== "rejected")
    ) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "uid, profileId, decision(verified|rejected) 가 필요합니다."
      );
    }
    const profileRef = getDb()
      .collection("clinics_accounts")
      .doc(uid)
      .collection("clinic_profiles")
      .doc(profileId);
    const snap = await profileRef.get();
    if (!snap.exists) {
      throw new functions.https.HttpsError("not-found", "프로필을 찾을 수 없음");
    }
    if (decision === "verified") {
      await profileRef.update({
        "businessVerification.status": "verified",
        "businessVerification.verifiedAt":
          admin.firestore.FieldValue.serverTimestamp(),
        "businessVerification.failReason":
          admin.firestore.FieldValue.delete(),
        "businessVerification.adminReviewedBy": adminUid,
        "businessVerification.adminReviewedAt":
          admin.firestore.FieldValue.serverTimestamp(),
        "businessVerification.adminNote": note || null,
        "updatedAt": admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      await profileRef.update({
        "businessVerification.status": "rejected",
        "businessVerification.failReason": note || "admin_rejected",
        "businessVerification.verifiedAt": null,
        "businessVerification.adminReviewedBy": adminUid,
        "businessVerification.adminReviewedAt":
          admin.firestore.FieldValue.serverTimestamp(),
        "businessVerification.adminNote": note || null,
        "updatedAt": admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await resolveAdminNotification(
      `business_verification_provisional_${uid}_${profileId}`,
      adminUid
    );
    return {ok: true};
  }
);

export const requestBusinessNameReview = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "로그인 필요");
    }
    const uid = context.auth.uid;
    const profileId = String(data?.profileId ?? "").trim();
    const registeredClinicName = String(
      data?.registeredClinicName ?? ""
    ).trim();
    const displayName = String(
      data?.displayName ?? data?.registeredClinicName ?? ""
    ).trim();
    const reviewReason = String(
      data?.reviewReason ?? "display_name_mismatch"
    ).trim();
    const ownerName = String(data?.ownerName ?? "").trim();
    const address = String(data?.address ?? "").trim();
    if (!profileId || !registeredClinicName || !displayName) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "profileId, registeredClinicName, displayName 이 필요합니다."
      );
    }

    const profileRef = getDb()
      .collection("clinics_accounts")
      .doc(uid)
      .collection("clinic_profiles")
      .doc(profileId);
    const profileSnap = await profileRef.get();
    if (!profileSnap.exists) {
      throw new functions.https.HttpsError("not-found", "프로필을 찾을 수 없음");
    }

    const requestSuffix =
      reviewReason === "registered_name_ocr_error" ?
        "registered_name_ocr" :
        "business_name";
    const requestId = `${uid}_${profileId}_${requestSuffix}`;
    const requestRef = getDb()
      .collection("adminVerificationRequests")
      .doc(requestId);
    const payload = {
      type: "business_name_review",
      status: "pending",
      uid,
      profileId,
      registeredClinicName,
      displayName,
      reviewReason,
      ownerName,
      address,
      requesterEmail: context.auth.token.email ?? null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    await requestRef.set(
      {
        ...payload,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true}
    );
    await profileRef.set(
      {
        displayName,
        businessNameReview: {
          status: "pending",
          requestId,
          registeredClinicName,
          displayName,
          reviewReason,
          requestedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true}
    );
    await upsertAdminNotification(`business_name_review_${requestId}`, {
      type: "business_name_review",
      status: "unread",
      title:
        reviewReason === "registered_name_ocr_error" ?
          "OCR 상호 확인 요청" :
          "상호 확인 요청",
      message:
        reviewReason === "registered_name_ocr_error" ?
          `OCR 상호 확인: ${registeredClinicName}` :
          `${registeredClinicName} / 노출명 ${displayName}`,
      requestId,
      uid,
      profileId,
    });
    await getDb().collection("activityLogs").add({
      userId: uid,
      type: "publisher_business_name_review_request",
      page: "job_draft_editor",
      targetId: profileId,
      extra: {
        requestId,
        registeredClinicName,
        displayName,
        reviewReason,
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    return {ok: true, requestId};
  }
);

export const adminListBusinessNameReviewRequests = functions.https.onCall(
  async (_data, context) => {
    await requireAdmin(context);
    const snap = await getDb()
      .collection("adminVerificationRequests")
      .where("type", "==", "business_name_review")
      .where("status", "==", "pending")
      .orderBy("updatedAt", "desc")
      .limit(200)
      .get();
    return {
      items: snap.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      })),
    };
  }
);

export const adminResolveBusinessNameReview = functions.https.onCall(
  async (data, context) => {
    const adminUid = await requireAdmin(context);
    const requestId = String(data?.requestId ?? "").trim();
    const decision = String(data?.decision ?? "").trim();
    const note = String(data?.note ?? "").trim();
    if (
      !requestId ||
      (decision !== "approved" && decision !== "rejected")
    ) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "requestId, decision(approved|rejected) 이 필요합니다."
      );
    }
    const requestRef = getDb()
      .collection("adminVerificationRequests")
      .doc(requestId);
    const requestSnap = await requestRef.get();
    if (!requestSnap.exists) {
      throw new functions.https.HttpsError("not-found", "요청을 찾을 수 없음");
    }
    const request = requestSnap.data() ?? {};
    const uid = String(request.uid ?? "");
    const profileId = String(request.profileId ?? "");
    if (!uid || !profileId) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "요청 데이터가 올바르지 않습니다."
      );
    }
    const profileRef = getDb()
      .collection("clinics_accounts")
      .doc(uid)
      .collection("clinic_profiles")
      .doc(profileId);
    await requestRef.set(
      {
        status: decision,
        adminNote: note || null,
        reviewedBy: adminUid,
        reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true}
    );
    await profileRef.set(
      {
        businessNameReview: {
          status: decision,
          requestId,
          adminNote: note || null,
          reviewedBy: adminUid,
          reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true}
    );
    await resolveAdminNotification(`business_name_review_${requestId}`, adminUid);
    await getDb().collection("activityLogs").add({
      userId: adminUid,
      type: "admin_business_name_review_resolve",
      page: "admin_verify",
      targetId: requestId,
      extra: {decision, uid, profileId},
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    return {ok: true};
  }
);
