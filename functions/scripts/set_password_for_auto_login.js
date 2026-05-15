/**
 * ── [CHIKA_WEB_AUTO_LOGIN: BEGIN] ──────────────────────────────────
 * 임시 기능 — 웹 자동 로그인용 계정에 이메일/비밀번호 자격을 추가/갱신.
 * (검색 키워드: CHIKA_WEB_AUTO_LOGIN)
 *
 * 무엇:
 *   Google 등 SNS 로만 가입돼 있어 signInWithEmailAndPassword 가 막힌
 *   계정에 비밀번호 provider 를 한 번에 추가한다. 기존 SNS 로그인은 그대로
 *   유지된다 (Firebase 는 한 계정에 여러 provider 동시 가능).
 *
 * 사용:
 *   1) 프로젝트 루트에 .chika_web_login.env 가 채워져 있어야 함
 *   2) cd functions && node scripts/set_password_for_auto_login.js
 *
 * 원복:
 *   - 자동 로그인 기능 자체를 원복할 때 이 파일도 함께 삭제.
 *   - 실 계정에 부여된 비밀번호를 끄고 싶다면 Firebase Console →
 *     Authentication → 해당 유저 → "Remove account" 또는 비번을 모르는
 *     상태로 두기 (제거 API 는 SDK 에 없음 — 새 비번으로 덮어 쓰는 방식).
 * ── [CHIKA_WEB_AUTO_LOGIN: END] ────────────────────────────────────
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const SERVICE_KEY = path.join(__dirname, '..', 'serviceAccountKey.json');
const ENV_FILE = path.join(__dirname, '..', '..', '.chika_web_login.env');

function loadEnv(file) {
  if (!fs.existsSync(file)) return {};
  const out = {};
  for (const raw of fs.readFileSync(file, 'utf8').split('\n')) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const idx = line.indexOf('=');
    if (idx <= 0) continue;
    const k = line.slice(0, idx).trim();
    let v = line.slice(idx + 1).trim();
    if (
      (v.startsWith("'") && v.endsWith("'")) ||
      (v.startsWith('"') && v.endsWith('"'))
    ) {
      v = v.slice(1, -1);
    }
    out[k] = v;
  }
  return out;
}

async function applyPassword(label, email, password) {
  if (!email || !password) {
    console.log(`▷ ${label}: 자격 증명이 비어 있어 건너뜀`);
    return { skipped: true };
  }
  try {
    const user = await admin.auth().getUserByEmail(email);
    const providers = (user.providerData || []).map((p) => p.providerId);
    console.log(`▶ [${label}] ${email}  uid=${user.uid}`);
    console.log(`  기존 provider: ${providers.join(', ') || '(없음)'}`);
    await admin.auth().updateUser(user.uid, { password });
    const after = await admin.auth().getUser(user.uid);
    const afterIds = (after.providerData || []).map((p) => p.providerId);
    console.log(`  적용 후 provider: ${afterIds.join(', ')}`);
    console.log(`✅ [${label}] 비밀번호 설정 완료 — signInWithEmailAndPassword 가능\n`);
    return { ok: true };
  } catch (e) {
    console.error(`✘ [${label}] 실패:`, e && e.message ? e.message : e);
    return { ok: false, error: e };
  }
}

(async () => {
  if (!fs.existsSync(SERVICE_KEY)) {
    console.error(`✘ serviceAccountKey.json 이 없음: ${SERVICE_KEY}`);
    process.exit(1);
  }
  const env = { ...process.env, ...loadEnv(ENV_FILE) };

  const applicantEmail = (env.CHIKA_WEB_AUTO_EMAIL || '').trim();
  const applicantPw = env.CHIKA_WEB_AUTO_PASSWORD || '';
  const clinicEmail = (env.CHIKA_WEB_AUTO_CLINIC_EMAIL || '').trim();
  const clinicPw = env.CHIKA_WEB_AUTO_CLINIC_PASSWORD || '';

  if (!applicantEmail || !applicantPw) {
    console.error('✘ CHIKA_WEB_AUTO_EMAIL / CHIKA_WEB_AUTO_PASSWORD 필요');
    process.exit(1);
  }

  const serviceAccount = require(SERVICE_KEY);
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

  const results = [];
  try {
    results.push({
      label: 'applicant',
      ...(await applyPassword('applicant', applicantEmail, applicantPw)),
    });
    // clinic 자격 증명이 채워진 경우만 추가 처리.
    if (clinicEmail || clinicPw) {
      results.push({
        label: 'clinic',
        ...(await applyPassword('clinic', clinicEmail, clinicPw)),
      });
    } else {
      console.log('▷ clinic: .env 에 CHIKA_WEB_AUTO_CLINIC_* 미설정 — 건너뜀');
    }
  } finally {
    await admin.app().delete().catch(() => {});
  }

  const failed = results.filter((r) => r && r.ok === false);
  if (failed.length > 0) {
    console.error(`\n✘ 일부 계정 처리 실패: ${failed.map((r) => r.label).join(', ')}`);
    process.exit(1);
  }
})();
