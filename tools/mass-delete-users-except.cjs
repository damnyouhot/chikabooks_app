/**
 * 보존 UID 1명만 남기고:
 * 1) Firebase Auth 사용자 삭제 + performAccountDeletion (Storage 일부·users 문서 등)
 * 2) Firestore: uid 기반·ownerUid 기반 문서 전면 스윕 (고아 clinics_accounts 포함)
 * 3) Storage: users/·profileImages/·avatars/ 하위 비보존 UID 폴더 삭제
 *
 * 사용법:
 *   cd functions && npm run build
 *   node tools/mass-delete-users-except.cjs --confirm
 */

const fs = require("fs");
const path = require("path");

const projectRoot = path.join(__dirname, "..");
const functionsDir = path.join(projectRoot, "functions");
const adminModulePath = path.join(functionsDir, "node_modules", "firebase-admin");

const PRESERVE_UID = "YhgjdjXMtlY2LIBHAfQnE7uBNv02";

function loadFirebaseAdmin() {
  if (!fs.existsSync(adminModulePath)) {
    console.error(
      "❌ firebase-admin 을 찾을 수 없습니다. `cd functions && npm install`",
    );
    process.exit(1);
  }
  return require(adminModulePath);
}

function loadServiceAccount() {
  const envPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const defaultPath = path.join(functionsDir, "serviceAccountKey.json");
  const keyPath = envPath && fs.existsSync(envPath) ? envPath : defaultPath;

  if (!fs.existsSync(keyPath)) {
    console.error(
      "❌ 서비스 계정 JSON이 없습니다. tools/setup_admin.js 주석 참고.",
    );
    process.exit(1);
  }
  return JSON.parse(fs.readFileSync(keyPath, "utf8"));
}

async function deleteClinicsAccountIfAny(db, uid) {
  const ref = db.collection("clinics_accounts").doc(uid);
  const snap = await ref.get();
  if (!snap.exists) return;
  await db.recursiveDelete(ref);
  console.log(`  ✅ clinics_accounts/${uid} 삭제`);
}

/** 문서 ID = UID 인 컬렉션: 보존 UID 제외 전부 recursiveDelete */
async function sweepUidDocIds(db, collectionName, preserveUid) {
  const snap = await db.collection(collectionName).get();
  let n = 0;
  for (const doc of snap.docs) {
    if (doc.id === preserveUid) continue;
    await db.recursiveDelete(doc.ref);
    n++;
    console.log(`  🗑️ ${collectionName}/${doc.id}`);
  }
  if (n) console.log(`  ✅ ${collectionName}: ${n}건 삭제`);
  else console.log(`  ⏭️ ${collectionName}: 삭제할 문서 없음`);
}

/** weeklyGoals 문서 ID: {uid}_{weekKey} */
async function sweepWeeklyGoals(db, preserveUid) {
  const snap = await db.collection("weeklyGoals").get();
  const prefix = `${preserveUid}_`;
  let n = 0;
  for (const doc of snap.docs) {
    if (doc.id.startsWith(prefix)) continue;
    await doc.ref.delete();
    n++;
    console.log(`  🗑️ weeklyGoals/${doc.id}`);
  }
  if (n) console.log(`  ✅ weeklyGoals: ${n}건 삭제`);
  else console.log(`  ⏭️ weeklyGoals: 삭제 없음`);
}

/** ownerUid / applicantUid 가 보존이 아닌 문서 삭제 */
async function sweepByOwnerField(db, collectionName, fieldName, preserveUid) {
  const snap = await db.collection(collectionName).get();
  let n = 0;
  for (const doc of snap.docs) {
    const v = doc.data()?.[fieldName];
    if (v === preserveUid) continue;
    await doc.ref.delete();
    n++;
    console.log(`  🗑️ ${collectionName}/${doc.id}`);
  }
  if (n) console.log(`  ✅ ${collectionName}: ${n}건 삭제`);
  else console.log(`  ⏭️ ${collectionName}: 삭제 없음`);
}

/** Storage: users/·profileImages/·avatars/ 아래 2번째 세그먼트(uid) 기준, 보존 UID 제외 삭제 */
async function sweepStorageUserPrefixes(bucket, preserveUid) {
  const topPrefixes = ["users/", "profileImages/", "avatars/"];
  let total = 0;
  for (const prefix of topPrefixes) {
    const [files] = await bucket.getFiles({ prefix });
    for (const file of files) {
      const parts = file.name.split("/");
      if (parts.length < 2) continue;
      const uid = parts[1];
      if (uid === preserveUid) continue;
      await file.delete().catch(() => {});
      total++;
    }
  }
  console.log(`  ✅ Storage (${topPrefixes.join(", ")}) 비보존 파일 ${total}개 삭제 시도`);
}

async function main() {
  if (!process.argv.includes("--confirm")) {
    console.error(
      "❌ 실수 방지: 다음으로 실행하세요.\n" +
        `   node tools/mass-delete-users-except.cjs --confirm\n\n` +
        `보존 UID: ${PRESERVE_UID}`,
    );
    process.exit(1);
  }

  const admin = loadFirebaseAdmin();
  const serviceAccount = loadServiceAccount();

  if (!admin.apps.length) {
    const projectId = serviceAccount.project_id || "chikabooks3rd";
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId,
      storageBucket: `${projectId}.firebasestorage.app`,
    });
  }

  const db = admin.firestore();
  const auth = admin.auth();
  const bucket = admin.storage().bucket();

  const { performAccountDeletion } = require(path.join(
    functionsDir,
    "lib",
    "account-deletion.js",
  ));

  console.log(`🔒 보존 UID: ${PRESERVE_UID}`);
  console.log("\n━━━ 1) Firebase Auth + 탈퇴 플로우 ━━━\n");

  let pageToken;
  let deleted = 0;
  const errors = [];

  do {
    const result = await auth.listUsers(1000, pageToken);
    for (const userRecord of result.users) {
      const uid = userRecord.uid;
      if (uid === PRESERVE_UID) {
        console.log(
          `⏭️  건너뜀 (보존): ${uid} (${userRecord.email || "no email"})`,
        );
        continue;
      }
      console.log(`… 삭제 중: ${uid} (${userRecord.email || "no email"})`);
      try {
        await deleteClinicsAccountIfAny(db, uid);
        await performAccountDeletion(uid);
        deleted++;
        console.log(`   ✅ 완료: ${uid}`);
      } catch (e) {
        console.error(`   ❌ 실패: ${uid}`, e);
        errors.push({ uid, error: String(e?.message || e) });
      }
    }
    pageToken = result.pageToken;
  } while (pageToken);

  console.log(`\n📊 Auth 삭제 성공: ${deleted}명`);
  if (errors.length) {
    console.log(`⚠️  Auth/탈퇴 실패: ${errors.length}건`, errors);
  }

  console.log("\n━━━ 2) Firestore 스윕 (고아·잔여 UID 문서) ━━━\n");

  await sweepUidDocIds(db, "users", PRESERVE_UID);
  await sweepUidDocIds(db, "clinics_accounts", PRESERVE_UID);
  await sweepUidDocIds(db, "publicProfiles", PRESERVE_UID);
  await sweepUidDocIds(db, "notifications", PRESERVE_UID);
  await sweepUidDocIds(db, "clinicVerifications", PRESERVE_UID);
  await sweepUidDocIds(db, "deletedUsers", PRESERVE_UID);

  await sweepWeeklyGoals(db, PRESERVE_UID);

  await sweepByOwnerField(db, "vouchers", "ownerUid", PRESERVE_UID);
  await sweepByOwnerField(db, "orders", "ownerUid", PRESERVE_UID);
  await sweepByOwnerField(db, "resumes", "ownerUid", PRESERVE_UID);
  await sweepByOwnerField(db, "resumeDrafts", "ownerUid", PRESERVE_UID);
  await sweepByOwnerField(db, "resumeImportDrafts", "ownerUid", PRESERVE_UID);
  await sweepByOwnerField(db, "jobDrafts", "ownerUid", PRESERVE_UID);
  await sweepByOwnerField(db, "jobs", "ownerUid", PRESERVE_UID);
  await sweepByOwnerField(db, "applications", "applicantUid", PRESERVE_UID);

  console.log("\n━━━ 3) Storage 스윕 ━━━\n");
  await sweepStorageUserPrefixes(bucket, PRESERVE_UID);

  console.log("\n✅ 전체 작업 종료.");
  if (errors.length) process.exit(1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
