/**
 * 사용자 검색·상세·플래그 토글 — 어드민 전용 callable.
 *
 * ── 설계 ────────────────────────────────────────────────────────
 * 1. **검색 전략 (3단계 자동 분기)**
 *    a) 입력이 28자 alphanumeric → uid 정확 매칭 (단일 doc.get)
 *    b) 입력이 이메일 형식       → Firebase Auth.getUserByEmail
 *    c) 그 외                    → users.nickname prefix 매칭 (limit 20)
 *
 * 2. **PII 마스킹 정책**
 *    - 응답에서 email 은 마스킹된 형태로만 노출 (`p***@gmail.com`)
 *    - 감사 로그의 args 에 query 원문을 그대로 남기지 않고 길이만 기록
 *
 * 3. **플래그 토글 안전장치**
 *    - flag === 'isAdmin' 인 경우 destructive: true 로 감사 로그 마킹
 *    - 자기 자신의 isAdmin 을 끄려고 하면 distress 잠금 방지를 위해 거부
 *
 * 4. **부분 실패 허용**
 *    - 상세 페이지의 5개 위젯(profile / auth / recentActivity / moderation /
 *      billing) 은 개별 try/catch 로 감싼다. 한 위젯 실패해도 다른 위젯은 표시.
 * ────────────────────────────────────────────────────────────────
 */
import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";

import {adminCallable} from "./_adminGuard";

const getDb = (): admin.firestore.Firestore => admin.firestore();
const getAuth = (): admin.auth.Auth => admin.auth();

// ── 공통 타입 ───────────────────────────────────────────────────

export interface UserSearchHit {
  uid: string;
  nickname: string | null;
  email: string | null; // 마스킹된 형태
  region: string | null;
  careerGroup: string | null;
  isAdmin: boolean;
  excludeFromStats: boolean;
  createdAtMs: number | null;
  matchedBy: "uid" | "email" | "nickname";
}

// ── adminSearchUsers ────────────────────────────────────────────

interface SearchInput {
  query?: string;
}

interface SearchOutput {
  items: UserSearchHit[];
  matchedBy: "uid" | "email" | "nickname" | "none";
}

export const adminSearchUsers = adminCallable<SearchInput, SearchOutput>(
  {
    name: "adminSearchUsers",
    logArgs: (i) => ({queryLen: (i?.query ?? "").length}),
  },
  async (input) => {
    const raw = String(input?.query ?? "").trim();
    if (raw.length === 0) {
      return {items: [], matchedBy: "none"};
    }

    // (a) uid 정확 매칭
    if (looksLikeUid(raw)) {
      const doc = await getDb().collection("users").doc(raw).get();
      if (doc.exists) {
        const hit = await projectUserHit(doc.id, doc.data() ?? {}, "uid");
        return {items: [hit], matchedBy: "uid"};
      }
    }

    // (b) email 형식 → auth.getUserByEmail
    if (looksLikeEmail(raw)) {
      try {
        const user = await getAuth().getUserByEmail(raw);
        const doc = await getDb().collection("users").doc(user.uid).get();
        const hit = await projectUserHit(
          user.uid,
          doc.data() ?? {},
          "email",
          user.email,
        );
        return {items: [hit], matchedBy: "email"};
      } catch (err) {
        // 등록되지 않은 이메일 → 빈 결과
        if ((err as {code?: string}).code === "auth/user-not-found") {
          return {items: [], matchedBy: "email"};
        }
        throw err;
      }
    }

    // (c) nickname prefix
    const upperBound = raw + "\uf8ff";
    const snap = await getDb()
      .collection("users")
      .where("nickname", ">=", raw)
      .where("nickname", "<=", upperBound)
      .orderBy("nickname")
      .limit(20)
      .get();
    const items: UserSearchHit[] = [];
    for (const d of snap.docs) {
      items.push(await projectUserHit(d.id, d.data() ?? {}, "nickname"));
    }
    return {items, matchedBy: "nickname"};
  },
);

// ── adminGetUserDetail ──────────────────────────────────────────

interface DetailInput {
  targetUid: string;
}

interface UserActivityEntry {
  type: string;
  timestampMs: number | null;
  meta: Record<string, unknown>;
}

interface UserModerationStats {
  reportedAgainstCount: number;
  hiddenPostCount: number;
}

interface UserBillingStats {
  paidCount: number;
  paidAmountKrw: number;
  refundCount: number;
  lastPaidAtMs: number | null;
}

interface DetailOutput {
  profile: Record<string, unknown>;
  auth: {
    email: string | null;
    emailVerified: boolean;
    disabled: boolean;
    providers: string[];
    lastSignInMs: number | null;
    createdAtMs: number | null;
  } | null;
  recentActivity: UserActivityEntry[];
  moderation: UserModerationStats | null;
  billing: UserBillingStats | null;
  partialErrors: string[];
}

export const adminGetUserDetail = adminCallable<DetailInput, DetailOutput>(
  {
    name: "adminGetUserDetail",
    logArgs: (i) => ({targetUid: i?.targetUid ?? ""}),
    resolveTarget: (i) => i?.targetUid ?? null,
  },
  async (input) => {
    const uid = String(input?.targetUid ?? "").trim();
    if (!looksLikeUid(uid)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "targetUid 가 유효하지 않습니다.",
      );
    }
    const db = getDb();
    const partialErrors: string[] = [];

    // 1) profile
    let profile: Record<string, unknown> = {};
    try {
      const doc = await db.collection("users").doc(uid).get();
      if (!doc.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "해당 사용자를 찾을 수 없습니다.",
        );
      }
      profile = sanitizeProfile(doc.data() ?? {});
    } catch (err) {
      if (err instanceof functions.https.HttpsError) throw err;
      console.error("adminGetUserDetail profile failed", err);
      partialErrors.push("profile");
    }

    // 2) auth
    let authInfo: DetailOutput["auth"] = null;
    try {
      const u = await getAuth().getUser(uid);
      authInfo = {
        email: u.email ? maskEmail(u.email) : null,
        emailVerified: u.emailVerified,
        disabled: u.disabled,
        providers: u.providerData.map((p) => p.providerId),
        lastSignInMs: u.metadata.lastSignInTime ?
          Date.parse(u.metadata.lastSignInTime) :
          null,
        createdAtMs: u.metadata.creationTime ?
          Date.parse(u.metadata.creationTime) :
          null,
      };
    } catch (err) {
      console.error("adminGetUserDetail auth failed", err);
      partialErrors.push("auth");
    }

    // 3) recent activity (최근 50건)
    const recentActivity: UserActivityEntry[] = [];
    try {
      const snap = await db
        .collection("activityLogs")
        .where("userId", "==", uid)
        .orderBy("timestamp", "desc")
        .limit(50)
        .get();
      for (const d of snap.docs) {
        const data = d.data();
        const ts = data.timestamp;
        recentActivity.push({
          type: String(data.type ?? ""),
          timestampMs: ts && typeof ts.toMillis === "function" ?
            ts.toMillis() :
            null,
          meta: {
            screen: data.screen ?? null,
            accountType: data.accountType ?? null,
            isFunnel: data.isFunnel === true,
          },
        });
      }
    } catch (err) {
      console.error("adminGetUserDetail activity failed", err);
      partialErrors.push("recentActivity");
    }

    // 4) moderation stats
    let moderation: UserModerationStats | null = null;
    try {
      // 본인이 작성한 글 중 isHidden 인 것
      const hiddenSnap = await db
        .collection("bondPosts")
        .where("uid", "==", uid)
        .where("isHidden", "==", true)
        .count()
        .get();
      // 본인이 작성한 글 중 reports > 0 인 것 (대략 신고당한 횟수의 하한)
      const reportedSnap = await db
        .collection("bondPosts")
        .where("uid", "==", uid)
        .where("reports", ">", 0)
        .count()
        .get();
      moderation = {
        hiddenPostCount: hiddenSnap.data().count ?? 0,
        reportedAgainstCount: reportedSnap.data().count ?? 0,
      };
    } catch (err) {
      console.error("adminGetUserDetail moderation failed", err);
      partialErrors.push("moderation");
    }

    // 5) billing stats — billingEvents 본인분 합산
    let billing: UserBillingStats | null = null;
    try {
      const snap = await db
        .collection("billingEvents")
        .where("ownerUid", "==", uid)
        .orderBy("happenedAt", "desc")
        .limit(200)
        .get();
      let paidCount = 0;
      let paidAmount = 0;
      let refundCount = 0;
      let lastPaid: number | null = null;
      for (const d of snap.docs) {
        const data = d.data();
        const t = String(data.type ?? "");
        const amount = Number(data.amount) || 0;
        if (
          [
            "order_paid",
            "order_paid_extend",
            "order_paid_upgrade",
            "auto_renewed",
          ].includes(t) &&
          amount > 0
        ) {
          paidCount += 1;
          paidAmount += amount;
          const h = data.happenedAt;
          if (h && typeof h.toMillis === "function" && lastPaid === null) {
            lastPaid = h.toMillis();
          }
        } else if (t === "order_refunded") {
          refundCount += 1;
        }
      }
      billing = {
        paidCount,
        paidAmountKrw: paidAmount,
        refundCount,
        lastPaidAtMs: lastPaid,
      };
    } catch (err) {
      console.error("adminGetUserDetail billing failed", err);
      partialErrors.push("billing");
    }

    return {
      profile,
      auth: authInfo,
      recentActivity,
      moderation,
      billing,
      partialErrors,
    };
  },
);

// ── adminToggleUserFlag ─────────────────────────────────────────

interface ToggleInput {
  targetUid: string;
  flag: "excludeFromStats" | "isAdmin";
  value: boolean;
}

interface ToggleOutput {
  success: boolean;
  flag: string;
  newValue: boolean;
}

export const adminToggleUserFlag = adminCallable<ToggleInput, ToggleOutput>(
  {
    name: "adminToggleUserFlag",
    destructive: true, // isAdmin 토글은 매우 민감 → 모든 토글을 파괴적으로 기록
    logArgs: (i) => ({
      targetUid: i?.targetUid ?? "",
      flag: i?.flag ?? "",
      value: i?.value === true,
    }),
    resolveTarget: (i) => i?.targetUid ?? null,
  },
  async (input, ctx) => {
    const uid = String(input?.targetUid ?? "").trim();
    const flag = input?.flag;
    const value = input?.value === true;

    if (!looksLikeUid(uid)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "targetUid 가 유효하지 않습니다.",
      );
    }
    if (flag !== "excludeFromStats" && flag !== "isAdmin") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "지원하지 않는 flag 입니다.",
      );
    }

    // 자기 자신의 isAdmin 을 끄려는 시도는 잠금 방지를 위해 거부
    if (flag === "isAdmin" && value === false && uid === ctx.uid) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "본인의 isAdmin 권한은 본인이 해제할 수 없습니다.",
      );
    }

    await getDb().collection("users").doc(uid).set({
      [flag]: value,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    return {success: true, flag, newValue: value};
  },
);

// ── 내부 헬퍼 ──────────────────────────────────────────────────

function looksLikeUid(s: string): boolean {
  // Firebase UID 는 일반적으로 28자 alphanumeric 이지만 변경 가능성 대비 16~64자 허용
  return /^[A-Za-z0-9]{16,64}$/.test(s);
}

function looksLikeEmail(s: string): boolean {
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(s);
}

function maskEmail(email: string): string {
  const [local, domain] = email.split("@");
  if (!local || !domain) return email;
  if (local.length <= 1) return `*@${domain}`;
  if (local.length === 2) return `${local[0]}*@${domain}`;
  return `${local[0]}${"*".repeat(local.length - 2)}${local[local.length - 1]}@${domain}`;
}

function sanitizeProfile(d: Record<string, unknown>): Record<string, unknown> {
  // 클라이언트(어드민)에 안전하게 노출할 수 있는 필드 화이트리스트
  const allowList = [
    "nickname",
    "region",
    "careerGroup",
    "careerBucket",
    "mainConcerns",
    "isProfileCompleted",
    "isAdmin",
    "excludeFromStats",
    "lastLoginAt",
  ];
  const out: Record<string, unknown> = {};
  for (const k of allowList) {
    if (d[k] !== undefined) out[k] = d[k];
  }
  // timestamp → millis 변환
  const createdAt = d["createdAt"];
  if (createdAt && typeof (createdAt as admin.firestore.Timestamp).toMillis ===
      "function") {
    out["createdAtMs"] = (createdAt as admin.firestore.Timestamp).toMillis();
  }
  const updatedAt = d["updatedAt"];
  if (updatedAt && typeof (updatedAt as admin.firestore.Timestamp).toMillis ===
      "function") {
    out["updatedAtMs"] = (updatedAt as admin.firestore.Timestamp).toMillis();
  }
  return out;
}

async function projectUserHit(
  uid: string,
  data: Record<string, unknown>,
  matchedBy: "uid" | "email" | "nickname",
  email?: string | null,
): Promise<UserSearchHit> {
  let resolvedEmail: string | null = email ?? null;
  if (!resolvedEmail) {
    try {
      const u = await getAuth().getUser(uid);
      resolvedEmail = u.email ?? null;
    } catch {
      resolvedEmail = null;
    }
  }
  const createdAt = data["createdAt"];
  return {
    uid,
    nickname: typeof data.nickname === "string" ? data.nickname : null,
    email: resolvedEmail ? maskEmail(resolvedEmail) : null,
    region: typeof data.region === "string" ? data.region : null,
    careerGroup: typeof data.careerGroup === "string" ?
      data.careerGroup :
      null,
    isAdmin: data.isAdmin === true,
    excludeFromStats: data.excludeFromStats === true,
    createdAtMs: createdAt &&
      typeof (createdAt as admin.firestore.Timestamp).toMillis === "function" ?
      (createdAt as admin.firestore.Timestamp).toMillis() :
      null,
    matchedBy,
  };
}
