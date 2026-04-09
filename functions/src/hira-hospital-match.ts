/**
 * 심평원 병원정보서비스 v2 — 기본목록으로 상호 검색 후 치과 요양기관 대조
 * @see https://www.data.go.kr (건강보험심사평가원_병원정보서비스)
 */
import axios from "axios";
import {parseStringPromise} from "xml2js";
import {
  HiraMatchLevel,
  HIRA_RESULT_DISCLAIMER,
  noteForLevel,
  tierForRow,
} from "./hira-match-tier";

export interface HiraMatchResult {
  matched: boolean | null;
  note: string;
  level: HiraMatchLevel;
}

function normalizeCompact(s: string): string {
  return String(s ?? "").replace(/\s/g, "").toLowerCase();
}

/** xml2js 가 단일 노드를 문자열·배열·객체로 줄 수 있음 */
function firstScalar(v: unknown): string {
  if (v == null) return "";
  if (Array.isArray(v)) return firstScalar(v[0]);
  if (typeof v === "object") return "";
  return String(v).trim();
}

/** 공공데이터 XML/JSON 루트가 `response` 외 형태인 경우 보조 */
function getHiraResponseBody(parsed: any): {header?: any; body?: any} {
  if (!parsed || typeof parsed !== "object") return {};
  if (parsed.response) {
    return {header: parsed.response.header, body: parsed.response.body};
  }
  if (parsed.OpenAPI_ServiceResponse) {
    const r = parsed.OpenAPI_ServiceResponse;
    return {header: r.header, body: r.body};
  }
  return {};
}

function rankLevel(a: HiraMatchLevel, b: HiraMatchLevel): HiraMatchLevel {
  const o = {strict: 2, partial: 1, none: 0};
  return o[a] >= o[b] ? a : b;
}

/** 등급 산출 후에도 안 맞으면 예전 상호·주소 일부 포함 휴리스틱으로 partial 승격 */
function legacyFuzzyHit(
  q: string,
  address: string,
  dental: Record<string, string>[]
): boolean {
  const nQ = normalizeCompact(q);
  const nAddr = normalizeCompact(address).slice(0, 20);
  return dental.some((it) => {
    const yn = normalizeCompact(String(it.yadmNm ?? it.yadmnm ?? ""));
    if (
      nQ.length >= 2 &&
      (yn.includes(nQ.slice(0, Math.min(6, nQ.length))) ||
        nQ.includes(yn.slice(0, Math.min(6, yn.length))))
    ) {
      return true;
    }
    const ad = normalizeCompact(String(it.addr ?? it.ADDR ?? ""));
    return nAddr.length >= 6 && ad.includes(nAddr.slice(0, 10));
  });
}

/**
 * @param {string} clinicName OCR 상호
 * @param {string} address OCR 주소 (보조)
 * @param {string} serviceKey 공공데이터포털 인증키
 */
export async function matchHiraClinicName(
  clinicName: string,
  address: string,
  serviceKey: string
): Promise<HiraMatchResult> {
  const q = clinicName.trim();
  if (!q) {
    return {
      matched: null,
      note: "상호가 없어 심평원 대조를 건너뛰었습니다.",
      level: "none",
    };
  }
  if (!serviceKey) {
    return {
      matched: null,
      note: "HIRA(공공데이터) 키가 설정되지 않았습니다.",
      level: "none",
    };
  }

  try {
    const url =
      "https://apis.data.go.kr/B551182/hospInfoServicev2/getHospBasisList" +
      "?ServiceKey=" +
      encodeURIComponent(serviceKey) +
      "&pageNo=1&numOfRows=30" +
      "&yadmNm=" +
      encodeURIComponent(q.slice(0, 100));

    const resp = await axios.get(url, {
      timeout: 25000,
      responseType: "text",
    });

    let parsed: any;
    const raw = resp.data;
    if (typeof raw === "string" && raw.trim().startsWith("<?xml")) {
      parsed = await parseStringPromise(raw, {
        explicitArray: false,
        trim: true,
      });
    } else if (typeof raw === "string") {
      parsed = JSON.parse(raw);
    } else {
      parsed = raw;
    }

    const {header, body} = getHiraResponseBody(parsed);
    const resultCode = firstScalar(header?.resultCode);
    if (resultCode && resultCode !== "00") {
      const msg = firstScalar(header?.resultMsg) || resultCode;
      return {
        matched: null,
        note: `심평원 API: ${msg}`,
        level: "none",
      };
    }

    if (!body) {
      return {
        matched: null,
        note: "심평원 응답 본문 없음",
        level: "none",
      };
    }

    let rawItems = body.items?.item;
    if (!rawItems || (typeof rawItems === "string" && rawItems.trim() === "")) {
      return {
        matched: false,
        note:
          "심평원 병원목록에 해당 상호로 검색된 항목이 없습니다. " +
          HIRA_RESULT_DISCLAIMER,
        level: "none",
      };
    }
    if (!Array.isArray(rawItems)) {
      rawItems = [rawItems];
    }

    const dental = rawItems.filter((it: Record<string, string>) => {
      const cl = String(it.clCdNm ?? it.clcdnm ?? "");
      return cl.includes("치과");
    });

    if (dental.length === 0) {
      return {
        matched: false,
        note:
          "검색 결과에 치과 요양기관(종별)이 없습니다. " +
          HIRA_RESULT_DISCLAIMER,
        level: "none",
      };
    }

    let best: HiraMatchLevel = "none";
    for (const it of dental) {
      const row = {
        yadmNm: String(it.yadmNm ?? it.yadmnm ?? ""),
        addr: String(it.addr ?? it.ADDR ?? ""),
      };
      const t = tierForRow(q, address, row);
      best = rankLevel(best, t);
      if (best === "strict") break;
    }

    if (best === "none" && legacyFuzzyHit(q, address, dental)) {
      best = "partial";
    }

    const matched = best === "strict" || best === "partial";

    const note =
      best === "none"
        ? noteForLevel("none", "no_hit")
        : noteForLevel(best, "hit");

    return {matched, note, level: best};
  } catch (e: unknown) {
    return {
      matched: null,
      note: `심평원 연동 오류: ${String(e).slice(0, 120)}`,
      level: "none",
    };
  }
}
