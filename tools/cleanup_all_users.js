/**
 * cleanup_all_users.js
 *
 * 지정한 KEEP_UID 한 명만 남기고 아래 데이터를 모두 삭제합니다:
 *
 *   1. users/{uid}                (Firestore)
 *   2. users/{uid}/notes/*        (서브컬렉션)
 *   3. clinics_accounts/{uid}     (Firestore)
 *   4. activityLogs               (관리자 제외)
 *   5. analytics_daily            (전체 초기화)
 *   6. Firebase Authentication    (관리자 제외, Auth 계정 삭제)
 *
 * 사전 준비:
 *   - functions/serviceAccountKey.json 또는
 *     GOOGLE_APPLICATION_CREDENTIALS 환경 변수
 *
 * 실행:
 *   node tools/cleanup_all_users.js
 */

const fs = require("fs");
const path = require("path");

const projectRoot = path.join(__dirname, "..");
const functionsDir = path.join(projectRoot, "functions");
const adminModulePath = path.join(functionsDir, "node_modules", "firebase-admin");

if (!fs.existsSync(adminModulePath)) {
  console.error(
    "❌ firebase-admin 을 찾을 수 없습니다. 다음을 실행하세요:\n" +
      "   cd functions && npm install"
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

  // 서비스 계정 키가 없으면 ADC 또는 firebase login 세션 사용
  admin.initializeApp({ projectId: "chikabooks3rd" });
}

initAdmin();
const db = admin.firestore();
const auth = admin.auth();

const KEEP_UID = "YhgjdjXMtlY2LIBHAfQnE7uBNv02";
const BATCH_SIZE = 400;

function chunk(arr, size) {
  const result = [];
  for (let i = 0; i < arr.length; i += size) {
    result.push(arr.slice(i, i + size));
  }
  return result;
}

async function deleteInBatches(docs, label) {
  if (docs.length === 0) {
    console.log(`  ✅ ${label}: 삭제 대상 없음`);
    return 0;
  }
  const chunks = chunk(docs, BATCH_SIZE);
  let total = 0;
  for (const c of chunks) {
    const batch = db.batch();
    for (const doc of c) batch.delete(doc.ref);
    await batch.commit();
    total += c.length;
    console.log(`  🗑️  ${label}: ${total}/${docs.length} 삭제 완료`);
  }
  return total;
}

async function deleteAuthUsers(uids) {
  if (uids.length === 0) {
    console.log("  ✅ Auth 삭제 대상 없음");
    return 0;
  }
  let deleted = 0;
  for (const uid of uids) {
    try {
      await auth.deleteUser(uid);
      deleted++;
    } catch (e) {
      if (e.code === "auth/user-not-found") continue;
      console.warn(`  ⚠️ Auth 삭제 실패 (${uid}): ${e.message}`);
    }
  }
  console.log(`  🗑️  Auth: ${deleted}/${uids.length} 삭제 완료`);
  return deleted;
}

async function listAllAuthUids() {
  const uids = [];
  let nextPageToken;
  do {
    const result = await auth.listUsers(1000, nextPageToken);
    for (const user of result.users) {
      if (user.uid !== KEEP_UID) uids.push(user.uid);
    }
    nextPageToken = result.pageToken;
  } while (nextPageToken);
  return uids;
}

async function main() {
  console.log("========================================");
  console.log(" 전체 유저 초기화 스크립트");
  console.log(` 보존 UID: ${KEEP_UID}`);
  console.log("========================================\n");

  // 1. users 컬렉션
  console.log("[1/6] users 컬렉션 조회 중...");
  const usersSnap = await db.collection("users").get();
  const usersToDelete = usersSnap.docs.filter((d) => d.id !== KEEP_UID);
  const firestoreUids = usersToDelete.map((d) => d.id);
  console.log(
    `  전체 유저: ${usersSnap.size}명, 삭제 대상: ${firestoreUids.length}명`
  );

  // 2. notes 서브컬렉션
  console.log("\n[2/6] notes 서브컬렉션 삭제 중...");
  let notesTotal = 0;
  for (const uid of firestoreUids) {
    const notesSnap = await db
      .collection("users")
      .doc(uid)
      .collection("notes")
      .get();
    if (notesSnap.size > 0) {
      await deleteInBatches(notesSnap.docs, `users/${uid}/notes`);
      notesTotal += notesSnap.size;
    }
  }
  console.log(`  → notes 총 ${notesTotal}건 삭제`);

  // 3. users 문서 삭제
  console.log("\n[3/6] users 문서 삭제 중...");
  await deleteInBatches(usersToDelete, "users");

  // 4. clinics_accounts 삭제
  console.log("\n[4/6] clinics_accounts 삭제 중...");
  const clinicsSnap = await db.collection("clinics_accounts").get();
  const clinicsToDelete = clinicsSnap.docs.filter((d) => d.id !== KEEP_UID);
  const clinicUids = clinicsToDelete.map((d) => d.id);
  await deleteInBatches(clinicsToDelete, "clinics_accounts");

  // 5. activityLogs 삭제 (보존 UID 제외)
  console.log("\n[5/6] activityLogs 삭제 중...");
  let logsDeleted = 0;
  while (true) {
    const snap = await db.collection("activityLogs").limit(BATCH_SIZE).get();
    if (snap.empty) break;
    const toDelete = snap.docs.filter(
      (d) => (d.data().userId || d.data().uid) !== KEEP_UID
    );
    if (toDelete.length === 0) break;
    const batch = db.batch();
    for (const doc of toDelete) batch.delete(doc.ref);
    await batch.commit();
    logsDeleted += toDelete.length;
    console.log(`  🗑️  activityLogs: ${logsDeleted}건 삭제 중...`);
  }
  console.log(`  → activityLogs 총 ${logsDeleted}건 삭제`);

  // 6. Firebase Auth 유저 삭제
  console.log("\n[6/6] Firebase Auth 유저 삭제 중...");
  const allAuthUids = await listAllAuthUids();
  console.log(`  Auth 전체: ${allAuthUids.length + 1}명, 삭제 대상: ${allAuthUids.length}명`);
  const authDeleted = await deleteAuthUsers(allAuthUids);

  // analytics_daily
  console.log("\n[bonus] analytics_daily 전체 삭제 중...");
  const dailySnap = await db.collection("analytics_daily").get();
  await deleteInBatches(dailySnap.docs, "analytics_daily");

  console.log("\n========================================");
  console.log(" ✅ 초기화 완료");
  console.log(`  - 삭제된 Firestore users:    ${firestoreUids.length}명`);
  console.log(`  - 삭제된 notes:              ${notesTotal}건`);
  console.log(`  - 삭제된 clinics_accounts:   ${clinicUids.length}건`);
  console.log(`  - 삭제된 activityLogs:       ${logsDeleted}건`);
  console.log(`  - 삭제된 analytics_daily:    ${dailySnap.size}건`);
  console.log(`  - 삭제된 Auth 유저:          ${authDeleted}명`);
  console.log(`  - 보존된 UID:                ${KEEP_UID}`);
  console.log("========================================");
  process.exit(0);
}

main().catch((err) => {
  console.error("❌ 오류 발생:", err);
  process.exit(1);
});
