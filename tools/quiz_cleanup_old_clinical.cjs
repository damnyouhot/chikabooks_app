/**
 * 이전 임상 문제 삭제 + 메타/스케줄 정리 (앱 공개 전 1회성)
 *
 * 수행 작업:
 *   1. quiz_pool: 현재 팩이 아닌 임상 문서 삭제 (isActive 무관)
 *   2. quiz_schedule: 삭제된 문제를 포함하는 과거 스케줄 삭제
 *   3. quiz_meta/state: usedQuizIds 에서 삭제된 ID 제거 + 통계 재계산
 *   4. config/quiz_content: includeClinicalWithoutPack = false 설정
 *
 * 사용법:
 *   node tools/quiz_cleanup_old_clinical.cjs --dry-run
 *   node tools/quiz_cleanup_old_clinical.cjs --yes
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
  const out = { dryRun: false, yes: false };
  for (const a of argv.slice(2)) {
    if (a === "--dry-run") out.dryRun = true;
    if (a === "--yes") out.yes = true;
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

function quizQuestionType(d) {
  return d.questionType === "national_exam" ? "national_exam" : "clinical";
}

async function main() {
  const args = parseArgs(process.argv);

  if (!admin.apps.length) {
    admin.initializeApp({ credential: admin.credential.cert(loadServiceAccount()) });
  }
  const db = admin.firestore();

  // ── 1. config/quiz_content 읽기 → 현재 팩 ID 확인 ──
  const cfgSnap = await db.doc("config/quiz_content").get();
  const cfg = cfgSnap.exists ? cfgSnap.data() : {};
  const keepPackId = (cfg.currentClinicalPackId || "").trim();

  if (!keepPackId) {
    console.error("❌ config/quiz_content.currentClinicalPackId 가 비어있습니다. 먼저 설정하세요.");
    process.exit(1);
  }
  console.log("현재 임상 팩:", keepPackId);

  // ── 2. quiz_pool: 삭제 대상 수집 (isActive 무관, 현재 팩 아닌 임상 전체) ──
  const poolSnap = await db.collection("quiz_pool").get();
  const deleteRefs = [];
  const deleteIds = new Set();
  let keepCount = 0;
  let nationalCount = 0;

  for (const doc of poolSnap.docs) {
    const d = doc.data();
    const qType = quizQuestionType(d);
    if (qType === "national_exam") {
      nationalCount++;
      continue;
    }
    const pid = typeof d.packId === "string" ? d.packId.trim() : "";
    if (pid === keepPackId) {
      keepCount++;
      continue;
    }
    deleteRefs.push(doc.ref);
    deleteIds.add(doc.id);
  }

  console.log("\n── quiz_pool 요약 ──");
  console.log("국시(유지):", nationalCount);
  console.log("임상(유지, 현재 팩):", keepCount);
  console.log("임상(삭제 대상):", deleteRefs.length);

  // ── 3. quiz_schedule: 삭제된 문제를 포함하는 스케줄 수집 ──
  const schedSnap = await db.collection("quiz_schedule").get();
  const schedDeleteRefs = [];
  const schedKeepRefs = [];

  for (const doc of schedSnap.docs) {
    const d = doc.data();
    const ids = d.quizIds || [];
    const hasDeleted = ids.some((id) => deleteIds.has(id));
    if (hasDeleted) {
      schedDeleteRefs.push(doc.ref);
    } else {
      schedKeepRefs.push(doc.ref);
    }
  }

  console.log("\n── quiz_schedule 요약 ──");
  console.log("삭제 대상(이전 임상 포함):", schedDeleteRefs.length);
  console.log("유지:", schedKeepRefs.length);

  // ── 4. quiz_meta/state: usedQuizIds 정리 계획 ──
  const metaSnap = await db.doc("quiz_meta/state").get();
  const meta = metaSnap.exists ? metaSnap.data() : {};
  const usedIds = Array.isArray(meta.usedQuizIds) ? meta.usedQuizIds : [];
  const cleanedUsedIds = usedIds.filter((id) => !deleteIds.has(id));

  console.log("\n── quiz_meta/state 요약 ──");
  console.log("usedQuizIds 현재:", usedIds.length);
  console.log("usedQuizIds 정리 후:", cleanedUsedIds.length, "(삭제된 ID", usedIds.length - cleanedUsedIds.length, "건 제거)");

  // ── 5. 정리 후 통계 재계산 (삭제 대상 제외) ──
  const activePoolAfter = poolSnap.docs.filter((doc) => {
    if (deleteIds.has(doc.id)) return false;
    return doc.data().isActive === true;
  });
  const usedSet = new Set(cleanedUsedIds);
  let totalNational = 0, totalClinical = 0, usedNational = 0, usedClinical = 0;
  for (const doc of activePoolAfter) {
    const t = quizQuestionType(doc.data());
    if (t === "national_exam") {
      totalNational++;
      if (usedSet.has(doc.id)) usedNational++;
    } else {
      totalClinical++;
      if (usedSet.has(doc.id)) usedClinical++;
    }
  }

  console.log("\n── 정리 후 예상 통계 ──");
  console.log("활성 국시:", totalNational, "/ 사용:", usedNational);
  console.log("활성 임상:", totalClinical, "/ 사용:", usedClinical);
  console.log("활성 합계:", totalNational + totalClinical);

  if (args.dryRun) {
    console.log("\n✅ dry-run: 쓰기 없음");
    return;
  }

  if (!args.yes) {
    const summary = [
      `quiz_pool ${deleteRefs.length}건 삭제`,
      `quiz_schedule ${schedDeleteRefs.length}건 삭제`,
      `usedQuizIds ${usedIds.length - cleanedUsedIds.length}건 제거`,
      `config 업데이트`,
    ].join(", ");
    const ok = await askYes(`\n${summary}\n계속? (yes/no) `);
    if (!ok) { console.log("취소"); process.exit(0); }
  }

  // ── 실행 ──
  const BATCH = 450;

  // A. quiz_pool 삭제
  console.log("\n🗑️  quiz_pool 삭제 시작...");
  let done = 0;
  for (let i = 0; i < deleteRefs.length; i += BATCH) {
    const batch = db.batch();
    const chunk = deleteRefs.slice(i, i + BATCH);
    for (const ref of chunk) batch.delete(ref);
    await batch.commit();
    done += chunk.length;
    console.log("  …", done, "/", deleteRefs.length);
  }

  // B. quiz_schedule 삭제
  console.log("🗑️  quiz_schedule 삭제 시작...");
  done = 0;
  for (let i = 0; i < schedDeleteRefs.length; i += BATCH) {
    const batch = db.batch();
    const chunk = schedDeleteRefs.slice(i, i + BATCH);
    for (const ref of chunk) batch.delete(ref);
    await batch.commit();
    done += chunk.length;
    console.log("  …", done, "/", schedDeleteRefs.length);
  }

  // C. quiz_meta/state 업데이트
  console.log("📝 quiz_meta/state 업데이트...");
  await db.doc("quiz_meta/state").set({
    usedQuizIds: cleanedUsedIds,
    cycleCount: meta.cycleCount ?? 1,
    lastScheduledDate: meta.lastScheduledDate ?? "",
    dailyCount: meta.dailyCount ?? 2,
    totalActiveCount: totalNational + totalClinical,
    totalNationalActiveCount: totalNational,
    totalClinicalActiveCount: totalClinical,
    usedNationalCount: usedNational,
    usedClinicalCount: usedClinical,
  }, { merge: true });

  // D. config/quiz_content 업데이트
  console.log("📝 config/quiz_content 업데이트...");
  await db.doc("config/quiz_content").set({
    includeClinicalWithoutPack: false,
    includeNationalWithoutPack: false,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  console.log("\n✅ 완료");
  console.log("  quiz_pool 삭제:", deleteRefs.length);
  console.log("  quiz_schedule 삭제:", schedDeleteRefs.length);
  console.log("  활성 풀: 국시", totalNational, "+ 임상", totalClinical, "=", totalNational + totalClinical);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
