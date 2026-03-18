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
          // 작성자 닉네임 조회 (billboardPosts에 스냅샷으로 저장)
          const authorUid =
            postData.uid ||
            postData.authorUid ||
            postData.userId ||
            postData.authorId ||
            null;

          let authorNickname: string | null = null;
          if (authorUid) {
            try {
              const userDoc = await db.collection("users").doc(authorUid).get();
              if (userDoc.exists) {
                const u = userDoc.data() || {};
                authorNickname =
                  u.nickname || u.name || u.displayName || authorUid;
              } else {
                authorNickname = authorUid;
              }
            } catch (e) {
              console.log("⚠️ [onEnthroneCreated] 작성자 닉네임 조회 실패:", e);
              authorNickname = authorUid;
            }
          }

          // 7. 전광판에 등록
          const now = admin.firestore.Timestamp.now();
          const expiresAt = admin.firestore.Timestamp.fromMillis(
            Date.now() + 12 * 60 * 60 * 1000 // 12시간 후
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
            // 전국구 게시판에서는 닉네임을 보여주기 위해 기본 비익명 처리
            isAnonymous: false,
            authorId: authorUid,
            authorNickname: authorNickname,
            reactions: {},
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
      let resolvedUid = uid; // 기본값: kakao:{kakaoId}

      // 7-1. 먼저 kakao: UID로 기존 계정 존재 여부 확인
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

// ========== 소모임 나가기 ==========
export { leavePartnerGroup } from "./partner-leave";

// ========== 계정 삭제 ==========
export { deleteMyAccount } from "./account-deletion";

// ========== 행동 분석 일별 집계 ==========
export { aggregateAnalyticsDaily } from "./scheduled-analytics";

// ========== 구인공고: 이미지 → 폼 자동채우기 (AI Vision) ==========
/**
 * parseJobImagesToForm
 *
 * 공고 이미지 URL 목록을 받아 OpenAI Vision으로 폼 필드를 추출한다.
 * 현재는 Mock 구현. 실제 OpenAI 키 발급 후 아래 TODO 섹션 교체.
 *
 * Input  : { imageUrls: string[], jobId: string }
 * Output : { title, role, employmentType, workHours, salary,
 *            benefits, description, address, contact, clinicName }
 */
export const parseJobImagesToForm = functions
  .runWith({ timeoutSeconds: 60, memory: "512MB" })
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

    // ── TODO: OpenAI Vision 실제 연동 ──────────────────────────
    // const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
    // const response = await openai.chat.completions.create({ ... });
    // ────────────────────────────────────────────────────────────

    // ── Mock 응답 (이미지 분석 없이 샘플 반환) ──────────────────
    functions.logger.info("parseJobImagesToForm called (mock)", {
      uid: context.auth.uid,
      imageCount: imageUrls.length,
    });

    // 실제 연동 전까지 샘플 데이터 반환
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
      _message:
        "AI 자동입력은 OpenAI 키 연동 후 활성화됩니다. 현재는 Mock 모드입니다.",
    };

    return mockResult;
  });

// ========== 구인공고: 공고 생성 ==========
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

    const jobData = {
      createdBy: uid,
      clinicId,
      clinicName: String(data.clinicName ?? "").trim(),
      title: String(data.title ?? "").trim(),
      role: String(data.role ?? "").trim(),
      employmentType: String(data.employmentType ?? "").trim(),
      workHours: String(data.workHours ?? "").trim(),
      salary: String(data.salary ?? "").trim(),
      benefits: Array.isArray(data.benefits) ? data.benefits : [],
      description: String(data.description ?? "").trim(),
      address: String(data.address ?? "").trim(),
      contact: String(data.contact ?? "").trim(),
      images: Array.isArray(data.images) ? data.images : [],
      status: "pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const ref = await db.collection("jobs").add(jobData);

    functions.logger.info("createJobPosting", { uid, jobId: ref.id });

    return { jobId: ref.id, status: "pending" };
  }
);

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
// syncImwebPurchases (v4 - imweb_orders 통합)
// ================================================================
// 아임웹 구매내역을 Firestore users/{uid}/purchases/ 에 동기화한다.
//
// 전략:
//   A) imweb_orders 컬렉션 검색 (CSV 과거 주문 보관소)
//      - email + emailAliases 로 검색
//      - linkedUid == null 인 항목만 처리 (코드 필터)
//
//   B) 아임웹 API (최근 3개월, 신규 주문 감지)
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

            for (const prodOrder of prodOrderList) {
              const items = prodOrder["items"];
              if (!Array.isArray(items)) continue;

              for (const item of items) {
                const itemObj = item as Record<string, unknown>;
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
//   1. 완전 랜덤 선정 (order 무관)
//   2. 하루 2문제는 반드시 서로 다른 책(sourceBook)에서 1개씩
//   3. 현재 사이클에서 이미 출제된 문제는 제외 (usedQuizIds)
//   4. 각 책의 미출제 문제가 소진되면 → 사이클 증가, usedQuizIds 초기화
//
// Firestore 컬렉션:
//   quiz_pool/{autoId}          — 원본 문제 은행
//   quiz_schedule/{dateKey}     — 날짜별 배포 스케줄
//   quiz_meta/state             — 진행 상태
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

/**
 * 핵심 선정 로직:
 * quiz_pool에서 오늘의 2문제를 선정한다.
 *   - 각기 다른 책(sourceBook)에서 1문제씩
 *   - 현재 사이클 내에서 이미 출제된 문제(usedQuizIds) 제외
 *   - 미출제 문제 중 완전 랜덤 선택
 *   - 어느 책이든 미출제 문제가 없으면 사이클 증가 후 풀 전체 재사용
 */
async function pickTodayQuizzes(meta: FirebaseFirestore.DocumentData): Promise<{
  selectedDocs: FirebaseFirestore.QueryDocumentSnapshot[];
  nextCycleCount: number;
  nextUsedQuizIds: string[];
  wasReset: boolean;
}> {
  const usedQuizIds: string[]   = meta.usedQuizIds   ?? [];
  const cycleCount:  number     = meta.cycleCount     ?? 1;
  const bookRotation: string[]  = meta.bookRotation   ?? [];

  // ── 1. 전체 풀 조회 ──
  const poolSnap = await db
    .collection("quiz_pool")
    .where("isActive", "==", true)
    .get();

  const allDocs = poolSnap.docs;

  // ── 2. 사용 가능한 책 목록 추출 ──
  const bookSet = new Set(allDocs.map((d) => d.data().sourceBook as string));
  const books   = bookRotation.filter((b) => bookSet.has(b));
  // bookRotation에 없는 책도 포함
  bookSet.forEach((b) => { if (!books.includes(b)) books.push(b); });

  // ── 3. 각 책에서 미출제 문제 그룹화 ──
  const unusedByBook: Record<string, FirebaseFirestore.QueryDocumentSnapshot[]> = {};
  for (const book of books) {
    unusedByBook[book] = shuffleArray(
      allDocs.filter(
        (d) => d.data().sourceBook === book && !usedQuizIds.includes(d.id)
      )
    );
  }

  // ── 4. 서로 다른 책에서 1문제씩 선정 ──
  //    books 중 미출제 문제가 있는 책 2개를 우선 선택 (셔플로 매일 다른 조합)
  const shuffledBooks = shuffleArray(books);
  const selected: FirebaseFirestore.QueryDocumentSnapshot[] = [];
  const usedBooksToday: string[] = [];

  for (const book of shuffledBooks) {
    if (selected.length >= 2) break;
    const candidates = unusedByBook[book];
    if (candidates && candidates.length > 0) {
      selected.push(candidates[0]);
      usedBooksToday.push(book);
    }
  }

  // ── 5. 사이클 소진 처리 ──
  //    2문제를 채우지 못하면(어느 책이든 미출제 문제 없음) → 사이클 초기화
  let wasReset     = false;
  let nextCycle    = cycleCount;
  let nextUsedIds  = [...usedQuizIds];

  if (selected.length < 2) {
    functions.logger.info("🔄 풀 소진 → 사이클 증가 및 usedQuizIds 초기화", {
      cycleCount: cycleCount + 1,
    });
    wasReset   = true;
    nextCycle  = cycleCount + 1;
    nextUsedIds = [];

    // 초기화 후 재선정
    const freshSelected: FirebaseFirestore.QueryDocumentSnapshot[] = [];
    const freshShuffled = shuffleArray(books);
    for (const book of freshShuffled) {
      if (freshSelected.length >= 2) break;
      const freshCandidates = shuffleArray(
        allDocs.filter((d) => d.data().sourceBook === book)
      );
      if (freshCandidates.length > 0) {
        freshSelected.push(freshCandidates[0]);
      }
    }
    selected.splice(0, selected.length, ...freshSelected);
  }

  // 선정된 문제를 usedQuizIds에 추가
  nextUsedIds = [...new Set([...nextUsedIds, ...selected.map((d) => d.id)])];

  return {
    selectedDocs:    selected,
    nextCycleCount:  nextCycle,
    nextUsedQuizIds: nextUsedIds,
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

    // ── 이미 생성됐으면 스킵 ──
    if ((await scheduleRef.get()).exists) {
      functions.logger.info("⏭️ 이미 스케줄 생성됨", { dateKey });
      return null;
    }

    // ── meta 조회 ──
    const metaDoc  = await metaRef.get();
    const meta     = metaDoc.exists ? metaDoc.data()! : {};
    const dailyCount: number = meta.dailyCount ?? 2;

    // ── 오늘의 문제 선정 ──
    const { selectedDocs, nextCycleCount, nextUsedQuizIds, wasReset } =
      await pickTodayQuizzes(meta);

    if (selectedDocs.length === 0) {
      functions.logger.warn("⚠️ 선정된 문제 없음 — quiz_pool을 확인하세요");
      return null;
    }

    const quizIds = selectedDocs.map((d) => d.id);
    const items   = selectedDocs.map((d) => ({
      id:             d.id,
      order:          d.data().order          ?? 0,
      question:       d.data().question       ?? "",
      options:        d.data().options        ?? [],
      correctIndex:   d.data().correctIndex   ?? 0,
      explanation:    d.data().explanation    ?? "",
      category:       d.data().category       ?? "",
      difficulty:     d.data().difficulty     ?? "basic",
      sourceBook:     d.data().sourceBook     ?? "",
      sourceFileName: d.data().sourceFileName ?? "",
      sourcePage:     d.data().sourcePage     ?? "",
      isActive:       true,
      lastCycleServed: nextCycleCount,
    }));

    // ── quiz_schedule/{dateKey} 저장 ──
    await scheduleRef.set({
      quizIds,
      items,
      cycleCount:  nextCycleCount,
      startOrder:  items[0].order,
      endOrder:    items[items.length - 1].order,
      createdAt:   admin.firestore.FieldValue.serverTimestamp(),
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
    const poolSnap     = await db.collection("quiz_pool").where("isActive", "==", true).get();
    const totalActive  = poolSnap.size;

    await metaRef.set({
      cycleCount:         nextCycleCount,
      totalActiveCount:   totalActive,
      lastScheduledDate:  dateKey,
      dailyCount,
      usedQuizIds:        nextUsedQuizIds,
    }, { merge: true });

    functions.logger.info("✅ scheduleQuizzes 완료", {
      dateKey,
      quizIds,
      books: selectedDocs.map((d) => d.data().sourceBook),
      wasReset,
      cycleCount: nextCycleCount,
      usedCount:  nextUsedQuizIds.length,
      totalActive,
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

    const { selectedDocs, nextCycleCount, nextUsedQuizIds, wasReset } =
      await pickTodayQuizzes(meta);

    if (selectedDocs.length === 0) {
      return { success: false, message: "quiz_pool에 활성화된 문제 없음" };
    }

    const quizIds = selectedDocs.map((d) => d.id);
    const items   = selectedDocs.map((d) => ({
      id:             d.id,
      order:          d.data().order          ?? 0,
      question:       d.data().question       ?? "",
      options:        d.data().options        ?? [],
      correctIndex:   d.data().correctIndex   ?? 0,
      explanation:    d.data().explanation    ?? "",
      category:       d.data().category       ?? "",
      difficulty:     d.data().difficulty     ?? "basic",
      sourceBook:     d.data().sourceBook     ?? "",
      sourceFileName: d.data().sourceFileName ?? "",
      sourcePage:     d.data().sourcePage     ?? "",
      isActive:       true,
      lastCycleServed: nextCycleCount,
    }));

    await scheduleRef.set({
      quizIds,
      items,
      cycleCount:  nextCycleCount,
      startOrder:  items[0].order,
      endOrder:    items[items.length - 1].order,
      createdAt:   admin.firestore.FieldValue.serverTimestamp(),
    });

    const batch = db.batch();
    for (const doc of selectedDocs) {
      batch.update(doc.ref, {
        lastCycleServed: nextCycleCount,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    const poolSnap    = await db.collection("quiz_pool").where("isActive", "==", true).get();
    const totalActive = poolSnap.size;

    await metaRef.set({
      cycleCount:        nextCycleCount,
      totalActiveCount:  totalActive,
      lastScheduledDate: dateKey,
      dailyCount,
      usedQuizIds:       nextUsedQuizIds,
    }, { merge: true });

    return {
      success: true,
      dateKey,
      quizIds,
      books:   selectedDocs.map((d) => d.data().sourceBook),
      wasReset,
      message: `${dateKey} 스케줄 생성 완료 (${quizIds.length}문제, ${wasReset ? "사이클 초기화" : "정상"})`,
    };
  });
