const fs = require("fs");
const path = require("path");
const functionsDir = path.join(__dirname, "../functions");
const admin = require(path.join(functionsDir, "node_modules/firebase-admin"));

(function initFirebase() {
  if (admin.apps.length) return;
  const saPath = path.join(functionsDir, "serviceAccountKey.json");
  if (fs.existsSync(saPath)) {
    admin.initializeApp({ credential: admin.credential.cert(JSON.parse(fs.readFileSync(saPath, "utf8"))) });
    return;
  }
  const cfgPath = path.join(require("os").homedir(), ".config/configstore/firebase-tools.json");
  const cfg = JSON.parse(fs.readFileSync(cfgPath, "utf8"));
  const adcPath = "/tmp/_quiz_ids_adc.json";
  fs.writeFileSync(adcPath, JSON.stringify({
    type: "authorized_user",
    client_id: cfg.tokens.client_id || "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com",
    client_secret: cfg.tokens.client_secret || "j9iVZfS8kkCEFUPaAeJV0sAi",
    refresh_token: cfg.tokens.refresh_token,
  }));
  process.env.GOOGLE_APPLICATION_CREDENTIALS = adcPath;
  admin.initializeApp({ credential: admin.credential.applicationDefault(), projectId: "chikabooks3rd" });
})();

async function main() {
  const db = admin.firestore();
  const ids = ["3Iiztvuyp6FL3f9eew2Z", "VHoxzHJaahUvQwaeroSc"];
  console.log("── 오늘(3/29) 스케줄 문제 ID 조회 ──\n");
  for (const id of ids) {
    const doc = await db.collection("quiz_pool").doc(id).get();
    if (!doc.exists) {
      console.log(`${id}: quiz_pool에 없음 (삭제됨)`);
    } else {
      const d = doc.data();
      console.log(`${id}:`);
      console.log(`  questionType: ${JSON.stringify(d.questionType)}`);
      console.log(`  category: ${JSON.stringify(d.category)}`);
      console.log(`  packId: ${JSON.stringify(d.packId || "")}`);
      console.log(`  isActive: ${d.isActive}`);
      console.log(`  question: ${(d.question || "").substring(0, 60)}...`);
    }
    console.log();
  }

  // 3/26 스케줄 문제도 확인
  const ids26 = ["qM0FDUOLGNP6HaMSK7KO", "JozrUbNuJ2Vwqri5ati2"];
  console.log("── 3/26 스케줄 문제 ID 조회 ──\n");
  for (const id of ids26) {
    const doc = await db.collection("quiz_pool").doc(id).get();
    if (!doc.exists) {
      console.log(`${id}: quiz_pool에 없음 (삭제됨)`);
    } else {
      const d = doc.data();
      console.log(`${id}:`);
      console.log(`  questionType: ${JSON.stringify(d.questionType)}`);
      console.log(`  category: ${JSON.stringify(d.category)}`);
      console.log(`  packId: ${JSON.stringify(d.packId || "")}`);
      console.log(`  isActive: ${d.isActive}`);
    }
    console.log();
  }
}
main().catch(console.error);
