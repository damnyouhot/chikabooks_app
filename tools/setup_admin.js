/**
 * 관리자 계정 설정 (Firebase Admin SDK)
 *
 * 앱·Firestore 규칙은 `users/{uid}.isAdmin == true` 만 인정합니다.
 * 통계 제외는 `excludeFromStats: true` 입니다.
 *
 * 사전 준비:
 *   1) Firebase Console → 프로젝트 설정 → 서비스 계정 → 새 비공개 키
 *   2) `functions/serviceAccountKey.json` 으로 저장 (git에 커밋하지 말 것)
 *   3) `cd functions && npm install`
 *
 * 사용법 (프로젝트 루트 또는 functions 폴더에서 모두 가능):
 *   node tools/setup_admin.js <Firebase UID>
 *   node tools/setup_admin.js someuser@gmail.com
 *   node tools/setup_admin.js --by-email-prefix Yhgjd
 *     → Auth에서 이메일이 해당 접두사(대소문자 무시)로 시작하는 사용자 검색 후 1명일 때만 설정
 *
 * 옵션:
 *   --no-exclude     관리자만 지정, 통계에는 포함 (excludeFromStats: false)
 *   --exclude-only   통계만 제외, 관리자 아님 (isAdmin: false)
 *
 * 환경 변수:
 *   GOOGLE_APPLICATION_CREDENTIALS=/절대경로/serviceAccount.json
 *   (설정 시 functions/serviceAccountKey.json 대신 사용)
 */

const fs = require("fs");
const path = require("path");

const projectRoot = path.join(__dirname, "..");
const functionsDir = path.join(projectRoot, "functions");
const adminModulePath = path.join(functionsDir, "node_modules", "firebase-admin");

function loadFirebaseAdmin() {
  if (!fs.existsSync(adminModulePath)) {
    console.error(
      "❌ firebase-admin 을 찾을 수 없습니다. 다음을 실행하세요:\n" +
        "   cd functions && npm install",
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
      "❌ 서비스 계정 JSON이 없습니다.\n" +
        "   - Firebase Console → 프로젝트 설정 → 서비스 계정 → 새 비공개 키\n" +
        `   - 저장: ${defaultPath}\n` +
        "   또는 GOOGLE_APPLICATION_CREDENTIALS 환경 변수로 경로 지정\n",
    );
    process.exit(1);
  }

  const raw = fs.readFileSync(keyPath, "utf8");
  return JSON.parse(raw);
}

function parseArgs(argv) {
  const flags = new Set();
  const positional = [];
  for (const a of argv) {
    if (a === "--no-exclude") flags.add("no-exclude");
    else if (a === "--exclude-only") flags.add("exclude-only");
    else if (a === "--by-email-prefix") flags.add("by-email-prefix");
    else if (a.startsWith("-")) {
      console.error(`❌ 알 수 없는 옵션: ${a}`);
      process.exit(1);
    } else positional.push(a);
  }
  if (flags.has("no-exclude") && flags.has("exclude-only")) {
    console.error("❌ --no-exclude 와 --exclude-only 는 함께 쓸 수 없습니다.");
    process.exit(1);
  }
  if (flags.has("by-email-prefix") && flags.has("exclude-only")) {
    console.error("❌ --by-email-prefix 와 --exclude-only 는 함께 쓰지 마세요.");
    process.exit(1);
  }
  return { positional, flags };
}

/** @param {any} auth firebase-admin auth() */
async function findUsersByEmailPrefix(auth, prefix) {
  const lower = prefix.trim().toLowerCase();
  if (!lower) return [];
  /** @type {{ uid: string, email: string }[]} */
  const matches = [];
  let pageToken;
  do {
    const result = await auth.listUsers(1000, pageToken);
    for (const u of result.users) {
      const em = u.email;
      if (em && em.toLowerCase().startsWith(lower)) {
        matches.push({ uid: u.uid, email: em });
      }
    }
    pageToken = result.pageToken;
  } while (pageToken);
  return matches;
}

async function main() {
  const admin = loadFirebaseAdmin();
  const serviceAccount = loadServiceAccount();

  const { positional, flags } = parseArgs(process.argv.slice(2));

  let isAdmin = true;
  let excludeFromStats = true;
  if (flags.has("no-exclude")) excludeFromStats = false;
  if (flags.has("exclude-only")) {
    isAdmin = false;
    excludeFromStats = true;
  }

  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  }

  const db = admin.firestore();
  const auth = admin.auth();

  let uid;

  if (flags.has("by-email-prefix")) {
    const prefix = positional[0];
    if (!prefix) {
      console.error(
        "❌ 사용법: node tools/setup_admin.js --by-email-prefix <접두사>\n" +
          "예: node tools/setup_admin.js --by-email-prefix Yhgjd",
      );
      process.exit(1);
    }
    console.log(`🔍 이메일 접두사 "${prefix}" 로 Auth 사용자 검색 중…`);
    const matches = await findUsersByEmailPrefix(auth, prefix);
    if (matches.length === 0) {
      console.error("❌ 일치하는 사용자가 없습니다.");
      process.exit(1);
    }
    if (matches.length > 1) {
      console.error(
        `❌ 동일 접두사 사용자가 ${matches.length}명입니다. 전체 이메일로 다시 실행하세요:\n` +
          matches.map((m) => `   - ${m.email} (${m.uid})`).join("\n"),
      );
      process.exit(1);
    }
    uid = matches[0].uid;
    console.log(`✅ 선택: ${matches[0].email} → UID ${uid}`);
  } else {
    const arg = positional[0];
    if (!arg) {
      console.error(
        "❌ 사용법:\n" +
          "   node tools/setup_admin.js <UID 또는 이메일>\n" +
          "   node tools/setup_admin.js --by-email-prefix Yhgjd\n" +
          "예:\n" +
          "   node tools/setup_admin.js abc123xyz\n" +
          "   node tools/setup_admin.js you@gmail.com",
      );
      process.exit(1);
    }
    uid = arg.trim();
    if (uid.includes("@")) {
      try {
        const user = await auth.getUserByEmail(uid);
        uid = user.uid;
        console.log(`📧 이메일로 UID 확인: ${uid}`);
      } catch (e) {
        console.error("❌ 해당 이메일의 Auth 사용자를 찾을 수 없습니다:", e.message);
        process.exit(1);
      }
    }
  }

  try {
    await db
      .collection("users")
      .doc(uid)
      .set(
        {
          isAdmin,
          excludeFromStats,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

    // 레거시 참고용 (앱 라우팅/규칙은 사용 안 함). UID만 누적.
    await db
      .collection("config")
      .doc("admins")
      .set(
        {
          uids: admin.firestore.FieldValue.arrayUnion(uid),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

    console.log("✅ users 문서 갱신 완료");
    console.log(`   UID: ${uid}`);
    console.log(`   isAdmin: ${isAdmin}`);
    console.log(`   excludeFromStats: ${excludeFromStats}`);
    console.log("");
    console.log("📱 앱에서 관리자 메뉴가 안 보이면 로그아웃 후 다시 로그인하세요.");
    process.exit(0);
  } catch (error) {
    console.error("❌ Firestore 오류:", error);
    process.exit(1);
  }
}

main();
