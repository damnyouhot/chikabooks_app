/**
 * 심평원 병원 대조 — strict / partial / none (B안 단계형)
 * 주소는 시·군·구 + 도로명(로/길/대로) 중심, 층·호·괄호 건물명은 약하게 처리.
 */

export type HiraMatchLevel = "strict" | "partial" | "none";

/** UI·로그용 — 다른 모듈에서 짧게 덧붙일 때 */
export const HIRA_RESULT_DISCLAIMER =
  "공개데이터 기준·자동 조회상 보조 확인이며 최종 인증 수단이 아닙니다.";

const DISCLAIMER = HIRA_RESULT_DISCLAIMER;

/** 상호: 법인 표기 등 제거 후 비교용 */
export function normalizeBizName(s: string): string {
  return String(s ?? "")
    .replace(/\s+/g, "")
    .replace(/[\(（][^)）]*[\)）]/g, "")
    .replace(/^(?:\(주\)|㈜|주식회사|유한회사)/, "")
    .toLowerCase();
}

export function stripAddressNoiseForCore(raw: string): string {
  let t = String(raw ?? "").replace(/\s+/g, "");
  t = t.replace(/\([^)]*\)/g, "");
  t = t.replace(/\d+층.*$/u, "");
  t = t.replace(/,\d+층.*$/u, "");
  t = t.replace(/\d+호.*$/u, "");
  return t;
}

export function extractAddressCore(compactStripped: string): string {
  const s = stripAddressNoiseForCore(compactStripped);
  const re = /^(.+?)([가-힣0-9]+(?:로|길|대로))(\d*)/u;
  const m = s.match(re);
  if (!m) return s.slice(0, 45);
  return `${m[1]}${m[2]}${m[3] ?? ""}`.slice(0, 85);
}

export function extractSigunguPrefix(compactStripped: string): string {
  const s = stripAddressNoiseForCore(compactStripped);
  const idx = s.search(/[가-힣0-9]+(?:로|길|대로)/u);
  if (idx <= 0) return s.slice(0, 24);
  return s.slice(0, Math.min(idx, 32));
}

export function extractRoadToken(compactStripped: string): string {
  const s = stripAddressNoiseForCore(compactStripped);
  const m = s.match(/[가-힣0-9]+(?:로|길|대로)/u);
  return m ? m[0] : "";
}

export function nameStrict(a: string, b: string): boolean {
  const x = normalizeBizName(a);
  const y = normalizeBizName(b);
  return x.length >= 2 && y.length >= 2 && x === y;
}

export function namePartial(a: string, b: string): boolean {
  if (nameStrict(a, b)) return true;
  const x = normalizeBizName(a);
  const y = normalizeBizName(b);
  if (x.length < 2 || y.length < 2) return false;
  const short = x.length <= y.length ? x : y;
  const long = x.length > y.length ? x : y;
  if (short.length >= 4 && long.includes(short)) return true;
  const px = x.slice(0, Math.min(6, x.length));
  const py = y.slice(0, Math.min(6, y.length));
  return px.length >= 2 && (long.includes(px) || long.includes(py));
}

export function addressStrict(ocr: string, hira: string): boolean {
  const o = extractAddressCore(ocr.replace(/\s+/g, ""));
  const h = extractAddressCore(hira.replace(/\s+/g, ""));
  return o.length >= 8 && h.length >= 8 && o === h;
}

export function addressPartial(ocr: string, hira: string): boolean {
  if (addressStrict(ocr, hira)) return true;
  const o0 = ocr.replace(/\s+/g, "");
  const h0 = hira.replace(/\s+/g, "");
  const op = extractSigunguPrefix(o0);
  const hp = extractSigunguPrefix(h0);
  const ort = extractRoadToken(o0);
  const hrt = extractRoadToken(h0);
  if (ort.length < 2 || hrt.length < 2) return false;
  const roadOk = ort === hrt || ort.includes(hrt) || hrt.includes(ort);
  if (!roadOk) return false;
  const minL = Math.min(op.length, hp.length, 8);
  if (minL < 6) return false;
  return op.includes(hp.slice(0, minL)) || hp.includes(op.slice(0, minL));
}

export interface HiraRowInput {
  yadmNm: string;
  addr: string;
}

export function tierForRow(
  ocrName: string,
  ocrAddr: string,
  row: HiraRowInput
): HiraMatchLevel {
  const ns = nameStrict(ocrName, row.yadmNm);
  const np = namePartial(ocrName, row.yadmNm);
  const as = addressStrict(ocrAddr, row.addr);
  const ap = addressPartial(ocrAddr, row.addr);

  if (ns && as) return "strict";
  if ((ns && ap) || (np && as) || (np && ap)) return "partial";
  return "none";
}

export function noteForLevel(
  level: HiraMatchLevel,
  kind: "hit" | "no_hit" | "api"
): string {
  if (kind === "api") {
    return `자동 확인 어려움: 공개데이터 연동을 완료하지 못했습니다. ${DISCLAIMER}`;
  }
  if (level === "strict") {
    return (
      "보조 확인: 자동 조회상·공개데이터 기준으로 심평원 병원목록의 상호·소재지(시·군·구 및 도로명·번지 코어)가 " +
      "등록증 정보와 일치합니다. " +
      DISCLAIMER
    );
  }
  if (level === "partial") {
    return (
      "보조 확인: 자동 조회상 부분 일치이며 표기 차이(층·호·건물명 등)가 있을 수 있습니다. " +
      "공개데이터 기준 참고용입니다. " +
      DISCLAIMER
    );
  }
  return (
    "자동 확인 어려움: 공개데이터 기준으로 상호·소재지를 확정하지 못했습니다. " +
    DISCLAIMER
  );
}
