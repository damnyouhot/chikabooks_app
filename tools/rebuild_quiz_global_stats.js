/**
 * rebuild_quiz_global_stats.js
 *
 * quiz_global/stats 문서를 현재 모든 유저의 quizStats/summary 기반으로 재계산합니다.
 *
 * ■ 필요한 상황:
 *   - cleanup_all_users.js 를 quiz_global/stats 리셋 없이 실행한 경우
 *   - 퀴즈 순위 퍼센테이지가 항상 같은 값으로 고정되어 변하지 않을 때
 *
 * ■ 실행:
 *   node tools/rebuild_quiz_global_stats.js
 */

const fs = require("fs");
const path = require("path");

const projectRoot = path.join(__dirname, "..");
const functionsDir = path.join(projectRoot, "functions");
const adminModulePath = path.join(functionsDir, "node_modules", "firebase-admin");

if (!fs.existsSync(adminModulePath)) {
  console.error(
    "❌ firebase-admin 을 찾을 수 없습니다. 다음을 실행하세요:\n" +
      "   cd functions && npm install"
  );
  process.exit(1);
}

const admin = require(adminModulePath);

function initAdmin() {
  const envPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const defaultPath = path.join(functionsDir, "serviceAccountKey.json");
  const keyPath = envPath && fs.existsSync(envPath) ? envPath : defaultPath;

  if (fs.existsSync(keyPath)) {
    const serviceAccount = JSON.parse(fs.readFileSync(keyPath, "utf8"));
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    return;
  }
  admin.initializeApp({ projectId: "chikabooks3rd" });
}

initAdmin();
const db = admin.firestore();

async function main() {
  console.log("========================================");
  console.log(" quiz_global/stats 재계산 스크립트");
  console.log("========================================\n");

  // 1. 모든 유저의 quizStats/summary 조회
  console.log("[1/3] 유저 quizStats/summary 조회 중...");
  const usersSnap = await db.collection("users").get();
  const uids = usersSnap.docs.map((d) => d.id);
  console.log(`  유저 수: ${uids.length}명`);

  const scoreDistribution = {};
  let totalParticipants = 0;
  let processedCount = 0;

  for (const uid of uids) {
    const statsDoc = await db
      .collection("users")
      .doc(uid)
      .collection("quizStats")
      .doc("summary")
      .get();

    if (!statsDoc.exists) continue;
    const data = statsDoc.data();

    // countedInGlobal = true 인 유저만 집계 대상
    if (data.countedInGlobal !== true) continue;

    const totalCorrect = (data.totalCorrect ?? 0);
    const key = String(totalCorrect);

    scoreDistribution[key] = (scoreDistribution[key] ?? 0) + 1;
    totalParticipants += 1;
    processedCount++;
  }

  console.log(`  집계 대상 유저 (countedInGlobal=true): ${processedCount}명`);
  console.log(`  scoreDistribution: ${JSON.stringify(scoreDistribution)}`);

  // 2. quiz_global/stats 덮어쓰기
  console.log("\n[2/3] quiz_global/stats 재기록 중...");
  await db.collection("quiz_global").doc("stats").set({
    totalParticipants,
    scoreDistribution,
    lastUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log(`  ✅ totalParticipants = ${totalParticipants}`);
  console.log(`  ✅ scoreDistribution = ${JSON.stringify(scoreDistribution)}`);

  // 3. countedInGlobal = false 인 유저들 확인 (미집계 유저 안내)
  console.log("\n[3/3] countedInGlobal = false 유저 확인 중...");
  let notCountedCount = 0;
  for (const uid of uids) {
    const statsDoc = await db
      .collection("users")
      .doc(uid)
      .collection("quizStats")
      .doc("summary")
      .get();
    if (statsDoc.exists && statsDoc.data().countedInGlobal !== true) {
      notCountedCount++;
    }
  }
  console.log(
    `  ℹ️  미집계 유저 수 (아직 퀴즈 미참여 또는 countedInGlobal=false): ${notCountedCount}명`
  );
  console.log("     → 이 유저들은 다음 번 퀴즈를 풀 때 자동으로 집계에 추가됩니다.");

  console.log("\n========================================");
  console.log(" ✅ 재계산 완료");
  console.log(`  totalParticipants : ${totalParticipants}`);
  console.log(`  scoreDistribution : ${JSON.stringify(scoreDistribution)}`);
  console.log("========================================");
  process.exit(0);
}

main().catch((err) => {
  console.error("❌ 오류 발생:", err);
  process.exit(1);
});
