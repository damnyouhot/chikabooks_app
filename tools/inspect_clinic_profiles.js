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
  const db = admin.firestore();
  const snap = await db.collectionGroup("clinic_profiles").get();
  for (const doc of snap.docs) {
    const data = doc.data();
    console.log(JSON.stringify({
      path: doc.ref.path,
      clinicName: data.clinicName,
      displayName: data.displayName,
      ownerName: data.ownerName,
      address: data.address,
      bv: data.businessVerification,
    }, null, 2));
    const attempts = await doc.ref
      .collection("verification_attempts")
      .orderBy("createdAt", "desc")
      .limit(5)
      .get();
    for (const a of attempts.docs) {
      console.log("ATTEMPT", a.id, JSON.stringify(a.data(), null, 2));
    }
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
