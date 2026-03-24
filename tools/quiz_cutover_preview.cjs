/**
 * 패크 전환 전·후 집계 (dry-run, 쓰기 없음)
 *
 *   node ../tools/quiz_cutover_preview.cjs
 *
 * config/quiz_content 와 quiz_pool packId 를 읽어
 * Cloud Functions 선정 로직과 동일한 기준으로 후보 수를 출력합니다.
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

function nationalMatches(data, cfg) {
  if (quizQuestionType(data) !== "national_exam") return true;
  if (!cfg.currentNationalPackId) return true;
  const pid = typeof data.packId === "string" ? data.packId.trim() : "";
  if (!pid) return cfg.includeNationalWithoutPack;
  return pid === cfg.currentNationalPackId;
}

function poolMatches(data, cfg) {
  return clinicalMatches(data, cfg) && nationalMatches(data, cfg);
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
    currentNationalPackId:
      typeof cfg.currentNationalPackId === "string" ? cfg.currentNationalPackId.trim() : "",
    includeNationalWithoutPack: cfg.includeNationalWithoutPack !== false,
  };

  const poolSnap = await db.collection("quiz_pool").where("isActive", "==", true).get();

  let nationalAll = 0;
  let clinicalAll = 0;
  let nationalEligible = 0;
  let clinicalEligible = 0;
  const byPackNational = {};
  const byPackClinical = {};

  for (const doc of poolSnap.docs) {
    const d = doc.data();
    const t = quizQuestionType(d);
    const pidRaw = typeof d.packId === "string" && d.packId.trim() ? d.packId.trim() : "(packId 없음)";
    if (t === "national_exam") {
      nationalAll++;
      byPackNational[pidRaw] = (byPackNational[pidRaw] || 0) + 1;
      if (nationalMatches(d, contentCfg)) nationalEligible++;
    } else {
      clinicalAll++;
      byPackClinical[pidRaw] = (byPackClinical[pidRaw] || 0) + 1;
      if (clinicalMatches(d, contentCfg)) clinicalEligible++;
    }
  }

  let bothEligible = 0;
  for (const doc of poolSnap.docs) {
    if (poolMatches(doc.data(), contentCfg)) bothEligible++;
  }

  console.log("── config/quiz_content ──");
  console.log(JSON.stringify(contentCfg, null, 2));
  console.log("── 활성 풀 (isActive) ──");
  console.log(
    "국시: 전체",
    nationalAll,
    "/ 스케줄 후보",
    nationalEligible,
    "| 임상: 전체",
    clinicalAll,
    "/ 스케줄 후보",
    clinicalEligible,
  );
  console.log("── 스케줄 후보 합계(임상∩국시 필터 동시 적용, CF와 동일) ──", bothEligible);
  console.log("── 국시 packId 별 건수 ──");
  Object.keys(byPackNational)
    .sort()
    .forEach((k) => console.log(`  ${k}: ${byPackNational[k]}`));
  console.log("── 임상 packId 별 건수 ──");
  Object.keys(byPackClinical)
    .sort()
    .forEach((k) => console.log(`  ${k}: ${byPackClinical[k]}`));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
