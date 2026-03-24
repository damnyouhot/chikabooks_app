/**
 * config/quiz_content 의 currentClinicalPackId 만 변경 (컷오버)
 *
 *   node ../tools/quiz_content_apply_clinical_pack.cjs --pack-id=clinical_xxx --yes
 *   --no-legacy  → includeClinicalWithoutPack: false (packId 없는 임상 제외)
 *
 * 사전: functions/serviceAccountKey.json 또는 GOOGLE_APPLICATION_CREDENTIALS
 */

const fs = require("fs");
const path = require("path");
const readline = require("readline");

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

function parseArgs(argv) {
  const out = { packId: "", yes: false, noLegacy: false };
  for (const a of argv.slice(2)) {
    if (a === "--yes") out.yes = true;
    if (a === "--no-legacy") out.noLegacy = true;
    if (a.startsWith("--pack-id=")) out.packId = a.slice("--pack-id=".length).trim();
  }
  return out;
}

function askYes(question) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => {
    rl.question(question, (ans) => {
      rl.close();
      resolve(/^y(es)?$/i.test(String(ans).trim()));
    });
  });
}

async function main() {
  const args = parseArgs(process.argv);
  if (!args.packId) {
    console.error("❌ --pack-id=... 필수");
    process.exit(1);
  }

  if (!args.yes) {
    const ok = await askYes(
      `config/quiz_content 에 currentClinicalPackId="${args.packId}"` +
        (args.noLegacy ? ", includeClinicalWithoutPack=false" : "") +
        " 를 merge 합니다. 계속? (yes/no) ",
    );
    if (!ok) {
      console.log("취소");
      process.exit(0);
    }
  }

  if (!admin.apps.length) {
    admin.initializeApp({ credential: admin.credential.cert(loadServiceAccount()) });
  }
  const db = admin.firestore();
  const now = admin.firestore.FieldValue.serverTimestamp();

  const patch = {
    currentClinicalPackId: args.packId,
    updatedAt: now,
  };
  if (args.noLegacy) patch.includeClinicalWithoutPack = false;

  await db.doc("config/quiz_content").set(patch, { merge: true });
  console.log("✅ merge 완료:", patch);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
