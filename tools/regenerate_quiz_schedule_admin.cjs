/**
 * quiz_schedule/{dateKey} 를 manualScheduleQuiz(forceReplace) 와 동일 로직으로 재생성
 * (서비스 계정 — 어드민 로그인 불필요)
 *
 *   cd functions
 *   node ../tools/regenerate_quiz_schedule_admin.cjs
 *   node ../tools/regenerate_quiz_schedule_admin.cjs --date=2026-03-25
 *   node ../tools/regenerate_quiz_schedule_admin.cjs --dry-run
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

function shuffleArray(arr) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

function toDateKey(date) {
  const kst = new Date(date.getTime() + 9 * 60 * 60 * 1000);
  const yyyy = kst.getUTCFullYear();
  const mm = String(kst.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(kst.getUTCDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

function quizQuestionType(data) {
  return data.questionType === "national_exam" ? "national_exam" : "clinical";
}

async function loadQuizContentConfig(db) {
  const snap = await db.doc("config/quiz_content").get();
  const d = snap.exists ? snap.data() : {};
  return {
    currentClinicalPackId:
      typeof d.currentClinicalPackId === "string" ? d.currentClinicalPackId.trim() : "",
    includeClinicalWithoutPack: d.includeClinicalWithoutPack !== false,
    currentNationalPackId:
      typeof d.currentNationalPackId === "string" ? d.currentNationalPackId.trim() : "",
    includeNationalWithoutPack: d.includeNationalWithoutPack !== false,
  };
}

function clinicalMatchesContentPack(data, cfg) {
  if (quizQuestionType(data) !== "clinical") return true;
  if (!cfg.currentClinicalPackId) return true;
  const pid = typeof data.packId === "string" ? data.packId.trim() : "";
  if (!pid) return cfg.includeClinicalWithoutPack;
  return pid === cfg.currentClinicalPackId;
}

function nationalMatchesContentPack(data, cfg) {
  if (quizQuestionType(data) !== "national_exam") return true;
  if (!cfg.currentNationalPackId) return true;
  const pid = typeof data.packId === "string" ? data.packId.trim() : "";
  if (!pid) return cfg.includeNationalWithoutPack;
  return pid === cfg.currentNationalPackId;
}

function poolDocMatchesContentPacks(data, cfg) {
  return clinicalMatchesContentPack(data, cfg) && nationalMatchesContentPack(data, cfg);
}

function computeQuizMetaAnalytics(poolSnap, usedQuizIds, contentCfg) {
  const used = new Set(usedQuizIds);
  let totalNational = 0;
  let totalClinical = 0;
  let usedNational = 0;
  let usedClinical = 0;
  for (const doc of poolSnap.docs) {
    if (!poolDocMatchesContentPacks(doc.data(), contentCfg)) continue;
    const t = quizQuestionType(doc.data());
    if (t === "national_exam") {
      totalNational++;
      if (used.has(doc.id)) usedNational++;
    } else {
      totalClinical++;
      if (used.has(doc.id)) usedClinical++;
    }
  }
  return {
    totalActiveCount: totalNational + totalClinical,
    totalNationalActiveCount: totalNational,
    totalClinicalActiveCount: totalClinical,
    usedNationalCount: usedNational,
    usedClinicalCount: usedClinical,
  };
}

function buildScheduleItem(doc, nextCycleCount) {
  const data = doc.data();
  const packVersion =
    typeof data.packVersion === "number" && Number.isFinite(data.packVersion)
      ? data.packVersion
      : 0;
  return {
    id: doc.id,
    order: data.order ?? 0,
    question: data.question ?? "",
    options: data.options ?? [],
    correctIndex: data.correctIndex ?? 0,
    explanation: data.explanation ?? "",
    category: data.category ?? "",
    difficulty: data.difficulty ?? "basic",
    sourceBook: data.sourceBook ?? "",
    sourceFileName: data.sourceFileName ?? "",
    sourcePage: data.sourcePage ?? "",
    sourceName: data.sourceName ?? "",
    isActive: true,
    lastCycleServed: nextCycleCount,
    questionType: quizQuestionType(data),
    packId: typeof data.packId === "string" ? data.packId : "",
    packVersion,
  };
}

async function pickTodayQuizzes(db, meta, contentCfg) {
  const usedQuizIds = meta.usedQuizIds ?? [];
  const cycleCount = meta.cycleCount ?? 1;

  const poolSnap = await db.collection("quiz_pool").where("isActive", "==", true).get();
  const allDocs = poolSnap.docs.filter((d) => poolDocMatchesContentPacks(d.data(), contentCfg));

  const trySelect = (used) => {
    const national = shuffleArray(
      allDocs.filter(
        (d) => quizQuestionType(d.data()) === "national_exam" && !used.includes(d.id),
      ),
    );
    const clinical = shuffleArray(
      allDocs.filter((d) => quizQuestionType(d.data()) === "clinical" && !used.includes(d.id)),
    );

    if (national.length >= 1 && clinical.length >= 1) {
      const n = national[0];
      const nBook = (n.data().sourceBook || "").toString();
      const clinDiff = clinical.filter((d) => (d.data().sourceBook || "").toString() !== nBook);
      const pool = clinDiff.length ? clinDiff : clinical;
      const c = pool[0];
      return { selected: [n, c], ok: true };
    }

    if (national.length === 0 && clinical.length >= 2) {
      const byBook = {};
      for (const d of clinical) {
        const b = (d.data().sourceBook || "_").toString();
        if (!byBook[b]) byBook[b] = [];
        byBook[b].push(d);
      }
      const bookKeys = shuffleArray(Object.keys(byBook));
      if (bookKeys.length >= 2) {
        return { selected: [byBook[bookKeys[0]][0], byBook[bookKeys[1]][0]], ok: true };
      }
      return { selected: [clinical[0], clinical[1]], ok: true };
    }

    return { selected: [], ok: false };
  };

  let wasReset = false;
  let nextCycle = cycleCount;
  let nextUsed = [...usedQuizIds];

  let { selected, ok } = trySelect(nextUsed);

  if (!ok || selected.length < 2) {
    wasReset = true;
    nextCycle = cycleCount + 1;
    nextUsed = [];
    ({ selected, ok } = trySelect(nextUsed));
  }

  if (!ok || selected.length < 2) {
    return { selectedDocs: selected, nextCycleCount: nextCycle, nextUsedQuizIds: nextUsed, wasReset };
  }

  nextUsed = [...new Set([...nextUsed, ...selected.map((d) => d.id)])];

  return { selectedDocs: selected, nextCycleCount: nextCycle, nextUsedQuizIds: nextUsed, wasReset };
}

async function main() {
  const argv = process.argv.slice(2);
  const dryRun = argv.includes("--dry-run");
  let dateKey = "";
  for (const a of argv) {
    if (a.startsWith("--date=")) dateKey = a.slice(7).trim();
  }
  if (!dateKey) dateKey = toDateKey(new Date());

  if (!admin.apps.length) {
    admin.initializeApp({ credential: admin.credential.cert(loadServiceAccount()) });
  }
  const db = admin.firestore();
  const metaRef = db.doc("quiz_meta/state");
  const scheduleRef = db.collection("quiz_schedule").doc(dateKey);

  const contentCfg = await loadQuizContentConfig(db);
  const metaDoc = await metaRef.get();
  const meta = metaDoc.exists ? metaDoc.data() : {};
  const dailyCount = meta.dailyCount ?? 2;

  const { selectedDocs, nextCycleCount, nextUsedQuizIds, wasReset } = await pickTodayQuizzes(
    db,
    meta,
    contentCfg,
  );

  if (selectedDocs.length === 0) {
    console.error("❌ 선정된 문제 없음");
    process.exit(1);
  }

  const quizIds = selectedDocs.map((d) => d.id);
  const items = selectedDocs.map((d) => buildScheduleItem(d, nextCycleCount));

  console.log("📅 dateKey:", dateKey);
  console.log("📌 선정 quizIds:", quizIds);
  console.log(
    "📌 요약:",
    items.map((it) => ({
      type: it.questionType,
      packId: it.packId,
      q: String(it.question).slice(0, 48) + (it.question.length > 48 ? "…" : ""),
      options: (it.options || []).length,
    })),
  );

  if (dryRun) {
    console.log("✅ dry-run — Firestore 쓰기 없음");
    return;
  }

  await scheduleRef.set({
    quizIds,
    items,
    cycleCount: nextCycleCount,
    startOrder: selectedDocs[0].data().order ?? 0,
    endOrder: selectedDocs[selectedDocs.length - 1].data().order ?? 0,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const batch = db.batch();
  for (const doc of selectedDocs) {
    batch.update(doc.ref, {
      lastCycleServed: nextCycleCount,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();

  const poolSnap = await db.collection("quiz_pool").where("isActive", "==", true).get();
  const analytics = computeQuizMetaAnalytics(poolSnap, nextUsedQuizIds, contentCfg);

  await metaRef.set(
    {
      cycleCount: nextCycleCount,
      lastScheduledDate: dateKey,
      dailyCount,
      usedQuizIds: nextUsedQuizIds,
      ...analytics,
    },
    { merge: true },
  );

  console.log("✅ quiz_schedule 재생성 완료", { wasReset, cycleCount: nextCycleCount });
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
