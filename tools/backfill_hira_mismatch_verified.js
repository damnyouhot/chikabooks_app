/**
 * 기존 데이터 정리:
 *   businessVerification.status == "verified" 이지만
 *   businessVerification.hiraMatched == false 인 clinic_profiles 를
 *   새 정책에 맞게 재분류한다.
 *
 * 정책:
 *   - 개원일이 있고 1개월 이내: provisional (게시 가능, 신규 개원 유예)
 *   - 개원일이 없거나 1개월 초과: manual_review (게시 불가)
 *
 * 사용:
 *   node tools/backfill_hira_mismatch_verified.js          # dry-run
 *   node tools/backfill_hira_mismatch_verified.js --apply  # 실제 반영
 */

const fs = require("fs");
const path = require("path");

const projectRoot = path.join(__dirname, "..");
const functionsDir = path.join(projectRoot, "functions");
const adminModulePath = path.join(functionsDir, "node_modules", "firebase-admin");

function loadFirebaseAdmin() {
  if (!fs.existsSync(adminModulePath)) {
    console.error("firebase-admin 을 찾을 수 없습니다. cd functions && npm install");
    process.exit(1);
  }
  return require(adminModulePath);
}

function loadServiceAccount() {
  const envPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const defaultPath = path.join(functionsDir, "serviceAccountKey.json");
  const keyPath = envPath && fs.existsSync(envPath) ? envPath : defaultPath;
  if (!fs.existsSync(keyPath)) {
    console.error(`서비스 계정 JSON이 없습니다: ${defaultPath}`);
    process.exit(1);
  }
  return JSON.parse(fs.readFileSync(keyPath, "utf8"));
}

function parseOpenedAt(value) {
  if (!value) return null;
  if (typeof value.toDate === "function") return value.toDate();
  if (value instanceof Date && !Number.isNaN(value.getTime())) return value;

  const raw = String(value).trim();
  const m = raw.match(/^(\d{4})[-./년\s]?(\d{1,2})[-./월\s]?(\d{1,2})/);
  if (!m) return null;
  const year = Number(m[1]);
  const month = Number(m[2]);
  const day = Number(m[3]);
  if (!year || month < 1 || month > 12 || day < 1 || day > 31) return null;
  const d = new Date(Date.UTC(year, month - 1, day));
  if (
    d.getUTCFullYear() !== year ||
    d.getUTCMonth() !== month - 1 ||
    d.getUTCDate() !== day
  ) {
    return null;
  }
  return d;
}

function isWithinGrace(openedAt, now = new Date()) {
  const graceUntil = new Date(openedAt.getTime());
  graceUntil.setUTCMonth(graceUntil.getUTCMonth() + 1);
  return now.getTime() <= graceUntil.getTime();
}

function daysSince(openedAt, now = new Date()) {
  return Math.max(0, Math.floor((now.getTime() - openedAt.getTime()) / 86400000));
}

async function main() {
  const apply = process.argv.includes("--apply");
  const admin = loadFirebaseAdmin();
  const serviceAccount = loadServiceAccount();
  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  }
  const db = admin.firestore();

  const snap = await db
    .collectionGroup("clinic_profiles")
    .get();

  const targets = snap.docs.filter((doc) => {
    const bv = doc.data().businessVerification || {};
    return bv.status === "verified" && bv.hiraMatched === false;
  });

  console.log(
    `clinic_profiles 문서 수: ${snap.size}, verified + HIRA 불일치 대상: ${targets.length} (${apply ? "APPLY" : "DRY-RUN"})`,
  );

  let toProvisional = 0;
  let toManual = 0;
  const batch = db.batch();

  for (const doc of targets) {
    const data = doc.data();
    const bv = data.businessVerification || {};
    const openedAt = parseOpenedAt(bv.openedAt || bv.ocrResult?.openedAt);
    const clinicName = data.clinicName || data.displayName || "(이름 없음)";
    const rel = doc.ref.path;

    if (openedAt && isWithinGrace(openedAt)) {
      toProvisional += 1;
      console.log(
        `→ provisional: ${clinicName} / ${rel} / openedAt=${openedAt.toISOString().slice(0, 10)} / days=${daysSince(openedAt)}`,
      );
      if (apply) {
        batch.update(doc.ref, {
          "businessVerification.status": "provisional",
          "businessVerification.verifiedAt": null,
          "businessVerification.failReason": admin.firestore.FieldValue.delete(),
          "businessVerification.policyReason": "new_clinic_hira_grace",
          "businessVerification.newClinicGraceDaysSinceOpened": daysSince(openedAt),
          "businessVerification.openedAt": admin.firestore.Timestamp.fromDate(openedAt),
          "businessVerification.lastCheckAt": admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    } else {
      toManual += 1;
      const reason = openedAt ?
        "hira_mismatch_after_grace" :
        "hira_mismatch_opened_at_unknown";
      console.log(
        `→ manual_review: ${clinicName} / ${rel} / reason=${reason}`,
      );
      if (apply) {
        batch.update(doc.ref, {
          "businessVerification.status": "manual_review",
          "businessVerification.verifiedAt": null,
          "businessVerification.failReason": reason,
          "businessVerification.policyReason": admin.firestore.FieldValue.delete(),
          "businessVerification.newClinicGraceDaysSinceOpened":
            admin.firestore.FieldValue.delete(),
          ...(openedAt
            ? {"businessVerification.openedAt": admin.firestore.Timestamp.fromDate(openedAt)}
            : {"businessVerification.openedAt": admin.firestore.FieldValue.delete()}),
          "businessVerification.lastCheckAt": admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }
  }

  console.log(`요약: provisional=${toProvisional}, manual_review=${toManual}`);
  if (apply && targets.length > 0) {
    await batch.commit();
    console.log("반영 완료");
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
