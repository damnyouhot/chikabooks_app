/**
 * 일회성 마이그레이션:
 *   `deletedUsers/{uid}.signUpCount` 값을 모두 **1**로 보정한다.
 *
 * 배경:
 *   `performAccountDeletion` 이전 버전은 `saveDeletedUserRecord`를
 *   `deleteAuthAccount`보다 먼저 실행해서, Auth 삭제가 실패해 클라이언트가
 *   재시도하면 동일 사용자에게 signUpCount가 +1 씩 누적되는 버그가 있었음.
 *
 *   본 스크립트는 신뢰할 수 있는 "진짜 재가입 횟수" 증거가 없는 상황에서
 *   가장 보수적이고 안전한 정책으로 카운터를 1로 일괄 보정한다.
 *
 * 영향:
 *   `OnboardingService.shouldShowOnboardingForReturningUser`는
 *   `signUpCount <= 1` 이면 온보딩을 표시한다. 즉 카운터가 1로 보정되면
 *   재가입 시 온보딩이 한 번 더 노출될 수 있는데, 이는 신규 사용자 흐름과
 *   동일하므로 부작용이 작다.
 *
 * 사용법:
 *   # dry-run (기본): 영향도만 확인, 변경 없음
 *   node tools/cap_deleted_users_signup_count.cjs
 *
 *   # 실제 적용
 *   node tools/cap_deleted_users_signup_count.cjs --confirm
 *
 * 사전 준비:
 *   - functions/serviceAccountKey.json 또는 GOOGLE_APPLICATION_CREDENTIALS 환경변수
 */

const fs = require("fs");
const path = require("path");

const projectRoot = path.join(__dirname, "..");
const functionsDir = path.join(projectRoot, "functions");
const adminModulePath = path.join(
  functionsDir,
  "node_modules",
  "firebase-admin",
);

const TARGET_VALUE = 1;
const BATCH_SIZE = 400; // Firestore batch 한도 500 미만으로 여유

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

async function main() {
  const confirm = process.argv.includes("--confirm");
  const admin = loadFirebaseAdmin();
  admin.initializeApp({
    credential: admin.credential.cert(loadServiceAccount()),
  });
  const db = admin.firestore();

  console.log(
    `\n🚧 cap_deleted_users_signup_count.cjs (${confirm ? "APPLY" : "DRY-RUN"})`,
  );
  console.log("   target collection : deletedUsers");
  console.log(`   target value      : signUpCount → ${TARGET_VALUE}`);
  console.log("");

  const snap = await db.collection("deletedUsers").get();
  if (snap.empty) {
    console.log("⏭️ deletedUsers 컬렉션이 비어 있습니다. 종료.");
    return;
  }

  const stats = {
    total: snap.size,
    missingField: 0,
    alreadyTarget: 0,
    needsCap: 0,
    distribution: new Map(), // count → 문서 수
    samples: [], // 미리보기용 (uid, count) 최대 10건
  };

  for (const doc of snap.docs) {
    const raw = doc.data()?.signUpCount;
    const count = typeof raw === "number" ? raw : null;
    if (count == null) {
      stats.missingField++;
      continue;
    }
    stats.distribution.set(count, (stats.distribution.get(count) ?? 0) + 1);
    if (count === TARGET_VALUE) {
      stats.alreadyTarget++;
    } else {
      stats.needsCap++;
      if (stats.samples.length < 10) {
        stats.samples.push({ uid: doc.id, count });
      }
    }
  }

  console.log("📊 현재 상태");
  console.log(`   전체 문서          : ${stats.total}`);
  console.log(`   signUpCount 누락    : ${stats.missingField}`);
  console.log(`   이미 ${TARGET_VALUE}             : ${stats.alreadyTarget}`);
  console.log(`   보정 대상 (≠${TARGET_VALUE})    : ${stats.needsCap}`);
  console.log("");

  if (stats.distribution.size) {
    const sorted = Array.from(stats.distribution.entries()).sort(
      (a, b) => a[0] - b[0],
    );
    console.log("📈 signUpCount 분포");
    for (const [value, n] of sorted) {
      console.log(`   ${String(value).padStart(4)} : ${n}건`);
    }
    console.log("");
  }

  if (stats.samples.length) {
    console.log("🔎 보정 대상 샘플 (최대 10건)");
    for (const s of stats.samples) {
      console.log(`   ${s.uid}  (signUpCount=${s.count})`);
    }
    console.log("");
  }

  if (!confirm) {
    console.log(
      "✅ DRY-RUN 완료. 실제 보정은 `--confirm` 플래그를 추가해 다시 실행하세요.",
    );
    return;
  }

  if (stats.needsCap === 0) {
    console.log("✅ 보정할 문서가 없습니다. 종료.");
    return;
  }

  console.log(`✏️ 보정 적용 시작: ${stats.needsCap}건`);
  let applied = 0;
  let batch = db.batch();
  let inBatch = 0;

  for (const doc of snap.docs) {
    const raw = doc.data()?.signUpCount;
    const count = typeof raw === "number" ? raw : null;
    if (count == null) continue;
    if (count === TARGET_VALUE) continue;

    batch.update(doc.ref, { signUpCount: TARGET_VALUE });
    inBatch++;
    applied++;

    if (inBatch >= BATCH_SIZE) {
      await batch.commit();
      console.log(`   ↻ commit: 누적 ${applied}건`);
      batch = db.batch();
      inBatch = 0;
    }
  }

  if (inBatch > 0) {
    await batch.commit();
    console.log(`   ↻ commit: 누적 ${applied}건`);
  }

  console.log(`✅ 보정 완료: ${applied}건 갱신됨.`);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("❌ 마이그레이션 실패:", err);
    process.exit(1);
  });
