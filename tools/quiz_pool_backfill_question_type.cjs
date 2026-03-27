/**
 * questionType 이 national_exam / clinical 이 아닌 문서만 packId·config 기준으로 보정
 * (기본: dry-run — 실제 쓰기는 --apply)
 *
 *   node tools/quiz_pool_backfill_question_type.cjs
 *   node tools/quiz_pool_backfill_question_type.cjs --apply
 *
 * 규칙: packId 가 국시 패크( config/quiz_content.currentNationalPackId 또는 national_default )이면 national_exam, 아니면 clinical
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

function inferType(packId, nationalPackIds) {
  const pid = typeof packId === "string" ? packId.trim() : "";
  return nationalPackIds.has(pid) ? "national_exam" : "clinical";
}

async function main() {
  const argv = process.argv.slice(2);
  const apply = argv.includes("--apply");

  if (!admin.apps.length) {
    admin.initializeApp({ credential: admin.credential.cert(loadServiceAccount()) });
  }
  const db = admin.firestore();

  const cfgSnap = await db.doc("config/quiz_content").get();
  const cfg = cfgSnap.exists ? cfgSnap.data() : {};
  const nationalId =
    typeof cfg.currentNationalPackId === "string" ? cfg.currentNationalPackId.trim() : "";
  const nationalPackIds = new Set(["national_default"]);
  if (nationalId) nationalPackIds.add(nationalId);

  const poolSnap = await db.collection("quiz_pool").get();
  const updates = [];

  for (const doc of poolSnap.docs) {
    const data = doc.data();
    const qt = data.questionType;
    const hasValid = qt === "national_exam" || qt === "clinical";
    if (hasValid) continue;
    const next = inferType(data.packId, nationalPackIds);
    updates.push({ id: doc.id, from: qt ?? "(없음)", to: next });
  }

  console.log(
    apply ? "=== APPLY 모드 ===" : "=== DRY-RUN (쓰기 없음) ===",
    "\n국시 packId 집합:",
    [...nationalPackIds].join(", ") || "(없음)",
    "\n변경 대상:",
    updates.length,
    "건\n",
  );
  for (const u of updates.slice(0, 50)) {
    console.log(`  ${u.id}: ${u.from} → ${u.to}`);
  }
  if (updates.length > 50) console.log(`  ... 외 ${updates.length - 50}건`);

  if (!apply || updates.length === 0) {
    if (!apply && updates.length > 0) {
      console.log("\n적용하려면: node tools/quiz_pool_backfill_question_type.cjs --apply");
    }
    process.exit(0);
  }

  let batch = db.batch();
  let n = 0;
  for (const u of updates) {
    const ref = db.collection("quiz_pool").doc(u.id);
    batch.update(ref, {
      questionType: u.to,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    n++;
    if (n >= 400) {
      await batch.commit();
      batch = db.batch();
      n = 0;
    }
  }
  if (n > 0) await batch.commit();
  console.log("✅ 적용 완료:", updates.length, "건");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
