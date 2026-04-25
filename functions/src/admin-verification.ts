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
    return {ok: true};
  }
);
