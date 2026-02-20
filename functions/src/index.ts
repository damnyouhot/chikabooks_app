import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import axios from "axios";
import {parseStringPromise} from "xml2js";
import * as crypto from "crypto";

admin.initializeApp();
const db = admin.firestore();

/**
 * 추대 트리거: enthrone 서브컬렉션에 문서 생성 시
 * 조건 충족 시 billboardPosts에 등재
 */
export const onEnthroneCreated = functions
  .firestore.document("bondGroups/{bondId}/posts/{postId}/enthrones/{uid}")
  .onCreate(async (snap, context) => {
    const {bondId, postId} = context.params as {
      bondId: string;
      postId: string;
    };

    try {
      // 1. 현재 추대 수 집계
      const enthronesSnap = await snap.ref.parent.get();
      const enthroneCount = enthronesSnap.size;

      // 2. Bond 그룹 멤버 수 확인
      const bondDoc = await db.doc(`bondGroups/${bondId}`).get();
      const bondData = bondDoc.data();
      const activeMemberUids = bondData?.activeMemberUids || [];
      const activeMemberCount = activeMemberUids.length;

      // 3. 필요 추대 수 (최소 2, 최대 3)
      const requiredCount = Math.max(2, activeMemberCount);

      // 4. 조건 충족 확인
      if (enthroneCount >= requiredCount) {
        // 5. 원본 게시물 가져오기
        const postDoc = await db
          .doc(`bondGroups/${bondId}/posts/${postId}`)
          .get();
        const postData = postDoc.data();

        // 6. 게시 조건 확인
        if (
          postData &&
          postData.publicEligible !== false &&
          !postData.isDeleted &&
          (postData.reports || 0) < 3
        ) {
          // 7. 전광판에 등재
          await db.collection("billboardPosts").add({
            sourceBondId: bondId,
            sourcePostId: postId,
            textSnapshot: postData.text || "",
            enthroneCount: enthroneCount,
            requiredCount: requiredCount,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            expiresAt: admin.firestore.Timestamp.fromMillis(
              Date.now() + 48 * 60 * 60 * 1000 // 48시간
            ),
            status: "confirmed",
            bondGroupName: bondData?.title || "결",
            isAnonymous: true,
          });

          console.log(
            `✅ Billboard post created: ${bondId}/${postId}`
          );
        }
      }
    } catch (error) {
      console.error("⚠️ onEnthroneCreated error:", error);
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
      await admin.auth().updateUser(uid, {
        displayName: displayName || null,
        email: email || null,
      }).catch(async () => {
        // 사용자가 없으면 새로 생성
        await admin.auth().createUser({
          uid,
          displayName: displayName || null,
          email: email || null,
        });
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
