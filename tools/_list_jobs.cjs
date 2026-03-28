/**
 * Firestore jobs 컬렉션 문서 요약 출력 (일회성 점검용)
 * 실행: node tools/_list_jobs.cjs
 */
const fs = require("fs");
const path = require("path");
const functionsDir = path.join(__dirname, "../functions");
const admin = require(path.join(functionsDir, "node_modules/firebase-admin"));

(function initFirebase() {
  if (admin.apps.length) return;
  const saPath = path.join(functionsDir, "serviceAccountKey.json");
  if (fs.existsSync(saPath)) {
    admin.initializeApp({
      credential: admin.credential.cert(JSON.parse(fs.readFileSync(saPath, "utf8"))),
    });
    return;
  }
  const cfgPath = path.join(require("os").homedir(), ".config/configstore/firebase-tools.json");
  if (!fs.existsSync(cfgPath)) {
    console.error("Firebase 인증 없음: functions/serviceAccountKey.json 또는 firebase login 필요");
    process.exit(1);
  }
  const cfg = JSON.parse(fs.readFileSync(cfgPath, "utf8"));
  const adcPath = "/tmp/_list_jobs_adc.json";
  fs.writeFileSync(
    adcPath,
    JSON.stringify({
      type: "authorized_user",
      client_id:
        cfg.tokens.client_id ||
        "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com",
      client_secret: cfg.tokens.client_secret || "j9iVZfS8kkCEFUPaAeJV0sAi",
      refresh_token: cfg.tokens.refresh_token,
    })
  );
  process.env.GOOGLE_APPLICATION_CREDENTIALS = adcPath;
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: "chikabooks3rd",
  });
})();

function trim(s, n) {
  if (s == null) return "";
  const t = String(s);
  return t.length <= n ? t : t.slice(0, n) + "…";
}

async function main() {
  const db = admin.firestore();
  const allSnap = await db.collection("jobs").get();
  console.log(`── Firestore jobs 전체 문서 수: ${allSnap.size} ──\n`);

  let snap;
  try {
    snap = await db.collection("jobs").orderBy("createdAt", "desc").limit(40).get();
  } catch (e) {
    console.warn("orderBy(createdAt) 실패, 전체 스냅샷 사용:", e.message);
    snap = allSnap;
  }

  console.log(`── 정렬 조회 건수: ${snap.size} ──\n`);

  if (allSnap.size > snap.size) {
    console.log(
      `⚠️  전체 ${allSnap.size}건 중 createdAt으로 정렬 가능한 문서만 ${snap.size}건 조회됨.\n` +
        `   (createdAt 없는 문서는 앱 목록 쿼리에서 제외됩니다.)\n`
    );
    console.log("── 전체 문서 ID · createdAt 유무 · title (앞 35자) ──");
    allSnap.docs.forEach((doc, i) => {
      const d = doc.data();
      const hasCA = d.createdAt != null;
      console.log(
        `  ${i + 1}. ${doc.id}  createdAt:${hasCA ? "✓" : "✗"}  ${trim(d.title, 35)}`
      );
    });
    console.log("");
  }

  if (snap.empty) {
    console.log("(문서 없음)");
    process.exit(0);
  }

  snap.docs.forEach((doc, i) => {
    const d = doc.data();
    const createdAt = d.createdAt?.toDate?.()?.toISOString?.() || d.createdAt;
    const postedAt = d.postedAt?.toDate?.()?.toISOString?.() || d.postedAt;
    console.log(`[${i + 1}] id: ${doc.id}`);
    console.log(`    status: ${d.status ?? "(없음)"}`);
    console.log(`    title: ${trim(d.title, 80)}`);
    console.log(`    clinicName: ${trim(d.clinicName, 60)}`);
    console.log(`    type/role: ${trim(d.type || d.role, 40)}`);
    console.log(`    employmentType: ${trim(d.employmentType, 40)}`);
    console.log(`    career: ${trim(d.career, 30)}`);
    console.log(`    salary / salaryText: ${trim(d.salaryText || d.salary, 50)}`);
    console.log(`    salaryRange: ${JSON.stringify(d.salaryRange)}`);
    console.log(`    workHours: ${trim(d.workHours, 50)}`);
    console.log(`    contact: ${trim(d.contact, 40)}`);
    console.log(`    address: ${trim(d.address, 60)}`);
    console.log(`    details(앞): ${trim(d.details, 80)}`);
    console.log(`    description(앞): ${trim(d.description, 80)}`);
    console.log(`    benefits: ${JSON.stringify(d.benefits || [])}`);
    console.log(`    images count: ${Array.isArray(d.images) ? d.images.length : 0}`);
    console.log(`    createdAt: ${createdAt}`);
    console.log(`    postedAt: ${postedAt}`);
    console.log("");
  });
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
