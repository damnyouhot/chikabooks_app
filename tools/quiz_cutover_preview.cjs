/**
 * 임상 패크 전환 전·후 집계 (dry-run, 쓰기 없음)
 *
 *   node ../tools/quiz_cutover_preview.cjs
 *
 * config/quiz_content 의 currentClinicalPackId / includeClinicalWithoutPack 과
 * quiz_pool 의 packId 를 읽어 후보 풀 크기를 출력합니다.
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

function quizQuestionType(d) {
  return d.questionType === "national_exam" ? "national_exam" : "clinical";
}

function clinicalMatches(data, cfg) {
  if (quizQuestionType(data) !== "clinical") return true;
  if (!cfg.currentClinicalPackId) return true;
  const pid = typeof data.packId === "string" ? data.packId.trim() : "";
  if (!pid) return cfg.includeClinicalWithoutPack;
  return pid === cfg.currentClinicalPackId;
}

async function main() {
  if (!admin.apps.length) {
    admin.initializeApp({ credential: admin.credential.cert(loadServiceAccount()) });
  }
  const db = admin.firestore();

  const cfgSnap = await db.doc("config/quiz_content").get();
  const cfg = cfgSnap.exists ? cfgSnap.data() : {};
  const contentCfg = {
    currentClinicalPackId:
      typeof cfg.currentClinicalPackId === "string" ? cfg.currentClinicalPackId.trim() : "",
    includeClinicalWithoutPack: cfg.includeClinicalWithoutPack !== false,
  };

  const poolSnap = await db.collection("quiz_pool").where("isActive", "==", true).get();

  let national = 0;
  let clinicalAll = 0;
  let clinicalEligible = 0;
  const byPack = {};

  for (const doc of poolSnap.docs) {
    const d = doc.data();
    const t = quizQuestionType(d);
    if (t === "national_exam") {
      national++;
      continue;
    }
    clinicalAll++;
    const pid = typeof d.packId === "string" && d.packId.trim() ? d.packId.trim() : "(packId 없음)";
    byPack[pid] = (byPack[pid] || 0) + 1;
    if (clinicalMatches(d, contentCfg)) clinicalEligible++;
  }

  console.log("── config/quiz_content ──");
  console.log(JSON.stringify(contentCfg, null, 2));
  console.log("── 활성 풀 (isActive) ──");
  console.log("국시:", national, "/ 임상(전체):", clinicalAll, "/ 임상(스케줄 후보):", clinicalEligible);
  console.log("── 임상 packId 별 건수 ──");
  Object.keys(byPack)
    .sort()
    .forEach((k) => console.log(`  ${k}: ${byPack[k]}`));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
