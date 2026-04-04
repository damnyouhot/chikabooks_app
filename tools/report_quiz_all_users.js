/**
 * report_quiz_all_users.js
 *
 * 모든 계정의 퀴즈 성적·순위·상위%를 앱과 동일한 규칙으로 출력합니다.
 *
 *   node tools/report_quiz_all_users.js
 */

const fs = require("fs");
const path = require("path");

const projectRoot = path.join(__dirname, "..");
const functionsDir = path.join(projectRoot, "functions");
const adminModulePath = path.join(functionsDir, "node_modules", "firebase-admin");

if (!fs.existsSync(adminModulePath)) {
  console.error(
    "❌ firebase-admin 을 찾을 수 없습니다.\n   cd functions && npm install"
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

function computeRank(totalCorrect, distribution) {
  let peopleAboveMe = 0;
  for (const [key, val] of Object.entries(distribution)) {
    const score = parseInt(key, 10);
    if (Number.isNaN(score)) continue;
    if (score > totalCorrect) {
      peopleAboveMe += typeof val === "number" ? val : (val | 0);
    }
  }
  return peopleAboveMe + 1;
}

function formatTopPct(rank, totalUsers) {
  if (totalUsers <= 0) return "0";
  const raw = Math.min(100, Math.max(0, (rank / totalUsers) * 100));
  return raw >= 10 ? raw.toFixed(1) : raw.toFixed(2);
}

async function main() {
  const globalSnap = await db.collection("quiz_global").doc("stats").get();
  let totalParticipants = 1;
  let distribution = {};

  if (globalSnap.exists) {
    const g = globalSnap.data() || {};
    totalParticipants = Math.max(1, (g.totalParticipants ?? 1) | 0);
    distribution = { ...(g.scoreDistribution || {}) };
  }

  const usersSnap = await db.collection("users").get();
  const rows = [];

  for (const userDoc of usersSnap.docs) {
    const uid = userDoc.id;
    const uData = userDoc.data() || {};
    const label =
      (uData.email && String(uData.email).trim()) ||
      (uData.displayName && String(uData.displayName).trim()) ||
      uid.slice(0, 8) + "…";

    const statsSnap = await db
      .collection("users")
      .doc(uid)
      .collection("quizStats")
      .doc("summary")
      .get();

    if (!statsSnap.exists) {
      rows.push({
        uid,
        label,
        hasStats: false,
        totalCorrect: null,
        totalWrong: null,
        countedInGlobal: null,
        rank: null,
        topPct: null,
      });
      continue;
    }

    const s = statsSnap.data() || {};
    const totalCorrect = (s.totalCorrect ?? 0) | 0;
    const totalWrong = (s.totalWrong ?? 0) | 0;
    const countedInGlobal = s.countedInGlobal === true;

    const rank = computeRank(totalCorrect, distribution);
    const topPct = formatTopPct(rank, totalParticipants);

    rows.push({
      uid,
      label,
      hasStats: true,
      totalCorrect,
      totalWrong,
      countedInGlobal,
      rank,
      topPct,
    });
  }

  console.log("========================================");
  console.log(" 퀴즈 성적 / 순위 / 상위% (앱과 동일 규칙)");
  console.log("========================================");
  console.log(
    ` quiz_global/stats: totalParticipants=${totalParticipants}, distribution=${JSON.stringify(distribution)}`
  );
  console.log("");

  rows.sort((a, b) => {
    if (!a.hasStats && !b.hasStats) return a.label.localeCompare(b.label);
    if (!a.hasStats) return 1;
    if (!b.hasStats) return -1;
    return b.totalCorrect - a.totalCorrect || a.rank - b.rank;
  });

  console.log(
    [
      "이메일/표시".padEnd(28),
      "정답".padStart(4),
      "오답".padStart(4),
      "글로벌집계".padStart(8),
      "순위".padStart(6),
      "상위%".padStart(8),
      "uid(앞8자)",
    ].join("  ")
  );
  console.log("-".repeat(100));

  for (const r of rows) {
    if (!r.hasStats) {
      console.log(
        [
          r.label.slice(0, 26).padEnd(28),
          "-".padStart(4),
          "-".padStart(4),
          "-".padStart(8),
          "-".padStart(6),
          "-".padStart(8),
          r.uid.slice(0, 8),
        ].join("  ")
      );
      continue;
    }
    console.log(
      [
        r.label.slice(0, 26).padEnd(28),
        String(r.totalCorrect).padStart(4),
        String(r.totalWrong).padStart(4),
        (r.countedInGlobal ? "Y" : "N").padStart(8),
        String(r.rank).padStart(6),
        (r.topPct + "%").padStart(8),
        r.uid.slice(0, 8),
      ].join("  ")
    );
  }

  console.log("");
  console.log("※ 순위 = (나보다 누적 정답이 많은 사람 수) + 1");
  console.log("※ 상위% = (순위 / 전체 참가자) × 100  (앱 카드와 동일)");
  console.log("========================================");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
