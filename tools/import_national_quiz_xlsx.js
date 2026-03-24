/**
 * 국시문제 시트 → Firestore quiz_pool 업로드
 *
 * 엑셀 형식 (2번째 시트 이름: 국시문제):
 *   헤더: 번호, 과목, 문제, 보기, 정답, 해설, 출처
 *   정답: 1~4 (①~④)
 *   보기: 첫 행에 ①, 이후 행에 ②③④만 채운 행이 이어짐
 *
 * 사용:
 *   cd functions && npm install
 *   node ../tools/import_national_quiz_xlsx.js [xlsx경로]
 *
 * 기본 경로: C:/Users/douglas/Desktop/공감투표.xlsx
 */

const fs = require("fs");
const path = require("path");
const admin = require(path.join(__dirname, "../functions/node_modules/firebase-admin"));
const XLSX = require(path.join(__dirname, "../functions/node_modules/xlsx"));

const functionsDir = path.join(__dirname, "../functions");
const defaultXlsx = "C:/Users/douglas/Desktop/공감투표.xlsx";

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

/**
 * @param {any[][]} rows
 */
function parseNationalRows(rows) {
  const out = [];
  let i = 1;
  while (i < rows.length) {
    const r = rows[i];
    const qText = r[2] != null ? String(r[2]).trim() : "";
    if (!qText) {
      i++;
      continue;
    }
    const num = r[0];
    const subject = r[1] != null ? String(r[1]).trim() : "";
    const options = [];
    if (r[3] != null && String(r[3]).trim()) {
      options.push(String(r[3]).trim());
    }
    const answerRaw = r[4];
    const expl = r[5] != null ? String(r[5]).trim() : "";
    const src = r[6] != null ? String(r[6]).trim() : "";
    i++;
    while (i < rows.length) {
      const nr = rows[i];
      const nextQ = nr[2] != null ? String(nr[2]).trim() : "";
      if (nextQ) break;
      const opt = nr[3] != null ? String(nr[3]).trim() : "";
      if (opt) options.push(opt);
      i++;
    }
    const ans = Number(answerRaw);
    if (!Number.isFinite(ans) || ans < 1 || ans > 4) {
      console.warn("⚠️ 정답 스킵:", num, answerRaw);
      continue;
    }
    if (options.length < 2) {
      console.warn("⚠️ 보기 부족 스킵:", num);
      continue;
    }
    const n = Number(num);
    out.push({
      order: (Number.isFinite(n) ? n : out.length + 1) + 100000,
      category: subject,
      question: qText,
      options,
      correctIndex: ans - 1,
      explanation: expl,
      sourceName: src,
    });
  }
  return out;
}

async function main() {
  const xlsxPath = process.argv[2] || defaultXlsx;
  if (!fs.existsSync(xlsxPath)) {
    console.error("❌ 파일 없음:", xlsxPath);
    process.exit(1);
  }

  const wb = XLSX.readFile(xlsxPath);
  const sheetName = wb.SheetNames.includes("국시문제")
    ? "국시문제"
    : wb.SheetNames[1];
  const sheet = wb.Sheets[sheetName];
  if (!sheet) {
    console.error("❌ 시트 없음:", sheetName);
    process.exit(1);
  }

  const rows = XLSX.utils.sheet_to_json(sheet, { header: 1, defval: "" });
  const items = parseNationalRows(rows);
  console.log("📋 시트:", sheetName, "→ 파싱 문항:", items.length);

  if (items.length === 0) {
    console.error("❌ 업로드할 문항 없음");
    process.exit(1);
  }

  if (!admin.apps.length) {
    admin.initializeApp({ credential: admin.credential.cert(loadServiceAccount()) });
  }
  const db = admin.firestore();
  const batch = db.batch();
  const col = db.collection("quiz_pool");
  const now = admin.firestore.FieldValue.serverTimestamp();

  for (const it of items) {
    const ref = col.doc();
    batch.set(ref, {
      order: it.order,
      question: it.question,
      options: it.options,
      correctIndex: it.correctIndex,
      explanation: it.explanation,
      category: it.category,
      difficulty: "basic",
      questionType: "national_exam",
      sourceBook: "",
      sourceFileName: "",
      sourcePage: "",
      sourceName: it.sourceName || "국가고시",
      isActive: true,
      lastCycleServed: 0,
      createdAt: now,
      updatedAt: now,
    });
  }

  await batch.commit();
  console.log("✅ quiz_pool에 national_exam", items.length, "건 추가 완료");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
