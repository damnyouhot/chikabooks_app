/**
 * 사업자등록증 OCR 이후 국세청(및 향후 HIRA) 검증 로직.
 * verifyBusinessLicense(OCR)와 분리해 유지보수·재시도에 유리하다.
 */
import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";
import axios from "axios";
import type {HiraMatchLevel} from "./hira-match-tier";
import {matchHiraClinicName} from "./hira-hospital-match";

/** Firestore businessVerification.status 와 동일한 문자열 */
export type RunCheckStatus =
  | "verified"
  | "provisional"
  | "rejected"
  | "manual_review"
  | "pending_auto";

export interface RunCheckResult {
  status: RunCheckStatus;
  failReason?: string;
  method: "nts" | "mock";
  /** 이미 verified였거나 검증을 건너뜀 */
  skipped?: boolean;
  /** 심평원 병원목록 대조 (보조) */
  hiraMatched?: boolean | null;
  hiraNote?: string;
  /** strict | partial | none */
  hiraMatchLevel?: HiraMatchLevel;
}

const NEW_CLINIC_GRACE_MONTHS = 1;

/**
 * 하이픈 등 비숫자 제거
 * @param {string} raw 원본 문자열
 * @return {string} 숫자만
 */
export function normalizeBizNoDigits(raw: string): string {
  return String(raw ?? "").replace(/[^0-9]/g, "");
}

interface NtsParseResult {
  valid: boolean;
  closed: boolean;
}

/**
 * 국세청 오픈API — 사업자 상태조회 (status)
 * @param {string} bizNoDigits 10자리 숫자
 * @param {string} serviceKey 공공데이터포털 서비스키
 * @return {Promise<NtsParseResult>} 유효·폐업 여부
 * @see https://www.data.go.kr (국세청_사업자등록정보 진위확인 및 상태조회)
 */
async function callNtsStatusApi(
  bizNoDigits: string,
  serviceKey: string
): Promise<NtsParseResult> {
  const url = "https://api.odcloud.kr/api/nts-businessman/v1/status";
  const resp = await axios.post(
    url,
    {b_no: [bizNoDigits]},
    {
      params: {serviceKey},
      timeout: 20000,
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
    }
  );

  const matchCnt = Number(resp.data?.match_cnt ?? 0);
  if (matchCnt < 1 || !resp.data?.data?.[0]) {
    return {valid: false, closed: false};
  }
  const row = resp.data.data[0];
  const stt = String(row.b_stt ?? "");
  const closed =
    stt.includes("폐업") ||
    stt.includes("휴업") ||
    String(row.b_stt_cd ?? "") === "03";
  return {valid: true, closed};
}

async function runHiraSupplement(
  clinicName: string,
  address: string,
  /** defineSecret().value() 등으로 전달(문자열 시크릿은 런타임에 env 미주입되는 경우가 있어 우선 사용) */
  hiraKeyOverride?: string
): Promise<{matched: boolean | null; note: string; level: HiraMatchLevel}> {
  const hiraKey = String(
    hiraKeyOverride ?? process.env.HIRA_SERVICE_KEY ?? ""
  ).trim();
  if (!hiraKey) {
    return {matched: null, note: "HIRA(공공데이터) 키 미설정", level: "none"};
  }
  if (!clinicName.trim()) {
    return {matched: null, note: "상호 없음", level: "none"};
  }
  return matchHiraClinicName(clinicName, address, hiraKey);
}

/**
 * Mock: 사업자번호 끝 2자리로 결과 시뮬레이션 (키 없을 때)
 * - 00: 폐업으로 간주 → rejected
 * - 99: HIRA 불일치 가정 → manual_review
 * - 그 외: verified
 * @param {string} bizNoDigits 숫자만
 * @return {{closed: boolean, hiraMismatch: boolean}} 시뮬 결과
 */
function mockDecision(
  bizNoDigits: string
): { closed: boolean; hiraMismatch: boolean } {
  const tail = bizNoDigits.slice(-2);
  if (tail === "00") {
    return {closed: true, hiraMismatch: false};
  }
  if (tail === "99") {
    return {closed: false, hiraMismatch: true};
  }
  return {closed: false, hiraMismatch: false};
}

function parseOpenedAt(value: unknown): Date | null {
  if (!value) return null;
  if (value instanceof admin.firestore.Timestamp) {
    return value.toDate();
  }
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return value;
  }

  const raw = String(value).trim();
  if (!raw) return null;

  const ymd = raw.match(/^(\d{4})[-./년\s]?(\d{1,2})[-./월\s]?(\d{1,2})/);
  if (!ymd) return null;

  const year = Number(ymd[1]);
  const month = Number(ymd[2]);
  const day = Number(ymd[3]);
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

function isWithinNewClinicGrace(openedAt: Date, now = new Date()): boolean {
  const graceUntil = new Date(openedAt.getTime());
  graceUntil.setUTCMonth(graceUntil.getUTCMonth() + NEW_CLINIC_GRACE_MONTHS);
  return now.getTime() <= graceUntil.getTime();
}

function daysSince(openedAt: Date, now = new Date()): number {
  const ms = now.getTime() - openedAt.getTime();
  return Math.max(0, Math.floor(ms / (1000 * 60 * 60 * 24)));
}

async function applyHiraDecision(args: {
  profileRef: FirebaseFirestore.DocumentReference<FirebaseFirestore.DocumentData>;
  method: "nts" | "mock";
  bizNoRaw: string;
  hira: {matched: boolean | null; note: string; level: HiraMatchLevel};
  openedAtRaw: unknown;
}): Promise<RunCheckResult> {
  const openedAt = parseOpenedAt(args.openedAtRaw);

  let status: RunCheckStatus = "provisional";
  let failReason: string | undefined;
  const extra: Record<string, unknown> = {};

  if (args.hira.matched === false) {
    if (!openedAt) {
      status = "manual_review";
      failReason = "hira_mismatch_opened_at_unknown";
    } else if (isWithinNewClinicGrace(openedAt)) {
      status = "provisional";
      extra["businessVerification.policyReason"] = "new_clinic_hira_grace";
      extra["businessVerification.newClinicGraceDaysSinceOpened"] =
        daysSince(openedAt);
    } else {
      status = "manual_review";
      failReason = "hira_mismatch_after_grace";
    }
  }

  await args.profileRef.update({
    "businessVerification.status": status,
    "businessVerification.bizNo": args.bizNoRaw,
    "businessVerification.failReason": failReason ??
      admin.firestore.FieldValue.delete(),
    "businessVerification.lastCheckAt":
      admin.firestore.FieldValue.serverTimestamp(),
    "businessVerification.checkMethod": args.method,
    "businessVerification.verifiedAt": null,
    "businessVerification.hiraMatched": args.hira.matched,
    "businessVerification.hiraNote": args.hira.note,
    "businessVerification.hiraMatchLevel": args.hira.level,
    "businessVerification.openedAt": openedAt ?
      admin.firestore.Timestamp.fromDate(openedAt) :
      admin.firestore.FieldValue.delete(),
    "businessVerification.policyReason": extra[
      "businessVerification.policyReason"
    ] ?? admin.firestore.FieldValue.delete(),
    "businessVerification.newClinicGraceDaysSinceOpened": extra[
      "businessVerification.newClinicGraceDaysSinceOpened"
    ] ?? admin.firestore.FieldValue.delete(),
    "updatedAt": admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    status,
    failReason,
    method: args.method,
    hiraMatched: args.hira.matched,
    hiraNote: args.hira.note,
    hiraMatchLevel: args.hira.level,
  };
}

/**
 * clinics_accounts/{uid}/clinic_profiles/{profileId} 를 읽고
 * businessVerification 을 갱신한다.
 * @param {FirebaseFirestore.Firestore} db Firestore
 * @param {string} uid 소유자 uid
 * @param {string} profileId 프로필 문서 id
 * @param {string} [hiraServiceKey] 심평원 API용 공공데이터 키(선호: defineSecret value)
 * @return {Promise<RunCheckResult>} 검증 결과
 */
export async function runCheckBusinessStatus(
  db: admin.firestore.Firestore,
  uid: string,
  profileId: string,
  hiraServiceKey?: string
): Promise<RunCheckResult> {
  const profileRef = db
    .collection("clinics_accounts")
    .doc(uid)
    .collection("clinic_profiles")
    .doc(profileId);

  const snap = await profileRef.get();
  if (!snap.exists) {
    throw new functions.https.HttpsError(
      "not-found",
      "치과 프로필을 찾을 수 없습니다."
    );
  }

  const data = snap.data() || {};
  const bv = data.businessVerification || {};
  const ocr = bv.ocrResult || {};
  const bizNoRaw = String(bv.bizNo ?? ocr.bizNo ?? "").trim();
  const bizNoDigits = normalizeBizNoDigits(bizNoRaw);
  const clinicName = String(data.clinicName ?? ocr.clinicName ?? "").trim();
  const addressStr = String(data.address ?? ocr.address ?? "").trim();
  const openedAtRaw = bv.openedAt ?? ocr.openedAt ?? data.openedAt;

  if (bv.status === "verified" || bv.status === "provisional") {
    const lv = bv.hiraMatchLevel;
    const hiraMatchLevel =
      lv === "strict" || lv === "partial" || lv === "none" ? lv : undefined;
    return {
      status: bv.status as RunCheckStatus,
      method: "mock",
      skipped: true,
      hiraMatched:
        typeof bv.hiraMatched === "boolean" ? bv.hiraMatched : null,
      hiraNote:
        typeof bv.hiraNote === "string" ? bv.hiraNote : "기존 인증 유지",
      hiraMatchLevel,
    };
  }

  if (!bizNoDigits || bizNoDigits.length < 10) {
    await profileRef.update({
      "businessVerification.status": "manual_review",
      "businessVerification.failReason": "missing_or_invalid_biz_no",
      "businessVerification.lastCheckAt":
        admin.firestore.FieldValue.serverTimestamp(),
      "businessVerification.checkMethod": "server_skip",
      "updatedAt": admin.firestore.FieldValue.serverTimestamp(),
    });
    return {
      status: "manual_review",
      failReason: "missing_or_invalid_biz_no",
      method: "mock",
    };
  }

  const serviceKey = String(process.env.NTS_SERVICE_KEY ?? "").trim();
  const forceMock =
    process.env.MOCK_BUSINESS_CHECK === "1" || serviceKey.length === 0;

  if (forceMock) {
    const m = mockDecision(bizNoDigits);
    if (m.closed) {
      await profileRef.update({
        "businessVerification.status": "rejected",
        "businessVerification.bizNo": bizNoRaw,
        "businessVerification.failReason": "business_closed",
        "businessVerification.lastCheckAt":
          admin.firestore.FieldValue.serverTimestamp(),
        "businessVerification.checkMethod": "mock",
        "businessVerification.verifiedAt": null,
        "updatedAt": admin.firestore.FieldValue.serverTimestamp(),
      });
      return {
        status: "rejected",
        failReason: "business_closed",
        method: "mock",
      };
    }
    const hiraMock = m.hiraMismatch ?
      {matched: false, note: "Mock HIRA 불일치", level: "none" as const} :
      await runHiraSupplement(clinicName, addressStr, hiraServiceKey);

    return applyHiraDecision({
      profileRef,
      method: "mock",
      bizNoRaw,
      hira: hiraMock,
      openedAtRaw,
    });
  }

  try {
    const nts = await callNtsStatusApi(bizNoDigits, serviceKey);
    if (nts.closed) {
      await profileRef.update({
        "businessVerification.status": "rejected",
        "businessVerification.bizNo": bizNoRaw,
        "businessVerification.failReason": "business_closed",
        "businessVerification.lastCheckAt":
          admin.firestore.FieldValue.serverTimestamp(),
        "businessVerification.checkMethod": "nts",
        "businessVerification.verifiedAt": null,
        "updatedAt": admin.firestore.FieldValue.serverTimestamp(),
      });
      return {
        status: "rejected",
        failReason: "business_closed",
        method: "nts",
      };
    }
    if (!nts.valid) {
      await profileRef.update({
        "businessVerification.status": "rejected",
        "businessVerification.bizNo": bizNoRaw,
        "businessVerification.failReason": "nts_not_matched",
        "businessVerification.lastCheckAt":
          admin.firestore.FieldValue.serverTimestamp(),
        "businessVerification.checkMethod": "nts",
        "businessVerification.verifiedAt": null,
        "updatedAt": admin.firestore.FieldValue.serverTimestamp(),
      });
      return {
        status: "rejected",
        failReason: "nts_not_matched",
        method: "nts",
      };
    }

    const hiraNts = await runHiraSupplement(
      clinicName,
      addressStr,
      hiraServiceKey
    );
    return applyHiraDecision({
      profileRef,
      method: "nts",
      bizNoRaw,
      hira: hiraNts,
      openedAtRaw,
    });
  } catch (e: unknown) {
    functions.logger.error("NTS API 호출 실패", {
      uid,
      profileId,
      error: String(e),
    });
    await profileRef.update({
      "businessVerification.status": "pending_auto",
      "businessVerification.bizNo": bizNoRaw,
      "businessVerification.failReason": "nts_api_error",
      "businessVerification.lastCheckAt":
        admin.firestore.FieldValue.serverTimestamp(),
      "businessVerification.checkMethod": "nts_error",
      "updatedAt": admin.firestore.FieldValue.serverTimestamp(),
    });
    return {
      status: "pending_auto",
      failReason: "nts_api_error",
      method: "nts",
    };
  }
}
