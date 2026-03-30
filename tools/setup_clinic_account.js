/**
 * 치과 계정을 인증 완료 상태로 설정 (테스트용)
 *
 * 사용법:
 *   node tools/setup_clinic_account.js chikabooks.app@gmail.com
 *
 * clinics_accounts/{uid} 문서를 approvalStatus: "approved", canPost: true로 설정
 */

const fs = require("fs");
const path = require("path");

const projectRoot = path.join(__dirname, "..");
const functionsDir = path.join(projectRoot, "functions");
const adminModulePath = path.join(functionsDir, "node_modules", "firebase-admin");

function loadFirebaseAdmin() {
  if (!fs.existsSync(adminModulePath)) {
    console.error("firebase-admin not found. Run: cd functions && npm install");
    process.exit(1);
  }
  return require(adminModulePath);
}

function loadServiceAccount() {
  const envPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const defaultPath = path.join(functionsDir, "serviceAccountKey.json");
  const keyPath = envPath && fs.existsSync(envPath) ? envPath : defaultPath;
  if (!fs.existsSync(keyPath)) {
    console.error("Service account key not found at:", keyPath);
    process.exit(1);
  }
  return JSON.parse(fs.readFileSync(keyPath, "utf8"));
}

async function main() {
  const email = process.argv[2];
  if (!email) {
    console.error("Usage: node tools/setup_clinic_account.js <email>");
    process.exit(1);
  }

  const admin = loadFirebaseAdmin();
  const sa = loadServiceAccount();
  admin.initializeApp({
    credential: admin.credential.cert(sa),
  });

  const db = admin.firestore();

  // Firebase Auth에서 UID 찾기
  let userRecord;
  try {
    userRecord = await admin.auth().getUserByEmail(email);
  } catch (e) {
    console.error(`Firebase Auth에서 ${email} 유저를 찾을 수 없습니다:`, e.message);
    process.exit(1);
  }

  const uid = userRecord.uid;
  console.log(`Found user: ${email} → uid: ${uid}`);

  // clinics_accounts/{uid} 문서 설정
  await db.collection("clinics_accounts").doc(uid).set(
    {
      clinicId: uid,
      clinicVerified: true,
      approvalStatus: "approved",
      canPost: true,
      normalizedEmail: email.trim().toLowerCase(),
      clinic: {
        name: "테스트 치과",
        bizNo: "000-00-00000",
      },
      onboarding: { business: "done" },
      approvedAt: admin.firestore.FieldValue.serverTimestamp(),
      role: "clinic",
    },
    { merge: true }
  );

  console.log(`clinics_accounts/${uid} → approvalStatus: approved, canPost: true`);

  // users/{uid}에도 role 반영
  await db.collection("users").doc(uid).set(
    {
      role: "clinic",
      email: email.trim().toLowerCase(),
    },
    { merge: true }
  );

  console.log(`users/${uid} → role: clinic`);
  console.log("Done!");
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
