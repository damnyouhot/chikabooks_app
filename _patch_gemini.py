#!/usr/bin/env python3
"""Patch index.ts: replace Mock with Gemini API calls."""

import sys

FILE = "functions/src/index.ts"

with open(FILE, "r", encoding="utf-8") as f:
    content = f.read()

changes = 0

# ── 1) parseJobImagesToForm: runWith에 secrets 추가 ──
old_rw = 'export const parseJobImagesToForm = functions\n  .runWith({ timeoutSeconds: 60, memory: "512MB" })'
new_rw = 'export const parseJobImagesToForm = functions\n  .runWith({ timeoutSeconds: 60, memory: "512MB", secrets: ["GEMINI_API_KEY"] })'
if old_rw in content:
    content = content.replace(old_rw, new_rw)
    changes += 1
    print("1) parseJobImagesToForm runWith: updated")
else:
    print("1) parseJobImagesToForm runWith: SKIP (already done or not found)")

# ── 2) parseJobImagesToForm: Mock → Gemini ──
OLD_MOCK = '''    // ── TODO: sourceType에 따른 실제 AI 처리 ────────────────
    // - "image": OpenAI Vision으로 이미지 분석
    // - "text": GPT로 텍스트 파싱
    // - "mixed": 이미지 + 텍스트 병합 분석

    // ── Mock 응답 (AI 키 연동 전까지 샘플 반환) ──────────────
    functions.logger.info("parseJobImagesToForm called (mock)", {
      uid: context.auth.uid,
      sourceType,
      imageCount: imageUrls.length,
      textLength: rawText.length,
    });

    const mockResult = {
      clinicName: "",
      title: "",
      role: "",
      employmentType: "",
      workHours: "",
      salary: "",
      benefits: [] as string[],
      description: "",
      address: "",
      contact: "",
      _mock: true,
      _sourceType: sourceType,
      _message:
        "AI 자동입력은 OpenAI 키 연동 후 활성화됩니다. 현재는 Mock 모드입니다.",
    };

    return mockResult;'''

NEW_GEMINI = r'''    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      throw new functions.https.HttpsError("internal", "AI API 키가 설정되지 않았습니다.");
    }

    functions.logger.info("parseJobImagesToForm", {
      uid: context.auth.uid, sourceType, imageCount: imageUrls.length, textLength: rawText.length,
    });

    const systemPrompt = `아래 치과 채용 공고 내용을 분석하여 반드시 아래 JSON 형식으로만 응답해줘.
다른 텍스트 없이 순수 JSON만 반환해.
필드가 파악되지 않으면 빈 문자열 또는 빈 배열로 남겨.
benefits는 문자열 배열로 반환해.

{
  "clinicName": "치과명",
  "title": "공고 제목",
  "role": "직종 (예: 치과위생사, 치과조무사 등)",
  "career": "경력 조건 (예: 신입, 경력 3년 이상)",
  "employmentType": "고용 형태 (예: 정규직, 계약직, 파트타임)",
  "workHours": "근무 시간 (예: 09:00~18:00)",
  "salary": "급여 (예: 월 250~300만원)",
  "benefits": ["복리후생1", "복리후생2"],
  "description": "상세 내용",
  "address": "근무지 주소",
  "contact": "연락처",
  "hospitalType": "병원 유형 (예: 일반치과, 교정과 등)",
  "workDays": ["월", "화", "수", "목", "금"],
  "weekendWork": "주말 근무 여부 (예: 격주 토요일)",
  "nightShift": "야간 근무 여부"
}`;

    const parts: Array<{text?: string; inlineData?: {mimeType: string; data: string}}> = [];
    parts.push({text: systemPrompt});

    if (sourceType === "text" || sourceType === "mixed") {
      parts.push({text: "아래는 공고 텍스트입니다:\n" + rawText});
    }

    if ((sourceType === "image" || sourceType === "mixed") && imageUrls.length > 0) {
      for (const url of imageUrls.slice(0, 5)) {
        try {
          const imgResp = await axios.get(url, {responseType: "arraybuffer", timeout: 15000});
          const base64 = Buffer.from(imgResp.data).toString("base64");
          const contentType = imgResp.headers["content-type"] || "image/jpeg";
          parts.push({inlineData: {mimeType: contentType, data: base64}});
        } catch (e) {
          functions.logger.warn("이미지 다운로드 실패", {url, error: String(e)});
        }
      }
    }

    try {
      const geminiUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=" + apiKey;
      const resp = await axios.post(geminiUrl, {
        contents: [{parts}],
        generationConfig: {responseMimeType: "application/json"},
      }, {timeout: 45000});

      const text = resp.data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
      const parsed = JSON.parse(text);

      return {
        clinicName: parsed.clinicName ?? "",
        title: parsed.title ?? "",
        role: parsed.role ?? "",
        career: parsed.career ?? "",
        employmentType: parsed.employmentType ?? "",
        workHours: parsed.workHours ?? "",
        salary: parsed.salary ?? "",
        benefits: Array.isArray(parsed.benefits) ? parsed.benefits : [],
        description: parsed.description ?? "",
        address: parsed.address ?? "",
        contact: parsed.contact ?? "",
        hospitalType: parsed.hospitalType ?? "",
        workDays: Array.isArray(parsed.workDays) ? parsed.workDays : [],
        weekendWork: parsed.weekendWork ?? "",
        nightShift: parsed.nightShift ?? "",
      };
    } catch (e: unknown) {
      functions.logger.error("Gemini API 호출 실패", {error: String(e)});
      throw new functions.https.HttpsError("internal", "AI 분석 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.");
    }'''

if OLD_MOCK in content:
    content = content.replace(OLD_MOCK, NEW_GEMINI)
    changes += 1
    print("2) parseJobImagesToForm mock: replaced with Gemini")
else:
    print("2) parseJobImagesToForm mock: NOT FOUND")

# ── 3) verifyBusinessLicense: runWith에 secrets 추가 ──
old_biz_rw = 'export const verifyBusinessLicense = functions\n  .runWith({ timeoutSeconds: 120, memory: "512MB" })'
new_biz_rw = 'export const verifyBusinessLicense = functions\n  .runWith({ timeoutSeconds: 120, memory: "512MB", secrets: ["GEMINI_API_KEY"] })'
if old_biz_rw in content:
    content = content.replace(old_biz_rw, new_biz_rw)
    changes += 1
    print("3) verifyBusinessLicense runWith: updated")
else:
    print("3) verifyBusinessLicense runWith: SKIP")

# ── 4) verifyBusinessLicense: Mock → Gemini ──
OLD_BIZ_MOCK = '''    // TODO: OpenAI Vision / OCR 실제 연동
    functions.logger.info("verifyBusinessLicense (mock)", { uid, profileId, docUrl });

    const extracted = {
      bizNo: "",
      clinicName: "",
      ownerName: "",
      address: "",
      openedAt: "",
    };

    // 프로필 businessVerification 갱신
    await profileRef.update({
      "businessVerification.status": "pending_auto",
      "businessVerification.docUrl": docUrl,
      "businessVerification.method": "ai_v1",
      "businessVerification.ocrResult": extracted,
      "bizRegImageUrl": docUrl,
      "updatedAt": admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      ...extracted,
      status: "pending_auto",
      _mock: true,
      _message: "OCR 키 연동 전 Mock 모드입니다. 정보를 직접 입력해주세요.",
    };'''

NEW_BIZ_GEMINI = r'''    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      throw new functions.https.HttpsError("internal", "AI API 키가 설정되지 않았습니다.");
    }

    functions.logger.info("verifyBusinessLicense", { uid, profileId, docUrl });

    const bizPrompt = `아래 사업자등록증 이미지를 분석하여 반드시 아래 JSON 형식으로만 응답해줘.
다른 텍스트 없이 순수 JSON만 반환해.
필드가 파악되지 않으면 빈 문자열로 남겨.

{
  "bizNo": "사업자등록번호 (예: 123-45-67890)",
  "clinicName": "상호명",
  "ownerName": "대표자명",
  "address": "사업장 소재지",
  "openedAt": "개업일 (예: 2020-01-15)"
}`;

    let extracted = { bizNo: "", clinicName: "", ownerName: "", address: "", openedAt: "" };

    try {
      const imgResp = await axios.get(docUrl, { responseType: "arraybuffer", timeout: 15000 });
      const base64 = Buffer.from(imgResp.data).toString("base64");
      const contentType = imgResp.headers["content-type"] || "image/jpeg";

      const geminiUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=" + apiKey;
      const resp = await axios.post(geminiUrl, {
        contents: [{
          parts: [
            { text: bizPrompt },
            { inlineData: { mimeType: contentType, data: base64 } },
          ],
        }],
        generationConfig: { responseMimeType: "application/json" },
      }, { timeout: 45000 });

      const text = resp.data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
      const parsed = JSON.parse(text);
      extracted = {
        bizNo: parsed.bizNo ?? "",
        clinicName: parsed.clinicName ?? "",
        ownerName: parsed.ownerName ?? "",
        address: parsed.address ?? "",
        openedAt: parsed.openedAt ?? "",
      };
    } catch (e) {
      functions.logger.error("Gemini OCR 실패", { error: String(e) });
    }

    const hasData = extracted.bizNo || extracted.clinicName;
    const verifyStatus = hasData ? "auto_verified" : "pending_manual";

    await profileRef.update({
      "businessVerification.status": verifyStatus,
      "businessVerification.docUrl": docUrl,
      "businessVerification.method": "gemini_v1",
      "businessVerification.ocrResult": extracted,
      "businessVerification.verifiedAt": hasData ? admin.firestore.FieldValue.serverTimestamp() : null,
      "bizRegImageUrl": docUrl,
      ...(extracted.clinicName ? { clinicName: extracted.clinicName } : {}),
      ...(extracted.ownerName ? { ownerName: extracted.ownerName } : {}),
      ...(extracted.address ? { address: extracted.address } : {}),
      "updatedAt": admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      ...extracted,
      status: verifyStatus,
    };'''

if OLD_BIZ_MOCK in content:
    content = content.replace(OLD_BIZ_MOCK, NEW_BIZ_GEMINI)
    changes += 1
    print("4) verifyBusinessLicense mock: replaced with Gemini")
else:
    print("4) verifyBusinessLicense mock: NOT FOUND")

with open(FILE, "w", encoding="utf-8") as f:
    f.write(content)

print(f"\nDone. {changes} replacements made.")
