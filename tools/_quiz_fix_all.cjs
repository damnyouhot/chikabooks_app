/**
 * 퀴즈 데이터 종합 정리 스크립트
 *
 * 1. quiz_schedule: questionType이 없거나 삭제된 문제를 참조하는 스케줄 삭제
 * 2. quiz_schedule: 오늘 스케줄 재생성 (국시 1 + 임상 1)
 * 3. quiz_meta/state: usedQuizIds에서 현재 활성 풀에 없는 ID 제거 + 통계 재계산
 * 4. config/quiz_content: includeClinicalWithoutPack, includeNationalWithoutPack = false 설정
 *
 * 사용법:
 *   node tools/_quiz_fix_all.cjs --dry-run
 *   node tools/_quiz_fix_all.cjs --yes
 */

const fs = require("fs");
const path = require("path");

const functionsDir = path.join(__dirname, "../functions");
const admin = require(path.join(functionsDir, "node_modules/firebase-admin"));

function initFirebase() {
  if (admin.apps.length) return;
  const saPath = path.join(functionsDir, "serviceAccountKey.json");
  if (fs.existsSync(saPath)) {
    admin.initializeApp({ credential: admin.credential.cert(JSON.parse(fs.readFileSync(saPath, "utf8"))) });
    return;
  }
  const cfgPath = path.join(require("os").homedir(), ".config/configstore/firebase-tools.json");
  if (!fs.existsSync(cfgPath)) {
    console.error("❌ Firebase 인증 없음.");
    process.exit(1);
  }
  const cfg = JSON.parse(fs.readFileSync(cfgPath, "utf8"));
  const rt = cfg.tokens && cfg.tokens.refresh_token;
  if (!rt) {
    console.error("❌ refresh_token 없음.");
    process.exit(1);
  }
  const adcPath = "/tmp/_quiz_fix_adc.json";
  fs.writeFileSync(adcPath, JSON.stringify({
    type: "authorized_user",
    client_id: cfg.tokens.client_id || "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com",
    client_secret: cfg.tokens.client_secret || "j9iVZfS8kkCEFUPaAeJV0sAi",
    refresh_token: rt,
  }));
  process.env.GOOGLE_APPLICATION_CREDENTIALS = adcPath;
  admin.initializeApp({ credential: admin.credential.applicationDefault(), projectId: "chikabooks3rd" });
}

function kstDateKey(d = new Date()) {
  const kst = new Date(d.getTime() + 9 * 60 * 60 * 1000);
  return `${kst.getUTCFullYear()}-${String(kst.getUTCMonth() + 1).padStart(2, "0")}-${String(kst.getUTCDate()).padStart(2, "0")}`;
}

function quizQuestionType(data) {
  return data.questionType === "national_exam" ? "national_exam" : "clinical";
}

function shuffleArray(arr) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

function loadQuizContentConfig(d) {
  return {
    currentClinicalPackId: typeof d.currentClinicalPackId === "string" ? d.currentClinicalPackId.trim() : "",
    includeClinicalWithoutPack: d.includeClinicalWithoutPack === true,
    currentNationalPackId: typeof d.currentNationalPackId === "string" ? d.currentNationalPackId.trim() : "",
    includeNationalWithoutPack: d.includeNationalWithoutPack === true,
  };
}

function poolDocMatchesContentPacks(data, cfg) {
  const qt = quizQuestionType(data);
  const pid = typeof data.packId === "string" ? data.packId.trim() : "";
  if (qt === "clinical") {
    if (!cfg.currentClinicalPackId) return true;
    if (!pid) return cfg.includeClinicalWithoutPack;
    return pid === cfg.currentClinicalPackId;
  }
  if (qt === "national_exam") {
    if (!cfg.currentNationalPackId) return true;
    if (!pid) return cfg.includeNationalWithoutPack;
    return pid === cfg.currentNationalPackId;
  }
  return true;
}

function buildScheduleItem(doc, nextCycleCount) {
  const data = doc.data();
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
    packVersion: typeof data.packVersion === "number" ? data.packVersion : 0,
  };
}

async function main() {
  const argv = process.argv.slice(2);
  const dryRun = !argv.includes("--yes");

  initFirebase();
  const db = admin.firestore();
  const today = kstDateKey();

  console.log(`날짜: ${today}  모드: ${dryRun ? "DRY-RUN" : "실행"}\n`);

  // ── 0. 활성 풀 로드 ──
  const poolSnap = await db.collection("quiz_pool").where("isActive", "==", true).get();
  const activeIds = new Set(poolSnap.docs.map((d) => d.id));
  console.log(`활성 quiz_pool: ${activeIds.size}개\n`);

  // ── 0-1. config 로드 ──
  const cfgSnap = await db.doc("config/quiz_content").get();
  const cfgData = cfgSnap.exists ? cfgSnap.data() : {};
  const contentCfg = loadQuizContentConfig(cfgData);

  // ── 1. 잘못된 스케줄 식별 ──
  const schedulesSnap = await db.collection("quiz_schedule").get();
  const badSchedules = [];
  for (const doc of schedulesSnap.docs) {
    const data = doc.data();
    const items = data.items || [];
    let isBad = false;
    for (const it of items) {
      if (!it.questionType || !activeIds.has(it.id)) {
        isBad = true;
        break;
      }
    }
    if (isBad) badSchedules.push(doc.id);
  }

  console.log("── 스케줄 정리 ──");
  console.log(`전체 스케줄: ${schedulesSnap.size}개`);
  console.log(`삭제 대상 (questionType 없음 or 삭제된 문제): ${badSchedules.length}개`);
  if (badSchedules.length > 0) {
    console.log(`  삭제할 날짜: ${badSchedules.join(", ")}`);
  }

  if (!dryRun && badSchedules.length > 0) {
    for (const dateKey of badSchedules) {
      await db.collection("quiz_schedule").doc(dateKey).delete();
    }
    console.log(`  ✅ ${badSchedules.length}개 스케줄 삭제 완료`);
  }

  // ── 2. 오늘 스케줄 재생성 ──
  console.log("\n── 오늘 스케줄 재생성 ──");

  const metaDoc = await db.doc("quiz_meta/state").get();
  const meta = metaDoc.exists ? metaDoc.data() : {};
  const currentUsedIds = Array.isArray(meta.usedQuizIds) ? meta.usedQuizIds : [];

  // 활성 풀에서 팩 필터 적용
  const filteredDocs = poolSnap.docs.filter((d) => poolDocMatchesContentPacks(d.data(), contentCfg));
  // 현재 usedQuizIds에서 활성 ID만 남기기
  const cleanUsedIds = currentUsedIds.filter((id) => activeIds.has(id));

  const national = shuffleArray(
    filteredDocs.filter((d) => quizQuestionType(d.data()) === "national_exam" && !cleanUsedIds.includes(d.id))
  );
  const clinical = shuffleArray(
    filteredDocs.filter((d) => quizQuestionType(d.data()) === "clinical" && !cleanUsedIds.includes(d.id))
  );

  console.log(`  필터된 국시 미사용: ${national.length}개`);
  console.log(`  필터된 임상 미사용: ${clinical.length}개`);

  if (national.length < 1 || clinical.length < 1) {
    console.error("  ❌ 국시 또는 임상 미사용 문제가 부족합니다!");
    process.exit(1);
  }

  const n = national[0];
  const nBook = (n.data().sourceBook || "").toString();
  const clinDiff = clinical.filter((d) => (d.data().sourceBook || "").toString() !== nBook);
  const c = (clinDiff.length > 0 ? clinDiff : clinical)[0];

  const selected = [n, c];
  const cycleCount = meta.cycleCount ?? 1;
  const quizIds = selected.map((d) => d.id);
  const items = selected.map((d) => buildScheduleItem(d, cycleCount));

  console.log(`  선정된 문제:`);
  items.forEach((it) => {
    console.log(`    ${it.questionType} | ${it.category} | packId=${it.packId} | ${(it.question || "").substring(0, 50)}...`);
  });

  if (!dryRun) {
    await db.collection("quiz_schedule").doc(today).set({
      quizIds,
      items,
      cycleCount,
      startOrder: selected[0].data().order ?? 0,
      endOrder: selected[selected.length - 1].data().order ?? 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const batch = db.batch();
    for (const doc of selected) {
      batch.update(doc.ref, {
        lastCycleServed: cycleCount,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    console.log("  ✅ 오늘 스케줄 재생성 완료");
  }

  // ── 3. usedQuizIds 정리 + 통계 재계산 ──
  console.log("\n── usedQuizIds 정리 ──");

  const newUsedIds = [...new Set([...cleanUsedIds, ...quizIds])];
  const removedCount = currentUsedIds.length - cleanUsedIds.length;

  const used = new Set(newUsedIds);
  let totalNational = 0, totalClinical = 0, usedNational = 0, usedClinical = 0;
  for (const doc of filteredDocs) {
    const t = quizQuestionType(doc.data());
    if (t === "national_exam") { totalNational++; if (used.has(doc.id)) usedNational++; }
    else { totalClinical++; if (used.has(doc.id)) usedClinical++; }
  }

  console.log(`  기존 usedQuizIds: ${currentUsedIds.length}개`);
  console.log(`  비활성 ID 제거: ${removedCount}개`);
  console.log(`  정리 후 usedQuizIds: ${newUsedIds.length}개`);
  console.log(`  국시: 활성 ${totalNational} / 사용 ${usedNational}`);
  console.log(`  임상: 활성 ${totalClinical} / 사용 ${usedClinical}`);
  console.log(`  합계: 활성 ${totalNational + totalClinical} / 사용 ${usedNational + usedClinical}`);

  if (!dryRun) {
    await db.doc("quiz_meta/state").set({
      cycleCount,
      lastScheduledDate: today,
      dailyCount: meta.dailyCount ?? 2,
      usedQuizIds: newUsedIds,
      totalActiveCount: totalNational + totalClinical,
      totalNationalActiveCount: totalNational,
      totalClinicalActiveCount: totalClinical,
      usedNationalCount: usedNational,
      usedClinicalCount: usedClinical,
    }, { merge: true });
    console.log("  ✅ quiz_meta/state 업데이트 완료");
  }

  // ── 4. config/quiz_content 업데이트 ──
  console.log("\n── config/quiz_content ──");
  const needClinicalField = cfgData.includeClinicalWithoutPack === undefined;
  const needNationalField = cfgData.includeNationalWithoutPack === undefined;
  console.log(`  includeClinicalWithoutPack: ${JSON.stringify(cfgData.includeClinicalWithoutPack)} ${needClinicalField ? "→ false (추가)" : "(이미 설정됨)"}`);
  console.log(`  includeNationalWithoutPack: ${JSON.stringify(cfgData.includeNationalWithoutPack)} ${needNationalField ? "→ false (추가)" : "(이미 설정됨)"}`);

  if (!dryRun && (needClinicalField || needNationalField)) {
    const updates = {};
    if (needClinicalField) updates.includeClinicalWithoutPack = false;
    if (needNationalField) updates.includeNationalWithoutPack = false;
    updates.updatedAt = admin.firestore.FieldValue.serverTimestamp();
    await db.doc("config/quiz_content").set(updates, { merge: true });
    console.log("  ✅ config/quiz_content 업데이트 완료");
  }

  console.log(`\n${dryRun ? "✅ DRY-RUN 완료 — 실행하려면 --yes 옵션 사용" : "✅ 모든 작업 완료!"}`);
}

main().catch((e) => { console.error(e); process.exit(1); });
