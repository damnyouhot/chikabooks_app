/**
 * 임상 quiz_pool 만: packId 가 --except-pack-id 가 아닌 문서 isActive=false (삭제 없음)
 *
 *   node ../tools/quiz_deactivate_clinical_except_pack.cjs --except-pack-id=clinical_xxx --dry-run
 *   node ../tools/quiz_deactivate_clinical_except_pack.cjs --except-pack-id=clinical_xxx --yes
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
  const out = { exceptPackId: "", dryRun: false, yes: false };
  for (const a of argv.slice(2)) {
    if (a === "--dry-run") out.dryRun = true;
    if (a === "--yes") out.yes = true;
    if (a.startsWith("--except-pack-id=")) out.exceptPackId = a.slice("--except-pack-id=".length).trim();
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
  if (!args.exceptPackId) {
    console.error("❌ --except-pack-id=... 필수");
    process.exit(1);
  }

  if (!admin.apps.length) {
    admin.initializeApp({ credential: admin.credential.cert(loadServiceAccount()) });
  }
  const db = admin.firestore();
  const snap = await db.collection("quiz_pool").where("isActive", "==", true).get();

  const targets = [];
  for (const doc of snap.docs) {
    const d = doc.data();
    const qType = d.questionType === "national_exam" ? "national_exam" : "clinical";
    if (qType !== "clinical") continue;
    const pid = typeof d.packId === "string" ? d.packId.trim() : "";
    if (pid === args.exceptPackId) continue;
    targets.push(doc.ref);
  }

  console.log("대상 임상 문서(비활성화):", targets.length, "| 유지 packId:", args.exceptPackId);
  if (args.dryRun) {
    console.log("✅ dry-run: 쓰기 없음");
    return;
  }

  if (!args.yes) {
    const ok = await askYes(`${targets.length}건 isActive=false 로 업데이트합니다. 계속? (yes/no) `);
    if (!ok) {
      console.log("취소");
      process.exit(0);
    }
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  const BATCH = 450;
  let done = 0;
  for (let i = 0; i < targets.length; i += BATCH) {
    const batch = db.batch();
    const chunk = targets.slice(i, i + BATCH);
    for (const ref of chunk) {
      batch.update(ref, { isActive: false, updatedAt: now });
    }
    await batch.commit();
    done += chunk.length;
    console.log("…", done, "/", targets.length);
  }
  console.log("✅ 완료");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
