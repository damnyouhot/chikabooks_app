const fs = require("fs");
const path = require("path");

const projectRoot = path.join(__dirname, "..");
const functionsDir = path.join(projectRoot, "functions");
const adminModulePath = path.join(functionsDir, "node_modules", "firebase-admin");
const admin = require(adminModulePath);

const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
  path.join(functionsDir, "serviceAccountKey.json");

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(JSON.parse(fs.readFileSync(keyPath, "utf8"))),
  });
}

async function main() {
  const apply = process.argv.includes("--apply");
  const db = admin.firestore();
  const ref = db
    .collection("clinics_accounts")
    .doc("Lb85C4mnvEXGik6ijLgLyxrEStE2")
    .collection("clinic_profiles")
    .doc("if0O2SXX45c6SfvVGlDs");

  const snap = await ref.get();
  if (!snap.exists) throw new Error("profile not found");
  const data = snap.data();
  const bv = data.businessVerification || {};

  console.log("현재 상태:", JSON.stringify({
    clinicName: data.clinicName,
    displayName: data.displayName,
    ownerName: data.ownerName,
    address: data.address,
    businessVerification: bv,
  }, null, 2));

  if (!apply) {
    console.log("DRY-RUN only. Use --apply to restore.");
    return;
  }

  await ref.collection("verification_attempts").add({
    profileId: ref.id,
    docUrl: bv.docUrl || null,
    source: "manual_restore_from_polluted_profile",
    status: "rejected",
    failReason: bv.failReason || "not_business_registration",
    checkMethod: bv.checkMethod || "ocr",
    profileMutation: "moved_from_profile_pollution",
    isBusinessRegistration: bv.isBusinessRegistration ?? false,
    confidence: bv.confidence ?? null,
    rejectReason: bv.rejectReason || null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await ref.update({
    "businessVerification.status": "provisional",
    "businessVerification.failReason": admin.firestore.FieldValue.delete(),
    "businessVerification.rejectReason": admin.firestore.FieldValue.delete(),
    "businessVerification.isBusinessRegistration": true,
    "businessVerification.confidence": admin.firestore.FieldValue.delete(),
    "businessVerification.checkMethod": bv.hiraMatched === true ? "nts" : (bv.checkMethod || "nts"),
    "businessVerification.verifiedAt": null,
    "businessVerification.lastCheckAt": admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log("복구 완료");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
