/**
 * rebuild_quiz_global_stats.js
 *
 * quiz_global/stats 의 정답률 분포와, 이번 주 quiz_global/weekly_{weekKey} 를
 * 모든 유저의 quizStats/summary 기반으로 재계산합니다.
 *
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

/** KST 달력 기준 요일: 월=1 … 일=7 (Dart weekday 와 동일) */
function kstWeekdayMon1Sun7() {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Seoul",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  })
    .formatToParts(new Date())
    .reduce((acc, p) => {
      if (p.type !== "literal") acc[p.type] = p.value;
      return acc;
    }, {});
  const y = parseInt(parts.year, 10);
  const m = parseInt(parts.month, 10);
  const d = parseInt(parts.day, 10);
  const jsSun0 = new Date(Date.UTC(y, m - 1, d)).getUTCDay();
  return jsSun0 === 0 ? 7 : jsSun0;
}

/** KST 기준 이번 주 월요일 dateKey (앱·saveAnswer 와 동일) */
function currentWeekKeyKst() {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Seoul",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  })
    .formatToParts(new Date())
    .reduce((acc, p) => {
      if (p.type !== "literal") acc[p.type] = p.value;
      return acc;
    }, {});
  const y = parseInt(parts.year, 10);
  const m = parseInt(parts.month, 10);
  const d = parseInt(parts.day, 10);
  const wd = kstWeekdayMon1Sun7();
  const monday = new Date(Date.UTC(y, m - 1, d));
  monday.setUTCDate(monday.getUTCDate() - (wd - 1));
  const yy = monday.getUTCFullYear();
  const mm = String(monday.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(monday.getUTCDate()).padStart(2, "0");
  return `${yy}-${mm}-${dd}`;
}

function accuracyPct(correct, wrong) {
  const t = (correct | 0) + (wrong | 0);
  if (t <= 0) return null;
  return Math.round((correct / t) * 100);
}

async function main() {
  console.log("========================================");
  console.log(" quiz_global 정답률·주간 분포 재계산");
  console.log("========================================\n");

  const weekKey = currentWeekKeyKst();
  console.log(`  이번 주 weekKey (KST 월요일): ${weekKey}\n`);

  console.log("[1/3] 유저 quizStats/summary 조회 중...");
  const usersSnap = await db.collection("users").get();
  const uids = usersSnap.docs.map((d) => d.id);
  console.log(`  유저 수: ${uids.length}명`);

  const accuracyDistribution = {};
  let totalParticipantsAccuracy = 0;

  const weeklyDistribution = {};
  let totalParticipantsWeekly = 0;

  let processedGlobal = 0;
  let processedWeekly = 0;

  for (const uid of uids) {
    const statsDoc = await db
      .collection("users")
      .doc(uid)
      .collection("quizStats")
      .doc("summary")
      .get();

    if (!statsDoc.exists) continue;
    const data = statsDoc.data();

    if (data.countedInGlobal !== true) continue;

    const totalCorrect = data.totalCorrect ?? 0;
    const totalWrong = data.totalWrong ?? 0;
    const pct = accuracyPct(totalCorrect, totalWrong);
    if (pct === null) continue;

    const key = String(pct);
    accuracyDistribution[key] = (accuracyDistribution[key] ?? 0) + 1;
    totalParticipantsAccuracy += 1;
    processedGlobal += 1;

    const wk = data.weekKey;
    const wc = data.weekCorrect ?? 0;
    const ww = data.weekWrong ?? 0;
    if (wk === weekKey) {
      const wpct = accuracyPct(wc, ww);
      if (wpct !== null) {
        const wkey = String(wpct);
        weeklyDistribution[wkey] = (weeklyDistribution[wkey] ?? 0) + 1;
        totalParticipantsWeekly += 1;
        processedWeekly += 1;
      }
    }
  }

  console.log(`  통산 집계 대상: ${processedGlobal}명`);
  console.log(
    `  accuracyDistribution: ${JSON.stringify(accuracyDistribution)}`
  );
  console.log(`  이번 주 집계 대상: ${processedWeekly}명`);
  console.log(
    `  weekly distribution: ${JSON.stringify(weeklyDistribution)}`
  );

  console.log("\n[2/3] quiz_global/stats 기록 중...");
  await db
    .collection("quiz_global")
    .doc("stats")
    .set(
      {
        totalParticipantsAccuracy,
        accuracyDistribution,
        lastUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  console.log(`  ✅ totalParticipantsAccuracy = ${totalParticipantsAccuracy}`);

  console.log("\n[3/3] quiz_global/weekly_* 기록 중...");
  await db
    .collection("quiz_global")
    .doc(`weekly_${weekKey}`)
    .set({
      weekKey,
      totalParticipantsWeekly,
      accuracyDistribution: weeklyDistribution,
      lastUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  console.log(`  ✅ weekly_${weekKey} totalParticipantsWeekly = ${totalParticipantsWeekly}`);

  console.log("\n========================================");
  console.log(" ✅ 재계산 완료");
  console.log(
    " ℹ️  유저 summary 의 countedInGlobalAccuracy 는 다음 퀴즈 응답 시 자동 갱신됩니다."
  );
  console.log("========================================");
  process.exit(0);
}

main().catch((err) => {
  console.error("❌ 오류 발생:", err);
  process.exit(1);
});
