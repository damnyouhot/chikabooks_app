/**
 * 퀴즈 진단: 오늘 스케줄 + 최근 5일 스케줄의 questionType/packId 확인
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
  const cfg = JSON.parse(fs.readFileSync(cfgPath, "utf8"));
  const rt = cfg.tokens && cfg.tokens.refresh_token;
  const adcPath = "/tmp/_quiz_diag_adc.json";
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
  const yyyy = kst.getUTCFullYear();
  const mm = String(kst.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(kst.getUTCDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

async function main() {
  initFirebase();
  const db = admin.firestore();

  // config 확인
  const cfgSnap = await db.doc("config/quiz_content").get();
  console.log("── config/quiz_content ──");
  console.log(JSON.stringify(cfgSnap.exists ? cfgSnap.data() : "(없음)", null, 2));

  // 최근 5일 스케줄 확인
  const today = new Date();
  console.log("\n── 최근 5일 스케줄 ──");
  for (let i = 0; i < 5; i++) {
    const d = new Date(today.getTime() - i * 86400000);
    const dk = kstDateKey(d);
    const snap = await db.collection("quiz_schedule").doc(dk).get();
    if (!snap.exists) {
      console.log(`${dk}: (없음)`);
      continue;
    }
    const data = snap.data();
    const items = data.items || [];
    console.log(`\n${dk} (quizIds: ${(data.quizIds || []).length}개):`);
    items.forEach((it, idx) => {
      console.log(`  item[${idx}] questionType=${JSON.stringify(it.questionType)} packId=${JSON.stringify(it.packId || "")} category=${JSON.stringify(it.category || "")} id=${it.id || ""}`);
    });
  }

  // quiz_pool에서 questionType 분포 확인
  console.log("\n── quiz_pool 활성 questionType 분포 ──");
  const poolSnap = await db.collection("quiz_pool").where("isActive", "==", true).get();
  const dist = {};
  for (const doc of poolSnap.docs) {
    const d = doc.data();
    const qt = d.questionType || "(없음)";
    const pid = (d.packId || "").trim() || "(없음)";
    const key = `${qt} / packId=${pid}`;
    dist[key] = (dist[key] || 0) + 1;
  }
  Object.entries(dist).sort((a, b) => b[1] - a[1]).forEach(([k, v]) => console.log(`  ${k}: ${v}`));

  // quiz_meta/state
  const metaSnap = await db.doc("quiz_meta/state").get();
  if (metaSnap.exists) {
    const m = metaSnap.data();
    console.log("\n── quiz_meta/state ──");
    console.log("  totalActiveCount:", m.totalActiveCount);
    console.log("  totalNationalActiveCount:", m.totalNationalActiveCount);
    console.log("  totalClinicalActiveCount:", m.totalClinicalActiveCount);
    console.log("  usedNationalCount:", m.usedNationalCount);
    console.log("  usedClinicalCount:", m.usedClinicalCount);
    console.log("  usedQuizIds.length:", (m.usedQuizIds || []).length);
    console.log("  cycleCount:", m.cycleCount);
    console.log("  lastScheduledDate:", m.lastScheduledDate);
  }
}

main().catch(console.error);
