/**
 * 컷오버 후 검증 (서비스 계정 필요)
 *
 *   node ../tools/quiz_cutover_verify.cjs --pack-id=clinical_xxx
 *   node ../tools/quiz_cutover_verify.cjs --pack-id=clinical_xxx --schedule-date=2026-03-25
 *
 * 출력:
 *   - config/quiz_content
 *   - quiz_pool: 해당 packId + clinical + isActive 건수
 *   - (선택) quiz_schedule/{date}: items별 questionType, packId, packVersion
 *
 * --schedule-date 생략 시 오늘(KST) 날짜 키 사용
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
    console.error("❌ 서비스 계정 JSON 없음:", p);
    console.error("   GOOGLE_APPLICATION_CREDENTIALS 또는 functions/serviceAccountKey.json 설정 후 실행하세요.");
    process.exit(1);
  }
  return JSON.parse(fs.readFileSync(keyPath, "utf8"));
}

function kstDateKey(d = new Date()) {
  const fmt = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Seoul",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  const parts = Object.fromEntries(fmt.formatToParts(d).map((x) => [x.type, x.value]));
  return `${parts.year}-${parts.month}-${parts.day}`;
}

function parseArgs(argv) {
  const out = { packId: "", scheduleDate: "" };
  for (const a of argv.slice(2)) {
    if (a.startsWith("--pack-id=")) out.packId = a.slice("--pack-id=".length).trim();
    if (a.startsWith("--schedule-date=")) out.scheduleDate = a.slice("--schedule-date=".length).trim();
  }
  return out;
}

function quizQuestionType(d) {
  return d.questionType === "national_exam" ? "national_exam" : "clinical";
}

async function main() {
  const args = parseArgs(process.argv);
  if (!args.packId) {
    console.error("❌ --pack-id=... 필수 (업로드한 clinical pack)");
    process.exit(1);
  }

  if (!admin.apps.length) {
    admin.initializeApp({ credential: admin.credential.cert(loadServiceAccount()) });
  }
  const db = admin.firestore();
  const dateKey = args.scheduleDate && /^\d{4}-\d{2}-\d{2}$/.test(args.scheduleDate)
    ? args.scheduleDate
    : kstDateKey();

  const cfgSnap = await db.doc("config/quiz_content").get();
  console.log("── config/quiz_content ──");
  console.log(cfgSnap.exists ? JSON.stringify(cfgSnap.data(), null, 2) : "(문서 없음)");

  const poolSnap = await db.collection("quiz_pool").where("isActive", "==", true).get();
  let clinicalPack = 0;
  let clinicalOther = 0;
  let clinicalNoPack = 0;
  let nationalAll = 0;
  for (const doc of poolSnap.docs) {
    const d = doc.data();
    const t = quizQuestionType(d);
    if (t === "national_exam") {
      nationalAll++;
      continue;
    }
    const pid = typeof d.packId === "string" ? d.packId.trim() : "";
    if (!pid) clinicalNoPack++;
    else if (pid === args.packId) clinicalPack++;
    else clinicalOther++;
  }
  console.log("\n── quiz_pool 활성 요약 ──");
  console.log("국시(활성):", nationalAll);
  console.log("임상 활성 / packId ===", args.packId + ":", clinicalPack);
  console.log("임상 활성 / packId 기타:", clinicalOther);
  console.log("임상 활성 / packId 없음(레거시):", clinicalNoPack);

  const schedRef = db.collection("quiz_schedule").doc(dateKey);
  const schedSnap = await schedRef.get();
  console.log("\n── quiz_schedule/" + dateKey + " ──");
  if (!schedSnap.exists) {
    console.log("(문서 없음 — 자정 전이거나 아직 스케줄 미생성)");
    return;
  }
  const sd = schedSnap.data();
  const quizIds = sd.quizIds || [];
  const items = sd.items || [];
  console.log("quizIds 개수:", quizIds.length);
  items.forEach((it, i) => {
    const row = {
      questionType: it.questionType,
      packId: it.packId ?? "",
      packVersion: it.packVersion ?? 0,
      id: it.id ?? "",
    };
    console.log("  item[" + i + "]", row);
    if (!it.questionType && (it.packId === undefined || it.packId === "")) {
      console.log("      ⚠️ questionType/packId 없음 → 예전 스케줄 스냅샷일 수 있음. 새 pack 반영은 재스케줄 후 확인.");
    }
  });
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
