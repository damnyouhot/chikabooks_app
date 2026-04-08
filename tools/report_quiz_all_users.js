/**
 * report_quiz_all_users.js
 *
 * 모든 계정의 퀴즈 성적·순위·상위%를 앱과 동일한 규칙(정답률)으로 출력합니다.
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
  const jsSun0 = new Date(Date.UTC(y, m - 1, d)).getUTCDay();
  const wd = jsSun0 === 0 ? 7 : jsSun0;
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

function computeRankAccuracy(myPct, distribution) {
  let peopleAboveMe = 0;
  for (const [key, val] of Object.entries(distribution)) {
    const score = parseInt(key, 10);
    if (Number.isNaN(score)) continue;
    if (score > myPct) {
      peopleAboveMe += typeof val === "number" ? val : val | 0;
    }
  }
  return peopleAboveMe + 1;
}

function formatTopPct(rank, totalUsers) {
  if (totalUsers <= 0) return "—";
  const raw = Math.min(100, Math.max(0, (rank / totalUsers) * 100));
  return raw >= 10 ? raw.toFixed(1) : raw.toFixed(2);
}

async function main() {
  const weekKey = currentWeekKeyKst();

  const globalSnap = await db.collection("quiz_global").doc("stats").get();
  let totalParticipantsAll = 0;
  let distAll = {};

  if (globalSnap.exists) {
    const g = globalSnap.data() || {};
    totalParticipantsAll = (g.totalParticipantsAccuracy ?? 0) | 0;
    distAll = { ...(g.accuracyDistribution || {}) };
  }

  const weeklySnap = await db
    .collection("quiz_global")
    .doc(`weekly_${weekKey}`)
    .get();
  let totalParticipantsWeek = 0;
  let distWeek = {};

  if (weeklySnap.exists) {
    const w = weeklySnap.data() || {};
    totalParticipantsWeek = (w.totalParticipantsWeekly ?? 0) | 0;
    distWeek = { ...(w.accuracyDistribution || {}) };
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
        rankAll: null,
        topPctAll: null,
        rankWeek: null,
        topPctWeek: null,
      });
      continue;
    }

    const s = statsSnap.data() || {};
    const totalCorrect = (s.totalCorrect ?? 0) | 0;
    const totalWrong = (s.totalWrong ?? 0) | 0;
    const countedInGlobal = s.countedInGlobal === true;

    const pctAll = accuracyPct(totalCorrect, totalWrong);
    const rankAll =
      pctAll === null ? null : computeRankAccuracy(pctAll, distAll);
    const topPctAll =
      pctAll === null ? null : formatTopPct(rankAll, totalParticipantsAll);

    const sameWeek = s.weekKey === weekKey;
    const wc = sameWeek ? (s.weekCorrect ?? 0) | 0 : 0;
    const ww = sameWeek ? (s.weekWrong ?? 0) | 0 : 0;
    const pctWeek = accuracyPct(wc, ww);
    const rankWeek =
      pctWeek === null ? null : computeRankAccuracy(pctWeek, distWeek);
    const topPctWeek =
      pctWeek === null ? null : formatTopPct(rankWeek, totalParticipantsWeek);

    rows.push({
      uid,
      label,
      hasStats: true,
      totalCorrect,
      totalWrong,
      countedInGlobal,
      rankAll,
      topPctAll,
      rankWeek,
      topPctWeek,
    });
  }

  console.log("========================================");
  console.log(" 퀴즈 성적 / 순위 / 상위% (정답률 기준)");
  console.log("========================================");
  console.log(
    ` 주간 weekKey=${weekKey} | 통산 참가자=${totalParticipantsAll}, 주간 참가자=${totalParticipantsWeek}`
  );
  console.log("");

  rows.sort((a, b) => {
    if (!a.hasStats && !b.hasStats) return a.label.localeCompare(b.label);
    if (!a.hasStats) return 1;
    if (!b.hasStats) return -1;
    const pa = accuracyPct(a.totalCorrect, a.totalWrong) ?? -1;
    const pb = accuracyPct(b.totalCorrect, b.totalWrong) ?? -1;
    return pb - pa || (a.rankAll ?? 0) - (b.rankAll ?? 0);
  });

  console.log(
    [
      "이메일/표시".padEnd(26),
      "정답".padStart(4),
      "오답".padStart(4),
      "집계".padStart(4),
      "통산순".padStart(6),
      "통산%".padStart(7),
      "주간순".padStart(6),
      "주간%".padStart(7),
      "uid(앞8)",
    ].join("  ")
  );
  console.log("-".repeat(110));

  for (const r of rows) {
    if (!r.hasStats) {
      console.log(
        [
          r.label.slice(0, 24).padEnd(26),
          "-".padStart(4),
          "-".padStart(4),
          "-".padStart(4),
          "-".padStart(6),
          "-".padStart(7),
          "-".padStart(6),
          "-".padStart(7),
          r.uid.slice(0, 8),
        ].join("  ")
      );
      continue;
    }
    console.log(
      [
        r.label.slice(0, 24).padEnd(26),
        String(r.totalCorrect).padStart(4),
        String(r.totalWrong).padStart(4),
        (r.countedInGlobal ? "Y" : "N").padStart(4),
        String(r.rankAll ?? "—").padStart(6),
        ((r.topPctAll != null ? r.topPctAll + "%" : "—")).padStart(7),
        String(r.rankWeek ?? "—").padStart(6),
        ((r.topPctWeek != null ? r.topPctWeek + "%" : "—")).padStart(7),
        r.uid.slice(0, 8),
      ].join("  ")
    );
  }

  console.log("");
  console.log("※ 통산·주간 순위 = (나보다 정답률이 높은 사람 수) + 1");
  console.log("※ 상위% = (순위 / 해당 참가자 수) × 100");
  console.log("========================================");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
