/**
 * 퀴즈 콘텐츠 전환용 Firestore 초기 문서
 *
 *   - config/quiz_content   … 현재 임상·국시 패크 ID 등
 *   - quiz_packs/national_default … 국시 업로드와 스키마 정합용 메타
 *
 * 사용: cd functions && npm install 후
 *   node ../tools/setup_quiz_content_config.cjs
 */

const fs = require("fs");
const path = require("path");

const functionsDir = path.join(__dirname, "../functions");
const admin = require(path.join(functionsDir, "node_modules/firebase-admin"));

function loadServiceAccount() {
  const envPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const p = path.join(functionsDir, "serviceAccountKey.json");
  const keyPath = envPath && fs.existsSync(envPath) ? envPath : p;
  if (!fs.existsSync(keyPath)) {
    console.error("❌ serviceAccountKey.json 없음:", p);
    process.exit(1);
  }
  return JSON.parse(fs.readFileSync(keyPath, "utf8"));
}

async function main() {
  if (!admin.apps.length) {
    admin.initializeApp({ credential: admin.credential.cert(loadServiceAccount()) });
  }
  const db = admin.firestore();
  const now = admin.firestore.FieldValue.serverTimestamp();

  await db.doc("config/quiz_content").set(
    {
      currentClinicalPackId: "",
      includeClinicalWithoutPack: true,
      currentNationalPackId: "",
      includeNationalWithoutPack: true,
      updatedAt: now,
    },
    { merge: true },
  );

  await db.doc("quiz_packs/national_default").set(
    {
      kind: "national_exam",
      title: "국시 기본",
      version: 1,
      isActive: true,
      updatedAt: now,
    },
    { merge: true },
  );

  console.log("✅ config/quiz_content, quiz_packs/national_default 초기화(merge) 완료");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
