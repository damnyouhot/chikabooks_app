import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import axios from "axios";
import {parseStringPromise} from "xml2js";
import * as crypto from "crypto";
import { defineSecret } from "firebase-functions/params";
import { resolvePollOpsFromRows } from "./poll-ops-hub";
import { runCheckBusinessStatus } from "./business-verification";
import { haversineMeters, linesForStationDisplayName } from "./metro_station_lines";

const GEMINI_MODEL = process.env.GEMINI_MODEL || "gemini-2.5-flash";

const GOOGLE_MAPS_API_KEY = defineSecret("GOOGLE_MAPS_API_KEY");
/** 심평원 병원정보 API — `defineSecret`로 바인딩해야 런타임에 값이 주입됨 */
const HIRA_SERVICE_KEY = defineSecret("HIRA_SERVICE_KEY");

admin.initializeApp();
const db = admin.firestore();

// ========== 소셜 로그인 에러 코드 정의 ==========
enum SocialLoginError {
  RATE_LIMIT = "RATE_LIMIT",
  TOKEN_EXPIRED = "TOKEN_EXPIRED",
  TOKEN_INVALID = "TOKEN_INVALID",
  PROVIDER_DOWN = "PROVIDER_DOWN",
  APP_CHECK_REQUIRED = "APP_CHECK_REQUIRED",
  INVALID_INPUT = "INVALID_INPUT",
  INTERNAL_ERROR = "INTERNAL_ERROR",
  EMAIL_ALREADY_IN_USE = "EMAIL_ALREADY_IN_USE",
}

/** Firebase Admin SDK 등에서 던진 오류의 `auth/...` 코드 추출 */
function getFirebaseAuthErrorCode(error: unknown): string | null {
  if (!error || typeof error !== "object") return null;
  const e = error as {code?: unknown; errorInfo?: {code?: string}};
  if (typeof e.code === "string") return e.code;
  if (e.errorInfo && typeof e.errorInfo.code === "string") {
    return e.errorInfo.code;
  }
  return null;
}

/**
 * Firestore 기반 레이트 리미팅 체크
 * @param key 레이트 리밋 키 (예: kakao_ip_192.168.1.1)
 * @param maxRequests 최대 요청 수
 * @param windowMs 윈도우 기간 (밀리초)
 */
async function checkRateLimitFirestore(
  key: string,
  maxRequests: number,
  windowMs: number
): Promise<void> {
  const now = Date.now();
  const docRef = db.collection("rate_limits").doc(key);

  await db.runTransaction(async (transaction) => {
    const doc = await transaction.get(docRef);

    if (!doc.exists) {
      // 첫 요청
      transaction.set(docRef, {
        count: 1,
        resetAt: now + windowMs,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    const data = doc.data()!;
    const resetAt = data.resetAt;

    if (now < resetAt) {
      // 윈도우 내
      if (data.count >= maxRequests) {
        throw new functions.https.HttpsError(
          "resource-exhausted",
          "너무 많은 요청이 발생했습니다. 잠시 후 다시 시도해주세요.",
          {errorCode: SocialLoginError.RATE_LIMIT}
        );
      }
      transaction.update(docRef, {
        count: admin.firestore.FieldValue.increment(1),
      });
    } else {
      // 윈도우 만료, 리셋
      transaction.set(docRef, {
        count: 1,
        resetAt: now + windowMs,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });
}

/**
 * Access Token 마스킹 헬퍼 함수
 */
function maskToken(token: string): string {
  if (token.length <= 20) return "***";
  return `${token.substring(0, 10)}...${token.substring(token.length - 10)}`;
}

/**
 * 역할 중복 가입 차단 헬퍼
 *
 * 위생사(applicant) 가입/로그인 시 호출:
 * clinics_accounts에 같은 uid 또는 같은 normalizedEmail이 있으면 차단
 */
async function checkApplicantRoleDuplicate(
  uid: string,
  email: string | null
): Promise<void> {
  // 1) uid 기준
  const clinicDoc = await db.collection("clinics_accounts").doc(uid).get();
  if (clinicDoc.exists) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "이 계정은 이미 공고자 계정으로 가입되어 있어 위생사 계정으로 사용할 수 없습니다."
    );
  }

  // 2) normalizedEmail 기준
  if (email && email.trim().length > 0) {
    const normalized = email.trim().toLowerCase();
    const emailSnap = await db
      .collection("clinics_accounts")
      .where("normalizedEmail", "==", normalized)
      .limit(1)
      .get();
    if (!emailSnap.empty) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "이 이메일은 이미 공고자 계정으로 가입되어 있어 위생사 계정으로 사용할 수 없습니다."
      );
    }
  }
}

// ────────────────────────────────────────
// Helper Functions
// ────────────────────────────────────────

function getCurrentDateKey(): string {
  const now = new Date();
  const kst = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  const year = kst.getFullYear();
  const month = String(kst.getMonth() + 1).padStart(2, "0");
  const day = String(kst.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

/** HIRA CMS RSS (구 /rc/rss/rss_hira_*.xml 는 404 — 고객지원 RSS 안내 URL) */
const HIRA_RSS_FEEDS = [
  {
    url: "https://www.hira.or.kr/cms/policy/03/01/01/01/act_notice.xml",
    topic: "act",
    filterKeyword: null,
  },
  {
    url: "https://www.hira.or.kr/cms/inform/01/notice.xml",
    topic: "notice",
    filterKeyword: "치과",
  },
  {
    url: "https://www.hira.or.kr/cms/policy/03/01/01/02/care_notice.xml",
    topic: "material",
    filterKeyword: null,
  },
  {
    url: "https://www.hira.or.kr/cms/policy/03/01/04/02/request.xml",
    topic: "billing",
    filterKeyword: null,
  },
] as const;

/** CMS 피드 pubDate: "20260325 17:28:44" (KST) — RFC822가 아님 */
function parseHiraRssPubDate(pubDate: string): Date {
  const trimmed = (pubDate || "").trim();
  const cms = /^(\d{4})(\d{2})(\d{2})\s+(\d{2}):(\d{2}):(\d{2})$/.exec(
    trimmed
  );
  if (cms) {
    const [, y, mo, d, h, mi, s] = cms;
    return new Date(`${y}-${mo}-${d}T${h}:${mi}:${s}+09:00`);
  }
  const parsed = new Date(trimmed);
  return Number.isNaN(parsed.getTime()) ? new Date() : parsed;
}

function absolutizeHiraLink(link: string): string {
  const t = (link || "").trim();
  if (!t) return t;
  if (/^https?:\/\//i.test(t)) return t;
  const base = "https://www.hira.or.kr";
  return t.startsWith("/") ? `${base}${t}` : `${base}/${t}`;
}

/** RSS <description> HTML → 읽을 수 있는 plain text */
function htmlToPlainText(html: string): string {
  if (!html) return "";
  return html
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, "\"")
    .replace(/&#xD;\n?/g, "\n")
    .replace(/<!\[CDATA\[/gi, "")
    .replace(/\]\]>/g, "")
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/p>/gi, "\n")
    .replace(/<\/div>/gi, "\n")
    .replace(/<\/li>/gi, "\n")
    .replace(/<\/tr>/gi, "\n")
    .replace(/<[^>]+>/g, "")
    .replace(/&nbsp;/g, " ")
    .replace(/[ \t]+/g, " ")
    .replace(/\n{3,}/g, "\n\n")
    .trim()
    .slice(0, 3000);
}

/** 본문에서 시행일 자동 추출 ("시행일자 : 2026.3.25." 등) */
function extractEffectiveDate(
  text: string
): admin.firestore.Timestamp | null {
  const patterns = [
    /시행일[자]?\s*[:：]\s*(\d{4})[.\-/\s](\d{1,2})[.\-/\s](\d{1,2})/,
    /(\d{4})[.\-/](\d{1,2})[.\-/](\d{1,2})[.\s]*시행/,
  ];
  for (const re of patterns) {
    const m = re.exec(text);
    if (m) {
      const d = new Date(
        `${m[1]}-${m[2].padStart(2, "0")}-${m[3].padStart(2, "0")}T00:00:00+09:00`
      );
      if (!Number.isNaN(d.getTime())) {
        return admin.firestore.Timestamp.fromDate(d);
      }
    }
  }
  return null;
}

// ────────────────────────────────────────
// HIRA RSS 수집 + Digest 생성
// ────────────────────────────────────────

interface HiraUpdate {
  title: string;
  link: string;
  publishedAt: admin.firestore.Timestamp;
  topic: string;
  impactScore: number;
  impactLevel: string;
  keywords: string[];
  actionHints: string[];
  fetchedAt: admin.firestore.Timestamp;
  body?: string;
  effectiveDate?: admin.firestore.Timestamp | null;
  isDental?: "yes" | "no" | "maybe";
}

// ── 치과 관련성 분류 ──

const DENTAL_WHITELIST = [
  "치과", "구강", "악안면", "치주", "근관", "발치", "임플란트",
  "틀니", "레진", "치석", "스케일링", "보철", "교정", "치아",
  "치수", "치은", "치조골", "사랑니", "크라운", "브릿지", "의치",
  "치과급여부", "치과기획부", "치과위생사",
];

const DENTAL_BLACKLIST = [
  "한방", "한의원", "한의사", "한약", "약국", "조제", "약사",
  "산부인과", "안과", "이비인후과", "정형외과", "피부과", "비뇨기과",
  "항암제", "조영제", "투석", "인공신장", "방사선치료",
  "정신건강", "요양병원",
  "장애인 보조기기", "간호등급", "영양관리료", "차등제",
  "요양기관", "입원료", "간호간병", "의료급여",
  "재활", "호스피스", "장기요양", "보조기기",
  "간호관리료", "치료식", "의료질평가",
];

const DENTAL_CODE_RE = /\b[UL]\d{3,5}\b/;

function classifyDental(title: string, body: string): "yes" | "no" | "maybe" {
  const text = `${title} ${body}`;

  const hasCode = DENTAL_CODE_RE.test(text);
  if (hasCode) return "yes";

  const blackCount = DENTAL_BLACKLIST.filter((kw) => text.includes(kw)).length;
  const whiteCount = DENTAL_WHITELIST.filter((kw) => text.includes(kw)).length;

  if (whiteCount > 0 && blackCount === 0) return "yes";
  if (whiteCount > 0 && whiteCount > blackCount) return "yes";
  if (whiteCount > 0 && whiteCount <= blackCount) return "maybe";
  if (blackCount > 0) return "no";
  return "maybe";
}

/**
 * HIRA RSS 수집 (6시간마다)
 */
export const syncHiraUpdates = functions
  .pubsub.schedule("0 */6 * * *")
  .timeZone("Asia/Seoul")
  .onRun(async () => {
    try {
      let totalProcessed = 0;

      for (const {url, topic, filterKeyword} of HIRA_RSS_FEEDS) {
        try {
          const response = await axios.get(url, {timeout: 10000});
          const parsed = await parseStringPromise(response.data);
          const items = parsed.rss?.channel?.[0]?.item || [];

          for (const item of items) {
            const title = item.title?.[0] || "";
            const rawLink = item.link?.[0] || "";
            const link = absolutizeHiraLink(rawLink);
            const pubDate = item.pubDate?.[0] || "";
            const descHtml = item.description?.[0] || "";

            if (!title || !link) continue;

            const body = htmlToPlainText(descHtml);

            if (filterKeyword &&
                !title.includes(filterKeyword) &&
                !body.includes(filterKeyword)) {
              continue;
            }

            const docId = crypto
              .createHash("sha1")
              .update(link)
              .digest("hex");

            const docRef = db.collection("content_hira_updates").doc(docId);
            const docSnap = await docRef.get();

            if (docSnap.exists) continue;

            const isDental = classifyDental(title, body);
            if (isDental === "no") continue;

            const {score: rawScore, keywords} = calculateImpactScore(title);
            const score = isDental === "maybe"
              ? Math.round(rawScore * 0.5)
              : rawScore;
            const impactLevel = getImpactLevel(score);
            const actionHints = generateActionHints(title);
            const effectiveDate = extractEffectiveDate(body);

            const publishedAt = admin.firestore.Timestamp.fromDate(
              parseHiraRssPubDate(pubDate)
            );

            const updateData: HiraUpdate = {
              title,
              link,
              publishedAt,
              topic,
              impactScore: score,
              impactLevel,
              keywords,
              actionHints,
              fetchedAt: admin.firestore.Timestamp.now(),
              body,
              effectiveDate,
              isDental,
            };

            await docRef.set(updateData);
            totalProcessed++;
          }
        } catch (error) {
          console.error(`⚠️ Error fetching RSS ${url}:`, error);
        }
      }

      console.log(`✅ syncHiraUpdates: ${totalProcessed} new items processed`);
    } catch (error) {
      console.error("⚠️ syncHiraUpdates error:", error);
    }
  });

/**
 * HIRA Digest 생성 (매일 07:00 KST)
 */
export const buildHiraDigest = functions
  .pubsub.schedule("0 7 * * *")
  .timeZone("Asia/Seoul")
  .onRun(async () => {
    try {
      const dateKey = getCurrentDateKey();
      const fourteenDaysAgo = admin.firestore.Timestamp.fromMillis(
        Date.now() - 14 * 24 * 60 * 60 * 1000
      );

      // 최근 14일 내 치과 확정(yes) + impactScore 높은 순 3개
      let snapshot = await db
        .collection("content_hira_updates")
        .where("isDental", "==", "yes")
        .where("publishedAt", ">=", fourteenDaysAgo)
        .orderBy("publishedAt", "desc")
        .orderBy("impactScore", "desc")
        .limit(3)
        .get();

      // "yes"가 3개 미만이면 "maybe"로 보충
      if (snapshot.docs.length < 3) {
        const maybeFallback = await db
          .collection("content_hira_updates")
          .where("isDental", "==", "maybe")
          .where("publishedAt", ">=", fourteenDaysAgo)
          .orderBy("publishedAt", "desc")
          .orderBy("impactScore", "desc")
          .limit(3 - snapshot.docs.length)
          .get();
        const allDocs = [...snapshot.docs, ...maybeFallback.docs];
        snapshot = {docs: allDocs} as typeof snapshot;
      }

      const topIds = snapshot.docs.map((doc) => doc.id);

      await db
        .collection("content_hira_digest")
        .doc(dateKey)
        .set({
          topIds,
          generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      console.log(
        `✅ buildHiraDigest: ${dateKey} with ${topIds.length} items`
      );
    } catch (error) {
      console.error("⚠️ buildHiraDigest error:", error);
    }
  });

/**
 * impactScore 계산
 */
function calculateImpactScore(title: string): {
  score: number;
  keywords: string[];
} {
  const strongKeywords = [
    "치과",
    "구강",
    "치주",
    "임플란트",
    "교정",
    "보철",
    "근관",
    "스케일링",
    "치석",
    "마취",
  ];
  const mediumKeywords = [
    "수가",
    "급여",
    "행위",
    "청구",
    "기준",
    "고시",
    "산정",
    "인정",
    "심사",
  ];
  const weakKeywords = ["보험", "평가", "공단", "제도", "개정"];

  let score = 0;
  const foundKeywords: string[] = [];

  for (const kw of strongKeywords) {
    if (title.includes(kw)) {
      score += 30;
      foundKeywords.push(kw);
    }
  }
  for (const kw of mediumKeywords) {
    if (title.includes(kw)) {
      score += 15;
      foundKeywords.push(kw);
    }
  }
  for (const kw of weakKeywords) {
    if (title.includes(kw)) {
      score += 5;
      foundKeywords.push(kw);
    }
  }

  return {score: Math.min(score, 100), keywords: foundKeywords};
}

/**
 * impactLevel 산출
 */
function getImpactLevel(score: number): string {
  if (score >= 70) return "HIGH";
  if (score >= 40) return "MID";
  return "LOW";
}

/**
 * actionHints 생성
 */
function generateActionHints(title: string): string[] {
  const hints: string[] = [];

  if (/청구|산정|행위|코드|수가/.test(title)) {
    hints.push("청구팀 확인 필요");
  }
  if (/기준|인정|산정기준/.test(title)) {
    hints.push("차트/기록 방식 변경 여부 확인");
  }
  if (/서식|양식|제출/.test(title)) {
    hints.push("서식 업데이트 필요");
  }
  if (/치과|구강|스케일링|치주/.test(title)) {
    hints.push("치과 항목 영향 가능 (진료/상담 멘트 점검)");
  }

  if (hints.length === 0) {
    hints.push("원문 링크로 핵심 문단만 확인");
  }

  return hints.slice(0, 3); // 최대 3개
}

/**
 * HIRA 과거 데이터 수집 (최근 3개월)
 * 수동 실행용 - Firebase Console에서 1회만 실행
 */
export const syncHiraUpdatesHistorical = functions
  .https.onRequest(async (req, res): Promise<void> => {
    try {
      let totalProcessed = 0;
      const threeMonthsAgo = new Date();
      threeMonthsAgo.setMonth(threeMonthsAgo.getMonth() - 3);

      console.log(`📅 수집 시작: ${threeMonthsAgo.toISOString()} 이후 데이터`);

      for (const {url, topic, filterKeyword} of HIRA_RSS_FEEDS) {
        try {
          const response = await axios.get(url, {timeout: 15000});
          const parsed = await parseStringPromise(response.data);
          const items = parsed.rss?.channel?.[0]?.item || [];

          console.log(`📥 ${topic}: ${items.length}개 아이템 수신`);

          for (const item of items) {
            const title = item.title?.[0] || "";
            const rawLink = item.link?.[0] || "";
            const link = absolutizeHiraLink(rawLink);
            const pubDate = item.pubDate?.[0] || "";
            const descHtml = item.description?.[0] || "";

            if (!title || !link) continue;

            const publishedDate = parseHiraRssPubDate(pubDate);
            if (publishedDate < threeMonthsAgo) continue;

            const body = htmlToPlainText(descHtml);

            if (filterKeyword &&
                !title.includes(filterKeyword) &&
                !body.includes(filterKeyword)) {
              continue;
            }

            const docId = crypto
              .createHash("sha1")
              .update(link)
              .digest("hex");

            const docRef = db.collection("content_hira_updates").doc(docId);
            const docSnap = await docRef.get();

            if (docSnap.exists) continue;

            const isDental = classifyDental(title, body);
            if (isDental === "no") continue;

            const {score: rawScore, keywords} = calculateImpactScore(title);
            const score = isDental === "maybe"
              ? Math.round(rawScore * 0.5)
              : rawScore;
            const impactLevel = getImpactLevel(score);
            const actionHints = generateActionHints(title);
            const effectiveDate = extractEffectiveDate(body);

            const publishedAt = admin.firestore.Timestamp.fromDate(
              publishedDate
            );

            const updateData: HiraUpdate = {
              title,
              link,
              publishedAt,
              topic,
              impactScore: score,
              impactLevel,
              keywords,
              actionHints,
              fetchedAt: admin.firestore.Timestamp.now(),
              body,
              effectiveDate,
              isDental,
            };

            await docRef.set(updateData);
            totalProcessed++;
          }
        } catch (error) {
          console.error(`⚠️ Error fetching RSS ${url}:`, error);
        }
      }

      console.log(
        `✅ syncHiraUpdatesHistorical 완료: ${totalProcessed}개 처리`
      );

      // 처리 후 바로 Digest 생성
      try {
        await buildHiraDigestManually();
        res.status(200).json({
          success: true,
          processed: totalProcessed,
          message: `과거 데이터 ${totalProcessed}건 수집 완료`,
        });
      } catch (digestError: any) {
        console.error("⚠️ buildHiraDigestManually error:", digestError);

        // 인덱스 에러인지 확인
        if (digestError.code === 9 || digestError.message?.includes("index")) {
          res.status(400).json({
            success: false,
            processed: totalProcessed,
            error: "Firestore 복합 인덱스가 필요합니다",
            details: digestError.message,
            indexUrl: extractIndexUrl(digestError.message),
          });
          return;
        }

        res.status(500).json({
          success: false,
          processed: totalProcessed,
          error: digestError.message || String(digestError),
        });
      }
    } catch (error: any) {
      console.error("⚠️ syncHiraUpdatesHistorical error:", error);
      res.status(500).json({
        success: false,
        processed: 0,
        error: error.message || String(error),
      });
    }
  });

/**
 * 인덱스 URL 추출 헬퍼
 */
function extractIndexUrl(errorMessage: string): string | undefined {
  const match = errorMessage.match(/https:\/\/console\.firebase\.google\.com[^\s]+/);
  return match ? match[0] : undefined;
}

/**
 * Digest 수동 생성 헬퍼
 */
async function buildHiraDigestManually() {
  try {
    const dateKey = getCurrentDateKey();
    const fourteenDaysAgo = admin.firestore.Timestamp.fromMillis(
      Date.now() - 14 * 24 * 60 * 60 * 1000
    );

    let snapshot = await db
      .collection("content_hira_updates")
      .where("isDental", "==", "yes")
      .where("publishedAt", ">=", fourteenDaysAgo)
      .orderBy("publishedAt", "desc")
      .orderBy("impactScore", "desc")
      .limit(3)
      .get();

    if (snapshot.docs.length < 3) {
      const maybeFallback = await db
        .collection("content_hira_updates")
        .where("isDental", "==", "maybe")
        .where("publishedAt", ">=", fourteenDaysAgo)
        .orderBy("publishedAt", "desc")
        .orderBy("impactScore", "desc")
        .limit(3 - snapshot.docs.length)
        .get();
      const allDocs = [...snapshot.docs, ...maybeFallback.docs];
      snapshot = {docs: allDocs} as typeof snapshot;
    }

    const topIds = snapshot.docs.map((doc) => doc.id);

    await db
      .collection("content_hira_digest")
      .doc(dateKey)
      .set({
        topIds,
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    console.log(
      `✅ buildHiraDigestManually: ${dateKey}, ${topIds.length}개 항목`
    );
  } catch (error) {
    console.error("⚠️ buildHiraDigestManually error:", error);
  }
}

/**
 * 기존 Firestore 문서에 isDental 필드를 소급 적용하는 1회성 함수
 */
export const reclassifyHiraDental = functions
  .region("asia-northeast3")
  .runWith({timeoutSeconds: 300, memory: "512MB"})
  .https.onRequest(async (req, res): Promise<void> => {
    try {
      const snap = await db.collection("content_hira_updates").get();
      let updated = 0;
      let removed = 0;
      let batch = db.batch();
      let batchCount = 0;

      for (const doc of snap.docs) {
        const data = doc.data();
        const title = data.title || "";
        const body = data.body || "";
        const isDental = classifyDental(title, body);

        if (isDental === "no") {
          batch.delete(doc.ref);
          removed++;
        } else {
          const updates: {[key: string]: string | number} = {isDental};
          if (isDental === "maybe" && typeof data.impactScore === "number") {
            const {score: freshRaw} = calculateImpactScore(title);
            updates.impactScore = Math.round(freshRaw * 0.5);
            updates.impactLevel = getImpactLevel(updates.impactScore);
          }
          batch.update(doc.ref, updates);
          updated++;
        }
        batchCount++;

        if (batchCount >= 450) {
          await batch.commit();
          batch = db.batch();
          batchCount = 0;
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }

      console.log(
        `✅ reclassifyHiraDental: ${updated} updated, ${removed} removed`
      );
      res.status(200).json({
        success: true,
        updated,
        removed,
        total: snap.size,
      });
    } catch (error: any) {
      console.error("⚠️ reclassifyHiraDental error:", error);
      res.status(500).json({
        success: false,
        error: error.message || String(error),
      });
    }
  });

/**
 * Custom Token 발급 함수
 * 카카오/네이버 로그인 후 Firebase Auth 연동용
 */
export const createCustomToken = functions.https.onCall(
  async (data, context) => {
    const {provider, providerId, email, displayName} = data;

    // 입력 검증
    if (!provider || !providerId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "provider와 providerId는 필수입니다."
      );
    }

    // 지원하는 provider 확인
    const allowedProviders = ["kakao", "naver", "apple"];
    if (!allowedProviders.includes(provider)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        `지원하지 않는 provider: ${provider}`
      );
    }

    try {
      // Firebase UID 생성 (provider + providerId 조합)
      const uid = `${provider}_${providerId}`;

      // 사용자 정보 업데이트 (없으면 생성)
      const updateData: admin.auth.UpdateRequest = {};
      if (displayName) {
        updateData.displayName = displayName;
      }
      if (email && email.trim().length > 0) {
        updateData.email = email;
      }

      await admin.auth().updateUser(uid, updateData).catch(async () => {
        // 사용자가 없으면 새로 생성
        const createData: admin.auth.CreateRequest = {uid};
        if (displayName) {
          createData.displayName = displayName;
        }
        if (email && email.trim().length > 0) {
          createData.email = email;
        }
        await admin.auth().createUser(createData);
      });

      // Firestore users 컬렉션에도 기본 정보 저장
      await db.collection("users").doc(uid).set({
        email: email || null,
        displayName: displayName || null,
        provider,
        providerId,
        lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});

      // Custom Token 발급
      const customToken = await admin.auth().createCustomToken(uid);

      console.log(`✅ Custom Token created for ${provider}: ${providerId}`);

      return {
        success: true,
        customToken,
        uid,
      };
    } catch (error) {
      console.error("⚠️ createCustomToken error:", error);
      throw new functions.https.HttpsError(
        "internal",
        `Custom Token 발급 실패: ${error}`
      );
    }
  }
);

/**
 * 네이버 로그인 (서버 기반 인증) - 보안 강화 버전
 * 네이버 Access Token을 검증하고 Custom Token 발급
 */
export const verifyNaverToken = functions.https.onCall(
  async (data, context) => {
    // ========== 0. App Check 검증 (개발 중에는 경고만) ==========
    if (!context.app) {
      console.warn("⚠️ App Check 미적용: 프로덕션 배포 시 활성화 필요");
      // 개발 환경에서는 통과, 프로덕션에서는 주석 해제
      // throw new functions.https.HttpsError(
      //   "failed-precondition",
      //   "App Check 인증이 필요합니다.",
      //   {errorCode: SocialLoginError.APP_CHECK_REQUIRED}
      // );
    }

    // ========== 1. 입력 검증 ==========
    const {accessToken} = data;

    // 1-1. 필수값 체크
    if (!accessToken) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "accessToken은 필수입니다.",
        {errorCode: SocialLoginError.INVALID_INPUT}
      );
    }

    // 1-2. 타입 검증
    if (typeof accessToken !== "string") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "accessToken은 문자열이어야 합니다.",
        {errorCode: SocialLoginError.INVALID_INPUT}
      );
    }

    // 1-3. 길이 검증
    if (accessToken.length < 20 || accessToken.length > 2000) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "accessToken 길이가 유효하지 않습니다.",
        {errorCode: SocialLoginError.INVALID_INPUT}
      );
    }

    // 1-4. 빈값/공백 검증
    if (accessToken.trim().length === 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "accessToken이 비어있습니다.",
        {errorCode: SocialLoginError.INVALID_INPUT}
      );
    }

    // ========== 2. 레이트 리미팅 (IP 기준, Firestore) ==========
    const clientIp = context.rawRequest?.ip || "unknown";
    const rateLimitKey = `naver_ip_${clientIp}`;
    
    try {
      await checkRateLimitFirestore(rateLimitKey, 10, 60 * 1000); // 1분당 10회
    } catch (error) {
      // 레이트 리밋 에러는 그대로 throw
      throw error;
    }

    // ========== 3. 토큰 마스킹 로깅 ==========
    const maskedToken = maskToken(accessToken);
    console.log(`🔐 네이버 토큰 검증 시작 (토큰: ${maskedToken}, IP: ${clientIp})`);

    try {
      // ========== 4. 네이버 API 호출 (토큰 검증) ==========
      const response = await axios.get(
        "https://openapi.naver.com/v1/nid/me",
        {
          headers: {
            Authorization: `Bearer ${accessToken}`,
          },
          timeout: 10000, // 10초 타임아웃
        }
      );

      const userData = response.data;

      // ========== 5. 응답 검증 ==========
      const resultCode = userData.resultcode;
      const resultOk =
        resultCode === "00" ||
        resultCode === 0 ||
        String(resultCode) === "00";
      if (!userData.response || !resultOk) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "네이버 토큰 검증 실패",
          {errorCode: SocialLoginError.TOKEN_INVALID}
        );
      }

      const raw = userData.response as Record<string, unknown>;
      const pickStr = (obj: Record<string, unknown>, keys: string[]): string | null => {
        for (const k of keys) {
          const v = obj[k];
          if (typeof v === "string" && v.trim().length > 0) return v.trim();
        }
        return null;
      };

      const pickEmail = (obj: Record<string, unknown>): string | null => {
        for (const k of ["email", "user_email", "userEmail"]) {
          const v = obj[k];
          if (typeof v === "string" && v.trim().length > 0) return v.trim();
        }
        return null;
      };

      const naverId = String(raw.id ?? "");
      let email = pickEmail(raw);
      const profileEmailHint = (data.profileEmail as string | undefined)?.trim().toLowerCase();
      if (!email && profileEmailHint && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(profileEmailHint)) {
        email = profileEmailHint;
        console.log(
          "verifyNaverToken: nid/me에 email 없음 → 앱에서 전달한 프로필 이메일 사용 (동일 세션)"
        );
      }
      const displayName = pickStr(raw, ["name", "nickname"]);

      const responseKeys = Object.keys(raw);
      console.log(
        `✅ 네이버 토큰 검증 성공 (네이버ID: ${naverId}, nid/me keys: ${responseKeys.join(",")}, emailPresent: ${!!pickEmail(raw)})`
      );

      // ========== 6. Firebase UID 생성 (prefix로 충돌 방지) ==========
      const legacyUid = `naver_${naverId}`;
      /** Firebase Auth 커스텀 UID는 `:` 미허용 → 레거시와 동일한 `naver_` 접두사만 사용 */
      const uid = legacyUid;

      // ========== 6-1. 기존 사용자 마이그레이션 체크 ==========
      try {
        const legacyUser = await admin.auth().getUser(legacyUid);
        if (legacyUser) {
          console.log(`⚠️ 기존 사용자 발견 (${legacyUid}), 하위 호환 유지`);

          // 역할 중복 체크: 공고자 계정이면 위생사 로그인 차단
          await checkApplicantRoleDuplicate(legacyUid, email);

          // 기존 UID로 토큰 발급 (하위 호환성 유지)
          const customToken = await admin.auth().createCustomToken(legacyUid);
          
          // Firestore 업데이트 (레거시 계정 — 조건부 필드 보호)
          const naverLegacyUserRef = db.collection("users").doc(legacyUid);
          await db.runTransaction(async (transaction) => {
            const snap = await transaction.get(naverLegacyUserRef);
            const existing = snap.data() ?? {};

            const baseData: Record<string, unknown> = {
              email: email || null,
              normalizedEmail: email ? email.trim().toLowerCase() : null,
              displayName: displayName || null,
              provider: "naver",
              providerId: naverId,
              lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
            };

            if (!snap.exists || existing["createdAt"] == null) {
              baseData["createdAt"] = admin.firestore.FieldValue.serverTimestamp();
            }
            if (existing["excludeFromStats"] == null) {
              baseData["excludeFromStats"] = false;
            }

            transaction.set(naverLegacyUserRef, baseData, {merge: true});
          });

          if (email && email.trim().length > 0) {
            try {
              await admin.auth().updateUser(legacyUid, {email: email.trim()});
            } catch (authUpdErr: unknown) {
              console.warn(
                "verifyNaverToken: 기존 사용자 Auth email 갱신 실패(무시)",
                String(authUpdErr)
              );
            }
          }

          console.log(`✅ 기존 사용자 로그인 완료 (UID: ${legacyUid})`);

          return {
            success: true,
            customToken,
            uid: legacyUid,
          };
        }
      } catch (error: any) {
        if (error instanceof functions.https.HttpsError) throw error;
        // 기존 사용자가 없으면 새 형식으로 생성
        console.log(`✅ 신규 사용자, 새 UID 형식 사용: ${uid}`);
      }

      // ========== 6-2. 신규 사용자 역할 중복 체크 ==========
      await checkApplicantRoleDuplicate(uid, email);

      // ========== 7. Firebase Auth 사용자 생성/업데이트 ==========
      const updateData: admin.auth.UpdateRequest = {};
      if (displayName) {
        updateData.displayName = displayName;
      }
      if (email && email.trim().length > 0) {
        updateData.email = email;
      }

      // 빈 updateUser({}) 는 INVALID_ARGUMENT → 재로그인 시 createUser(uid) 가 uid 중복으로 실패할 수 있음
      // (이메일·이름 미제공 네이버 계정에서 특히 자주 발생)
      const hasAuthFields = Object.keys(updateData).length > 0;
      if (hasAuthFields) {
        await admin.auth().updateUser(uid, updateData).catch(async () => {
          const createData: admin.auth.CreateRequest = {uid};
          if (displayName) {
            createData.displayName = displayName;
          }
          if (email && email.trim().length > 0) {
            createData.email = email;
          }
          await admin.auth().createUser(createData);
        });
      } else {
        try {
          await admin.auth().getUser(uid);
        } catch (e: unknown) {
          const code =
            e && typeof e === "object" && "code" in e
              ? String((e as {code?: string}).code)
              : "";
          if (code === "auth/user-not-found") {
            await admin.auth().createUser({uid});
          } else {
            throw e;
          }
        }
      }

      // ========== 8. Firestore users 컬렉션에 저장 ==========
      const naverNewUserRef = db.collection("users").doc(uid);
      await db.runTransaction(async (transaction) => {
        const snap = await transaction.get(naverNewUserRef);
        const existing = snap.data() ?? {};

        const baseData: Record<string, unknown> = {
          email: email || null,
          normalizedEmail: email ? email.trim().toLowerCase() : null,
          displayName: displayName || null,
          provider: "naver",
          providerId: naverId,
          lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        if (!snap.exists || existing["createdAt"] == null) {
          baseData["createdAt"] = admin.firestore.FieldValue.serverTimestamp();
        }
        if (existing["excludeFromStats"] == null) {
          baseData["excludeFromStats"] = false;
        }

        transaction.set(naverNewUserRef, baseData, {merge: true});
      });

      // ========== 9. Custom Token 발급 ==========
      const customToken = await admin.auth().createCustomToken(uid);

      console.log(`✅ 네이버 Custom Token 발급 완료 (UID: ${uid})`);

      return {
        success: true,
        customToken,
        uid,
      };
    } catch (error: any) {
      const authCode = getFirebaseAuthErrorCode(error);
      console.error(
        "⚠️ verifyNaverToken error:",
        authCode || error?.code || "(no code)",
        error?.message ?? error
      );

      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      // ========== 10. Firebase Auth (Admin) 오류 — internal 로만 묻히지 않도록 ==========
      if (
        authCode === "auth/email-already-exists" ||
        authCode === "auth/email-already-in-use"
      ) {
        throw new functions.https.HttpsError(
          "already-exists",
          "이 이메일은 다른 로그인 방식으로 이미 가입되어 있습니다. 기존 방식으로 로그인하거나 계정 통합이 필요합니다.",
          {errorCode: SocialLoginError.EMAIL_ALREADY_IN_USE, authCode}
        );
      }
      if (authCode === "auth/uid-already-exists") {
        throw new functions.https.HttpsError(
          "aborted",
          "계정 생성이 충돌했습니다. 잠시 후 다시 시도해 주세요.",
          {errorCode: SocialLoginError.INTERNAL_ERROR, authCode}
        );
      }

      // ========== 11. 에러 분류 및 전달 (네이버 API 등) ==========
      if (axios.isAxiosError(error)) {
        if (error.response) {
          const status = error.response.status;
          const naverError = error.response.data;

          console.error(`네이버 API 에러 (status: ${status}):`, naverError);

          // 네이버 에러코드 분류
          if (status === 401) {
            throw new functions.https.HttpsError(
              "unauthenticated",
              "유효하지 않거나 만료된 Access Token입니다. 다시 로그인해주세요.",
              {errorCode: SocialLoginError.TOKEN_EXPIRED}
            );
          } else if (status === 400) {
            throw new functions.https.HttpsError(
              "invalid-argument",
              "잘못된 요청입니다. Access Token을 확인해주세요.",
              {errorCode: SocialLoginError.TOKEN_INVALID}
            );
          } else if (status >= 500) {
            throw new functions.https.HttpsError(
              "unavailable",
              "네이버 서버에 일시적인 문제가 발생했습니다. 잠시 후 다시 시도해주세요.",
              {errorCode: SocialLoginError.PROVIDER_DOWN}
            );
          }
        } else if (error.code === "ECONNABORTED") {
          throw new functions.https.HttpsError(
            "deadline-exceeded",
            "네이버 서버 응답 시간 초과. 네트워크를 확인해주세요.",
            {errorCode: SocialLoginError.PROVIDER_DOWN}
          );
        }
      }

      throw new functions.https.HttpsError(
        "internal",
        "네이버 로그인 처리 중 오류가 발생했습니다.",
        {errorCode: SocialLoginError.INTERNAL_ERROR}
      );
    }
  }
);

/**
 * 카카오 로그인 (서버 기반 인증) - 보안 강화 버전
 * 카카오 Access Token을 검증하고 Custom Token 발급
 */
export const verifyKakaoToken = functions.https.onCall(
  async (data, context) => {
    // ========== 0. App Check 검증 (개발 중에는 경고만) ==========
    if (!context.app) {
      console.warn("⚠️ App Check 미적용: 프로덕션 배포 시 활성화 필요");
      // 개발 환경에서는 통과, 프로덕션에서는 주석 해제
      // throw new functions.https.HttpsError(
      //   "failed-precondition",
      //   "App Check 인증이 필요합니다.",
      //   {errorCode: SocialLoginError.APP_CHECK_REQUIRED}
      // );
    }

    // ========== 1. 입력 검증 ==========
    const {accessToken} = data;

    // 1-1. 필수값 체크
    if (!accessToken) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "accessToken은 필수입니다.",
        {errorCode: SocialLoginError.INVALID_INPUT}
      );
    }

    // 1-2. 타입 검증
    if (typeof accessToken !== "string") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "accessToken은 문자열이어야 합니다.",
        {errorCode: SocialLoginError.INVALID_INPUT}
      );
    }

    // 1-3. 길이 검증 (카카오 Access Token은 보통 100~500자)
    if (accessToken.length < 20 || accessToken.length > 2000) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "accessToken 길이가 유효하지 않습니다.",
        {errorCode: SocialLoginError.INVALID_INPUT}
      );
    }

    // 1-4. 빈값/공백 검증
    if (accessToken.trim().length === 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "accessToken이 비어있습니다.",
        {errorCode: SocialLoginError.INVALID_INPUT}
      );
    }

    // ========== 2. 레이트 리미팅 (IP 기준, Firestore) ==========
    const clientIp = context.rawRequest?.ip || "unknown";
    const rateLimitKey = `kakao_ip_${clientIp}`;
    
    try {
      await checkRateLimitFirestore(rateLimitKey, 10, 60 * 1000); // 1분당 10회
    } catch (error) {
      // 레이트 리밋 에러는 그대로 throw
      throw error;
    }

    // ========== 3. 토큰 마스킹 로깅 ==========
    const maskedToken = maskToken(accessToken);
    console.log(`🔐 카카오 토큰 검증 시작 (토큰: ${maskedToken}, IP: ${clientIp})`);

    try {
      // ========== 4. 카카오 API 호출 (토큰 검증) ==========
      const response = await axios.get(
        "https://kapi.kakao.com/v2/user/me",
        {
          headers: {
            Authorization: `Bearer ${accessToken}`,
          },
          timeout: 10000, // 10초 타임아웃
        }
      );

      const kakaoUser = response.data;

      // ========== 5. 응답 검증 ==========
      if (!kakaoUser.id) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "카카오 사용자 ID를 가져올 수 없습니다.",
          {errorCode: SocialLoginError.TOKEN_INVALID}
        );
      }

      const kakaoId = kakaoUser.id.toString();
      const email = kakaoUser.kakao_account?.email || null;
      const displayName = kakaoUser.kakao_account?.profile?.nickname || null;

      console.log(`✅ 카카오 토큰 검증 성공 (카카오ID: ${kakaoId})`);

      // ========== 6. Firebase UID 생성 (prefix로 충돌 방지) ==========
      const legacyUid = `kakao_${kakaoId}`;
      /** Firebase Auth 커스텀 UID는 `:` 미허용 → 레거시와 동일한 `kakao_` 접두사만 사용 */
      const uid = legacyUid;

      // ========== 6-1. 기존 사용자 마이그레이션 체크 ==========
      try {
        const legacyUser = await admin.auth().getUser(legacyUid);
        if (legacyUser) {
          console.log(`⚠️ 기존 사용자 발견 (${legacyUid}), 하위 호환 유지`);

          // 역할 중복 체크: 공고자 계정이면 위생사 로그인 차단
          await checkApplicantRoleDuplicate(legacyUid, email);

          // 기존 UID로 토큰 발급 (하위 호환성 유지)
          const customToken = await admin.auth().createCustomToken(legacyUid);
          
          // Firestore 업데이트 (레거시 계정 — 조건부 필드 보호)
          const kakaoLegacyUserRef = db.collection("users").doc(legacyUid);
          await db.runTransaction(async (transaction) => {
            const snap = await transaction.get(kakaoLegacyUserRef);
            const existing = snap.data() ?? {};

            const baseData: Record<string, unknown> = {
              email: email || null,
              normalizedEmail: email ? email.trim().toLowerCase() : null,
              displayName: displayName || null,
              provider: "kakao",
              providerId: kakaoId,
              lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
            };

            if (!snap.exists || existing["createdAt"] == null) {
              baseData["createdAt"] = admin.firestore.FieldValue.serverTimestamp();
            }
            if (existing["excludeFromStats"] == null) {
              baseData["excludeFromStats"] = false;
            }

            transaction.set(kakaoLegacyUserRef, baseData, {merge: true});
          });

          console.log(`✅ 기존 사용자 로그인 완료 (UID: ${legacyUid})`);

          return {
            success: true,
            customToken,
            uid: legacyUid,
          };
        }
      } catch (error: any) {
        if (error instanceof functions.https.HttpsError) throw error;
        // 기존 사용자가 없으면 새 형식으로 생성
        console.log(`✅ 신규 사용자, 새 UID 형식 사용: ${uid}`);
      }

      // ========== 6-2. 신규 사용자 역할 중복 체크 ==========
      await checkApplicantRoleDuplicate(uid, email);

      // ========== 7. Firebase Auth 사용자 생성/조회 (email-already-exists 방지) ==========
      let resolvedUid = uid; // 기본값: kakao_<카카오숫자ID>

      // 7-1. 먼저 kakao_* UID로 기존 계정 존재 여부 확인
      let userExists = false;
      try {
        await admin.auth().getUser(uid);
        userExists = true;
        console.log(`✅ 기존 카카오 계정 확인 (UID: ${uid})`);
      } catch {
        userExists = false;
      }

      if (userExists) {
        // 7-2. 기존 계정 업데이트 — 이메일 충돌 시 이메일 제외하고 재시도
        try {
          const updateData: admin.auth.UpdateRequest = {};
          if (displayName) updateData.displayName = displayName;
          if (email && email.trim().length > 0) updateData.email = email;
          await admin.auth().updateUser(uid, updateData);
        } catch (updateError: any) {
          if (updateError.code === "auth/email-already-exists") {
            // 이메일 충돌 시 이메일 제외하고 이름만 업데이트
            const safeUpdate: admin.auth.UpdateRequest = {};
            if (displayName) safeUpdate.displayName = displayName;
            await admin.auth().updateUser(uid, safeUpdate).catch(() => {});
            console.log(`⚠️ 이메일 충돌로 이름만 업데이트 (UID: ${uid})`);
          } else {
            throw updateError;
          }
        }
      } else {
        // 7-3. 신규 계정 생성 — 이메일이 이미 다른 계정에 존재하면 그 계정 UID 사용
        try {
          const createData: admin.auth.CreateRequest = {uid};
          if (displayName) createData.displayName = displayName;
          if (email && email.trim().length > 0) createData.email = email;
          await admin.auth().createUser(createData);
          console.log(`✅ 신규 카카오 계정 생성 완료 (UID: ${uid})`);
        } catch (createError: any) {
          if (createError.code === "auth/email-already-exists" && email) {
            // 동일 이메일의 기존 계정(구글, 이메일 등) UID를 사용
            console.log(`⚠️ 이메일(${email}) 이미 존재 → 기존 계정 UID 사용`);
            const existingUser = await admin.auth().getUserByEmail(email);
            resolvedUid = existingUser.uid;
            // 연결되는 기존 UID에 대해서도 역할 중복 체크
            await checkApplicantRoleDuplicate(resolvedUid, email);
            console.log(`✅ 기존 계정 UID로 연결: ${resolvedUid}`);
          } else {
            throw createError;
          }
        }
      }

      // ========== 8. Firestore users 컬렉션에 저장 ==========
      const kakaoNewUserRef = db.collection("users").doc(resolvedUid);
      await db.runTransaction(async (transaction) => {
        const snap = await transaction.get(kakaoNewUserRef);
        const existing = snap.data() ?? {};

        const baseData: Record<string, unknown> = {
          email: email || null,
          normalizedEmail: email ? email.trim().toLowerCase() : null,
          displayName: displayName || null,
          provider: "kakao",
          providerId: kakaoId,
          lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        if (!snap.exists || existing["createdAt"] == null) {
          baseData["createdAt"] = admin.firestore.FieldValue.serverTimestamp();
        }
        if (existing["excludeFromStats"] == null) {
          baseData["excludeFromStats"] = false;
        }

        transaction.set(kakaoNewUserRef, baseData, {merge: true});
      });

      // ========== 9. Custom Token 발급 ==========
      const customToken = await admin.auth().createCustomToken(resolvedUid);

      console.log(`✅ 카카오 Custom Token 발급 완료 (UID: ${resolvedUid})`);

      return {
        success: true,
        customToken,
        uid: resolvedUid,
      };
    } catch (error: any) {
      console.error("⚠️ verifyKakaoToken error:", error.message);
      if (error?.code) {
        console.error("⚠️ verifyKakaoToken error.code:", error.code);
      }

      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      // ========== 10. 에러 분류 및 전달 ==========
      if (axios.isAxiosError(error)) {
        if (error.response) {
          const status = error.response.status;
          const kakaoError = error.response.data;

          console.error(`카카오 API 에러 (status: ${status}):`, kakaoError);

          // 카카오 에러코드 분류
          if (status === 401) {
            throw new functions.https.HttpsError(
              "unauthenticated",
              "유효하지 않거나 만료된 Access Token입니다. 다시 로그인해주세요.",
              {errorCode: SocialLoginError.TOKEN_EXPIRED}
            );
          } else if (status === 400) {
            throw new functions.https.HttpsError(
              "invalid-argument",
              "잘못된 요청입니다. Access Token을 확인해주세요.",
              {errorCode: SocialLoginError.TOKEN_INVALID}
            );
          } else if (status >= 500) {
            throw new functions.https.HttpsError(
              "unavailable",
              "카카오 서버에 일시적인 문제가 발생했습니다. 잠시 후 다시 시도해주세요.",
              {errorCode: SocialLoginError.PROVIDER_DOWN}
            );
          }
        } else if (error.code === "ECONNABORTED") {
          throw new functions.https.HttpsError(
            "deadline-exceeded",
            "카카오 서버 응답 시간 초과. 네트워크를 확인해주세요.",
            {errorCode: SocialLoginError.PROVIDER_DOWN}
          );
        }
      }

      throw new functions.https.HttpsError(
        "internal",
        "카카오 로그인 처리 중 오류가 발생했습니다.",
        {errorCode: SocialLoginError.INTERNAL_ERROR}
      );
    }
  }
);

// ========== 계정 삭제 ==========
export { deleteMyAccount } from "./account-deletion";

// ========== 행동 분석 일별 집계 ==========
export { aggregateAnalyticsDaily } from "./scheduled-analytics";

// ========== 공감투표 자동 종료 ==========
export {
  adminAdvancePollQueue,
  adminDeletePoll,
  closeExpiredPolls,
  manualClosePoll,
} from "./poll-close";

// 공감투표: 신고 누적 삭제 · 작성자 보기 삭제(공감 본인 1표)
export {
  authorDeletePollOptionWithVote,
  onPollOptionReportThreshold,
  purgePollOptionAfterReports,
} from "./poll-option-moderation";

// ========== 구인공고: 이미지 → 폼 자동채우기 (AI Vision) ==========

/** 한 줄에서 휴대폰 → 지역번호 순으로 첫 전화번호만 추출 */
function extractFirstPhoneFromHay(hay: string): string {
  const patterns = [
    /01[016789](?:[.\-\s]?\d{3,4}){2}/,
    /0?2(?:[.\-\s]?\d{3,4}){2}/,
    /0[3-6]\d(?:[.\-\s]?\d{3,4}){2}/,
    /(?:070|050[2-8])(?:[.\-\s]?\d{3,4}){2}/,
  ];
  for (const re of patterns) {
    const m = hay.match(re);
    if (m) return m[0].replace(/\s/g, "");
  }
  return "";
}

/** description 본문에서 전화 + 이메일을 찾아 ` · `로 합침(한쪽만 있어도 반환). */
function extractContactFromDescriptionBlob(text: string): string {
  const raw = String(text ?? "").trim();
  if (!raw) return "";
  const flat = raw.replace(/\s+/g, " ");
  const lines = raw.split(/\r?\n/).map((l) => l.trim()).filter(Boolean);
  const haystacks = [flat, ...lines];

  let phone = "";
  for (const hay of haystacks) {
    phone = extractFirstPhoneFromHay(hay);
    if (phone) break;
  }

  const emailMatch = flat.match(
    /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i
  );
  const email = emailMatch ? emailMatch[0].trim() : "";

  const parts: string[] = [];
  if (phone) parts.push(phone);
  if (email) parts.push(email);
  return parts.join(" · ");
}

/** 공백·대소문자 무시 중복 제거 후 ` · `로 합침 */
function mergeContactParts(a: string, b: string): string {
  const seen = new Set<string>();
  const out: string[] = [];
  const pushChunk = (s: string) => {
    const t = s.trim();
    if (!t) return;
    const key = t.replace(/\s+/g, " ").toLowerCase();
    if (seen.has(key)) return;
    seen.add(key);
    out.push(t);
  };
  for (const chunk of a.split(/\s*·\s*/)) pushChunk(chunk);
  for (const chunk of b.split(/\s*·\s*/)) pushChunk(chunk);
  return out.join(" · ");
}

/** [parseJobImagesToForm] description 본문에서 한국식 주소 한 줄 후보 추출 */
function extractAddressLineFromDescriptionBlob(text: string): string {
  const raw = String(text ?? "").trim();
  if (!raw) return "";
  const lines = raw
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l.length > 5);
  const region =
    /(서울시|서울특별시|부산광역시|대구광역시|인천광역시|광주광역시|대전광역시|울산광역시|세종|경기도|강원특별자치도|강원도|충청북도|충청남도|전북특별자치도|전라북도|전라남도|경상북도|경상남도|제주특별자치도|제주도|[가-힣]{2,12}(시|군|구))/;
  let best = "";
  for (const line of lines) {
    if (!region.test(line)) continue;
    if (/\d/.test(line) || /(로|길)\s*\d/.test(line)) {
      if (line.length > best.length) best = line;
    }
  }
  return best.trim();
}

/** 모델 출력 후 주소·연락처가 비었을 때 description에서만 보강 + 로그용 태그 */
function postProcessAddressContactFromDescription(
  description: string,
  address: string,
  contact: string,
): {
  address: string;
  contact: string;
  logTags: string[];
  recoverySource: "none" | "description_regex" | "description_regex_both";
} {
  const logTags: string[] = [];
  let addr = String(address ?? "").trim();
  let ct = String(contact ?? "").trim();
  const desc = String(description ?? "").trim();
  let recoverySource: "none" | "description_regex" | "description_regex_both" = "none";
  if (!desc) {
    return { address: addr, contact: ct, logTags, recoverySource };
  }
  let touchedC = false;
  let touchedA = false;
  const fromDescContact = extractContactFromDescriptionBlob(desc);
  if (!ct) {
    if (fromDescContact) {
      ct = fromDescContact;
      touchedC = true;
      logTags.push("contact_recovered_from_description");
    }
  } else if (fromDescContact) {
    const merged = mergeContactParts(ct, fromDescContact);
    if (merged !== ct.trim()) {
      ct = merged;
      touchedC = true;
      logTags.push("contact_merged_with_description_regex");
    }
  }
  if (!addr) {
    const a = extractAddressLineFromDescriptionBlob(desc);
    if (a) {
      addr = a;
      touchedA = true;
      logTags.push("address_recovered_from_description");
    }
  }
  if (touchedC && touchedA) recoverySource = "description_regex_both";
  else if (touchedC || touchedA) recoverySource = "description_regex";
  return { address: addr, contact: ct, logTags, recoverySource };
}

/**
 * parseJobImagesToForm
 *
 * 공고 이미지 URL 목록을 받아 OpenAI Vision으로 폼 필드를 추출한다.
 * 현재는 Mock 구현. 실제 OpenAI 키 발급 후 아래 TODO 섹션 교체.
 *
 * Input  : { imageUrls: string[], jobId: string }
 * Output : { title, role, employmentType, workHours, salary,
 *            benefits, description, address, contact, clinicName, education }
 */
export const parseJobImagesToForm = functions
  .runWith({ timeoutSeconds: 180, memory: "512MB", secrets: ["GEMINI_API_KEY"] })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "로그인이 필요합니다."
      );
    }

    const imageUrls: string[] = data.imageUrls ?? [];
    if (!imageUrls.length) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "이미지 URL이 없습니다."
      );
    }

    // ── sourceType 분기 (image / text / mixed) ────────────────
    const sourceType: string = data.sourceType ?? "image";
    const rawText: string = data.rawText ?? "";

    if (sourceType === "text" && !rawText.trim()) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "텍스트 입력이 비어 있습니다."
      );
    }

    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      throw new functions.https.HttpsError("internal", "AI API 키가 설정되지 않았습니다.");
    }

    functions.logger.info("parseJobImagesToForm", {
      uid: context.auth.uid, sourceType, imageCount: imageUrls.length, textLength: rawText.length,
    });

    const systemPrompt = `아래 치과 채용 공고 내용을 분석하여 반드시 아래 JSON 형식으로만 응답해줘.
다른 텍스트 없이 순수 JSON만 반환해.
원문에 명시된 정보만 추출하고, 없으면 빈 문자열·null·빈 배열을 사용해.

[추출 우선순위 — 반드시 이 순서로 정보를 분리할 것]

1순위 (핵심 구조화 필드 — 절대 description에 섞지 말 것):
- mainDuties: 담당 업무 항목 (배열, 한 항목당 80자 이내)
- workHours / salary / workDays: 근무 시간·급여·요일
- applyMethod / closingDate: 지원 방법·마감일
- benefits: 복리후생·수당·휴가·식대 등 복지성 항목 (배열)
- subwayStationName / subwayLines / address: 교통·주소

2순위 (병원 정보):
- hospitalType / chairCount / staffCount
- specialties: 주요 진료 과목 배열 (일반진료/교정/임플란트/소아치과/치주/보존/기타 중 해당하는 것)
- hasOralScanner / hasCT / has3DPrinter: 장비 보유 여부 (true/false/null)
- digitalEquipmentRaw: 위 3가지로 분류 안 된 기타 장비 설명 문자열

3순위 (description — 분류 실패한 나머지만):
- 병원 소개, 진료 철학, 팀 문화, 분위기 설명
- 위 1·2순위로 분류된 내용은 절대 description에 다시 쓰지 말 것

[상세 규칙]
A) salary에는 급여만, workHours에는 근무 시간만. 이 내용을 description에 반복하지 않는다.
B) 역·출구·도보 거리·지하철 노선은 benefits에 넣지 않는다.
C) 체어·에어석션·스툴 등 시설은 description에 서술하고 benefits에 넣지 않는다.
D) hospitalType은 clinic | network | hospital | general 중 하나. 모르면 빈 문자열.
E) chairCount·staffCount는 원문에 숫자 있을 때만 정수, 없으면 null.
F) workDays는 한글 요일 그대로 반환 (예: ["월","화","수","목","금"]).
G) closingDate·recruitmentStart는 YYYY-MM-DD. 원문에 없으면 null.
H) fieldStatus: 아래 키들을 빠짐없이 포함하고, 각각 confirmed(원문 명시) / inferred(추론) / missing(미기재) / conflict(원문과 불일치 가능) 중 하나. 앱은 동일 키로 뱃지를 표시한다.

{
  "clinicName": "치과명",
  "title": "공고 제목",
  "role": "직종",
  "career": "경력 조건",
  "education": "무관 | 고등학교 졸업 이상 | 전문대 졸업 이상 중 하나",
  "employmentType": "고용 형태",
  "workHours": "근무 시간",
  "workDays": ["월", "화", "수", "목", "금"],
  "weekendWork": "주말 근무 여부",
  "nightShift": "야간 근무 여부",
  "salary": "급여",
  "mainDuties": ["업무1", "업무2"],
  "benefits": ["복리후생1", "복리후생2"],
  "description": "병원 소개·팀 문화 등 분류 안 된 나머지만",
  "address": "근무지 주소",
  "contact": "연락처",
  "applyMethod": ["online", "phone"],
  "hospitalType": "clinic | network | hospital | general",
  "chairCount": null,
  "staffCount": null,
  "specialties": ["일반진료", "임플란트"],
  "hasOralScanner": null,
  "hasCT": null,
  "has3DPrinter": null,
  "digitalEquipmentRaw": "",
  "requiredDocuments": ["이력서", "자기소개서"],
  "subwayStationName": "강남역",
  "subwayLines": ["2호선", "신분당선"],
  "recruitmentStart": null,
  "closingDate": null,
  "fieldStatus": {
    "title": "confirmed",
    "clinicName": "confirmed",
    "career": "confirmed",
    "role": "confirmed",
    "mainDuties": "confirmed",
    "education": "confirmed",
    "employmentType": "confirmed",
    "salary": "confirmed",
    "workHours": "confirmed",
    "workDays": "confirmed",
    "benefits": "confirmed",
    "description": "inferred",
    "address": "confirmed",
    "contact": "missing",
    "subwayStationName": "confirmed",
    "applyMethod": "confirmed",
    "hospitalType": "confirmed",
    "chairCount": "missing",
    "staffCount": "missing",
    "specialties": "confirmed",
    "hasOralScanner": "missing",
    "hasCT": "missing",
    "has3DPrinter": "missing",
    "digitalEquipmentRaw": "missing",
    "requiredDocuments": "missing",
    "closingDate": "missing"
  }
}`;

    const parts: Array<{text?: string; inlineData?: {mimeType: string; data: string}}> = [];
    parts.push({text: systemPrompt});

    if (sourceType === "text" || sourceType === "mixed") {
      parts.push({text: "아래는 공고 텍스트입니다:\n" + rawText});
    }

    if ((sourceType === "image" || sourceType === "mixed") && imageUrls.length > 0) {
      for (const url of imageUrls.slice(0, 10)) {
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
      const geminiUrl = "https://generativelanguage.googleapis.com/v1beta/models/" + GEMINI_MODEL + ":generateContent?key=" + apiKey;
      const resp = await axios.post(geminiUrl, {
        contents: [{parts}],
        generationConfig: {responseMimeType: "application/json"},
      }, {timeout: 110000});

      const text = resp.data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
      const parsed = JSON.parse(text);

      const pickInt = (v: unknown): number | null => {
        if (typeof v === "number" && Number.isFinite(v)) return Math.round(v);
        if (typeof v === "string") {
          const n = parseInt(String(v).replace(/[^\d]/g, ""), 10);
          return Number.isFinite(n) ? n : null;
        }
        return null;
      };

      const subwayLinesRaw = Array.isArray(parsed.subwayLines)
        ? parsed.subwayLines.map((s: unknown) => String(s).trim()).filter(Boolean)
        : [];
      const mainDutiesRaw = Array.isArray(parsed.mainDuties)
        ? parsed.mainDuties.map((s: unknown) => String(s).trim()).filter(Boolean)
        : [];
      const specialtiesRaw = Array.isArray(parsed.specialties)
        ? parsed.specialties.map((s: unknown) => String(s).trim()).filter(Boolean)
        : [];

      const pickBool = (v: unknown): boolean | null => {
        if (typeof v === "boolean") return v;
        if (typeof v === "string") {
          const l = v.toLowerCase().trim();
          if (l === "true" || l === "있음" || l === "있다" || l === "보유") return true;
          if (l === "false" || l === "없음" || l === "없다") return false;
        }
        return null;
      };

      // fieldStatus: Gemini 응답 그대로 전달, 없으면 빈 객체
      const fieldStatus: Record<string, string> = {};
      if (parsed.fieldStatus && typeof parsed.fieldStatus === "object") {
        for (const [k, v] of Object.entries(parsed.fieldStatus)) {
          if (typeof v === "string") fieldStatus[k] = v;
        }
      }

      const descriptionTrimmed = String(parsed.description ?? "").trim();
      let addressOut = String(parsed.address ?? "").trim();
      let contactOut = String(parsed.contact ?? "").trim();

      const fieldGapTags: string[] = [];
      if (!addressOut) fieldGapTags.push("address_missing_after_model");
      if (!contactOut) fieldGapTags.push("contact_missing_after_model");

      const recovered = postProcessAddressContactFromDescription(
        descriptionTrimmed,
        addressOut,
        contactOut,
      );
      addressOut = recovered.address;
      contactOut = recovered.contact;

      const postTags: string[] = [...fieldGapTags, ...recovered.logTags];
      if (!addressOut) postTags.push("address_still_empty_after_recovery");
      if (!contactOut) postTags.push("contact_still_empty_after_recovery");

      const clinicNameOut = String(parsed.clinicName ?? "").trim();
      const reqDocs = Array.isArray(parsed.requiredDocuments) ? parsed.requiredDocuments : [];
      functions.logger.info("parseJobImagesToForm_postprocess", {
        uid: context.auth.uid,
        sourceType,
        imageCount: imageUrls.length,
        descriptionLen: descriptionTrimmed.length,
        clinicName: clinicNameOut,
        address: addressOut,
        contact: contactOut,
        subwayStationName: String(parsed.subwayStationName ?? "").trim(),
        requiredDocumentsCount: reqDocs.length,
        fieldStatusAddress: fieldStatus["address"] ?? "",
        fieldStatusContact: fieldStatus["contact"] ?? "",
        recoverySource: recovered.recoverySource,
        tags: [...new Set(postTags)],
      });

      return {
        clinicName: String(parsed.clinicName ?? "").trim(),
        title: String(parsed.title ?? "").trim(),
        role: String(parsed.role ?? "").trim(),
        career: String(parsed.career ?? "").trim(),
        education: String(parsed.education ?? "").trim(),
        employmentType: String(parsed.employmentType ?? "").trim(),
        workHours: String(parsed.workHours ?? "").trim(),
        salary: String(parsed.salary ?? "").trim(),
        benefits: Array.isArray(parsed.benefits) ? parsed.benefits : [],
        description: descriptionTrimmed,
        address: addressOut,
        contact: contactOut,
        hospitalType: String(parsed.hospitalType ?? "").trim(),
        workDays: Array.isArray(parsed.workDays) ? parsed.workDays : [],
        weekendWork: parsed.weekendWork ?? "",
        nightShift: parsed.nightShift ?? "",
        chairCount: pickInt(parsed.chairCount),
        staffCount: pickInt(parsed.staffCount),
        specialties: specialtiesRaw,
        hasOralScanner: pickBool(parsed.hasOralScanner),
        hasCT: pickBool(parsed.hasCT),
        has3DPrinter: pickBool(parsed.has3DPrinter),
        digitalEquipmentRaw: parsed.digitalEquipmentRaw ? String(parsed.digitalEquipmentRaw).trim() : null,
        subwayStationName: String(parsed.subwayStationName ?? "").trim(),
        subwayLines: subwayLinesRaw,
        mainDuties: mainDutiesRaw,
        recruitmentStart: parsed.recruitmentStart ? String(parsed.recruitmentStart).trim() : null,
        closingDate: parsed.closingDate ? String(parsed.closingDate).trim() : null,
        fieldStatus,
      };
    } catch (e: unknown) {
      functions.logger.error("Gemini API 호출 실패", {error: String(e)});
      throw new functions.https.HttpsError("internal", "AI 분석 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.");
    }
  });

// ========== 구인공고: 공고 생성 ==========
/** 앱 [Job] salaryRange(만원)와 동기화하기 위한 급여 문자열 파싱 */
function parseJobSalaryRange(salary: string): { min: number; max: number } {
  const t = String(salary ?? "").replace(/\s/g, "");
  if (!t) return { min: 0, max: 0 };
  const range = t.match(/(\d{2,4})[~～\-](\d{2,4})/);
  if (range) {
    return { min: parseInt(range[1], 10), max: parseInt(range[2], 10) };
  }
  const singles = t.match(/(\d{2,4})/g);
  if (singles && singles.length >= 2) {
    return { min: parseInt(singles[0], 10), max: parseInt(singles[1], 10) };
  }
  if (singles && singles.length === 1) {
    const v = parseInt(singles[0], 10);
    return { min: v, max: v };
  }
  return { min: 0, max: 0 };
}

/**
 * createJobPosting
 *
 * 서버 측에서 구인공고를 생성한다(검증/정규화/스팸방지).
 * 생성 시 status=pending 으로 설정.
 */
export const createJobPosting = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "로그인이 필요합니다."
      );
    }

    const uid = context.auth.uid;

    // 필수 필드 검증
    const required = ["clinicName", "title", "address"];
    for (const field of required) {
      if (!data[field] || !String(data[field]).trim()) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          `${field} 필드가 비어 있습니다.`
        );
      }
    }

    // ── images 다층 검증 ──────────────────────────────────────
    const rawImages = data.images;
    if (rawImages !== undefined && !Array.isArray(rawImages)) {
      throw new functions.https.HttpsError("invalid-argument", "images는 배열이어야 합니다.");
    }
    const imagesArr: unknown[] = Array.isArray(rawImages) ? rawImages : [];
    if (imagesArr.length > 10) {
      throw new functions.https.HttpsError("invalid-argument", "이미지는 최대 10장입니다.");
    }
    const storagePrefix = "https://firebasestorage.googleapis.com/";
    const validImages: string[] = [];
    for (const url of imagesArr) {
      if (
        typeof url !== "string" ||
        url.trim().length === 0 ||
        url.length > 2000 ||
        !url.startsWith(storagePrefix)
      ) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "유효하지 않은 이미지 URL이 포함되어 있습니다."
        );
      }
      validImages.push(url.trim());
    }

    // clinics_accounts/{uid}에서 공고자 승인 상태 확인
    const clinicAccDoc = await db.collection("clinics_accounts").doc(uid).get();
    if (!clinicAccDoc.exists) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "공고자 계정이 아닙니다. 공고자 가입을 먼저 진행해주세요."
      );
    }
    const clinicAccData = clinicAccDoc.data() || {};
    if (clinicAccData.approvalStatus !== "approved" || clinicAccData.canPost !== true) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "공고 작성 권한이 없습니다. 사업자 인증 승인 후 공고를 작성할 수 있습니다."
      );
    }
    const clinicId = clinicAccData.clinicId || uid;

    const salaryStr = String(data.salary ?? "").trim();
    const sr = parseJobSalaryRange(salaryStr);
    const roleStr = String(data.role ?? "").trim();
    const careerStr = String(data.career ?? "").trim();
    const descStr = String(data.description ?? "").trim();

    // district 자동 생성: 주소에서 시/구/동 추출
    const addressStr = String(data.address ?? "").trim();
    let district = "";
    if (addressStr.length > 0) {
      const parts = addressStr.split(/\s+/);
      // 패턴: "서울시 강남구 역삼동 ..." → "역삼동 · 강남구"
      // 또는: "서울 강남구 역삼동 ..." → "역삼동 · 강남구"
      const guIdx = parts.findIndex((p) => p.endsWith("구") || p.endsWith("군"));
      const dongIdx = parts.findIndex(
        (p) => p.endsWith("동") || p.endsWith("읍") || p.endsWith("면") || p.endsWith("로") || p.endsWith("길")
      );
      const gu = guIdx >= 0 ? parts[guIdx] : "";
      const dong = dongIdx >= 0 && dongIdx > guIdx ? parts[dongIdx] : "";
      if (dong && gu) {
        district = `${dong} · ${gu}`;
      } else if (gu) {
        district = gu;
      } else if (parts.length >= 2) {
        district = parts.slice(0, 2).join(" ");
      }
    }

    // ── 신규 필드 검증 ────────────────────────────────────

    // 병원 정보
    const validHospitalTypes = ["clinic", "network", "hospital", "general"];
    const hospitalType = typeof data.hospitalType === "string" && validHospitalTypes.includes(data.hospitalType)
      ? data.hospitalType : null;
    const chairCount = typeof data.chairCount === "number" && data.chairCount > 0
      ? Math.floor(data.chairCount) : null;
    const staffCount = typeof data.staffCount === "number" && data.staffCount > 0
      ? Math.floor(data.staffCount) : null;

    // 근무 조건
    const validDays = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"];
    const korDayMap: Record<string, string> = {
      "월": "mon", "화": "tue", "수": "wed", "목": "thu",
      "금": "fri", "토": "sat", "일": "sun",
      "월요일": "mon", "화요일": "tue", "수요일": "wed", "목요일": "thu",
      "금요일": "fri", "토요일": "sat", "일요일": "sun",
    };
    const workDays: string[] = Array.isArray(data.workDays)
      ? data.workDays
        .map((d: unknown) => {
          if (typeof d !== "string") return null;
          const trimmed = (d as string).trim();
          return korDayMap[trimmed] ?? (validDays.includes(trimmed) ? trimmed : null);
        })
        .filter((d: string | null): d is string => d !== null)
      : [];
    const weekendWork = data.weekendWork === true;
    const nightShift = data.nightShift === true;

    // 지원 관련
    const validMethods = ["online", "phone", "email"];
    const applyMethod: string[] = Array.isArray(data.applyMethod)
      ? data.applyMethod.filter((m: unknown) => typeof m === "string" && validMethods.includes(m as string))
      : [];
    const isAlwaysHiring = data.isAlwaysHiring === true;

    // 마감일
    let closingDate: admin.firestore.Timestamp | null = null;
    if (!isAlwaysHiring && typeof data.closingDate === "string" && data.closingDate.trim()) {
      try {
        const d = new Date(data.closingDate.trim());
        if (!isNaN(d.getTime())) closingDate = admin.firestore.Timestamp.fromDate(d);
      } catch (_) { /* ignore */ }
    }

    // 교통편
    let transportation: Record<string, unknown> | null = null;
    if (data.transportation && typeof data.transportation === "object") {
      const t = data.transportation;
      transportation = {
        subwayLines: Array.isArray(t.subwayLines) ? t.subwayLines.filter((s: unknown) => typeof s === "string") : [],
        ...(typeof t.subwayStationName === "string" && t.subwayStationName.trim()
          ? { subwayStationName: t.subwayStationName.trim() } : {}),
        ...(typeof t.walkingDistanceMeters === "number" ? { walkingDistanceMeters: Math.floor(t.walkingDistanceMeters) } : {}),
        ...(typeof t.walkingMinutes === "number" ? { walkingMinutes: Math.floor(t.walkingMinutes) } : {}),
        ...(typeof t.exitNumber === "string" && t.exitNumber.trim() ? { exitNumber: t.exitNumber.trim() } : {}),
        parking: t.parking === true,
      };
    }
    const subwayLines: string[] = transportation
      ? (transportation.subwayLines as string[]) ?? []
      : [];
    const hasParking = transportation ? transportation.parking === true : false;
    const walkMin = transportation ? (transportation.walkingMinutes as number | undefined) : undefined;
    const stationName = transportation ? (transportation.subwayStationName as string | undefined) : undefined;
    const isNearStation = !!stationName && typeof walkMin === "number" && walkMin <= 10;

    // 태그
    const tags: string[] = Array.isArray(data.tags)
      ? data.tags.filter((t: unknown) => typeof t === "string" && (t as string).trim().length > 0).slice(0, 30)
      : [];

    // 좌표
    const lat = typeof data.lat === "number" && isFinite(data.lat) ? data.lat : null;
    const lng = typeof data.lng === "number" && isFinite(data.lng) ? data.lng : null;

    const jobData: Record<string, unknown> = {
      createdBy: uid,
      clinicId,
      clinicName: String(data.clinicName ?? "").trim(),
      title: String(data.title ?? "").trim(),
      role: roleStr,
      type: roleStr,
      career: careerStr || "미정",
      employmentType: String(data.employmentType ?? "").trim(),
      workHours: String(data.workHours ?? "").trim(),
      salary: salaryStr,
      salaryText: salaryStr,
      salaryMin: sr.min,
      salaryMax: sr.max,
      salaryRange: [sr.min, sr.max],
      benefits: Array.isArray(data.benefits) ? data.benefits : [],
      description: descStr,
      details: descStr,
      address: addressStr,
      district,
      contact: String(data.contact ?? "").trim(),
      images: validImages,
      ...(lat != null && lng != null ? { lat, lng } : {}),
      status: "pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      postedAt: admin.firestore.FieldValue.serverTimestamp(),
      // 병원 정보
      ...(hospitalType ? { hospitalType } : {}),
      ...(chairCount ? { chairCount } : {}),
      ...(staffCount ? { staffCount } : {}),
      // 근무 조건
      ...(workDays.length > 0 ? { workDays } : {}),
      weekendWork,
      nightShift,
      // 지원 관련
      ...(applyMethod.length > 0 ? { applyMethod } : {}),
      isAlwaysHiring,
      ...(closingDate ? { closingDate } : {}),
      // 교통편
      ...(transportation ? { transportation } : {}),
      ...(subwayLines.length > 0 ? { subwayLines } : {}),
      hasParking,
      isNearStation,
      // 태그
      ...(tags.length > 0 ? { tags } : {}),
    };

    // 클라이언트가 미리 생성한 jobId가 있으면 사용 (Storage 경로 일치)
    const providedJobId = typeof data.jobId === "string" && data.jobId.trim() ? data.jobId.trim() : null;
    let jobId: string;
    if (providedJobId) {
      await db.collection("jobs").doc(providedJobId).set(jobData);
      jobId = providedJobId;
    } else {
      const ref = await db.collection("jobs").add(jobData);
      jobId = ref.id;
    }

    functions.logger.info("createJobPosting", { uid, jobId });

    return { jobId, status: "pending" };
  }
);

/**
 * lookupNearbyStation
 *
 * 좌표(lat/lng) 또는 주소(address)를 받아 가장 가까운 지하철역을 자동 조회한다.
 * address만 보내면 Geocoding API로 좌표 변환 후 진행.
 * Google Geocoding API + Places API (Nearby Search) + Routes API (walking) 사용.
 *
 * Input:  { lat?: number, lng?: number, address?: string }
 * Output: { subwayStationName, subwayLines, walkingDistanceMeters, walkingMinutes, lat, lng } | { found: false }
 */
export const lookupNearbyStation = functions
  .runWith({ secrets: [GOOGLE_MAPS_API_KEY] })
  .https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "로그인이 필요합니다.");
    }

    const apiKey = GOOGLE_MAPS_API_KEY.value();
    if (!apiKey) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "서버에 Google Maps API 키가 설정되지 않았습니다."
      );
    }

    let lat = Number(data.lat);
    let lng = Number(data.lng);
    const address = typeof data.address === "string" ? data.address.trim() : "";

    functions.logger.info("lookupNearbyStation input", { lat, lng, address, hasLat: isFinite(lat), hasLng: isFinite(lng) });

    // 좌표가 없거나 유효하지 않으면 주소로 지오코딩
    if ((!isFinite(lat) || !isFinite(lng) || (lat === 0 && lng === 0)) && address.length > 0) {
      try {
        const geocodeUrl = `https://maps.googleapis.com/maps/api/geocode/json`;
        const geoRes = await axios.get(geocodeUrl, {
          params: { address, key: apiKey, language: "ko", region: "kr" },
        });
        const geoStatus = geoRes.data?.status ?? "UNKNOWN";
        const geoError = geoRes.data?.error_message ?? "";
        functions.logger.info("lookupNearbyStation geocoding response", {
          status: geoStatus, error: geoError, resultCount: geoRes.data?.results?.length ?? 0,
        });
        if (geoStatus !== "OK" && geoStatus !== "ZERO_RESULTS") {
          return { found: false, reason: "Geocoding API 오류: " + geoStatus + " " + geoError };
        }
        const geoResult = geoRes.data?.results?.[0];
        if (!geoResult) {
          return { found: false, reason: "주소를 찾을 수 없습니다 (" + geoStatus + ")" };
        }
        lat = geoResult.geometry.location.lat;
        lng = geoResult.geometry.location.lng;
        functions.logger.info("lookupNearbyStation geocoded", { lat, lng, formattedAddress: geoResult.formatted_address });
      } catch (e) {
        functions.logger.error("lookupNearbyStation geocoding error", e);
        throw new functions.https.HttpsError("internal", "주소 변환 중 오류가 발생했습니다.");
      }
    }

    if (!isFinite(lat) || !isFinite(lng) || (lat === 0 && lng === 0)) {
      throw new functions.https.HttpsError("invalid-argument", "유효한 좌표 또는 주소가 필요합니다.");
    }

    try {
      // 1) Places API (Nearby Search) - 반경 1000m 내 subway_station
      const SEARCH_RADIUS = 1000;
      const placesUrl = "https://places.googleapis.com/v1/places:searchNearby";
      const placesBody = {
        includedTypes: ["subway_station"],
        maxResultCount: 10,
        languageCode: "ko",
        regionCode: "KR",
        locationRestriction: {
          circle: {
            center: { latitude: lat, longitude: lng },
            radius: SEARCH_RADIUS,
          },
        },
      };
      let placesRes;
      try {
        placesRes = await axios.post(placesUrl, placesBody, {
          headers: {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": apiKey,
            "X-Goog-FieldMask": "places.displayName,places.location",
          },
        });
      } catch (placesErr: any) {
        const status = placesErr?.response?.status ?? "unknown";
        const msg = placesErr?.response?.data?.error?.message ?? placesErr?.message ?? "unknown";
        functions.logger.error("lookupNearbyStation Places API call failed", { status, msg, lat, lng });
        return { found: false, reason: `지하철역 검색 API 오류 (${status}): ${msg}` };
      }

      const places = placesRes.data?.places ?? [];
      functions.logger.info("lookupNearbyStation Places API response", {
        status: placesRes.status,
        placeCount: places.length,
        lat, lng, radius: SEARCH_RADIUS,
      });
      if (places.length === 0) {
        return { found: false, reason: `반경 ${SEARCH_RADIUS}m 내 지하철역을 찾지 못했습니다.` };
      }

      // 2) 역별 직선거리 + Routes 도보거리(없으면 직선거리로 표시)
      const routesUrl = "https://routes.googleapis.com/directions/v2:computeRoutes";
      const parseRouteDurationSec = (route: Record<string, unknown> | undefined): number => {
        if (!route) return 0;
        const dur = route.duration;
        if (typeof dur === "string") {
          return parseInt(dur.replace("s", ""), 10) || 0;
        }
        if (dur && typeof dur === "object" && dur !== null && "seconds" in dur) {
          const s = (dur as { seconds?: string }).seconds;
          return s ? parseInt(s, 10) || 0 : 0;
        }
        return 0;
      };
      type StationRow = {
        name: string;
        stationLat: number;
        stationLng: number;
        lines: string[];
        straightMeters: number;
        walkingDistanceMeters: number;
        walkingMinutes: number;
      };
      const stationResults: StationRow[] = [];

      for (const p of places) {
        let rawName: string = p.displayName?.text ?? "";
        rawName = rawName.replace(/\s*\d+호선/g, "").trim() || rawName;
        const sLat = p.location.latitude;
        const sLng = p.location.longitude;
        const straight = Math.round(haversineMeters(lat, lng, sLat, sLng));
        const lines = linesForStationDisplayName(rawName);
        let walkM = 0;
        let walkMin = 0;
        try {
          const routesRes = await axios.post(routesUrl, {
            origin: { location: { latLng: { latitude: lat, longitude: lng } } },
            destination: { location: { latLng: { latitude: sLat, longitude: sLng } } },
            travelMode: "WALK",
          }, {
            headers: {
              "Content-Type": "application/json",
              "X-Goog-Api-Key": apiKey,
              "X-Goog-FieldMask": "routes.distanceMeters,routes.duration",
            },
          });
          const route = routesRes.data?.routes?.[0] as Record<string, unknown> | undefined;
          walkM = (route?.distanceMeters as number) ?? 0;
          const durationSec = parseRouteDurationSec(route);
          walkMin = durationSec > 0 ? Math.max(1, Math.round(durationSec / 60)) : 0;
        } catch (routeErr) {
          functions.logger.warn("lookupNearbyStation route calc failed for " + rawName, routeErr);
        }
        if (walkM <= 0) {
          walkM = straight;
        }
        if (walkMin <= 0 && walkM > 0) {
          walkMin = Math.max(1, Math.round(walkM / 80));
        }
        stationResults.push({
          name: rawName,
          stationLat: sLat,
          stationLng: sLng,
          lines,
          straightMeters: straight,
          walkingDistanceMeters: walkM,
          walkingMinutes: walkMin,
        });
      }

      if (stationResults.length === 0) {
        return { found: false, reason: "역 도보 경로 계산에 실패했습니다." };
      }

      stationResults.sort((a, b) => a.straightMeters - b.straightMeters);
      const deduped: StationRow[] = [];
      const seenKeys = new Set<string>();
      for (const s of stationResults) {
        const key = `${s.stationLat.toFixed(4)},${s.stationLng.toFixed(4)}`;
        if (seenKeys.has(key)) continue;
        seenKeys.add(key);
        deduped.push(s);
      }
      deduped.sort((a, b) => a.walkingDistanceMeters - b.walkingDistanceMeters);

      const nearest = deduped[0];
      return {
        found: true,
        lat,
        lng,
        subwayStationName: nearest.name,
        subwayLines: nearest.lines,
        walkingDistanceMeters: nearest.walkingDistanceMeters,
        walkingMinutes: nearest.walkingMinutes,
        stations: deduped.map((s) => ({
          name: s.name,
          lines: s.lines,
          distanceMeters: s.walkingDistanceMeters,
          walkingMinutes: s.walkingMinutes,
        })),
      };
    } catch (e: unknown) {
      functions.logger.error("lookupNearbyStation error", e);
      throw new functions.https.HttpsError("internal", "교통편 조회 중 오류가 발생했습니다.");
    }
  }
);

/**
 * onJobDeleted
 *
 * 공고 문서 삭제 시 Storage에 연결된 이미지 파일도 함께 정리한다.
 */
export const onJobDeleted = functions.firestore
  .document("jobs/{jobId}")
  .onDelete(async (snap) => {
    const images: unknown[] = snap.data().images ?? [];
    const bucket = admin.storage().bucket();

    for (const url of images) {
      if (typeof url !== "string") continue;
      try {
        // Storage download URL → 파일 경로 추출
        // 형식: https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{encodedPath}?...
        const match = url.match(/\/o\/(.+?)(\?|$)/);
        if (!match) continue;
        const filePath = decodeURIComponent(match[1]);
        await bucket.file(filePath).delete();
      } catch (e) {
        functions.logger.warn("onJobDeleted: 이미지 삭제 실패", { url, error: e });
      }
    }
    functions.logger.info("onJobDeleted: 이미지 정리 완료", { jobId: snap.id, count: images.length });
  });

// ========== 치과 사업자 인증 ==========
/**
 * submitClinicVerification
 *
 * 사업자등록증 이미지 URL 또는 직접 입력 데이터를 받아:
 * 1) AI로 필드 추출 (현재 Mock → OpenAI 키 발급 후 실제 연동)
 * 2) 국세청 사업자 상태 조회 (현재 Mock → API 발급 후 실제 연동)
 * 3) 통과 시 users/{uid}.clinicVerified = true 업데이트
 * 4) clinicVerifications/{uid} 문서 생성
 *
 * Input (이미지 모드): { docUrl: string, uid?: string }
 * Input (직접제출 모드): { bizNo, clinicName, ownerName, openedAt, address, finalSubmit: true }
 * Output: { bizNo, clinicName, ownerName, openedAt, address, ntsValid, status, _mock? }
 */
export const submitClinicVerification = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "로그인이 필요합니다."
      );
    }

    const uid = context.auth.uid;

    // ── 직접 제출 모드 (finalSubmit: true) ──────────────
    if (data.finalSubmit === true) {
      const bizNo = String(data.bizNo ?? "").trim();
      const clinicName = String(data.clinicName ?? "").trim();

      if (!bizNo || !clinicName) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "사업자번호와 치과명은 필수입니다."
        );
      }

      // TODO: 실제 국세청 API 연동 (현재 Mock)
      const ntsResult = {
        valid: true,
        state: "ACTIVE",
        _mock: true,
        _message: "국세청 API 발급 후 실제 조회로 교체 예정",
      };

      // clinicVerifications 문서 저장
      await db.collection("clinicVerifications").doc(uid).set({
        status: ntsResult.valid ? "approved" : "rejected",
        bizNo,
        clinicName,
        ownerName: String(data.ownerName ?? "").trim(),
        openedAt: String(data.openedAt ?? "").trim(),
        address: String(data.address ?? "").trim(),
        nts: ntsResult,
        submittedAt: admin.firestore.FieldValue.serverTimestamp(),
        reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 승인 시 clinics + clinics_accounts 문서 업데이트
      if (ntsResult.valid) {
        const clinicId = uid;
        const clinicAddress = String(data.address ?? "").trim();

        // 1) clinics/{clinicId} 생성/갱신
        await db.collection("clinics").doc(clinicId).set(
          {
            name: clinicName,
            bizNo,
            address: clinicAddress,
            ownerUids: [uid],
            memberUids: [uid],
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        // 2) clinics_accounts/{uid} 승인 상태 업데이트
        await db.collection("clinics_accounts").doc(uid).set(
          {
            clinicId,
            clinicVerified: true,
            approvalStatus: "approved",
            canPost: true,
            clinic: { name: clinicName, bizNo },
            onboarding: { business: "done" },
            approvedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }

      functions.logger.info("submitClinicVerification finalSubmit", {
        uid,
        bizNo,
        ntsValid: ntsResult.valid,
      });

      return {
        status: ntsResult.valid ? "approved" : "rejected",
        ntsValid: ntsResult.valid,
        _mock: true,
      };
    }

    // ── 이미지 AI 추출 모드 ──────────────────────────────
    const docUrl = String(data.docUrl ?? "");
    if (!docUrl) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "사업자등록증 이미지 URL이 없습니다."
      );
    }

    // TODO: OpenAI Vision으로 실제 추출 (현재 Mock)
    functions.logger.info("submitClinicVerification AI extract (mock)", {
      uid,
      docUrl,
    });

    // clinicVerifications 문서에 pending 상태로 저장
    await db.collection("clinicVerifications").doc(uid).set(
      {
        status: "pending",
        docPath: docUrl,
        submittedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return {
      bizNo: "",
      clinicName: "",
      ownerName: "",
      openedAt: "",
      address: "",
      _mock: true,
      _message:
        "OpenAI 키 연동 전 Mock 모드입니다. 정보를 직접 입력해주세요.",
    };
  }
);

// ================================================================
// syncImwebPurchases (v5 - 취소/환불 제외)
// ================================================================
// 아임웹 구매내역을 Firestore users/{uid}/purchases/ 에 동기화한다.
//
// 전략:
//   A) imweb_orders 컬렉션 검색 (CSV 과거 주문 보관소)
//      - email + emailAliases 로 검색
//      - linkedUid == null 인 항목만 처리 (코드 필터)
//      - 취소사유·취소 상태 필드가 있으면 동기화하지 않음
//
//   B) 아임웹 API (최근 3개월, 신규 주문 감지)
//      - 주문/품목주문/라인의 status·claim_* 등으로 취소·환불·반품 건 제외
//      - 위 A에서 못 찾은 경우 보완
//
// 입력: { email: string }
// 출력: { synced: number, skipped: number, message: string }
// ================================================================

// 아임웹 응답에서 리스트 추출 헬퍼
function extractImwebList(body: Record<string, unknown>): Record<string, unknown>[] {
  const dataField = body?.data;
  if (Array.isArray(dataField)) return dataField as Record<string, unknown>[];
  if (dataField && typeof dataField === "object" && !Array.isArray(dataField)) {
    const list = (dataField as Record<string, unknown>)["list"];
    if (Array.isArray(list)) return list as Record<string, unknown>[];
  }
  return [];
}

// Rate Limit 방지: API 호출 간 딜레이 (1.5초)
function imwebDelay(ms = 1500): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** 아임웹 상태 문자열이 취소·환불·반품·클레임 완료 등인지 (한·영, 부분 문자열) */
function imwebStatusIndicatesCancelledOrRefunded(value: unknown): boolean {
  if (value === null || value === undefined) return false;
  const s = String(value).trim();
  if (!s) return false;
  const lower = s.toLowerCase();
  const asciiBad = [
    "cancel",
    "refund",
    "return",
    "exchange",
    "void",
    "reject",
    "fail",
  ];
  for (const w of asciiBad) {
    if (lower.includes(w)) return true;
  }
  const koBad = ["취소", "환불", "반품", "교환", "클레임", "부분취소", "부분환불"];
  for (const w of koBad) {
    if (s.includes(w)) return true;
  }
  return false;
}

/** 주문 목록 API 한 건이 통째로 취소/환불 등이면 동기화 대상에서 제외 */
function shouldExcludeImwebOrderSummary(order: Record<string, unknown>): boolean {
  if (imwebStatusIndicatesCancelledOrRefunded(order["order_status"])) return true;
  if (imwebStatusIndicatesCancelledOrRefunded(order["status"])) return true;
  if (imwebStatusIndicatesCancelledOrRefunded(order["payment_status"])) return true;
  if (imwebStatusIndicatesCancelledOrRefunded(order["order_section_status"])) return true;
  if (order["is_cancel"] === true || order["is_cancel"] === 1 || order["is_cancel"] === "Y") {
    return true;
  }
  const cancelTs =
    order["cancel_date"] ??
    order["canceled_at"] ??
    order["refund_finish_date"] ??
    order["cancel_finish_date"];
  if (cancelTs !== null && cancelTs !== undefined && cancelTs !== "" && cancelTs !== 0) {
    return true;
  }
  return false;
}

/** 품목 주문(prod-order) 단위가 취소/클레임이면 라인 전체 제외 */
function imwebProdOrderExcluded(po: Record<string, unknown>): boolean {
  for (const v of [
    po["status"],
    po["claim_status"],
    po["claim_type"],
    po["delivery_status"],
  ]) {
    if (imwebStatusIndicatesCancelledOrRefunded(v)) return true;
  }
  return false;
}

/** 주문 + 품목 라인: 취소/환불 등이면 전자책 동기화 제외 */
function shouldExcludeImwebLineAfterProdOk(
  order: Record<string, unknown>,
  item: Record<string, unknown>
): boolean {
  if (shouldExcludeImwebOrderSummary(order)) return true;
  for (const v of [
    item["status"],
    item["order_item_status"],
    item["claim_status"],
    item["claim_type"],
  ]) {
    if (imwebStatusIndicatesCancelledOrRefunded(v)) return true;
  }
  return false;
}

/** Firestore imweb_orders 문서가 취소/환불 건이면 동기화 제외 (CSV에 취소사유 등) */
function imwebOrderFirestoreDocIndicatesCancelled(data: Record<string, unknown>): boolean {
  const reason =
    data["cancelReason"] ?? data["cancel_reason"] ?? data["취소사유"];
  if (reason != null && String(reason).trim() !== "") return true;
  if (data["isCancelled"] === true || data["is_cancelled"] === true) return true;
  const st = data["orderStatus"] ?? data["order_status"];
  if (st != null && imwebStatusIndicatesCancelledOrRefunded(st)) return true;
  return false;
}

export const syncImwebPurchases = functions
  .region("us-central1")
  .runWith({ timeoutSeconds: 60, memory: "256MB" })
  .https.onCall(async (data, context) => {
    // ── 인증 확인 ───────────────────────────────────────────
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "로그인이 필요합니다."
      );
    }

    const uid = context.auth.uid;
    const email = (data.email as string | undefined)?.trim().toLowerCase();

    if (!email) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "이메일이 필요합니다."
      );
    }

    functions.logger.info("syncImwebPurchases 시작", { uid, email });

    // ── 이 사용자의 emailAliases 조회 ───────────────────────
    const userDoc = await db.collection("users").doc(uid).get();
    const userData = userDoc.data() ?? {};
    const emailAliases: string[] = Array.isArray(userData.emailAliases)
      ? (userData.emailAliases as string[])
      : [];
    const searchEmails = [email, ...emailAliases];

    functions.logger.info("검색 이메일 목록", { searchEmails });

    // ── ebooks 맵 사전 로드 ──────────────────────────────────
    const ebooksSnap = await db.collection("ebooks").get();
    const ebookMap = new Map<string, string>(); // imwebProductCode → docId
    for (const doc of ebooksSnap.docs) {
      const code = doc.data().imwebProductCode as string | undefined;
      if (code) ebookMap.set(code, doc.id);
    }

    // ── 기존 purchases 로드 ──────────────────────────────────
    const purchasesRef = db.collection("users").doc(uid).collection("purchases");
    const existingSnap = await purchasesRef.get();
    const existingIds = new Set(existingSnap.docs.map((d) => d.id));

    const writeBatch = db.batch();
    let synced = 0;
    let skipped = 0;

    // ──────────────────────────────────────────────────────────
    // A) imweb_orders 컬렉션에서 검색 (CSV 과거 주문 보관소)
    //    email in searchEmails 로 조회 → linkedUid == null 인 것만 처리
    // ──────────────────────────────────────────────────────────
    const processedProductCodes = new Set<string>(); // 이미 처리한 상품코드 추적

    // Firestore 'in' 쿼리는 최대 10개 → 분할 조회
    const chunkSize = 10;
    for (let i = 0; i < searchEmails.length; i += chunkSize) {
      const chunk = searchEmails.slice(i, i + chunkSize);
      const ordersSnap = await db
        .collection("imweb_orders")
        .where("email", "in", chunk)
        .get();

      for (const doc of ordersSnap.docs) {
        const orderData = doc.data();

        if (imwebOrderFirestoreDocIndicatesCancelled(orderData as Record<string, unknown>)) {
          functions.logger.info("imweb_orders: 취소/환불 건 스킵", { docId: doc.id });
          continue;
        }

        // linkedUid == null 인 것만 처리 (코드 레벨 필터)
        if (orderData.linkedUid !== null && orderData.linkedUid !== undefined) {
          // 이미 다른 uid 와 연결된 주문은 스킵
          if (orderData.linkedUid !== uid) {
            functions.logger.info("타 uid 연결 주문 스킵", {
              docId: doc.id,
              linkedUid: orderData.linkedUid,
            });
            continue;
          }
          // 이미 이 uid 와 연결됐으면 상품코드 처리는 하되 linkedUid 재설정 불필요
        }

        const productCode = String(orderData.productCode ?? "");
        if (!productCode || processedProductCodes.has(productCode)) continue;
        processedProductCodes.add(productCode);

        const ebookId = ebookMap.get(productCode);
        if (!ebookId) {
          functions.logger.info("imweb_orders: 미매핑 상품코드", { productCode });
          continue;
        }

        if (existingIds.has(ebookId)) {
          skipped++;
          // linkedUid 연결은 업데이트
          writeBatch.update(doc.ref, { linkedUid: uid });
          continue;
        }

        // purchases 생성
        writeBatch.set(
          purchasesRef.doc(ebookId),
          {
            ebookId,
            purchasedAt: orderData.purchasedAt ?? admin.firestore.FieldValue.serverTimestamp(),
            source: orderData.source ?? "imweb_orders",
            syncedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        // linkedUid 업데이트
        writeBatch.update(doc.ref, { linkedUid: uid });

        existingIds.add(ebookId);
        synced++;

        functions.logger.info("imweb_orders 매칭", {
          docId: doc.id,
          productCode,
          ebookId,
          orderEmail: orderData.email,
        });
      }
    }

    // ──────────────────────────────────────────────────────────
    // B) 아임웹 API — 최근 3개월 신규 주문 감지
    // ──────────────────────────────────────────────────────────
    try {
      const keysSnap = await db.collection("api_keys").doc("imweb_keys").get();
      if (keysSnap.exists) {
    const keysData = keysSnap.data()!;
    const imwebKey = keysData.key as string;
    const imwebSecret = keysData.secret_key as string;

    const authRes = await axios.get(
      `https://api.imweb.me/v2/auth?key=${imwebKey}&secret=${imwebSecret}`
    );
    const accessToken: string = authRes.data?.access_token;

        if (accessToken) {
    const headers = { "access-token": accessToken };
          const nowSec = Math.floor(Date.now() / 1000);
          const threeMonthsAgoSec = nowSec - (90 * 24 * 60 * 60);

          const myOrders: Record<string, unknown>[] = [];
          const seenOrderNos = new Set<string>();
    let page = 1;

          while (page <= 10) {
            const ordersUrl =
              `https://api.imweb.me/v2/shop/orders` +
              `?order_date_from=${threeMonthsAgoSec}` +
              `&order_date_to=${nowSec}` +
              `&order_version=v2` +
              `&page=${page}` +
              `&limit=100`;

            if (page > 1) await imwebDelay();

            const ordersRes = await axios.get(ordersUrl, { headers });
            const orderList = extractImwebList(ordersRes.data);

            if (orderList.length === 0) break;

      for (const order of orderList) {
              const orderNo = String(order["order_no"] ?? "");
              if (seenOrderNos.has(orderNo)) continue;

              const orderer = order["orderer"] as Record<string, unknown> | undefined;
              const ordererEmail = (orderer?.["email"] as string | undefined)
                ?.trim().toLowerCase();

              // searchEmails 중 하나와 매칭
              if (ordererEmail && searchEmails.includes(ordererEmail)) {
                const o = order as Record<string, unknown>;
                if (shouldExcludeImwebOrderSummary(o)) {
                  functions.logger.info("API: 주문 목록에서 제외(취소/환불)", {
                    orderNo,
                    order_status: o["order_status"],
                    status: o["status"],
                  });
                  continue;
                }
                myOrders.push(order);
                seenOrderNos.add(orderNo);
              }
            }

            if (orderList.length < 100) break;
      page++;
    }

          functions.logger.info("API 주문 매칭", {
            email, matchedOrders: myOrders.length,
    });

          for (const order of myOrders) {
            const orderNo = String(order["order_no"] ?? "");
            if (!orderNo) continue;

            await imwebDelay();

            const prodRes = await axios.get(
              `https://api.imweb.me/v2/shop/orders/${orderNo}/prod-orders`,
              { headers }
            );
            const prodOrderList = extractImwebList(prodRes.data);
            const orderRec = order as Record<string, unknown>;

            for (const prodOrder of prodOrderList) {
              const po = prodOrder as Record<string, unknown>;
              if (imwebProdOrderExcluded(po)) {
                functions.logger.info("API: prod-order 제외", {
                  orderNo,
                  status: po["status"],
                  claim_status: po["claim_status"],
                });
                continue;
              }
              const items = prodOrder["items"];
              if (!Array.isArray(items)) continue;

              for (const item of items) {
                const itemObj = item as Record<string, unknown>;
                if (shouldExcludeImwebLineAfterProdOk(orderRec, itemObj)) {
                  functions.logger.info("API: 품목 라인 제외", {
                    orderNo,
                    prodNo: itemObj["prod_no"],
                    status: itemObj["status"],
                  });
                  continue;
                }
                const prodNo = String(itemObj["prod_no"] ?? "");
                if (!prodNo || processedProductCodes.has(prodNo)) continue;
                processedProductCodes.add(prodNo);

                const ebookId = ebookMap.get(prodNo);
                if (!ebookId) {
                  functions.logger.info("API: 미매핑 상품코드", { prodNo });
                  continue;
                }
      if (existingIds.has(ebookId)) {
        skipped++;
        continue;
      }

                writeBatch.set(
        purchasesRef.doc(ebookId),
        {
          ebookId,
          purchasedAt: admin.firestore.FieldValue.serverTimestamp(),
                    source: "imweb",
          syncedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
                existingIds.add(ebookId);
      synced++;

                functions.logger.info("API 상품 발견", { orderNo, prodNo, ebookId });
              }
            }
          }
        }
      }
    } catch (apiErr) {
      // API 오류는 로그만 남기고 계속 진행 (imweb_orders 결과는 유지)
      functions.logger.warn("아임웹 API 조회 실패 (무시하고 계속)", { error: String(apiErr) });
    }

    // ── 배치 커밋 ────────────────────────────────────────────
    if (synced > 0 || skipped > 0) {
      await writeBatch.commit();
    }

    functions.logger.info("syncImwebPurchases 완료", { uid, synced, skipped });

    return {
      synced,
      skipped,
      message:
        synced > 0
          ? `${synced}권의 구매내역을 불러왔습니다.`
          : "이미 모두 동기화되어 있습니다.",
    };
  });

// ══════════════════════════════════════════════════════════════
// 퀴즈 풀 자동 스케줄러
//
// 배포 규칙:
//   1. 반드시 national_exam 1문제 + clinical 1문제 (quiz_pool.questionType 기준)
//   2. 임상 쪽은 가능하면 국시와 다른 sourceBook 우선
//   3. 임상만 2문제로 채우는 폴백 없음 — 한쪽 풀이 비면 스케줄 미생성
//   4. 현재 사이클 usedQuizIds 에 이미 나간 문항 제외
//   5. 2문제를 못 채우면 사이클 증가 후 1회 재시도, 그래도 불가면 중단
//
// Firestore 컬렉션:
//   quiz_pool/{autoId}          — 원본 문제 은행
//   quiz_schedule/{dateKey}     — 날짜별 배포 스냅샷 (items에 questionType 포함)
//   quiz_meta/state             — 진행 상태 + 타입별 활성/배포 수
// ══════════════════════════════════════════════════════════════

/** Fisher-Yates 셔플 */
function shuffleArray<T>(arr: T[]): T[] {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

/** 날짜 → 'YYYY-MM-DD' */
function toDateKey(date: Date): string {
  // Asia/Seoul(UTC+9) 기준 날짜 계산
  const kst = new Date(date.getTime() + 9 * 60 * 60 * 1000);
  const yyyy = kst.getUTCFullYear();
  const mm   = String(kst.getUTCMonth() + 1).padStart(2, "0");
  const dd   = String(kst.getUTCDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

/** 미설정 시 임상으로 간주 (기존 풀 호환) */
function quizQuestionType(data: FirebaseFirestore.DocumentData): "national_exam" | "clinical" {
  return data.questionType === "national_exam" ? "national_exam" : "clinical";
}

/** `config/quiz_content` — 임상·국시 풀 패킹 ID (공감투표와 무관) */
const QUIZ_CONTENT_CONFIG_PATH = "config/quiz_content";

interface QuizContentConfig {
  currentClinicalPackId: string;
  includeClinicalWithoutPack: boolean;
  currentNationalPackId: string;
  includeNationalWithoutPack: boolean;
}

async function loadQuizContentConfig(): Promise<QuizContentConfig> {
  const snap = await db.doc(QUIZ_CONTENT_CONFIG_PATH).get();
  const d = snap.exists ? snap.data()! : {};
  return {
    currentClinicalPackId: typeof d.currentClinicalPackId === "string"
      ? d.currentClinicalPackId.trim()
      : "",
    includeClinicalWithoutPack: d.includeClinicalWithoutPack === true,
    currentNationalPackId: typeof d.currentNationalPackId === "string"
      ? d.currentNationalPackId.trim()
      : "",
    includeNationalWithoutPack: d.includeNationalWithoutPack === true,
  };
}

/**
 * 임상 후보 필터
 * - currentClinicalPackId 비어 있음: 임상 전부 후보 (기존 동작)
 * - 비어 있지 않음: 해당 packId 이거나, packId 없음+includeClinicalWithoutPack
 */
function clinicalMatchesContentPack(
  data: FirebaseFirestore.DocumentData,
  cfg: QuizContentConfig,
): boolean {
  if (quizQuestionType(data) !== "clinical") return true;
  if (!cfg.currentClinicalPackId) return true;
  const pid = typeof data.packId === "string" ? data.packId.trim() : "";
  if (!pid) return cfg.includeClinicalWithoutPack;
  return pid === cfg.currentClinicalPackId;
}

/**
 * 국시 후보 필터 (임상과 동일 패턴)
 * - currentNationalPackId 비어 있음: 국시 전부 후보 (기존 동작)
 * - 비어 있지 않음: 해당 packId 이거나, packId 없음+includeNationalWithoutPack
 */
function nationalMatchesContentPack(
  data: FirebaseFirestore.DocumentData,
  cfg: QuizContentConfig,
): boolean {
  if (quizQuestionType(data) !== "national_exam") return true;
  if (!cfg.currentNationalPackId) return true;
  const pid = typeof data.packId === "string" ? data.packId.trim() : "";
  if (!pid) return cfg.includeNationalWithoutPack;
  return pid === cfg.currentNationalPackId;
}

function poolDocMatchesContentPacks(
  data: FirebaseFirestore.DocumentData,
  cfg: QuizContentConfig,
): boolean {
  return clinicalMatchesContentPack(data, cfg) && nationalMatchesContentPack(data, cfg);
}

/** 활성 quiz_pool 전체를 타입·packId 기준으로 집계 (운영 허브용, 읽기 전용 스냅샷) */
function computeQuizPoolPackBreakdown(
  poolSnap: FirebaseFirestore.QuerySnapshot,
): {
  activeTotal: number;
  nationalExam: {withoutPackId: number; byPack: {packId: string; count: number}[]};
  clinical: {withoutPackId: number; byPack: {packId: string; count: number}[]};
} {
  const natMap = new Map<string, number>();
  const clinMap = new Map<string, number>();
  let natLoose = 0;
  let clinLoose = 0;
  for (const doc of poolSnap.docs) {
    const d = doc.data();
    const t = quizQuestionType(d);
    const pid = typeof d.packId === "string" ? d.packId.trim() : "";
    if (t === "national_exam") {
      if (!pid) natLoose++;
      else natMap.set(pid, (natMap.get(pid) ?? 0) + 1);
    } else {
      if (!pid) clinLoose++;
      else clinMap.set(pid, (clinMap.get(pid) ?? 0) + 1);
    }
  }
  const toSorted = (m: Map<string, number>) =>
    [...m.entries()]
      .map(([packId, count]) => ({packId, count}))
      .sort((a, b) => b.count - a.count);
  return {
    activeTotal: poolSnap.size,
    nationalExam: {withoutPackId: natLoose, byPack: toSorted(natMap)},
    clinical: {withoutPackId: clinLoose, byPack: toSorted(clinMap)},
  };
}

/** 대시보드용: 스케줄 후보(패크 필터 적용) 기준 타입별 개수 + 이번 사이클 배포 수 */
function computeQuizMetaAnalytics(
  poolSnap: FirebaseFirestore.QuerySnapshot,
  usedQuizIds: string[],
  contentCfg: QuizContentConfig,
): {
  totalActiveCount: number;
  totalNationalActiveCount: number;
  totalClinicalActiveCount: number;
  usedNationalCount: number;
  usedClinicalCount: number;
} {
  const used = new Set(usedQuizIds);
  let totalNational = 0;
  let totalClinical = 0;
  let usedNational = 0;
  let usedClinical = 0;
  for (const doc of poolSnap.docs) {
    if (!poolDocMatchesContentPacks(doc.data(), contentCfg)) continue;
    const t = quizQuestionType(doc.data());
    if (t === "national_exam") {
      totalNational++;
      if (used.has(doc.id)) usedNational++;
    } else {
      totalClinical++;
      if (used.has(doc.id)) usedClinical++;
    }
  }
  return {
    totalActiveCount: totalNational + totalClinical,
    totalNationalActiveCount: totalNational,
    totalClinicalActiveCount: totalClinical,
    usedNationalCount: usedNational,
    usedClinicalCount: usedClinical,
  };
}

/** 스케줄 문서 items[] 원소 — 앱은 questionType 필드로 배지 표시 */
function buildScheduleItem(
  d: FirebaseFirestore.QueryDocumentSnapshot,
  nextCycleCount: number,
): Record<string, unknown> {
  const data = d.data();
  const packVersion = typeof data.packVersion === "number" && Number.isFinite(data.packVersion)
    ? data.packVersion
    : 0;
  return {
    id: d.id,
    order: data.order ?? 0,
    question: data.question ?? "",
    options: data.options ?? [],
    correctIndex: data.correctIndex ?? 0,
    explanation: data.explanation ?? "",
    category: data.category ?? "",
    difficulty: data.difficulty ?? "basic",
    sourceBook: data.sourceBook ?? "",
    sourceFileName: data.sourceFileName ?? "",
    sourcePage: data.sourcePage ?? "",
    sourceName: data.sourceName ?? "",
    isActive: true,
    lastCycleServed: nextCycleCount,
    questionType: quizQuestionType(data),
    packId: typeof data.packId === "string" ? data.packId : "",
    packVersion,
  };
}

/**
 * 오늘의 2문제 선정 — national_exam 1 + clinical 1 만 허용 (임상 2개 폴백 없음)
 */
async function pickTodayQuizzes(
  meta: FirebaseFirestore.DocumentData,
  contentCfg: QuizContentConfig,
): Promise<{
  selectedDocs: FirebaseFirestore.QueryDocumentSnapshot[];
  nextCycleCount: number;
  nextUsedQuizIds: string[];
  wasReset: boolean;
}> {
  const usedQuizIds: string[] = meta.usedQuizIds ?? [];
  const cycleCount = meta.cycleCount ?? 1;

  const poolSnap = await db
    .collection("quiz_pool")
    .where("isActive", "==", true)
    .get();

  const allDocs = poolSnap.docs.filter((d) => poolDocMatchesContentPacks(d.data(), contentCfg));

  const trySelect = (used: string[]): {
    selected: FirebaseFirestore.QueryDocumentSnapshot[];
    ok: boolean;
  } => {
    const national = shuffleArray(
      allDocs.filter(
        (d) =>
          quizQuestionType(d.data()) === "national_exam" &&
          !used.includes(d.id),
      ),
    );
    const clinical = shuffleArray(
      allDocs.filter(
        (d) =>
          quizQuestionType(d.data()) === "clinical" &&
          !used.includes(d.id),
      ),
    );

    if (national.length >= 1 && clinical.length >= 1) {
      const n = national[0];
      const nBook = (n.data().sourceBook as string) || "";
      const clinDiff = clinical.filter(
        (d) => ((d.data().sourceBook as string) || "") !== nBook,
      );
      const pool = clinDiff.length ? clinDiff : clinical;
      const c = pool[0];
      return {selected: [n, c], ok: true};
    }

    return {selected: [], ok: false};
  };

  let wasReset = false;
  let nextCycle = cycleCount;
  let nextUsed = [...usedQuizIds];

  let {selected, ok} = trySelect(nextUsed);

  if (!ok || selected.length < 2) {
    functions.logger.info("🔄 국시+임상 1+1 선정 불가 → 사이클 증가 및 usedQuizIds 초기화 후 재시도", {
      cycleCount: cycleCount + 1,
    });
    wasReset = true;
    nextCycle = cycleCount + 1;
    nextUsed = [];
    ({selected, ok} = trySelect(nextUsed));
  }

  if (!ok || selected.length < 2) {
    return {
      selectedDocs: selected,
      nextCycleCount: nextCycle,
      nextUsedQuizIds: nextUsed,
      wasReset,
    };
  }

  nextUsed = [...new Set([...nextUsed, ...selected.map((d) => d.id)])];

  return {
    selectedDocs: selected,
    nextCycleCount: nextCycle,
    nextUsedQuizIds: nextUsed,
    wasReset,
  };
}

export const scheduleQuizzes = functions
  .region("us-central1")
  .pubsub.schedule("0 0 * * *")   // 매일 자정 00:00 (Asia/Seoul 기준)
  .timeZone("Asia/Seoul")
  .onRun(async () => {
    functions.logger.info("🗓️ scheduleQuizzes: 실행 시작");

    const dateKey     = toDateKey(new Date());
    const scheduleRef = db.collection("quiz_schedule").doc(dateKey);
    const metaRef     = db.doc("quiz_meta/state");
    const contentCfg  = await loadQuizContentConfig();

    // ── 이미 생성됐으면 선정은 스킵하되, meta는 스케줄과 맞춤(usedQuizIds 누락 방지) ──
    const scheduleSnapEarly = await scheduleRef.get();
    if (scheduleSnapEarly.exists) {
      const schedData = scheduleSnapEarly.data()!;
      const todayQuizIds: string[] = Array.isArray(schedData.quizIds)
        ? (schedData.quizIds as string[])
        : [];
      const scheduleCycle = typeof schedData.cycleCount === "number"
        ? schedData.cycleCount
        : 1;

      const metaDocEarly = await metaRef.get();
      const metaEarly = metaDocEarly.exists ? metaDocEarly.data()! : {};
      const prevUsed: string[] = Array.isArray(metaEarly.usedQuizIds)
        ? (metaEarly.usedQuizIds as string[])
        : [];
      const mergedUsed = [...new Set([...prevUsed, ...todayQuizIds])];

      const poolSnapEarly = await db.collection("quiz_pool").where("isActive", "==", true).get();
      const analyticsEarly = computeQuizMetaAnalytics(poolSnapEarly, mergedUsed, contentCfg);
      await metaRef.set({
        ...analyticsEarly,
        lastScheduledDate: dateKey,
        usedQuizIds: mergedUsed,
        cycleCount: scheduleCycle,
      }, { merge: true });
      functions.logger.info("⏭️ 이미 스케줄 생성됨 — quiz_meta 동기화(usedQuizIds 병합)", {
        dateKey,
        totalActive: analyticsEarly.totalActiveCount,
        todayIds: todayQuizIds.length,
        mergedCount: mergedUsed.length,
        scheduleCycle,
      });
      return null;
    }

    // ── meta 조회 ──
    const metaDoc  = await metaRef.get();
    const meta     = metaDoc.exists ? metaDoc.data()! : {};
    const dailyCount: number = meta.dailyCount ?? 2;

    // ── 오늘의 문제 선정 ──
    const { selectedDocs, nextCycleCount, nextUsedQuizIds, wasReset } =
      await pickTodayQuizzes(meta, contentCfg);

    if (selectedDocs.length !== 2) {
      functions.logger.warn(
        "⚠️ 국시+임상 1+1 선정 실패 — 스케줄 미생성. 활성 풀·questionType·패크·usedQuizIds 확인",
        { count: selectedDocs.length, dateKey },
      );
      return null;
    }
    const t0 = quizQuestionType(selectedDocs[0].data());
    const t1 = quizQuestionType(selectedDocs[1].data());
    if (t0 === t1) {
      functions.logger.error("⚠️ 선정 결과 타입 중복 — 스케줄 미생성", { t0, t1, dateKey });
      return null;
    }

    const quizIds = selectedDocs.map((d) => d.id);
    const items = selectedDocs.map((d) => buildScheduleItem(d, nextCycleCount));

    // ── quiz_schedule/{dateKey} 저장 ──
    await scheduleRef.set({
      quizIds,
      items,
      cycleCount: nextCycleCount,
      startOrder: selectedDocs[0].data().order ?? 0,
      endOrder: selectedDocs[selectedDocs.length - 1].data().order ?? 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // ── quiz_pool lastCycleServed 업데이트 ──
    const batch = db.batch();
    for (const doc of selectedDocs) {
      batch.update(doc.ref, {
        lastCycleServed: nextCycleCount,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    // ── quiz_meta/state 업데이트 ──
    const poolSnap = await db.collection("quiz_pool").where("isActive", "==", true).get();
    const analytics = computeQuizMetaAnalytics(poolSnap, nextUsedQuizIds, contentCfg);

    await metaRef.set({
      cycleCount: nextCycleCount,
      lastScheduledDate: dateKey,
      dailyCount,
      usedQuizIds: nextUsedQuizIds,
      ...analytics,
    }, { merge: true });

    functions.logger.info("✅ scheduleQuizzes 완료", {
      dateKey,
      quizIds,
      books: selectedDocs.map((d) => d.data().sourceBook),
      questionTypes: selectedDocs.map((d) => quizQuestionType(d.data())),
      wasReset,
      cycleCount: nextCycleCount,
      usedCount: nextUsedQuizIds.length,
      clinicalPackId: contentCfg.currentClinicalPackId || "(전체 임상)",
      nationalPackId: contentCfg.currentNationalPackId || "(전체 국시)",
      ...analytics,
    });

    return null;
  });

// ── 수동 트리거 버전 (테스트/보충용) ──
// Admin이 특정 날짜의 스케줄을 수동으로 생성하거나 재생성할 때 사용
export const manualScheduleQuiz = functions
  .region("us-central1")
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "로그인 필요");
    }
    const callerDoc = await db.collection("users").doc(context.auth.uid).get();
    if (callerDoc.data()?.isAdmin !== true) {
      throw new functions.https.HttpsError("permission-denied", "어드민 권한 필요");
    }

    const { targetDate, forceReplace } = data as {
      targetDate?: string;
      forceReplace?: boolean;
    };

    const dateKey     = targetDate ?? toDateKey(new Date());
    const scheduleRef = db.collection("quiz_schedule").doc(dateKey);
    const metaRef     = db.doc("quiz_meta/state");

    if (!forceReplace) {
      const existing = await scheduleRef.get();
      if (existing.exists) {
        return {
          success: false,
          message: `${dateKey} 스케줄이 이미 존재합니다. forceReplace: true로 재요청하세요.`,
        };
      }
    }

    const metaDoc  = await metaRef.get();
    const meta     = metaDoc.exists ? metaDoc.data()! : {};
    const dailyCount: number = meta.dailyCount ?? 2;
    const contentCfg = await loadQuizContentConfig();

    const { selectedDocs, nextCycleCount, nextUsedQuizIds, wasReset } =
      await pickTodayQuizzes(meta, contentCfg);

    if (selectedDocs.length !== 2) {
      return {
        success: false,
        message:
          "국시·임상 각 1문항씩 선정할 수 없습니다. 활성 풀에 questionType(national_exam/clinical)과 " +
          "미사용 문항이 충분한지, config/quiz_content 패크 필터를 확인하세요.",
      };
    }
    const t0 = quizQuestionType(selectedDocs[0].data());
    const t1 = quizQuestionType(selectedDocs[1].data());
    if (t0 === t1) {
      return {
        success: false,
        message: `선정 결과가 국시+임상 1+1이 아닙니다(동일 타입: ${t0}). quiz_pool을 확인하세요.`,
      };
    }

    const quizIds = selectedDocs.map((d) => d.id);
    const items = selectedDocs.map((d) => buildScheduleItem(d, nextCycleCount));

    await scheduleRef.set({
      quizIds,
      items,
      cycleCount: nextCycleCount,
      startOrder: selectedDocs[0].data().order ?? 0,
      endOrder: selectedDocs[selectedDocs.length - 1].data().order ?? 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const batch = db.batch();
    for (const doc of selectedDocs) {
      batch.update(doc.ref, {
        lastCycleServed: nextCycleCount,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    const poolSnap = await db.collection("quiz_pool").where("isActive", "==", true).get();
    const analytics = computeQuizMetaAnalytics(poolSnap, nextUsedQuizIds, contentCfg);

    await metaRef.set({
      cycleCount: nextCycleCount,
      lastScheduledDate: dateKey,
      dailyCount,
      usedQuizIds: nextUsedQuizIds,
      ...analytics,
    }, { merge: true });

    return {
      success: true,
      dateKey,
      quizIds,
      books: selectedDocs.map((d) => d.data().sourceBook),
      questionTypes: selectedDocs.map((d) => quizQuestionType(d.data())),
      wasReset,
      message: `${dateKey} 스케줄 생성 완료 (${quizIds.length}문제, ${wasReset ? "사이클 초기화" : "정상"})`,
    };
  });

function scheduleItemQuestionType(it: Record<string, unknown>): "national_exam" | "clinical" {
  return it.questionType === "national_exam" ? "national_exam" : "clinical";
}

function orderBoundsFromItems(items: Record<string, unknown>[]): { startOrder: number; endOrder: number } {
  if (items.length === 0) return { startOrder: 0, endOrder: 0 };
  const orders = items.map((it) =>
    typeof it.order === "number" && Number.isFinite(it.order) ? it.order : 0,
  );
  return { startOrder: Math.min(...orders), endOrder: Math.max(...orders) };
}

function findFirstScheduleSlotIndex(
  items: Record<string, unknown>[],
  slotType: "national_exam" | "clinical",
): number {
  return items.findIndex((it) => scheduleItemQuestionType(it) === slotType);
}

/** 스케줄 슬롯 1개 교체용: 패크 필터·타입·excludeIds·(가능하면) 다른 책 우선 */
async function pickSingleScheduleReplacement(
  slotType: "national_exam" | "clinical",
  excludeIds: string[],
  preferDifferentBookThan: string,
  contentCfg: QuizContentConfig,
): Promise<FirebaseFirestore.QueryDocumentSnapshot | null> {
  const poolSnap = await db.collection("quiz_pool").where("isActive", "==", true).get();
  const allDocs = poolSnap.docs.filter((d) => poolDocMatchesContentPacks(d.data(), contentCfg));
  let candidates = allDocs.filter(
    (d) => quizQuestionType(d.data()) === slotType && !excludeIds.includes(d.id),
  );
  const otherBook = (preferDifferentBookThan || "").trim();
  if (otherBook) {
    const diffBook = candidates.filter(
      (d) => ((d.data().sourceBook as string) || "") !== otherBook,
    );
    if (diffBook.length) candidates = diffBook;
  }
  const shuffled = shuffleArray(candidates);
  return shuffled[0] ?? null;
}

/** getContentOpsHub: 오늘 스케줄 기준 교체 후보 1문항씩(읽기 전용, 스케줄 미변경) */
async function computeTodaySlotNextPreviewsForHub(
  schedData: FirebaseFirestore.DocumentData,
  contentCfg: QuizContentConfig,
): Promise<{
  national: Record<string, unknown> | null;
  clinical: Record<string, unknown> | null;
}> {
  const rawItems = schedData.items;
  if (!Array.isArray(rawItems)) {
    return { national: null, clinical: null };
  }
  const items: Record<string, unknown>[] = rawItems.map((it) => {
    if (typeof it === "object" && it !== null && !Array.isArray(it)) {
      return { ...(it as Record<string, unknown>) };
    }
    return {};
  });
  const excludeIds = items.map((it) => String(it.id ?? "")).filter((id) => id.length > 0);
  const natItem = items.find((it) => scheduleItemQuestionType(it) === "national_exam");
  const clinItem = items.find((it) => scheduleItemQuestionType(it) === "clinical");
  const clinBook = clinItem ? String(clinItem.sourceBook ?? "") : "";
  const natBook = natItem ? String(natItem.sourceBook ?? "") : "";

  const [natDoc, clinDoc] = await Promise.all([
    pickSingleScheduleReplacement("national_exam", excludeIds, clinBook, contentCfg),
    pickSingleScheduleReplacement("clinical", excludeIds, natBook, contentCfg),
  ]);

  const toPreview = (
    d: FirebaseFirestore.QueryDocumentSnapshot | null,
    qt: string,
  ): Record<string, unknown> | null => {
    if (!d) return null;
    const data = d.data();
    const q = String(data.question ?? "");
    return {
      id: d.id,
      questionType: qt,
      questionPreview: q.length > 220 ? `${q.slice(0, 220)}…` : q,
      sourceBook: String(data.sourceBook ?? ""),
      sourceFileName: String(data.sourceFileName ?? ""),
      packId: typeof data.packId === "string" ? data.packId : "",
    };
  };

  return {
    national: toPreview(natDoc, "national_exam"),
    clinical: toPreview(clinDoc, "clinical"),
  };
}

/**
 * 어드민: 특정 날짜 quiz_schedule 에서 국시/임상 "첫 슬롯"만 제거 또는 교체.
 * remove: quiz_pool 원본 삭제 + 같은 타입 다음 문항으로 교체 (후보 없으면 슬롯 비움)
 * replace: quiz_pool 원본 유지 + 다른 문항으로 교체
 * quiz_meta · 사용자 기록은 수정하지 않음.
 */
export const adminMutateQuizScheduleSlot = functions
  .region("us-central1")
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "로그인 필요");
    }
    const callerDoc = await db.collection("users").doc(context.auth.uid).get();
    if (callerDoc.data()?.isAdmin !== true) {
      throw new functions.https.HttpsError("permission-denied", "어드민 권한 필요");
    }

    const { dateKey: rawDate, action, slotType } = data as {
      dateKey?: string;
      action?: string;
      slotType?: string;
    };

    if (action !== "remove" && action !== "replace") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "action은 remove 또는 replace 여야 합니다.",
      );
    }
    if (slotType !== "national_exam" && slotType !== "clinical") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "slotType은 national_exam 또는 clinical 이어야 합니다.",
      );
    }

    const dateKey = (rawDate && String(rawDate).trim()) || toDateKey(new Date());
    const scheduleRef = db.collection("quiz_schedule").doc(dateKey);
    const snap = await scheduleRef.get();
    if (!snap.exists) {
      return { success: false, message: `${dateKey} 스케줄이 없습니다.` };
    }

    const sched = snap.data()!;
    const rawItems = sched.items;
    if (!Array.isArray(rawItems)) {
      return { success: false, message: "스케줄 items 형식이 올바르지 않습니다." };
    }

    const items: Record<string, unknown>[] = rawItems.map((it) => {
      if (typeof it === "object" && it !== null && !Array.isArray(it)) {
        return { ...(it as Record<string, unknown>) };
      }
      return {};
    });

    const st = slotType as "national_exam" | "clinical";
    const idx = findFirstScheduleSlotIndex(items, st);
    if (idx < 0) {
      return { success: false, message: `${slotType} 슬롯을 찾을 수 없습니다.` };
    }

    const cycleCount = typeof sched.cycleCount === "number" && Number.isFinite(sched.cycleCount)
      ? sched.cycleCount
      : 1;
    const contentCfg = await loadQuizContentConfig();

    if (action === "remove") {
      const removedItem = items[idx];
      const removedPoolId = typeof removedItem.id === "string" ? removedItem.id : "";

      items.splice(idx, 1);
      const excludeIds = items
        .map((it) => String(it.id ?? ""))
        .filter((id) => id.length > 0);
      if (removedPoolId) excludeIds.push(removedPoolId);

      let preferBook = "";
      for (const it of items) {
        if (scheduleItemQuestionType(it) !== st) {
          preferBook = String(it.sourceBook ?? "");
          break;
        }
      }

      const newDoc = await pickSingleScheduleReplacement(st, excludeIds, preferBook, contentCfg);
      if (newDoc) {
        const built = buildScheduleItem(newDoc, cycleCount);
        items.splice(idx, 0, built);
      }

      const quizIds = items.map((it) => String(it.id ?? "")).filter((id) => id.length > 0);
      const bounds = orderBoundsFromItems(items);
      await scheduleRef.update({
        items,
        quizIds,
        startOrder: bounds.startOrder,
        endOrder: bounds.endOrder,
      });

      // quiz_pool 원본 삭제
      if (removedPoolId) {
        await db.collection("quiz_pool").doc(removedPoolId).delete();
      }

      return {
        success: true,
        dateKey,
        action: "remove",
        slotType,
        quizIds,
        deletedPoolId: removedPoolId || null,
        newQuizId: newDoc ? newDoc.id : null,
        message: newDoc
          ? `문항 ${removedPoolId} 를 풀에서 삭제하고, 다음 문항 ${newDoc.id} 로 교체했습니다.`
          : `문항 ${removedPoolId} 를 풀에서 삭제했습니다. 교체할 후보가 없어 슬롯은 비어 있습니다.`,
      };
    }

    const [removed] = items.splice(idx, 1);
    const excludeIds = items
      .map((it) => String(it.id ?? ""))
      .filter((id) => id.length > 0);

    let preferBook = "";
    for (const it of items) {
      if (scheduleItemQuestionType(it) !== st) {
        preferBook = String(it.sourceBook ?? "");
        break;
      }
    }

    const newDoc = await pickSingleScheduleReplacement(st, excludeIds, preferBook, contentCfg);
    if (!newDoc) {
      items.splice(idx, 0, removed);
      return {
        success: false,
        message:
          "교체할 문항이 없습니다. 활성 풀·콘텐츠 패크·이미 스케줄에 있는 ID 제외 조건을 확인하세요.",
      };
    }

    const built = buildScheduleItem(newDoc, cycleCount);
    items.splice(idx, 0, built);
    const quizIds = items.map((it) => String(it.id ?? "")).filter((id) => id.length > 0);
    const bounds = orderBoundsFromItems(items);

    await scheduleRef.update({
      items,
      quizIds,
      startOrder: bounds.startOrder,
      endOrder: bounds.endOrder,
    });

    return {
      success: true,
      dateKey,
      action: "replace",
      slotType,
      quizIds,
      newQuizId: newDoc.id,
      message: "해당 슬롯을 다른 문항으로 교체했습니다.",
    };
  });

/**
 * 다음 일일 스케줄에 들어갈 문항 선정 시뮬 (읽기 전용)
 *
 * - `pickTodayQuizzes` 와 동일 알고리즘·셔플을 사용하나 Firestore 에 기록하지 않음
 * - 셔플 때문에 호출마다 결과가 달라질 수 있음 (실제 자정 배치와도 다를 수 있음)
 */
export const previewNextQuizSelection = functions
  .region("us-central1")
  .https.onCall(async (_data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "로그인 필요");
    }
    const callerDoc = await db.collection("users").doc(context.auth.uid).get();
    if (callerDoc.data()?.isAdmin !== true) {
      throw new functions.https.HttpsError("permission-denied", "어드민 권한 필요");
    }

    const metaRef = db.doc("quiz_meta/state");
    const metaDoc = await metaRef.get();
    const meta = metaDoc.exists ? metaDoc.data()! : {};
    const contentCfg = await loadQuizContentConfig();

    const {selectedDocs, nextCycleCount, nextUsedQuizIds, wasReset} =
      await pickTodayQuizzes(meta, contentCfg);

    const trimPreview = (q: unknown, max: number): string => {
      const s = typeof q === "string" ? q.trim() : "";
      if (s.length <= max) return s;
      return `${s.slice(0, max)}…`;
    };

    if (selectedDocs.length !== 2) {
      return {
        success: false,
        readOnly: true,
        message:
          "국시+임상 1+1을 구성할 수 없습니다. 활성 풀·questionType·미사용(usedQuizIds)·패크 설정을 확인하세요.",
      };
    }

    const items = selectedDocs.map((d) => {
      const row = d.data();
      return {
        id: d.id,
        questionType: quizQuestionType(row),
        questionPreview: trimPreview(row.question, 140),
        sourceBook: (row.sourceBook as string) || "",
        packId: typeof row.packId === "string" ? row.packId : "",
        sourceFileName: typeof row.sourceFileName === "string" ? row.sourceFileName : "",
      };
    });

    return {
      success: true,
      readOnly: true,
      disclaimer:
        "자정 스케줄러와 같은 선정 로직이지만 셔플이 들어가 호출할 때마다 결과가 달라질 수 있습니다. 스케줄·메타·풀 문서는 변경하지 않습니다.",
      wasReset,
      cycleCountUsed: nextCycleCount,
      hypotheticalUsedQuizIdsCount: nextUsedQuizIds.length,
      contentConfig: contentCfg,
      items,
    };
  });

/**
 * quiz_meta/state 의 usedQuizIds·lastScheduledDate 를
 * 현재 사이클의 quiz_schedule 문서들과 다시 맞춤 (대시보드 불일치 보정).
 */
export const rebuildQuizMetaFromSchedules = functions
  .region("us-central1")
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "로그인 필요");
    }
    const callerDoc = await db.collection("users").doc(context.auth.uid).get();
    if (callerDoc.data()?.isAdmin !== true) {
      throw new functions.https.HttpsError("permission-denied", "어드민 권한 필요");
    }

    const metaRef = db.doc("quiz_meta/state");
    const metaDoc = await metaRef.get();
    const meta = metaDoc.exists ? metaDoc.data()! : {};
    const cycleCount: number = (meta.cycleCount as number) ?? 1;

    const schedSnap = await db.collection("quiz_schedule").get();
    const idSet = new Set<string>();
    let maxDateKey = "";

    for (const doc of schedSnap.docs) {
      const d = doc.data();
      const c = (d.cycleCount as number) ?? 1;
      if (c !== cycleCount) continue;

      const ids = (d.quizIds as string[]) || [];
      ids.forEach((id) => {
        if (typeof id === "string" && id.length) idSet.add(id);
      });

      const key = doc.id;
      if (/^\d{4}-\d{2}-\d{2}$/.test(key) && key > maxDateKey) {
        maxDateKey = key;
      }
    }

    const usedQuizIds = Array.from(idSet);
    const contentCfg = await loadQuizContentConfig();
    const poolSnap = await db.collection("quiz_pool").where("isActive", "==", true).get();
    const analytics = computeQuizMetaAnalytics(poolSnap, usedQuizIds, contentCfg);

    await metaRef.set({
      usedQuizIds,
      lastScheduledDate: maxDateKey || (meta.lastScheduledDate as string) || "",
      ...analytics,
    }, { merge: true });

    return {
      success: true,
      cycleCount,
      usedCount: usedQuizIds.length,
      lastScheduledDate: maxDateKey || (meta.lastScheduledDate as string) || "",
      ...analytics,
      message: `사이클 ${cycleCount}: 스케줄에서 고유 문항 ${usedQuizIds.length}개로 동기화`,
    };
  });

/**
 * 콘텐츠 운영 허브용 읽기 전용 스냅샷 (어드민)
 * - polls: displayOrder 오름차순
 * - quiz: config/quiz_content + quiz_meta/state + 최근 N일 quiz_schedule 요약
 */
export const getContentOpsHub = functions
  .region("us-central1")
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "로그인 필요");
    }
    const callerDoc = await db.collection("users").doc(context.auth.uid).get();
    if (callerDoc.data()?.isAdmin !== true) {
      throw new functions.https.HttpsError("permission-denied", "어드민 권한 필요");
    }

    const raw = data as { schedulePreviewDays?: number } | undefined;
    const n = raw?.schedulePreviewDays;
    const schedulePreviewDays =
      typeof n === "number" && Number.isFinite(n) && n > 0 && n <= 60 ?
        Math.floor(n) :
        14;

    const contentCfg = await loadQuizContentConfig();

    const metaSnap = await db.doc("quiz_meta/state").get();
    const meta = metaSnap.exists ? metaSnap.data()! : {};
    const usedQuizIds: string[] = Array.isArray(meta.usedQuizIds) ?
      (meta.usedQuizIds as string[]) :
      [];

    const metaSummary = {
      cycleCount: (meta.cycleCount as number) ?? 1,
      lastScheduledDate: (meta.lastScheduledDate as string) ?? "",
      dailyCount: (meta.dailyCount as number) ?? 2,
      usedQuizIdsCount: usedQuizIds.length,
      usedQuizIdsSample: usedQuizIds.slice(0, 40),
      totalActiveCount: (meta.totalActiveCount as number) ?? 0,
      totalNationalActiveCount: (meta.totalNationalActiveCount as number) ?? 0,
      totalClinicalActiveCount: (meta.totalClinicalActiveCount as number) ?? 0,
      usedNationalCount: (meta.usedNationalCount as number) ?? 0,
      usedClinicalCount: (meta.usedClinicalCount as number) ?? 0,
    };

    const pollsSnap = await db.collection("polls").get();
    const pollRows = pollsSnap.docs.map((doc) => {
      const d = doc.data();
      let displayOrder: number;
      if (typeof d.displayOrder === "number" && Number.isFinite(d.displayOrder)) {
        displayOrder = d.displayOrder;
      } else if (typeof d.dayIndex === "number" && Number.isFinite(d.dayIndex)) {
        displayOrder = d.dayIndex;
      } else {
        const m = /^empathy_(\d+)$/.exec(doc.id);
        displayOrder = m ? parseInt(m[1], 10) : 1_000_000;
      }
      const ts = (v: unknown): string | null => {
        if (v && typeof (v as admin.firestore.Timestamp).toDate === "function") {
          return (v as admin.firestore.Timestamp).toDate().toISOString();
        }
        return null;
      };
      return {
        id: doc.id,
        displayOrder,
        question: (d.question as string) ?? "",
        status: (d.status as string) ?? "",
        category: (d.category as string) ?? "",
        startsAt: ts(d.startsAt),
        endsAt: ts(d.endsAt),
        closedAt: ts(d.closedAt),
        dayIndex: d.dayIndex ?? null,
        totalEmpathyCount: typeof d.totalEmpathyCount === "number" ? d.totalEmpathyCount : 0,
      };
    });
    pollRows.sort((a, b) => {
      if (a.displayOrder !== b.displayOrder) return a.displayOrder - b.displayOrder;
      return a.id.localeCompare(b.id);
    });

    const nowMs = Date.now();
    const notYetStarted = pollRows.filter((p) => {
      if (!p.startsAt) return false;
      const t = Date.parse(p.startsAt);
      return !Number.isNaN(t) && t > nowMs;
    });
    notYetStarted.sort((a, b) => {
      if (a.displayOrder !== b.displayOrder) return a.displayOrder - b.displayOrder;
      return a.id.localeCompare(b.id);
    });
    const pollNextPreview = notYetStarted[0] ?? null;

    const poolSnapHub = await db.collection("quiz_pool").where("isActive", "==", true).get();
    const quizPoolPackBreakdown = computeQuizPoolPackBreakdown(poolSnapHub);

    const scheduleKeys: string[] = [];
    for (let i = 0; i < schedulePreviewDays; i++) {
      scheduleKeys.push(toDateKey(new Date(Date.now() - i * 86400000)));
    }

    const schedSnaps = await Promise.all(
      scheduleKeys.map((k) => db.collection("quiz_schedule").doc(k).get()),
    );

    const schedules = schedSnaps.map((sdoc, i) => {
      const k = scheduleKeys[i];
      if (!sdoc.exists) {
        return { dateKey: k, exists: false };
      }
      const sd = sdoc.data()!;
      const items = (sd.items as unknown[]) || [];
      const quizIds = (sd.quizIds as string[]) || [];
      return {
        dateKey: k,
        exists: true,
        cycleCount: (sd.cycleCount as number) ?? 1,
        quizIds,
        itemCount: items.length,
        questionTypes: items.map((it) => {
          const row = it as Record<string, unknown>;
          return (row.questionType as string) || "clinical";
        }),
      };
    });

    let todaySlotNextPreviews: {
      national: Record<string, unknown> | null;
      clinical: Record<string, unknown> | null;
    } = { national: null, clinical: null };
    const todaySchedDoc = schedSnaps[0];
    if (todaySchedDoc.exists) {
      todaySlotNextPreviews = await computeTodaySlotNextPreviewsForHub(
        todaySchedDoc.data()!,
        contentCfg,
      );
    }

    const pollOps = resolvePollOpsFromRows(
      pollRows.map((r) => ({
        id: r.id,
        displayOrder: r.displayOrder,
        question: r.question,
        status: r.status,
        startsAt: r.startsAt,
        endsAt: r.endsAt,
      })),
      Date.now(),
    );

    return {
      success: true,
      generatedAt: new Date().toISOString(),
      polls: pollRows,
      pollNextPreview,
      pollOps: {
        ...pollOps,
        totalPolls: pollRows.length,
        closedPolls: pollRows.filter((p) => p.status === "closed").length,
      },
      quiz: {
        contentConfig: contentCfg,
        meta: metaSummary,
        schedules,
        poolPackBreakdown: quizPoolPackBreakdown,
        todaySlotNextPreviews,
      },
    };
  });

// ─────────────────────────────────────────────────────────────
// 심평원 보험인정기준 검색 프록시 (Callable)
// ─────────────────────────────────────────────────────────────

interface HiraSearchResult {
  category: string;
  reference: string;
  title: string;
  link: string;
  date: string;
  views: number;
}

// tabGbn 코드 → 탭 이름 폴백 (HTML span에 없을 때만)
const HIRA_TAB_MAP: Record<string, string> = {
  "01": "고시",
  "02": "행정해석",
  "09": "심사지침",
  "10": "심의사례공개",
  "17": "요양기관현지조사",
  "18": "심사사례",
};

interface HiraTabEntry {
  id: string;
  label: string;
  count: number;
}

/** 심평원 탭 스트립에서 id·표시명·건수 추출 (신규 탭 코드도 라벨 표시 가능) */
function parseHiraTabList(html: string): HiraTabEntry[] {
  const out: HiraTabEntry[] = [];
  const tabRe = /goTabMove\('(\d+)'\)[^>]*><span>(.*?)<\/span><em>\((\d+)건\)<\/em>/g;
  let tm;
  while ((tm = tabRe.exec(html)) !== null) {
    out.push({
      id: tm[1],
      label: tm[2].trim().replace(/\s+/g, " "),
      count: parseInt(tm[3], 10),
    });
  }
  return out;
}

function tabListToCounts(tabList: HiraTabEntry[]): Record<string, number> {
  const tabCounts: Record<string, number> = {};
  for (const t of tabList) {
    tabCounts[t.label] = t.count;
  }
  return tabCounts;
}

function idToLabelMap(tabList: HiraTabEntry[]): Map<string, string> {
  return new Map(tabList.map((t) => [t.id, t.label]));
}

function parseHiraRows(html: string, fallbackCategory = ""): HiraSearchResult[] {
  const results: HiraSearchResult[] = [];
  // viewInsuAdtCrtr(no, 'mtgHmeDd', 'sno', 'mtgMtrRegSno', 'RN')
  const rowRe = /onclick="viewInsuAdtCrtr\(\s*\d+\s*,\s*'(\d+)'\s*,\s*'(\d+)'\s*,\s*'(\d+)'\s*,\s*'\d+'[^)]*\)[^"]*"[^>]*title="([^"]*)"[\s\S]*?<td class="col-date">([\d-]+)<\/td>[\s\S]*?<td class="col-views">([\d,]+)<\/td>/g;
  let rm;
  while ((rm = rowRe.exec(html)) !== null) {
    const [, mtgHmeDd, sno, mtgMtrRegSno, titleRaw, date, viewsStr] = rm;
    const title = titleRaw.replace(/\s*새창으로 열기\s*$/, "").trim();
    const link =
      "https://www.hira.or.kr/rc/insu/insuadtcrtr/InsuAdtCrtrPopup.do" +
      `?mtgHmeDd=${mtgHmeDd}&sno=${sno}&mtgMtrRegSno=${mtgMtrRegSno}`;

    // col-gubun 값 추출 시도
    const categoryRe = new RegExp(
      `<td class="col-gubun">(.*?)<\\/td>[\\s\\S]*?${mtgHmeDd}`
    );
    const catMatch = categoryRe.exec(html);
    const category = catMatch ? catMatch[1].trim() : fallbackCategory;

    // col-num2 (관련근거) 추출 시도
    const refRe = new RegExp(
      `<td class="col-gubun">.*?<\\/td>\\s*<td class="col-num2">(.*?)<\\/td>[\\s\\S]*?${mtgHmeDd}`
    );
    const refMatch = refRe.exec(html);
    const reference = refMatch ? refMatch[1].trim() : "";

    results.push({
      category,
      reference,
      title,
      link,
      date,
      views: parseInt(viewsStr.replace(/,/g, ""), 10),
    });
  }
  return results;
}


async function fetchHiraTab(
  keyword: string,
  tabGbn: string,
  pageIndex: number,
  recordCountPerPage: number
): Promise<string> {
  const url =
    "https://www.hira.or.kr/rc/insu/insuadtcrtr/InsuAdtCrtrList.do" +
    "?pgmid=HIRAA030069000400";
  const formData = new URLSearchParams({
    pgmid: "HIRAA030069000400",
    pageIndex: String(pageIndex),
    tabGbn: tabGbn,
    mtgHmeDd: "RN",
    divRngCdSc: "",
    sno: "",
    mtgMtrRegSno: "",
    seqListYn: "N",
    seqList: "",
    searchYn: "Y",
    allViewYn: "",
    decIteTpCd: tabGbn,
    startDate: "",
    endDate: "",
    recordCountPerPage: String(recordCountPerPage),
    searchKeyword: keyword,
    startDt: "",
    endDt: "",
    searchCondition: "TXTALL",
    searchWord: keyword,
    searchKeyword2: "",
  });
  const resp = await axios.post(url, formData.toString(), {
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      "User-Agent":
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    },
    timeout: 30000,
    responseType: "text",
  });
  return resp.data as string;
}

export const searchHiraInsurance = functions
  .region("asia-northeast3")
  .runWith({timeoutSeconds: 60, memory: "512MB"})
  .https.onCall(
  async (data: {
    keyword: string;
    page?: number;
    tab?: string;
    perPage?: number;
  }) => {
    const keyword = (data.keyword || "").trim();
    if (!keyword || keyword.length < 2) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "검색어는 2글자 이상이어야 합니다."
      );
    }

    const pageIndex = data.page ?? 1;
    const requestedTab = (data.tab ?? "all").trim();
    const recordCountPerPage = Math.min(data.perPage ?? 20, 50);

    try {
      // 1단계: 탭01(고시)로 요청하여 탭 스트립(라벨·건수·id) 파악
      const firstHtml = await fetchHiraTab(keyword, "01", 1, 5);
      const tabList = parseHiraTabList(firstHtml);
      const tabCounts = tabListToCounts(tabList);
      const idLabel = idToLabelMap(tabList);
      const totalAll = tabList.reduce((a, t) => a + t.count, 0);

      // 특정 탭만 (고시 01 포함)
      if (requestedTab !== "all") {
        const tabHtml = await fetchHiraTab(
          keyword,
          requestedTab,
          pageIndex,
          recordCountPerPage
        );
        const catLabel =
          idLabel.get(requestedTab) ??
          HIRA_TAB_MAP[requestedTab] ??
          requestedTab;
        const rows = parseHiraRows(tabHtml, catLabel);
        const thisCount =
          tabList.find((t) => t.id === requestedTab)?.count ?? rows.length;
        return {
          success: true,
          keyword,
          totalAllCount: totalAll,
          totalCount: thisCount,
          page: pageIndex,
          perPage: recordCountPerPage,
          results: rows,
          tabResults: { [requestedTab]: rows },
          tabCounts,
          tabs: tabList,
        };
      }

      // 전체(all): 건수가 있는 탭들을 순회하여 결과 수집
      const nonZeroTabs = tabList
        .filter((t) => t.count > 0)
        .map((t) => t.id);

      if (nonZeroTabs.length === 0) {
        return {
          success: true,
          keyword,
          totalAllCount: 0,
          totalCount: 0,
          page: 1,
          perPage: recordCountPerPage,
          results: [],
          tabCounts,
          tabs: tabList,
        };
      }

      const tabsToFetch = nonZeroTabs.slice(0, 3);
      const tabHtmls = await Promise.all(
        tabsToFetch.map((tabGbn) =>
          fetchHiraTab(keyword, tabGbn, pageIndex, recordCountPerPage)
        )
      );

      const allResults: HiraSearchResult[] = [];
      const tabResults: Record<string, HiraSearchResult[]> = {};
      for (let i = 0; i < tabsToFetch.length; i++) {
        const tabGbn = tabsToFetch[i];
        const categoryName =
          idLabel.get(tabGbn) ?? HIRA_TAB_MAP[tabGbn] ?? tabGbn;
        const rows = parseHiraRows(tabHtmls[i], categoryName);
        allResults.push(...rows);
        tabResults[tabGbn] = rows;
      }

      return {
        success: true,
        keyword,
        totalAllCount: totalAll,
        totalCount: totalAll,
        page: pageIndex,
        perPage: recordCountPerPage,
        results: allResults,
        tabResults,
        tabCounts,
        tabs: tabList,
      };
    } catch (err: any) {
      console.error("searchHiraInsurance error:", err.message);
      throw new functions.https.HttpsError(
        "unavailable",
        "심평원 서버 응답 오류. 잠시 후 다시 시도해주세요."
      );
    }
  }
);

// ─────────────────────────────────────────────────────────────
// 수가 조회 프록시 (data.go.kr 공공데이터 API)
// ─────────────────────────────────────────────────────────────

interface FeeScheduleItem {
  code: string;
  codeName: string;
  category: string;
  relativeValue: number;
  unitPrice: number;
  priceClinic: number;
  priceHospital: number;
  priceGeneral: number;
  priceAdvanced: number;
  payType: string;
  startDate: string;
  note: string;
}

export const searchFeeSchedule = functions
  .region("asia-northeast3")
  .runWith({timeoutSeconds: 30, memory: "256MB"})
  .https.onCall(
  async (data: {
    keyword: string;
    page?: number;
    perPage?: number;
  }) => {
    const keyword = (data.keyword || "").trim();
    if (!keyword) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "검색어를 입력해 주세요."
      );
    }

    const pageNo = data.page ?? 1;
    const numOfRows = Math.min(data.perPage ?? 20, 50);

    const apiKey = process.env.DATA_GO_KR_API_KEY;
    if (!apiKey) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "수가 조회 API 키가 설정되지 않았습니다."
      );
    }

    const encoded = encodeURIComponent(keyword);
    const isEngCode = /^[A-Za-z]\d/.test(keyword);
    const isDivNo = /^[가-힣]/.test(keyword) && /\d/.test(keyword);

    let searchParams = "";
    if (isEngCode) {
      searchParams = `&mdfeeCd=${encoded}`;
    } else if (isDivNo) {
      searchParams = `&mdfeeDivNo=${encoded}`;
    } else {
      searchParams = `&korNm=${encoded}`;
    }

    const apiUrl =
      `https://apis.data.go.kr/B551182/mdfeeCrtrInfoService/getDiagnossMdfeeList` +
      `?ServiceKey=${apiKey}` +
      `&numOfRows=${numOfRows}&pageNo=${pageNo}` +
      searchParams;

    try {
      const resp = await axios.get(apiUrl, {
        timeout: 15000,
      });

      let parsed: any;
      if (typeof resp.data === "string") {
        if (resp.data.startsWith("<?xml")) {
          parsed = await parseStringPromise(resp.data, {
            explicitArray: false,
            trim: true,
          });
        } else {
          parsed = JSON.parse(resp.data);
        }
      } else {
        parsed = resp.data;
      }

      const header = parsed?.response?.header;
      if (header?.resultCode !== "00") {
        console.error("API error:", header?.resultMsg);
        throw new Error(header?.resultMsg || "API error");
      }

      const body = parsed?.response?.body;
      if (!body) {
        return {totalCount: 0, page: pageNo, perPage: numOfRows, items: []};
      }

      const totalCount = parseInt(body.totalCount || "0", 10);

      let rawItems = body.items?.item;
      if (!rawItems || (typeof rawItems === "string" && rawItems.trim() === "")) {
        return {totalCount: 0, page: pageNo, perPage: numOfRows, items: []};
      }

      if (!Array.isArray(rawItems)) {
        rawItems = [rawItems];
      }

      const items: FeeScheduleItem[] = rawItems.map((r: any) => {
        const unprc2 = parseInt(r.unprc2 || "0", 10);
        const unprc3 = parseInt(r.unprc3 || "0", 10);
        const unprc4 = parseInt(r.unprc4 || "0", 10);
        const unprc6 = parseInt(r.unprc6 || "0", 10);
        const bestPrice = unprc2 || unprc3 || unprc4 || unprc6;

        return {
          code: r.mdfeeCd || "",
          codeName: r.korNm || "",
          category: r.mdfeeDivNo || "",
          relativeValue: parseFloat(r.cvalPnt || "0"),
          unitPrice: bestPrice,
          priceClinic: unprc2,
          priceHospital: unprc3,
          priceGeneral: unprc4,
          priceAdvanced: unprc6,
          payType: r.payTpCd || "",
          startDate: r.adtStaDd || "",
          note: r.soprTpNm || "",
        };
      });

      return {
        totalCount,
        page: pageNo,
        perPage: numOfRows,
        items,
      };
    } catch (err: any) {
      console.error("searchFeeSchedule error:", err.message);
      if (err.response?.data) {
        console.error("API response:",
          typeof err.response.data === "string"
            ? err.response.data.substring(0, 500)
            : JSON.stringify(err.response.data).substring(0, 500));
      }
      throw new functions.https.HttpsError(
        "unavailable",
        "수가 조회 서버 응답 오류. 잠시 후 다시 시도해주세요."
      );
    }
  }
);


// ════════════════════════════════════════════════════════════════
// 새 공고자 플로우 Callable (v2)
// ════════════════════════════════════════════════════════════════

/**
 * verifyBusinessLicense
 *
 * 1) 사업자등록증 이미지를 Gemini로 OCR
 * 2) clinic_profiles 에 OCR 결과·pending_auto 저장
 * 3) runCheckBusinessStatus — 국세청(Mock 가능) 검증 (별도 모듈)
 *
 * Input: { docUrl, profileId }
 * Output: { bizNo, clinicName, ownerName, address, openedAt, status, failReason?, checkMethod?, skipped? }
 */
export const verifyBusinessLicense = functions
  .runWith({
    timeoutSeconds: 120,
    memory: "512MB",
    secrets: ["GEMINI_API_KEY", "NTS_SERVICE_KEY", HIRA_SERVICE_KEY],
  })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "로그인이 필요합니다.");
    }
    const uid = context.auth.uid;
    const docUrl = String(data.docUrl ?? "").trim();
    const profileId = String(data.profileId ?? "").trim();

    if (!docUrl) {
      throw new functions.https.HttpsError("invalid-argument", "등록증 이미지 URL이 없습니다.");
    }
    if (!profileId) {
      throw new functions.https.HttpsError("invalid-argument", "profileId가 없습니다.");
    }

    const profileRef = db
      .collection("clinics_accounts").doc(uid)
      .collection("clinic_profiles").doc(profileId);
    const profileDoc = await profileRef.get();
    if (!profileDoc.exists) {
      throw new functions.https.HttpsError("not-found", "치과 프로필을 찾을 수 없습니다.");
    }

    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      throw new functions.https.HttpsError("internal", "AI API 키가 설정되지 않았습니다.");
    }

    functions.logger.info("verifyBusinessLicense", { uid, profileId, docUrl });

    const bizPrompt = `아래 사업자등록증 이미지를 분석하여 반드시 아래 JSON 형식으로만 응답해줘.
다른 텍스트 없이 순수 JSON만 반환해.
필드가 파악되지 않으면 빈 문자열로 남겨. 절대 추측하지 말고 이미지에서 읽을 수 있는 정보만 추출해.

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

      const geminiUrl = "https://generativelanguage.googleapis.com/v1beta/models/" + GEMINI_MODEL + ":generateContent?key=" + apiKey;
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

    const hasData = !!(extracted.bizNo || extracted.clinicName);

    if (!hasData) {
      await profileRef.update({
        "businessVerification.status": "rejected",
        "businessVerification.docUrl": docUrl,
        "businessVerification.method": "gemini_v1",
        "businessVerification.ocrResult": extracted,
        "businessVerification.failReason": "ocr_failed",
        "businessVerification.verifiedAt": null,
        "bizRegImageUrl": docUrl,
        "updatedAt": admin.firestore.FieldValue.serverTimestamp(),
      });
      return {
        ...extracted,
        status: "rejected",
        failReason: "ocr_failed",
      };
    }

    await profileRef.update({
      ...(extracted.clinicName ? { clinicName: extracted.clinicName } : {}),
      ...(extracted.ownerName ? { ownerName: extracted.ownerName } : {}),
      ...(extracted.address ? { address: extracted.address } : {}),
      "businessVerification.status": "pending_auto",
      "businessVerification.bizNo": extracted.bizNo,
      "businessVerification.docUrl": docUrl,
      "businessVerification.method": "gemini_v1",
      "businessVerification.ocrResult": extracted,
      "businessVerification.failReason": admin.firestore.FieldValue.delete(),
      "businessVerification.verifiedAt": null,
      "bizRegImageUrl": docUrl,
      "updatedAt": admin.firestore.FieldValue.serverTimestamp(),
    });

    const check = await runCheckBusinessStatus(
      db,
      uid,
      profileId,
      HIRA_SERVICE_KEY.value()
    );

    return {
      ...extracted,
      status: check.status,
      failReason: check.failReason,
      checkMethod: check.method,
      skipped: check.skipped,
      hiraMatched: check.hiraMatched,
      hiraNote: check.hiraNote,
      hiraMatchLevel: check.hiraMatchLevel,
    };
  });

/**
 * checkBusinessStatus
 *
 * OCR 이후 국세청·Mock 검증만 재실행 (재시도·수동 트리거).
 * Input: { profileId }
 */
export const checkBusinessStatus = functions
  .runWith({
    timeoutSeconds: 60,
    memory: "256MB",
    secrets: ["NTS_SERVICE_KEY", HIRA_SERVICE_KEY],
  })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "로그인이 필요합니다.");
    }
    const uid = context.auth.uid;
    const profileId = String(data.profileId ?? "").trim();
    if (!profileId) {
      throw new functions.https.HttpsError("invalid-argument", "profileId가 필요합니다.");
    }
    const result = await runCheckBusinessStatus(
      db,
      uid,
      profileId,
      HIRA_SERVICE_KEY.value()
    );
    return result;
  });

/**
 * createOrder
 *
 * 게시 버튼 클릭 시 호출. Draft 유효성 검증 후 Order 문서를 생성한다.
 * 공고권 적용 시 amount=0으로 처리.
 *
 * Input: { draftId, clinicProfileId, voucherId? }
 * Output: { orderId, amount, requiresPayment }
 */
export const createOrder = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "로그인이 필요합니다.");
    }
    const uid = context.auth.uid;
    const draftId = String(data.draftId ?? "").trim();
    const clinicProfileId = String(data.clinicProfileId ?? "").trim();
    const voucherId: string | null = data.voucherId ? String(data.voucherId).trim() : null;

    if (!draftId || !clinicProfileId) {
      throw new functions.https.HttpsError("invalid-argument", "draftId와 clinicProfileId는 필수입니다.");
    }

    // Draft 존재 및 소유권 확인
    const draftDoc = await db.collection("jobDrafts").doc(draftId).get();
    if (!draftDoc.exists || draftDoc.data()?.ownerUid !== uid) {
      throw new functions.https.HttpsError("not-found", "Draft를 찾을 수 없습니다.");
    }

    // 계정 상태 확인
    const accountDoc = await db.collection("clinics_accounts").doc(uid).get();
    if (!accountDoc.exists) {
      throw new functions.https.HttpsError("permission-denied", "공고자 계정이 없습니다.");
    }
    const accountData = accountDoc.data() || {};
    const identityVerified = accountData.identityVerified === true || accountData.phoneVerified === true;
    if (!identityVerified) {
      throw new functions.https.HttpsError("failed-precondition", "본인인증이 필요합니다.");
    }

    // 프로필 사업자 인증 확인
    const profileDoc = await db
      .collection("clinics_accounts").doc(uid)
      .collection("clinic_profiles").doc(clinicProfileId)
      .get();
    if (!profileDoc.exists) {
      throw new functions.https.HttpsError("not-found", "치과 프로필을 찾을 수 없습니다.");
    }
    const profileData = profileDoc.data() || {};
    const bizStatus = profileData.businessVerification?.status;
    if (bizStatus !== "verified") {
      throw new functions.https.HttpsError("failed-precondition", "사업자 인증이 필요합니다.");
    }

    // 동일 Draft 중복 주문 방지
    const existingOrders = await db.collection("orders")
      .where("ownerUid", "==", uid)
      .where("draftId", "==", draftId)
      .where("status", "in", ["created", "payment_pending"])
      .limit(1)
      .get();
    if (!existingOrders.empty) {
      const existing = existingOrders.docs[0];
      return {
        orderId: existing.id,
        amount: existing.data().amount ?? 0,
        requiresPayment: (existing.data().amount ?? 0) > 0,
      };
    }

    // 기본 금액 (상품 정책에 따라 조정)
    let amount = 50000; // 기본 30일 노출
    let appliedVoucherId: string | null = null;

    // 공고권 적용
    if (voucherId) {
      const voucherDoc = await db.collection("vouchers").doc(voucherId).get();
      if (voucherDoc.exists) {
        const v = voucherDoc.data()!;
        if (v.ownerUid === uid && v.status === "active") {
          const expiresAt = v.expiresAt?.toDate?.();
          if (!expiresAt || expiresAt > new Date()) {
            amount = 0;
            appliedVoucherId = voucherId;
          }
        }
      }
    }

    // Order 생성
    const orderData = {
      ownerUid: uid,
      draftId,
      clinicProfileId,
      status: amount > 0 ? "created" : "created",
      amount,
      currency: "KRW",
      voucherId: appliedVoucherId,
      paymentProvider: appliedVoucherId ? "voucher_only" : null,
      exposureDays: 30,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const orderRef = await db.collection("orders").add(orderData);
    functions.logger.info("createOrder", { uid, orderId: orderRef.id, amount, voucherId: appliedVoucherId });

    return {
      orderId: orderRef.id,
      amount,
      requiresPayment: amount > 0,
    };
  }
);

/**
 * confirmPayment
 *
 * 결제 완료(또는 공고권 전용 0원 결제) 후 호출.
 * PG 검증 → Order 상태 갱신 → Draft에서 jobs 문서 생성.
 *
 * Input: { orderId, paymentKey? }
 * Output: { jobId, success }
 */
export const confirmPayment = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "로그인이 필요합니다.");
    }
    const uid = context.auth.uid;
    const orderId = String(data.orderId ?? "").trim();
    const paymentKey: string | null = data.paymentKey ? String(data.paymentKey).trim() : null;

    if (!orderId) {
      throw new functions.https.HttpsError("invalid-argument", "orderId는 필수입니다.");
    }

    const orderRef = db.collection("orders").doc(orderId);
    const orderDoc = await orderRef.get();
    if (!orderDoc.exists || orderDoc.data()?.ownerUid !== uid) {
      throw new functions.https.HttpsError("not-found", "주문을 찾을 수 없습니다.");
    }

    const orderData = orderDoc.data()!;
    if (orderData.status === "paid") {
      // 멱등성: 이미 처리된 주문
      return { jobId: orderData.jobId ?? "", success: true };
    }
    if (orderData.status !== "created" && orderData.status !== "payment_pending") {
      throw new functions.https.HttpsError("failed-precondition", "처리할 수 없는 주문 상태입니다.");
    }

    const amount = orderData.amount ?? 0;

    // 유료 결제: 토스페이먼츠 검증 (Phase 8에서 실제 연동)
    if (amount > 0) {
      if (!paymentKey) {
        throw new functions.https.HttpsError("invalid-argument", "paymentKey가 필요합니다.");
      }
      // TODO: 토스페이먼츠 서버 검증 API 호출
      functions.logger.info("confirmPayment: toss verification placeholder", { orderId, paymentKey });
    }

    // Draft 데이터 로드
    const draftDoc = await db.collection("jobDrafts").doc(orderData.draftId).get();
    if (!draftDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Draft를 찾을 수 없습니다.");
    }
    const draftData = draftDoc.data()!;

    // 프로필에서 치과 정보 병합
    const profileDoc = await db
      .collection("clinics_accounts").doc(uid)
      .collection("clinic_profiles").doc(orderData.clinicProfileId)
      .get();
    const profileData = profileDoc.exists ? profileDoc.data()! : {};

    const now = new Date();
    const exposureDays = orderData.exposureDays ?? 30;
    const expiresAt = new Date(now.getTime() + exposureDays * 24 * 60 * 60 * 1000);

    // 급여 파싱
    const salaryStr = String(draftData.salary ?? "").trim();
    const sr = parseJobSalaryRange(salaryStr);

    // jobs 문서 생성
    const jobData: Record<string, unknown> = {
      createdBy: uid,
      clinicProfileId: orderData.clinicProfileId,
      orderId,
      clinicName: profileData.displayName || profileData.clinicName || draftData.clinicName || "",
      title: draftData.title || "",
      role: draftData.role || "",
      type: draftData.role || "",
      career: draftData.career || "미정",
      employmentType: draftData.employmentType || "",
      workHours: draftData.workHours || "",
      salary: salaryStr,
      salaryText: salaryStr,
      salaryMin: sr.min,
      salaryMax: sr.max,
      salaryRange: [sr.min, sr.max],
      benefits: draftData.benefits || [],
      description: draftData.description || "",
      details: draftData.description || "",
      address: profileData.address || draftData.address || "",
      contact: draftData.contact || "",
      images: draftData.imageUrls || [],
      tags: draftData.tags || [],
      status: "active",
      paymentStatus: "paid",
      publishedAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      postedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const jobRef = await db.collection("jobs").add(jobData);

    // Order 상태 업데이트
    const orderUpdates: Record<string, unknown> = {
      status: "paid",
      jobId: jobRef.id,
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (paymentKey) {
      orderUpdates.providerTxId = paymentKey;
      orderUpdates.paymentProvider = "toss";
    }
    await orderRef.update(orderUpdates);

    // 공고권 사용 처리
    if (orderData.voucherId) {
      await db.collection("vouchers").doc(orderData.voucherId).update({
        status: "used",
        usedForOrderId: orderId,
        usedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // Draft 상태 업데이트
    await db.collection("jobDrafts").doc(orderData.draftId).update({
      currentStep: "published",
      publishedJobId: jobRef.id,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    functions.logger.info("confirmPayment success", { uid, orderId, jobId: jobRef.id });

    return { jobId: jobRef.id, success: true };
  }
);

/**
 * expireJobs (스케줄러)
 *
 * 매일 00:30 KST에 실행. expiresAt이 지난 active 공고를 closed로 전환.
 */
export const expireJobs = functions
  .pubsub.schedule("30 0 * * *")
  .timeZone("Asia/Seoul")
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const snap = await db.collection("jobs")
      .where("status", "==", "active")
      .where("expiresAt", "<=", now)
      .get();

    if (snap.empty) {
      functions.logger.info("expireJobs: no expired jobs");
      return null;
    }

    const batch = db.batch();
    for (const doc of snap.docs) {
      batch.update(doc.ref, {
        status: "closed",
        closedAt: admin.firestore.FieldValue.serverTimestamp(),
        closedReason: "expired",
      });
    }
    await batch.commit();
    functions.logger.info("expireJobs: closed", { count: snap.size });
    return null;
  });

/**
 * onClinicAccountCreated
 *
 * clinics_accounts 문서 생성 시 가입 축하 무료 공고권(90일)을 자동 발급.
 * CI 중복 체크는 추후 토스 본인확인 연동 시 추가.
 */
export const onClinicAccountCreated = functions.firestore
  .document("clinics_accounts/{uid}")
  .onCreate(async (snap, context) => {
    const uid = context.params.uid;

    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 90);

    await db.collection("vouchers").add({
      ownerUid: uid,
      type: "signup_free",
      status: "active",
      issuedBy: "system",
      issuedAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    });

    functions.logger.info("onClinicAccountCreated: signup voucher issued", { uid });
  });

// ════════════════════════════════════════════════════════════════
// 🔔 알림 스케줄러 (Phase 8-3)
// ════════════════════════════════════════════════════════════════

/**
 * notifyJobExpiringSoon
 *
 * 매일 09:00 KST 실행.
 * expiresAt이 7일 이내인 active 공고를 찾아 알림 문서를 생성합니다.
 * notifications/{uid}/items/{notificationId} 서브컬렉션에 기록.
 */
export const notifyJobExpiringSoon = functions
  .runWith({ timeoutSeconds: 120 })
  .pubsub.schedule("every day 09:00")
  .timeZone("Asia/Seoul")
  .onRun(async () => {
    const now = new Date();
    const sevenDaysLater = new Date();
    sevenDaysLater.setDate(now.getDate() + 7);

    const snap = await db.collection("jobs")
      .where("status", "==", "active")
      .where("expiresAt", "<=", admin.firestore.Timestamp.fromDate(sevenDaysLater))
      .where("expiresAt", ">", admin.firestore.Timestamp.fromDate(now))
      .get();

    if (snap.empty) {
      functions.logger.info("notifyJobExpiringSoon: no expiring jobs");
      return null;
    }

    const batch = db.batch();
    const notified = new Set<string>();

    for (const doc of snap.docs) {
      const data = doc.data();
      const uid = data.createdBy as string;
      if (!uid || notified.has(`${uid}_${doc.id}`)) continue;

      const expiresAt = (data.expiresAt as admin.firestore.Timestamp).toDate();
      const daysLeft = Math.ceil((expiresAt.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
      const title = data.title || "(제목 없음)";

      const ref = db.collection("notifications").doc(uid)
        .collection("items").doc();
      batch.set(ref, {
        type: "job_expiring",
        jobId: doc.id,
        title: `공고 만료 예정 (${daysLeft}일 남음)`,
        body: `"${title}" 공고가 ${daysLeft}일 후 만료됩니다.`,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      notified.add(`${uid}_${doc.id}`);
    }

    await batch.commit();
    functions.logger.info("notifyJobExpiringSoon: sent", { count: notified.size });
    return null;
  });

/**
 * remindStaleDrafts
 *
 * 매일 10:00 KST 실행.
 * 24시간 이상 방치된 임시저장(jobDrafts)에 대해 리마인드 알림을 보냅니다.
 * 동일 드래프트에 대해 24시간 내 중복 알림은 보내지 않습니다.
 */
export const remindStaleDrafts = functions
  .runWith({ timeoutSeconds: 120 })
  .pubsub.schedule("every day 10:00")
  .timeZone("Asia/Seoul")
  .onRun(async () => {
    const now = new Date();
    const oneDayAgo = new Date();
    oneDayAgo.setDate(now.getDate() - 1);
    const threeDaysAgo = new Date();
    threeDaysAgo.setDate(now.getDate() - 3);

    // 1~3일 사이 방치된 드래프트 (너무 오래된 건 제외)
    const snap = await db.collection("jobDrafts")
      .where("updatedAt", "<=", admin.firestore.Timestamp.fromDate(oneDayAgo))
      .where("updatedAt", ">=", admin.firestore.Timestamp.fromDate(threeDaysAgo))
      .where("status", "in", ["draft", "ai_generated", "editing"])
      .get();

    if (snap.empty) {
      functions.logger.info("remindStaleDrafts: no stale drafts");
      return null;
    }

    const batch = db.batch();
    let count = 0;

    for (const doc of snap.docs) {
      const data = doc.data();
      const uid = data.ownerUid as string;
      if (!uid) continue;

      const title = data.title || data.clinicName || "작성 중인 공고";

      // 중복 방지: 같은 draftId로 24시간 내 알림이 있는지 확인
      const existing = await db.collection("notifications").doc(uid)
        .collection("items")
        .where("type", "==", "draft_reminder")
        .where("draftId", "==", doc.id)
        .where("createdAt", ">", admin.firestore.Timestamp.fromDate(oneDayAgo))
        .limit(1)
        .get();

      if (!existing.empty) continue;

      const ref = db.collection("notifications").doc(uid)
        .collection("items").doc();
      batch.set(ref, {
        type: "draft_reminder",
        draftId: doc.id,
        title: "임시저장 공고가 있어요",
        body: `"${title}" 공고를 이어서 작성해보세요.`,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      count++;
    }

    if (count > 0) await batch.commit();
    functions.logger.info("remindStaleDrafts: sent", { count });
    return null;
  });

/**
 * notifyVoucherExpiringSoon
 *
 * 매일 09:30 KST 실행.
 * 7일 이내 만료 예정인 active 공고권에 대해 알림을 보냅니다.
 */
export const notifyVoucherExpiringSoon = functions
  .runWith({ timeoutSeconds: 120 })
  .pubsub.schedule("every day 09:30")
  .timeZone("Asia/Seoul")
  .onRun(async () => {
    const now = new Date();
    const sevenDaysLater = new Date();
    sevenDaysLater.setDate(now.getDate() + 7);

    const snap = await db.collection("vouchers")
      .where("status", "==", "active")
      .where("expiresAt", "<=", admin.firestore.Timestamp.fromDate(sevenDaysLater))
      .where("expiresAt", ">", admin.firestore.Timestamp.fromDate(now))
      .get();

    if (snap.empty) {
      functions.logger.info("notifyVoucherExpiringSoon: no expiring vouchers");
      return null;
    }

    const batch = db.batch();
    const notified = new Set<string>();

    for (const doc of snap.docs) {
      const data = doc.data();
      const uid = data.ownerUid as string;
      if (!uid || notified.has(uid)) continue;

      const expiresAt = (data.expiresAt as admin.firestore.Timestamp).toDate();
      const daysLeft = Math.ceil((expiresAt.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));

      const ref = db.collection("notifications").doc(uid)
        .collection("items").doc();
      batch.set(ref, {
        type: "voucher_expiring",
        voucherId: doc.id,
        title: "무료 공고권 만료 예정",
        body: `보유한 무료 공고권이 ${daysLeft}일 후 만료됩니다. 지금 공고를 등록해보세요!`,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      notified.add(uid);
    }

    await batch.commit();
    functions.logger.info("notifyVoucherExpiringSoon: sent", { count: notified.size });
    return null;
  });

// ========== 이력서: 이미지 → 필드 자동추출 (Gemini Vision) ==========

/**
 * extractResumeFromImages
 *
 * 이력서 이미지 URL 목록을 받아 Gemini Vision으로 이력서 필드를 추출한다.
 * Firestore `resumeImportDrafts/{draftId}` 문서를 직접 업데이트하며
 * 결과를 반환한다.
 *
 * Input  : { draftId: string, imageUrls: string[] }
 * Output : { ok: true, fields: {...}, confidence: {...} }
 *          또는 오류 시 HttpsError
 */
export const extractResumeFromImages = functions
  .runWith({ timeoutSeconds: 180, memory: "512MB", secrets: ["GEMINI_API_KEY"] })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "로그인이 필요합니다.");
    }

    const draftId: string = data.draftId ?? "";
    const imageUrls: string[] = data.imageUrls ?? [];

    if (!draftId) {
      throw new functions.https.HttpsError("invalid-argument", "draftId가 없습니다.");
    }
    if (!imageUrls.length) {
      throw new functions.https.HttpsError("invalid-argument", "이미지 URL이 없습니다.");
    }

    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      await db.collection("resumeImportDrafts").doc(draftId).update({
        status: "failed",
        failReason: "api_key_missing",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      throw new functions.https.HttpsError("internal", "AI API 키가 설정되지 않았습니다.");
    }

    // 소유자 확인
    const draftDoc = await db.collection("resumeImportDrafts").doc(draftId).get();
    if (!draftDoc.exists) {
      throw new functions.https.HttpsError("not-found", "드래프트 문서를 찾을 수 없습니다.");
    }
    if (draftDoc.data()?.ownerUid !== context.auth.uid) {
      throw new functions.https.HttpsError("permission-denied", "권한이 없습니다.");
    }

    functions.logger.info("extractResumeFromImages start", {
      uid: context.auth.uid,
      draftId,
      imageCount: imageUrls.length,
    });

    const resumePrompt = `아래 이력서 이미지를 분석하여 반드시 아래 JSON 형식으로만 응답해줘.
다른 텍스트 없이 순수 JSON만 반환해.
원문에 명시된 정보만 추출하고, 없으면 빈 문자열을 사용해.
치과 구직자(치과위생사/치과조무사 등) 이력서를 기준으로 추출해.

{
  "name": "성명",
  "phone": "연락처 (숫자와 - 만 포함)",
  "email": "이메일",
  "address": "현 거주지 또는 주소",
  "birthDate": "생년월일 (YYYY-MM-DD 형식, 없으면 빈 문자열)",
  "gender": "성별 (남/여/빈 문자열)",
  "licenses": ["면허·자격증명 (예: 치과위생사면허, 치과기공사면허)"],
  "licenseNumbers": ["면허번호"],
  "experiences": [
    {
      "clinicName": "근무지명",
      "role": "직종/직위",
      "startDate": "YYYY-MM",
      "endDate": "YYYY-MM 또는 현재",
      "description": "담당업무 요약"
    }
  ],
  "skills": ["보유 스킬 (예: 스케일링, 교정, CAD/CAM)"],
  "education": [
    {
      "school": "학교명",
      "major": "전공",
      "degree": "학위/졸업구분",
      "graduatedAt": "YYYY-MM"
    }
  ],
  "summary": "자기소개 또는 지원 동기 요약 (없으면 빈 문자열)",
  "confidence": {
    "name": 0.0,
    "phone": 0.0,
    "email": 0.0,
    "address": 0.0,
    "birthDate": 0.0,
    "licenses": 0.0,
    "experiences": 0.0,
    "skills": 0.0,
    "education": 0.0,
    "summary": 0.0
  }
}

confidence 값은 0.0(전혀 확신 없음) ~ 1.0(명확히 확인됨) 사이로 설정해.`;

    const parts: Array<{text?: string; inlineData?: {mimeType: string; data: string}}> = [];
    parts.push({text: resumePrompt});

    for (const url of imageUrls.slice(0, 8)) {
      try {
        const imgResp = await axios.get(url, {responseType: "arraybuffer", timeout: 20000});
        const base64 = Buffer.from(imgResp.data).toString("base64");
        const contentType = (imgResp.headers["content-type"] as string) || "image/jpeg";
        parts.push({inlineData: {mimeType: contentType, data: base64}});
      } catch (e) {
        functions.logger.warn("이력서 이미지 다운로드 실패", {url, error: String(e)});
      }
    }

    if (parts.length < 2) {
      await db.collection("resumeImportDrafts").doc(draftId).update({
        status: "failed",
        failReason: "no_images_downloaded",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      throw new functions.https.HttpsError("internal", "이미지를 다운로드할 수 없습니다.");
    }

    try {
      const geminiUrl =
        "https://generativelanguage.googleapis.com/v1beta/models/" +
        GEMINI_MODEL +
        ":generateContent?key=" +
        apiKey;

      const resp = await axios.post(
        geminiUrl,
        {
          contents: [{parts}],
          generationConfig: {responseMimeType: "application/json"},
        },
        {timeout: 120000},
      );

      const rawTextRaw = resp.data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";

      // Gemini가 마크다운 코드펜스·주석·비표준 따옴표로 감쌀 수 있으므로 전처리
      let rawText = rawTextRaw
        .replace(/^```(?:json)?\s*/im, "")  // 앞쪽 ```json 또는 ``` 제거
        .replace(/\s*```\s*$/m, "")         // 뒤쪽 ``` 제거
        .trim();

      // JSON 객체 블록만 추출 (앞뒤에 설명 문구가 붙는 경우 대비)
      const jsonBlockMatch = rawText.match(/\{[\s\S]*\}/);
      if (jsonBlockMatch) rawText = jsonBlockMatch[0];

      functions.logger.info("extractResumeFromImages raw", {
        draftId,
        rawLen: rawText.length,
        preview: rawText.slice(0, 120),
      });

      const parsed = JSON.parse(rawText);

      const confRaw = parsed.confidence ?? {};
      const confidence: Record<string, number> = {};
      for (const key of ["name", "phone", "email", "address", "birthDate", "licenses", "experiences", "skills", "education", "summary"]) {
        const v = confRaw[key];
        confidence[key] = typeof v === "number" ? Math.min(1, Math.max(0, v)) : 0.0;
      }

      const suggestedFields: Record<string, unknown> = {
        name:          String(parsed.name ?? "").trim(),
        phone:         String(parsed.phone ?? "").trim(),
        email:         String(parsed.email ?? "").trim(),
        address:       String(parsed.address ?? "").trim(),
        birthDate:     String(parsed.birthDate ?? "").trim(),
        gender:        String(parsed.gender ?? "").trim(),
        licenses:      Array.isArray(parsed.licenses) ? parsed.licenses.map((s: unknown) => String(s).trim()).filter(Boolean) : [],
        licenseNumbers: Array.isArray(parsed.licenseNumbers) ? parsed.licenseNumbers.map((s: unknown) => String(s).trim()).filter(Boolean) : [],
        experiences:   Array.isArray(parsed.experiences) ? parsed.experiences : [],
        skills:        Array.isArray(parsed.skills) ? parsed.skills.map((s: unknown) => String(s).trim()).filter(Boolean) : [],
        education:     Array.isArray(parsed.education) ? parsed.education : [],
        summary:       String(parsed.summary ?? "").trim(),
      };

      await db.collection("resumeImportDrafts").doc(draftId).update({
        suggestedFields,
        confidence,
        status: "ready",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      functions.logger.info("extractResumeFromImages done", {
        uid: context.auth.uid,
        draftId,
        fieldsExtracted: Object.keys(suggestedFields).filter((k) => {
          const v = suggestedFields[k];
          return Array.isArray(v) ? v.length > 0 : String(v ?? "").trim().length > 0;
        }).length,
      });

      return {ok: true, fields: suggestedFields, confidence};
    } catch (e: unknown) {
      functions.logger.error("extractResumeFromImages Gemini 실패", {error: String(e), draftId});
      await db.collection("resumeImportDrafts").doc(draftId).update({
        status: "failed",
        failReason: "gemini_error",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }).catch(() => {/* 오류 무시 */});
      throw new functions.https.HttpsError("internal", "AI 분석 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.");
    }
  });
