/**
 * Chikabooks 테스트 유저 시드 스크립트
 *
 * Firebase Auth에 테스트 계정 10개를 생성하고,
 * Firestore users/{uid} + partnerMatchingPool/{uid} 문서를 함께 만듭니다.
 *
 * ───────────── 사전 준비 ─────────────
 * 1. Firebase 콘솔 → 프로젝트 설정 → 서비스 계정 → "새 비공개 키 생성"
 * 2. 다운로드된 JSON 파일을 tools/serviceAccountKey.json 으로 저장
 * 3. 이 파일은 .gitignore에 추가하여 절대 커밋하지 말 것!
 *
 * ───────────── 실행 방법 ─────────────
 * cd <project_root>
 * node tools/seed_test_users.js
 *
 * ⚠️ 이 스크립트는 로컬 개발 전용입니다. 운영 환경에서 실행 금지.
 */

const admin = require("firebase-admin");
const path = require("path");

// serviceAccountKey.json 경로
const serviceAccount = require(path.join(__dirname, "serviceAccountKey.json"));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// ── 선택지 데이터 ──

const regions = [
  "서울", "경기", "인천", "부산", "대구", "광주",
  "대전", "울산", "세종", "강원", "충북", "충남",
  "전북", "전남", "경북", "경남", "제주",
];

const careers = ["0-2", "3-5", "6+"];

const concerns = [
  "환자 응대",
  "원장/상사 관계",
  "동료 관계/팀 분위기",
  "업무량/동선/체력",
  "보험청구/실무 숙련",
  "술기 성장(교정/임플란트 등)",
  "이직/커리어/연봉",
  "번아웃/감정 소진",
];

const workplaceTypes = ["개인치과", "네트워크", "대학병원", "기타"];

// ── 유틸 ──

function pick(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function pickTwo(arr) {
  const a = pick(arr);
  let b = pick(arr);
  while (b === a) b = pick(arr);
  return [a, b];
}

// ── 메인 ──

async function main() {
  console.log("🔧 테스트 유저 10명 시드 시작...\n");

  const created = [];

  for (let i = 1; i <= 10; i++) {
    const email = `test_hygienist_${i}@example.com`;
    const password = "Test1234!";

    let userRecord;
    try {
      // 이미 존재하면 가져오기
      userRecord = await admin.auth().getUserByEmail(email);
      console.log(`  ↳ 기존 계정 발견: ${email} (uid: ${userRecord.uid})`);
    } catch {
      // 없으면 새로 생성
      userRecord = await admin.auth().createUser({
        email,
        password,
        displayName: `테스트치위${i}`,
      });
      console.log(`  ✅ 계정 생성: ${email} (uid: ${userRecord.uid})`);
    }

    const uid = userRecord.uid;
    const region = pick(regions);
    const careerBucket = pick(careers);
    const mainConcerns = pickTwo(concerns);
    const workplaceType = pick(workplaceTypes);
    const bondScore = 50.0 + Math.floor(Math.random() * 20); // 50~69

    // users/{uid} 문서 생성/업데이트
    await db.collection("users").doc(uid).set(
      {
        uid,
        nickname: `테스트치위${i}`,
        region,
        careerBucket,
        mainConcerns,
        workplaceType,
        bondScore,
        bondScoreVersion: 2,
        lastActiveAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // 매칭 풀에 waiting 상태로 등록
    await db.collection("partnerMatchingPool").doc(uid).set(
      {
        uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        region,
        careerBucket,
        workplaceType,
        mainConcerns,
        status: "waiting",
      },
      { merge: true }
    );

    created.push({
      "#": i,
      email,
      uid: uid.substring(0, 8) + "...",
      region,
      career: careerBucket,
      concerns: mainConcerns.map((c) => c.substring(0, 6)).join(", "),
      workplace: workplaceType,
    });
  }

  console.log("\n✅ 시드 완료! 생성된 계정:\n");
  console.table(created);
  console.log("\n📌 비밀번호: Test1234! (모든 계정 동일)");
  console.log("📌 매칭 풀에 10명이 waiting 상태로 등록되어 있습니다.");
  console.log("📌 앱에서 '추천으로 찾기'를 누르면 즉시 매칭이 시작됩니다.\n");

  process.exit(0);
}

main().catch((err) => {
  console.error("❌ 시드 실패:", err);
  process.exit(1);
});



