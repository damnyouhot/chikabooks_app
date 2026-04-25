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

async function dumpDoc(ref, label) {
  const snap = await ref.get();
  console.log(`\n## ${label}: ${ref.path}`);
  console.log(snap.exists ? JSON.stringify(snap.data(), null, 2) : "(missing)");
}

async function main() {
  const db = admin.firestore();
  const uid = "Lb85C4mnvEXGik6ijLgLyxrEStE2";
  await dumpDoc(db.collection("clinics_accounts").doc(uid), "clinics_accounts root");
  await dumpDoc(db.collection("users").doc(uid), "users");
  await dumpDoc(db.collection("clinicVerifications").doc(uid), "clinicVerifications legacy");

  const jobs = await db.collection("jobs").where("createdBy", "==", uid).limit(10).get();
  console.log(`\n## jobs createdBy ${uid}: ${jobs.size}`);
  for (const j of jobs.docs) {
    console.log(j.id, JSON.stringify(j.data(), null, 2));
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
