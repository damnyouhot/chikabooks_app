import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import axios from "axios";
import {parseStringPromise} from "xml2js";
import * as crypto from "crypto";

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
 * 추대 트리거: enthrone 서브컬렉션에 문서 생성 시
 * 3개 달성 시 billboardPosts에 자동 등록
 */
export const onEnthroneCreated = functions
  .region("asia-northeast3")
  .firestore.document("partnerGroups/{groupId}/posts/{postId}/enthrones/{uid}")
  .onCreate(async (snap, context) => {
    const {groupId, postId} = context.params as {
      groupId: string;
      postId: string;
    };

    try {
      console.log(`🔍 [onEnthroneCreated] groupId: ${groupId}, postId: ${postId}`);

      // 1. 현재 추대 수 집계
      const enthronesSnap = await snap.ref.parent.get();
      const enthroneCount = enthronesSnap.size;
      console.log(`🔍 [onEnthroneCreated] 현재 추대 수: ${enthroneCount}`);

      // 2. 3개 달성 체크
      if (enthroneCount >= 3) {
        console.log("✅ [onEnthroneCreated] 3개 달성! 전광판 등록 시작...");

        // 3. 게시물 정보 가져오기
        const postDoc = await db
          .collection("partnerGroups")
          .doc(groupId)
          .collection("posts")
          .doc(postId)
          .get();

        if (!postDoc.exists) {
          console.error("⚠️ [onEnthroneCreated] 게시물 없음");
          return;
        }

        const postData = postDoc.data()!;

        // 4. 이미 전광판에 등록되었는지 확인 (중복 방지)
        const existingBillboard = await db
          .collection("billboardPosts")
          .where("sourceBondId", "==", groupId)
          .where("sourcePostId", "==", postId)
          .limit(1)
          .get();

        if (!existingBillboard.empty) {
          console.log("⚠️ [onEnthroneCreated] 이미 전광판에 등록됨");
          return;
        }

        // 5. 그룹 정보 가져오기 (그룹명)
        const groupDoc = await db.collection("partnerGroups").doc(groupId).get();
        const groupName = groupDoc.exists
          ? (groupDoc.data()?.title || "익명의 결")
          : "익명의 결";

        // 6. 게시 조건 확인
        if (
          postData.publicEligible !== false &&
          !postData.isDeleted &&
          (postData.reports || 0) < 3
        ) {
          // 7. 전광판에 등록
          const now = admin.firestore.Timestamp.now();
          const expiresAt = admin.firestore.Timestamp.fromMillis(
            Date.now() + 48 * 60 * 60 * 1000 // 48시간 후
          );

          await db.collection("billboardPosts").add({
            sourceBondId: groupId,
            sourcePostId: postId,
            textSnapshot: postData.text || postData.body || "",
            enthroneCount: enthroneCount,
            requiredCount: 3,
            createdAt: now,
            expiresAt: expiresAt,
            status: "confirmed",
            bondGroupName: groupName,
            isAnonymous: true,
          });

          console.log(`✅ [onEnthroneCreated] 전광판 등록 완료! (${groupId}/${postId})`);

          // 8. 게시물에 전광판 등록 플래그 추가
          await db
            .collection("partnerGroups")
            .doc(groupId)
            .collection("posts")
            .doc(postId)
            .update({
              onBillboard: true,
              billboardedAt: now,
            });
        } else {
          console.log("⚠️ [onEnthroneCreated] 게시 조건 불충족 (삭제/신고/비공개)");
        }
      } else {
        console.log(`⏳ [onEnthroneCreated] 아직 ${3 - enthroneCount}개 더 필요`);
      }
    } catch (error) {
      console.error("❌ [onEnthroneCreated] 에러:", error);
    }
  });

/**
 * 일일 요약 생성: 매일 19:00 KST에 실행
 */
export const generateDailySummary = functions
  .pubsub.schedule("0 19 * * *") // 매일 19:00 (UTC+0 기준이므로 실제로는 10:00 UTC)
  .timeZone("Asia/Seoul")
  .onRun(async () => {
    try {
      const dateKey = getCurrentDateKey();

      // 모든 활성 파트너 그룹 가져오기
      const groupsSnap = await db
        .collection("partnerGroups")
        .where("isActive", "==", true)
        .get();

      for (const groupDoc of groupsSnap.docs) {
        const groupId = groupDoc.id;
        const groupData = groupDoc.data();
        const memberUids = groupData.activeMemberUids || [];

        // 각 멤버의 오늘 활동 집계
        const activityCounts: {[key: string]: number} = {};
        for (const uid of memberUids) {
          // TODO: 실제 활동 집계 로직
          // bondPosts, 투표, 리액션 등을 합산
          activityCounts[uid] = 0;
        }

        // 요약 메시지 생성
        const summaryMessage = generateSummaryMessage(activityCounts);
        const ctaMessage = "함께 마무리해볼까요?";

        // 저장
        await db
          .collection("partnerGroups")
          .doc(groupId)
          .collection("dailySummaries")
          .doc(dateKey)
          .set({
            dateKey,
            activityCounts,
            summaryMessage,
            ctaMessage,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
      }

      console.log(`✅ Daily summaries generated for ${dateKey}`);
    } catch (error) {
      console.error("⚠️ generateDailySummary error:", error);
    }
  });

/**
 * 전광판 만료 처리: 매시간 실행
 */
export const expireBillboardPosts = functions
  .pubsub.schedule("0 * * * *") // 매시간 0분
  .timeZone("Asia/Seoul")
  .onRun(async () => {
    try {
      const now = admin.firestore.Timestamp.now();

      const expiredSnap = await db
        .collection("billboardPosts")
        .where("status", "==", "confirmed")
        .where("expiresAt", "<=", now)
        .get();

      const batch = db.batch();
      expiredSnap.docs.forEach((doc) => {
        batch.update(doc.ref, {status: "expired"});
      });

      await batch.commit();
      console.log(`✅ Expired ${expiredSnap.size} billboard posts`);
    } catch (error) {
      console.error("⚠️ expireBillboardPosts error:", error);
    }
  });

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

function generateSummaryMessage(
  activityCounts: {[key: string]: number}
): string {
  const activeMembers = Object.values(activityCounts).filter(
    (c) => c >= 1
  ).length;

  switch (activeMembers) {
  case 3:
    return "오늘 우리 셋 다 움직였다 ✨";
  case 2:
    return "오늘은 두 명이 함께했다 🌙";
  case 1:
    return "오늘은 한 사람이 버텼다";
  default:
    return "오늘은 조용한 날 (내일 한 칸만 채워도 충분해)";
  }
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
}

/**
 * HIRA RSS 수집 (6시간마다)
 */
export const syncHiraUpdates = functions
  .pubsub.schedule("0 */6 * * *")
  .timeZone("Asia/Seoul")
  .onRun(async () => {
    try {
      const rssUrls = [
        {
          url: "https://www.hira.or.kr/rc/rss/rss_hira_act.xml",
          topic: "act",
        },
        {
          url: "https://www.hira.or.kr/rc/rss/rss_hira_notice.xml",
          topic: "notice",
        },
      ];

      let totalProcessed = 0;

      for (const {url, topic} of rssUrls) {
        try {
          const response = await axios.get(url, {timeout: 10000});
          const parsed = await parseStringPromise(response.data);
          const items = parsed.rss?.channel?.[0]?.item || [];

          for (const item of items) {
            const title = item.title?.[0] || "";
            const link = item.link?.[0] || "";
            const pubDate = item.pubDate?.[0] || "";

            if (!title || !link) continue;

            // docId = SHA-1(link)
            const docId = crypto
              .createHash("sha1")
              .update(link)
              .digest("hex");

            // 이미 존재하는지 확인
            const docRef = db.collection("content_hira_updates").doc(docId);
            const docSnap = await docRef.get();

            if (docSnap.exists) continue; // 이미 있으면 스킵

            // impactScore 계산
            const {score, keywords} = calculateImpactScore(title);
            const impactLevel = getImpactLevel(score);
            const actionHints = generateActionHints(title);

            // publishedAt 변환
            let publishedAt: admin.firestore.Timestamp;
            try {
              publishedAt = admin.firestore.Timestamp.fromDate(
                new Date(pubDate)
              );
            } catch {
              publishedAt = admin.firestore.Timestamp.now();
            }

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

      // 최근 14일 내 impactScore 높은 순 3개
      const snapshot = await db
        .collection("content_hira_updates")
        .where("publishedAt", ">=", fourteenDaysAgo)
        .orderBy("publishedAt", "desc")
        .orderBy("impactScore", "desc")
        .limit(3)
        .get();

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
      const rssUrls = [
        {
          url: "https://www.hira.or.kr/rc/rss/rss_hira_act.xml",
          topic: "act",
        },
        {
          url: "https://www.hira.or.kr/rc/rss/rss_hira_notice.xml",
          topic: "notice",
        },
      ];

      let totalProcessed = 0;
      const threeMonthsAgo = new Date();
      threeMonthsAgo.setMonth(threeMonthsAgo.getMonth() - 3);

      console.log(`📅 수집 시작: ${threeMonthsAgo.toISOString()} 이후 데이터`);

      for (const {url, topic} of rssUrls) {
        try {
          const response = await axios.get(url, {timeout: 15000});
          const parsed = await parseStringPromise(response.data);
          const items = parsed.rss?.channel?.[0]?.item || [];

          console.log(`📥 ${topic}: ${items.length}개 아이템 수신`);

          for (const item of items) {
            const title = item.title?.[0] || "";
            const link = item.link?.[0] || "";
            const pubDate = item.pubDate?.[0] || "";

            if (!title || !link) continue;

            // 3개월 이내 데이터만
            let publishedDate: Date;
            try {
              publishedDate = new Date(pubDate);
              if (publishedDate < threeMonthsAgo) continue;
            } catch {
              continue;
            }

            // docId = SHA-1(link)
            const docId = crypto
              .createHash("sha1")
              .update(link)
              .digest("hex");

            // 이미 존재하는지 확인
            const docRef = db.collection("content_hira_updates").doc(docId);
            const docSnap = await docRef.get();

            if (docSnap.exists) continue;

            // impactScore 계산
            const {score, keywords} = calculateImpactScore(title);
            const impactLevel = getImpactLevel(score);
            const actionHints = generateActionHints(title);

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

    const snapshot = await db
      .collection("content_hira_updates")
      .where("publishedAt", ">=", fourteenDaysAgo)
      .orderBy("publishedAt", "desc")
      .orderBy("impactScore", "desc")
      .limit(3)
      .get();

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
      if (!userData.response || userData.resultcode !== "00") {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "네이버 토큰 검증 실패",
          {errorCode: SocialLoginError.TOKEN_INVALID}
        );
      }

      const naverUser = userData.response;
      const naverId = naverUser.id;
      const email = naverUser.email || null;
      const displayName = naverUser.name || null;

      console.log(`✅ 네이버 토큰 검증 성공 (네이버ID: ${naverId})`);

      // ========== 6. Firebase UID 생성 (prefix로 충돌 방지) ==========
      const uid = `naver:${naverId}`;
      const legacyUid = `naver_${naverId}`; // 기존 형식

      // ========== 6-1. 기존 사용자 마이그레이션 체크 ==========
      try {
        const legacyUser = await admin.auth().getUser(legacyUid);
        if (legacyUser) {
          console.log(`⚠️ 기존 사용자 발견 (${legacyUid}), 하위 호환 유지`);
          // 기존 UID로 토큰 발급 (하위 호환성 유지)
          const customToken = await admin.auth().createCustomToken(legacyUid);
          
          // Firestore 업데이트
          await db.collection("users").doc(legacyUid).set({
            email: email || null,
            displayName: displayName || null,
            provider: "naver",
            providerId: naverId,
            lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {merge: true});

          console.log(`✅ 기존 사용자 로그인 완료 (UID: ${legacyUid})`);

          return {
            success: true,
            customToken,
            uid: legacyUid,
          };
        }
      } catch (error: any) {
        // 기존 사용자가 없으면 새 형식으로 생성
        console.log(`✅ 신규 사용자, 새 UID 형식 사용: ${uid}`);
      }

      // ========== 7. Firebase Auth 사용자 생성/업데이트 ==========
      const updateData: admin.auth.UpdateRequest = {};
      if (displayName) {
        updateData.displayName = displayName;
      }
      if (email && email.trim().length > 0) {
        updateData.email = email;
      }

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

      // ========== 8. Firestore users 컬렉션에 저장 ==========
      await db.collection("users").doc(uid).set({
        email: email || null,
        displayName: displayName || null,
        provider: "naver",
        providerId: naverId,
        lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});

      // ========== 9. Custom Token 발급 ==========
      const customToken = await admin.auth().createCustomToken(uid);

      console.log(`✅ 네이버 Custom Token 발급 완료 (UID: ${uid})`);

      return {
        success: true,
        customToken,
        uid,
      };
    } catch (error: any) {
      console.error("⚠️ verifyNaverToken error:", error.message);

      // ========== 10. 에러 분류 및 전달 ==========
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
      const uid = `kakao:${kakaoId}`;
      const legacyUid = `kakao_${kakaoId}`; // 기존 형식

      // ========== 6-1. 기존 사용자 마이그레이션 체크 ==========
      try {
        const legacyUser = await admin.auth().getUser(legacyUid);
        if (legacyUser) {
          console.log(`⚠️ 기존 사용자 발견 (${legacyUid}), 하위 호환 유지`);
          // 기존 UID로 토큰 발급 (하위 호환성 유지)
          const customToken = await admin.auth().createCustomToken(legacyUid);
          
          // Firestore 업데이트
          await db.collection("users").doc(legacyUid).set({
            email: email || null,
            displayName: displayName || null,
            provider: "kakao",
            providerId: kakaoId,
            lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {merge: true});

          console.log(`✅ 기존 사용자 로그인 완료 (UID: ${legacyUid})`);

          return {
            success: true,
            customToken,
            uid: legacyUid,
          };
        }
      } catch (error: any) {
        // 기존 사용자가 없으면 새 형식으로 생성
        console.log(`✅ 신규 사용자, 새 UID 형식 사용: ${uid}`);
      }

      // ========== 7. Firebase Auth 사용자 생성/업데이트 ==========
      const updateData: admin.auth.UpdateRequest = {};
      if (displayName) {
        updateData.displayName = displayName;
      }
      if (email && email.trim().length > 0) {
        updateData.email = email;
      }

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

      // ========== 8. Firestore users 컬렉션에 저장 ==========
      await db.collection("users").doc(uid).set({
        email: email || null,
        displayName: displayName || null,
        provider: "kakao",
        providerId: kakaoId,
        lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});

      // ========== 9. Custom Token 발급 ==========
      const customToken = await admin.auth().createCustomToken(uid);

      console.log(`✅ 카카오 Custom Token 발급 완료 (UID: ${uid})`);

      return {
        success: true,
        customToken,
        uid,
      };
    } catch (error: any) {
      console.error("⚠️ verifyKakaoToken error:", error.message);

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

// ========== 파트너 매칭 시스템 ==========
export {
  requestPartnerMatching,
  weeklyPartnerMatching,
  expirePartnerGroups,
} from "./partner-matching";

// ========== 주중 보충 매칭 ==========
export {
  onGroupMemberChanged,
  scheduledSupplementation,
} from "./partner-supplementation";

// ========== 계정 삭제 ==========
export { deleteMyAccount } from "./account-deletion";
