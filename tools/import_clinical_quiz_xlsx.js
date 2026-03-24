/**
 * 임상문제 시트 → Firestore quiz_pool (새 clinical packId)
 *
 * 실제 시트 구조 (공감투표.xlsx / 임상문제):
 *   헤더: 문제 | 보기 | 정답 | 해설 | 출처
 *   보기: 한 셀에 "1) ... 2) ... 3) ..." 형태 (한 문항 = 한 행)
 *   정답: 1~3 (①②③에 대응) → Firestore correctIndex 는 0-based (정답-1)
 *
 * 사용:
 *   cd functions && npm install
 *   node ../tools/import_clinical_quiz_xlsx.js "C:/Users/douglas/Desktop/공감투표.xlsx" --pack-id=clinical_2026_03
 *   node ../tools/import_clinical_quiz_xlsx.js --dry-run "C:/path/공감투표.xlsx" --pack-id=clinical_2026_03
 *
 * 환경변수:
 *   GOOGLE_APPLICATION_CREDENTIALS 또는 functions/serviceAccountKey.json
 *   CLINICAL_ORDER_BASE (기본 300000) — order = BASE + 행번호(1..)
 */

const fs = require("fs");
const path = require("path");

const functionsDir = path.join(__dirname, "../functions");
const admin = require(path.join(functionsDir, "node_modules/firebase-admin"));
const XLSX = require(path.join(functionsDir, "node_modules/xlsx"));

const defaultXlsx = "C:/Users/douglas/Desktop/공감투표.xlsx";
const SHEET_NAME = "임상문제";

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
  const out = {
    xlsxPath: defaultXlsx,
    dryRun: false,
    packId: "",
    packVersion: 1,
  };
  for (const a of argv.slice(2)) {
    if (a === "--dry-run") out.dryRun = true;
    else if (a.startsWith("--pack-id=")) out.packId = a.slice("--pack-id=".length).trim();
    else if (a.startsWith("--pack-version=")) {
      const n = Number(a.slice("--pack-version=".length).trim());
      out.packVersion = Number.isFinite(n) ? n : 1;
    } else if (!a.startsWith("--")) out.xlsxPath = a;
  }
  return out;
}

/**
 * 한 셀에 "1) / 1. … 2) … 3) …" 전부 있는 경우
 */
function parseOptionsOneCell(cell) {
  const t = String(cell ?? "").trim();
  if (!t) return [];
  const m = t.match(/1[.)]\s*(.+?)\s+2[.)]\s*(.+?)\s+3[.)]\s*(.+)$/s);
  if (m) {
    return [m[1].trim(), m[2].trim(), m[3].trim()];
  }
  const parts = t
    .split(/\s*(?=\d[.)]\s*)/)
    .map((p) => p.replace(/^\d[.)]\s*/, "").trim())
    .filter(Boolean);
  return parts.length >= 3 ? parts.slice(0, 3) : [];
}

/**
 * 첫 행 col1에 "1. …" 만 있고, 다음 행들에 "2. …" "3. …" 만 있는 형식 (동일 시트 혼재)
 * @returns {{ options: string[], nextRow: number }} | null
 */
function parseOptionsMultiline(rows, startIdx) {
  const r = rows[startIdx];
  const first = String(r[1] ?? "").trim();
  if (!/^1[.)]\s/.test(first)) return null;
  const opts = [first.replace(/^1[.)]\s*/, "").trim()];
  let j = startIdx + 1;
  while (j < rows.length && opts.length < 3) {
    const nr = rows[j] || [];
    const c0 = String(nr[0] ?? "").trim();
    const c1 = String(nr[1] ?? "").trim();
    if (c0) break;
    if (/^2[.)]\s/.test(c1)) {
      opts.push(c1.replace(/^2[.)]\s*/, "").trim());
      j++;
      continue;
    }
    if (/^3[.)]\s/.test(c1)) {
      opts.push(c1.replace(/^3[.)]\s*/, "").trim());
      j++;
      break;
    }
    if (!c1) {
      j++;
      continue;
    }
    j++;
  }
  if (opts.length !== 3) return null;
  return { options: opts, nextRow: j };
}

/** 출처 "책이름, 11p" → { sourceBook, sourcePage } */
function parseSource(raw) {
  const s = String(raw ?? "").trim();
  if (!s) return { sourceBook: "", sourcePage: "", sourceName: "" };
  const sourceName = s;
  const idx = s.lastIndexOf(",");
  if (idx <= 0) return { sourceBook: s, sourcePage: "", sourceName };
  const book = s.slice(0, idx).trim();
  const tail = s.slice(idx + 1).trim();
  const pageM = tail.match(/^(\d+)\s*p$/i);
  const sourcePage = pageM ? pageM[1] : tail;
  return { sourceBook: book, sourcePage, sourceName };
}

function parseClinicalRows(rows) {
  const base =
    Number(process.env.CLINICAL_ORDER_BASE) >= 0
      ? Number(process.env.CLINICAL_ORDER_BASE)
      : 300000;
  const out = [];
  let dataIndex = 0;
  let i = 1;
  while (i < rows.length) {
    const r = rows[i];
    if (!r || r.length === 0) {
      i++;
      continue;
    }
    const question = r[0] != null ? String(r[0]).trim() : "";
    if (!question) {
      i++;
      continue;
    }

    const ansRaw = r[2];
    const explanation = r[3] != null ? String(r[3]).trim() : "";
    const src = parseSource(r[4]);

    let options = parseOptionsOneCell(r[1]);
    let nextRow = i + 1;
    if (options.length < 3) {
      const multi = parseOptionsMultiline(rows, i);
      if (multi) {
        options = multi.options;
        nextRow = multi.nextRow;
      }
    }

    const ans = Number(ansRaw);
    if (!Number.isFinite(ans) || ans < 1 || ans > 3) {
      console.warn("⚠️ 정답 스킵 (1~3 필요): 행", i + 1, ansRaw);
      i = nextRow;
      continue;
    }
    if (options.length < 3) {
      console.warn("⚠️ 보기 파싱 실패(3개 필요): 행", i + 1, String(r[1]).slice(0, 60));
      i++;
      continue;
    }

    dataIndex += 1;
    out.push({
      order: base + dataIndex,
      question,
      options,
      correctIndex: ans - 1,
      explanation,
      category: "임상",
      sourceBook: src.sourceBook,
      sourceFileName: "",
      sourcePage: src.sourcePage,
      sourceName: src.sourceName,
    });
    i = nextRow;
  }
  return out;
}

async function commitInBatches(db, items, packId, packVersion, dryRun) {
  const col = db.collection("quiz_pool");
  const now = admin.firestore.FieldValue.serverTimestamp();
  const packRef = db.doc(`quiz_packs/${packId}`);

  if (!dryRun) {
    await packRef.set(
      {
        kind: "clinical",
        title: process.env.CLINICAL_PACK_TITLE || packId,
        version: packVersion,
        isActive: true,
        updatedAt: now,
      },
      { merge: true },
    );
  }

  const BATCH = 450;
  let count = 0;
  for (let i = 0; i < items.length; i += BATCH) {
    const chunk = items.slice(i, i + BATCH);
    if (dryRun) {
      count += chunk.length;
      continue;
    }
    const batch = db.batch();
    for (const it of chunk) {
      const ref = col.doc();
      batch.set(ref, {
        order: it.order,
        question: it.question,
        options: it.options,
        correctIndex: it.correctIndex,
        explanation: it.explanation,
        category: it.category,
        difficulty: "basic",
        questionType: "clinical",
        sourceBook: it.sourceBook,
        sourceFileName: it.sourceFileName,
        sourcePage: it.sourcePage,
        sourceName: it.sourceName,
        packId,
        packVersion,
        isActive: true,
        lastCycleServed: 0,
        createdAt: now,
        updatedAt: now,
      });
    }
    await batch.commit();
    count += chunk.length;
    console.log("  … 커밋", count, "/", items.length);
  }
  return count;
}

async function main() {
  const args = parseArgs(process.argv);
  if (!args.packId) {
    console.error("❌ --pack-id=... 필수");
    process.exit(1);
  }
  if (!fs.existsSync(args.xlsxPath)) {
    console.error("❌ 파일 없음:", args.xlsxPath);
    process.exit(1);
  }

  const wb = XLSX.readFile(args.xlsxPath);
  if (!wb.SheetNames.includes(SHEET_NAME)) {
    console.error("❌ 시트 없음:", SHEET_NAME, "| 있는 시트:", wb.SheetNames.join(", "));
    process.exit(1);
  }
  const sheet = wb.Sheets[SHEET_NAME];
  const rows = XLSX.utils.sheet_to_json(sheet, { header: 1, defval: "", raw: false });
  const items = parseClinicalRows(rows);

  console.log("📋 시트:", SHEET_NAME, "| 파싱 문항:", items.length, args.dryRun ? "(dry-run)" : "");
  if (items.length === 0) {
    console.error("❌ 업로드할 문항 없음");
    process.exit(1);
  }
  console.log("📌 샘플 1문항:", JSON.stringify(items[0], null, 2));

  if (args.dryRun) {
    console.log("✅ dry-run: Firestore 쓰기 없음. packId=", args.packId, "version=", args.packVersion);
    return;
  }

  if (!admin.apps.length) {
    admin.initializeApp({ credential: admin.credential.cert(loadServiceAccount()) });
  }
  const db = admin.firestore();
  await commitInBatches(db, items, args.packId, args.packVersion, false);
  console.log("✅ quiz_pool clinical", items.length, "건, packId=", args.packId);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
