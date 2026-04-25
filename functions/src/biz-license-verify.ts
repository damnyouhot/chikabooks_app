/**
 * verifyBusinessLicense
 *
 * 클라이언트(공고 편집기·/me/verify)에서 사업자등록증 이미지를 업로드한 직후
 * 호출되는 OCR + 1차 검증 callable.
 *
 * 전 단계(legacy ghost) 와 달리 이 구현은:
 *   1. Gemini Vision 으로 이미지 안의 사업자등록증 여부를 **명시적으로 판정**하고
 *      (isBusinessRegistration / confidence), 그렇지 않다면 즉시 'ocr_failed'
 *      + failReason='not_business_registration' 으로 끝낸다.
 *   2. 통과 시 OCR 필드(상호·대표자·주소·등록번호·개업일) 를 추출.
 *   3. 추출 결과를 clinic_profiles/{profileId}.businessVerification.ocrResult
 *      및 docUrl 에 명확히 저장한다 (이전 사용자 데이터가 화면에 잔존하지 않게
 *      모든 필드를 명시적으로 set).
 *   4. 이어서 runCheckBusinessStatus 로 NTS+HIRA 까지 자동 진행 (provisional/
 *      rejected/manual_review 결정).
 *
 * 응답 스키마 — biz_license_verify_snapshot.dart 의 fromCallable 와 정합:
 *   { clinicName, ownerName, address, bizNo, openedAt,
 *     status, failReason, checkMethod, skipped,
 *     hiraMatched, hiraNote, hiraMatchLevel,
 *     isBusinessRegistration, confidence }
 */
import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";
import axios from "axios";

import {runCheckBusinessStatus} from "./business-verification";

const getDb = (): admin.firestore.Firestore => admin.firestore();

function normalizeBizNo(raw: string | null | undefined): string {
  return String(raw ?? "").replace(/[^0-9]/g, "");
}

/** Gemini API 응답 형식 (우리가 강제하는 JSON 스키마) */
interface GeminiOcrResult {
  isBusinessRegistration: boolean;
  confidence: number;
  rejectReason?: string | null;
  bizNo?: string | null;
  clinicName?: string | null;
  ownerName?: string | null;
  address?: string | null;
  openedAt?: string | null;
}

/** 사용자에게 보여줄 안전한 빈 OCR 결과 */
const EMPTY_OCR: GeminiOcrResult = {
  isBusinessRegistration: false,
  confidence: 0,
  rejectReason: "ocr_unavailable",
};

/**
 * Cloud Storage `https://...` download URL 또는 `gs://` URI 양쪽을 받아
 * 바이트 배열을 반환한다.
 *
 * @param {string} docUrl 이미지 URL
 * @return {Promise<{bytes: Buffer, mimeType: string}>} 이미지 데이터
 */
async function fetchImageBytes(
  docUrl: string
): Promise<{ bytes: Buffer; mimeType: string }> {
  const resp = await axios.get<ArrayBuffer>(docUrl, {
    responseType: "arraybuffer",
    timeout: 20000,
  });
  const ct = String(resp.headers["content-type"] ?? "image/jpeg");
  // application/octet-stream 같은 일반 타입이면 jpeg 로 가정 (Gemini 가 거의 다 읽음)
  const safeMime = ct.startsWith("image/") || ct === "application/pdf" ?
    ct :
    "image/jpeg";
  return {bytes: Buffer.from(resp.data), mimeType: safeMime};
}

/**
 * Gemini 1.5 Flash Vision 을 호출해서 사업자등록증 판정 + OCR.
 *
 * 키 미설정 시 EMPTY_OCR 을 반환해 호출 측이 'ocr_unavailable' 로 처리하게 한다
 * (배포 직후 키가 없을 때도 함수가 죽지 않도록).
 *
 * @param {Buffer} bytes 이미지 바이트
 * @param {string} mimeType MIME 타입
 * @return {Promise<GeminiOcrResult>} 판정 + 필드
 */
async function callGeminiOcr(
  bytes: Buffer,
  mimeType: string
): Promise<GeminiOcrResult> {
  const apiKey = String(
    process.env.GEMINI_API_KEY ?? process.env.GOOGLE_API_KEY ?? ""
  ).trim();
  if (!apiKey) {
    functions.logger.warn("GEMINI_API_KEY 미설정 — OCR 건너뜀");
    return {...EMPTY_OCR, rejectReason: "ocr_key_missing"};
  }

  const prompt = `당신은 한국 국세청이 발급한 "사업자등록증(Business Registration Certificate)" 만을 처리하는 OCR 모듈입니다.

다음 이미지가 정말로 한국 국세청이 발급한 사업자등록증인지 먼저 판정한 뒤, JSON 만 반환하세요. 마크다운/설명/주석 금지.

판정 기준 (모두 만족해야 isBusinessRegistration=true):
- 문서 상단에 "사업자등록증" 이라는 제목이 있어야 합니다.
- 발급기관(국세청, 세무서) 표기가 있어야 합니다.
- "등록번호" 또는 "사업자등록번호" 항목이 있고, 10자리 숫자(하이픈 포함 가능)가 보여야 합니다.
- "상호(법인명)" 또는 "법인명/단체명" 항목이 있어야 합니다.
- "대표자" 또는 "성명" 항목이 있어야 합니다.

만약 세금계산서, 계산서, 영수증, 거래명세서, 명함, 계약서, 일반 사진, 신분증, 진료확인서, 이력서, 기타 다른 문서이면 isBusinessRegistration=false 로 하고 rejectReason 에 한국어로 어떤 종류의 이미지로 보이는지 짧게 적으세요.

응답 JSON 스키마:
{
  "isBusinessRegistration": boolean,
  "confidence": number (0.0 ~ 1.0),
  "rejectReason": string | null,
  "bizNo": string | null,
  "clinicName": string | null,
  "ownerName": string | null,
  "address": string | null,
  "openedAt": string | null
}

규칙:
- isBusinessRegistration=false 인 경우 bizNo/clinicName/ownerName/address/openedAt 은 모두 null.
- bizNo 는 하이픈 포함 형식(예: "123-45-67890") 으로.
- openedAt 은 "YYYY-MM-DD" 형식. 모르면 null.
- 텍스트가 흐려서 100% 확신 못 하는 필드는 null.`;

  const url =
    "https://generativelanguage.googleapis.com/v1beta/models/" +
    "gemini-1.5-flash:generateContent?key=" +
    encodeURIComponent(apiKey);

  try {
    const resp = await axios.post(
      url,
      {
        contents: [
          {
            parts: [
              {text: prompt},
              {
                inline_data: {
                  mime_type: mimeType,
                  data: bytes.toString("base64"),
                },
              },
            ],
          },
        ],
        generationConfig: {
          temperature: 0,
          response_mime_type: "application/json",
        },
      },
      {timeout: 30000}
    );

    const text: string =
      resp.data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
    if (!text) {
      functions.logger.warn("Gemini 응답 텍스트 비어있음", {data: resp.data});
      return {...EMPTY_OCR, rejectReason: "ocr_empty_response"};
    }

    const parsed = JSON.parse(text);
    const result: GeminiOcrResult = {
      isBusinessRegistration: parsed.isBusinessRegistration === true,
      confidence: Number(parsed.confidence ?? 0),
      rejectReason: parsed.rejectReason ?? null,
      bizNo: parsed.bizNo ?? null,
      clinicName: parsed.clinicName ?? null,
      ownerName: parsed.ownerName ?? null,
      address: parsed.address ?? null,
      openedAt: parsed.openedAt ?? null,
    };
    return result;
  } catch (e: unknown) {
    functions.logger.error("Gemini API 호출 실패", {error: String(e)});
    return {...EMPTY_OCR, rejectReason: "ocr_api_error"};
  }
}

/** 응답을 클라이언트가 바로 쓸 수 있는 포맷으로 변환 */
function buildEmptyResponse(args: {
  failReason: string;
  rejectReason?: string | null;
  confidence?: number;
  attemptId?: string;
}): Record<string, unknown> {
  return {
    clinicName: "",
    ownerName: "",
    address: "",
    bizNo: "",
    openedAt: "",
    status: "rejected",
    failReason: args.failReason,
    checkMethod: "ocr",
    skipped: false,
    hiraMatched: null,
    hiraNote: null,
    hiraMatchLevel: null,
    isBusinessRegistration: false,
    confidence: args.confidence ?? 0,
    rejectReason: args.rejectReason ?? null,
    attemptId: args.attemptId ?? null,
    profileRelation: "invalid_document",
  };
}

export const verifyBusinessLicense = functions
  .region("asia-northeast3")
  .runWith({
    timeoutSeconds: 60,
    memory: "512MB",
    secrets: ["GEMINI_API_KEY", "NTS_SERVICE_KEY", "HIRA_SERVICE_KEY"],
  })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "로그인이 필요합니다."
      );
    }
    const uid = context.auth.uid;
    const docUrl = String(data?.docUrl ?? "").trim();
    const profileId = String(data?.profileId ?? "").trim();
    if (!docUrl) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "사업자등록증 이미지 URL이 없습니다."
      );
    }
    if (!profileId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "지점(profileId) 정보가 없습니다."
      );
    }

    const db = getDb();
    const profileRef = db
      .collection("clinics_accounts")
      .doc(uid)
      .collection("clinic_profiles")
      .doc(profileId);
    const attemptsCol = profileRef.collection("verification_attempts");

    const createAttempt = async (
      payload: Record<string, unknown>
    ): Promise<FirebaseFirestore.DocumentReference> => {
      const ref = attemptsCol.doc();
      await ref.set({
        profileId,
        docUrl,
        source: "verifyBusinessLicense",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        ...payload,
      });
      return ref;
    };

    // 0) 이미지 받아오기
    let bytes: Buffer;
    let mimeType: string;
    try {
      const fetched = await fetchImageBytes(docUrl);
      bytes = fetched.bytes;
      mimeType = fetched.mimeType;
    } catch (e: unknown) {
      functions.logger.error("이미지 다운로드 실패", {docUrl, error: String(e)});
      const attemptRef = await createAttempt({
        status: "rejected",
        failReason: "image_download_failed",
        checkMethod: "ocr",
        profileMutation: "none",
      });
      return buildEmptyResponse({
        failReason: "ocr_failed",
        rejectReason: "image_download_failed",
        attemptId: attemptRef.id,
      });
    }

    // 1) Gemini OCR + 문서 종류 판정
    const ocr = await callGeminiOcr(bytes, mimeType);

    // 2) 사업자등록증이 아니면 즉시 거절 (NTS 호출 안 함 → 비용/오인 방지)
    const CONFIDENCE_THRESHOLD = 0.7;
    if (
      !ocr.isBusinessRegistration ||
      ocr.confidence < CONFIDENCE_THRESHOLD
    ) {
      const attemptRef = await createAttempt({
        status: "rejected",
        failReason: "not_business_registration",
        checkMethod: "ocr",
        profileMutation: "none",
        isBusinessRegistration: false,
        confidence: ocr.confidence,
        rejectReason: ocr.rejectReason ?? null,
      });
      return buildEmptyResponse({
        failReason: "not_business_registration",
        rejectReason: ocr.rejectReason ?? null,
        confidence: ocr.confidence,
        attemptId: attemptRef.id,
      });
    }

    // 3) 통과 — OCR 필드 정리
    const clinicName = String(ocr.clinicName ?? "").trim();
    const ownerName = String(ocr.ownerName ?? "").trim();
    const address = String(ocr.address ?? "").trim();
    const bizNo = String(ocr.bizNo ?? "").trim();
    const openedAt = String(ocr.openedAt ?? "").trim();

    // OCR 가 통과했지만 핵심 필드가 비어있으면 ocr_failed 처리
    if (!bizNo || !clinicName) {
      const attemptRef = await createAttempt({
        status: "rejected",
        failReason: "ocr_failed",
        checkMethod: "ocr",
        profileMutation: "none",
        isBusinessRegistration: true,
        confidence: ocr.confidence,
      });
      return buildEmptyResponse({
        failReason: "ocr_failed",
        confidence: ocr.confidence,
        attemptId: attemptRef.id,
      });
    }

    const profileSnap = await profileRef.get();
    if (!profileSnap.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "치과 프로필을 찾을 수 없습니다."
      );
    }
    const profileData = profileSnap.data() || {};
    const currentBv = profileData.businessVerification || {};
    const currentBizNo = normalizeBizNo(currentBv.bizNo);
    const newBizNo = normalizeBizNo(bizNo);
    const profileHasIdentity = Boolean(
      String(profileData.clinicName ?? "").trim() ||
      String(profileData.displayName ?? "").trim() ||
      String(profileData.address ?? "").trim() ||
      String(profileData.ownerName ?? "").trim()
    );
    const profileRelation =
      currentBizNo.length === 10 && currentBizNo !== newBizNo ?
        "different_business" :
        currentBizNo.length === 10 ?
          "same_business" :
      profileHasIdentity ?
        "unverified_existing_profile" :
          "empty_profile";

    const attemptRef = await createAttempt({
      status: profileRelation === "different_business" ||
        profileRelation === "unverified_existing_profile" ?
        "needs_user_decision" :
        "pending_auto",
      failReason: profileRelation === "different_business" ?
        "different_business_number" :
        profileRelation === "unverified_existing_profile" ?
          "unverified_profile_requires_user_decision" :
        null,
      checkMethod: "ocr",
      profileMutation: "none",
      profileRelation,
      previousBizNo: currentBv.bizNo ?? null,
      isBusinessRegistration: true,
      confidence: ocr.confidence,
      ocrResult: {
        bizNo,
        clinicName,
        ownerName,
        address,
        openedAt,
      },
    });

    if (
      profileRelation === "different_business" ||
      profileRelation === "unverified_existing_profile"
    ) {
      return {
        clinicName,
        ownerName,
        address,
        bizNo,
        openedAt,
        status: "needs_user_decision",
        failReason: profileRelation === "different_business" ?
          "different_business_number" :
          "unverified_profile_requires_user_decision",
        checkMethod: "ocr",
        skipped: false,
        hiraMatched: null,
        hiraNote: null,
        hiraMatchLevel: null,
        isBusinessRegistration: true,
        confidence: ocr.confidence,
        attemptId: attemptRef.id,
        profileRelation,
      };
    }

    // 4) 프로필에 OCR 결과 + 본문 필드 명시적 저장
    //    (이전 OCR 잔존을 막기 위해 모든 필드를 명시적으로 set)
    await profileRef.set(
      {
        clinicName,
        ownerName,
        address,
        bizRegImageUrl: docUrl,
        businessVerification: {
          bizNo,
          docUrl,
          method: "gemini_ocr",
          checkMethod: "ocr",
          status: "pending_auto",
          openedAt,
          isBusinessRegistration: true,
          confidence: ocr.confidence,
          rejectReason: admin.firestore.FieldValue.delete(),
          ocrResult: {
            bizNo,
            clinicName,
            ownerName,
            address,
            openedAt,
          },
          lastCheckAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true}
    );

    // 5) NTS + HIRA 자동 검증
    const checkResult = await runCheckBusinessStatus(db, uid, profileId);
    await attemptRef.set(
      {
        status: checkResult.status,
        failReason: checkResult.failReason ?? null,
        checkMethod: checkResult.method,
        hiraMatched: checkResult.hiraMatched ?? null,
        hiraNote: checkResult.hiraNote ?? null,
        hiraMatchLevel: checkResult.hiraMatchLevel ?? null,
        profileMutation: "applied_to_profile",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true}
    );

    return {
      clinicName,
      ownerName,
      address,
      bizNo,
      openedAt,
      status: checkResult.status,
      failReason: checkResult.failReason ?? null,
      checkMethod: checkResult.method,
      skipped: checkResult.skipped === true,
      hiraMatched: checkResult.hiraMatched ?? null,
      hiraNote: checkResult.hiraNote ?? null,
      hiraMatchLevel: checkResult.hiraMatchLevel ?? null,
      isBusinessRegistration: true,
      confidence: ocr.confidence,
      attemptId: attemptRef.id,
      profileRelation,
    };
  });
