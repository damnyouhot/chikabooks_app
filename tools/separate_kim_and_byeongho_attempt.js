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
  console.log("before", JSON.stringify(snap.data(), null, 2));
  if (!apply) {
    console.log("DRY-RUN. Use --apply.");
    return;
  }

  const attemptPayload = {
    profileId: ref.id,
    source: "manual_separate_polluted_business",
    status: "rejected",
    failReason: "business_closed",
    checkMethod: "nts",
    profileMutation: "none",
    profileRelation: "unverified_existing_profile",
    isBusinessRegistration: true,
    confidence: 1,
    docUrl: snap.data().businessVerification?.docUrl || null,
    ocrResult: {
      clinicName: "병호상사",
      ownerName: "김병호",
      address: "부산광역시 수영구 망미번영로88번길 72-2, 2층(망미동)",
      bizNo: "112-18-96823",
    },
    hiraMatched: true,
    hiraNote: "심평원 병원목록에서 치과 요양기관으로 조회되었으나, 국세청 검증은 통과하지 못한 별도 시도입니다.",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  const attempts = await ref.collection("verification_attempts").get();
  const batch = db.batch();
  for (const doc of attempts.docs) {
    batch.delete(doc.ref);
  }
  batch.set(ref.collection("verification_attempts").doc(), attemptPayload);
  batch.update(ref, {
    clinicName: "김승인치과의원",
    displayName: "김승인치과의원",
    ownerName: "",
    address: "",
    bizRegImageUrl: admin.firestore.FieldValue.delete(),
    businessVerification: {
      status: "none",
      bizNo: "",
    },
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await batch.commit();
  console.log("separated");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
