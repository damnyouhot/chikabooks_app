/**
 * quiz_schedule/{dateKey}.items[] 의 questionType 을 quiz_pool 현재 문서 기준으로 맞춤
 * (스냅샷에 타입 필드가 빠져 앱에서 임상 2개로 보이는 경우 등)
 *
 *   node tools/patch_quiz_schedule_question_types.cjs --date=2026-03-25
 *   node tools/patch_quiz_schedule_question_types.cjs --date=2026-03-25 --apply
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

function quizQuestionType(data) {
  return data.questionType === "national_exam" ? "national_exam" : "clinical";
}

function inferFromPack(packId, nationalPackIds) {
  const pid = typeof packId === "string" ? packId.trim() : "";
  return nationalPackIds.has(pid) ? "national_exam" : "clinical";
}

async function main() {
  const argv = process.argv.slice(2);
  const apply = argv.includes("--apply");
  let dateKey = "";
  for (const a of argv) {
    if (a.startsWith("--date=")) dateKey = a.slice(7).trim();
  }
  if (!dateKey) {
    console.error("사용법: node tools/patch_quiz_schedule_question_types.cjs --date=YYYY-MM-DD [--apply]");
    process.exit(1);
  }

  if (!admin.apps.length) {
    admin.initializeApp({ credential: admin.credential.cert(loadServiceAccount()) });
  }
  const db = admin.firestore();

  const cfgSnap = await db.doc("config/quiz_content").get();
  const cfg = cfgSnap.exists ? cfgSnap.data() : {};
  const nationalId =
    typeof cfg.currentNationalPackId === "string" ? cfg.currentNationalPackId.trim() : "";
  const nationalPackIds = new Set(["national_default"]);
  if (nationalId) nationalPackIds.add(nationalId);

  const schedRef = db.collection("quiz_schedule").doc(dateKey);
  const schedSnap = await schedRef.get();
  if (!schedSnap.exists) {
    console.error("❌ quiz_schedule 없음:", dateKey);
    process.exit(1);
  }

  const data = schedSnap.data();
  const items = Array.isArray(data.items) ? [...data.items] : [];
  if (items.length === 0) {
    console.log("items 비어 있음 — 종료");
    process.exit(0);
  }

  const nextItems = [];
  let changed = 0;

  for (let i = 0; i < items.length; i++) {
    const it = { ...items[i] };
    const id = typeof it.id === "string" ? it.id : "";
    let desired = inferFromPack(it.packId, nationalPackIds);

    if (id) {
      const poolSnap = await db.collection("quiz_pool").doc(id).get();
      if (poolSnap.exists) {
        desired = quizQuestionType(poolSnap.data());
      }
    }

    const cur = it.questionType;
    if (cur !== desired) {
      console.log(`  [${i}] id=${id || "?"}: questionType ${JSON.stringify(cur)} → ${desired}`);
      changed++;
      it.questionType = desired;
    }
    nextItems.push(it);
  }

  console.log(apply ? "=== APPLY ===" : "=== DRY-RUN ===", `변경 ${changed}건 / items ${items.length}`);

  if (apply && changed > 0) {
    await schedRef.update({
      items: nextItems,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log("✅ 반영 완료");
  } else if (!apply && changed > 0) {
    console.log("\n적용: 동일 명령에 --apply 추가");
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
