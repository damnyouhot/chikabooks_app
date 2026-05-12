/**
 * 모더레이션 큐 — 어드민이 신고 누적·자동 숨김 게시물을 검토/조치하는 callable.
 *
 * ── 설계 ────────────────────────────────────────────────────────
 * 1. 별도 큐 컬렉션을 두지 않는다. `bondPosts` 와 `partnerGroups/{groupId}/posts`
 *    에 이미 `reports`, `isHidden`, `hiddenReason`, `hiddenAt`,
 *    `lastReportedAt`, `lastReportReason` 필드가 적재되므로 collectionGroup
 *    쿼리만으로 큐를 재구성한다.
 *
 * 2. **읽기 권한 우회**: 신고 서브컬렉션(`/reports/{uid}`) 은 본인만 읽을 수
 *    있어 클라이언트에서 어드민이라도 직접 조회할 수 없다. callable 안에서
 *    `admin.firestore()` (Admin SDK) 가 룰을 우회해 신고자 목록을 가져온다.
 *
 * 3. **세 callable**:
 *    - `adminListReportedPosts`  : 모더레이션 대상 게시물 리스트
 *    - `adminGetReportedItem`    : 단건 본문 + 신고자/사유 리스트
 *    - `adminResolveReportedPost`: 복구 / 영구삭제 / 숨김유지 결정
 *
 * 4. 모든 액션은 `adminCallable` 래퍼로 감싸 자동으로 `adminAuditLog` 적재.
 *    파괴적 액션(영구삭제) 은 `destructive: true` 마킹.
 * ────────────────────────────────────────────────────────────────
 */
import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";

import {adminCallable} from "./_adminGuard";

const getDb = (): admin.firestore.Firestore => admin.firestore();

const MAX_LIST_LIMIT = 100;
const DEFAULT_LIST_LIMIT = 30;

export type ModerationFilter = "all" | "hidden_only" | "reported_only";

export interface ReportedPostSummary {
  documentPath: string;
  documentType: "bondPost" | "partnerPost";
  authorUid: string;
  preview: string;
  reportCount: number;
  isHidden: boolean;
  hiddenReason: string | null;
  hiddenAtMs: number | null;
  lastReportedAtMs: number | null;
  lastReportReason: string | null;
  createdAtMs: number | null;
}

export interface ReportEntry {
  reporterUid: string;
  reason: string;
  reasonDisplay: string;
  additionalInfo: string | null;
  createdAtMs: number | null;
}

interface ListInput {
  filter?: ModerationFilter;
  limit?: number;
}

interface ListOutput {
  items: ReportedPostSummary[];
  partialErrors: string[];
}

export const adminListReportedPosts = adminCallable<ListInput, ListOutput>(
  {
    name: "adminListReportedPosts",
    logArgs: (i) => ({filter: i?.filter ?? "all", limit: i?.limit ?? null}),
  },
  async (input) => {
    const filter: ModerationFilter = input?.filter ?? "all";
    const requestedLimit = Number(input?.limit) || DEFAULT_LIST_LIMIT;
    const limit = Math.min(Math.max(requestedLimit, 1), MAX_LIST_LIMIT);
    const db = getDb();
    const items: ReportedPostSummary[] = [];
    const partialErrors: string[] = [];

    // 1) bondPosts — 전국 게시판
    try {
      const snap = await buildQuery(
        db.collection("bondPosts"),
        filter,
        limit,
      ).get();
      for (const doc of snap.docs) {
        items.push(summarizeBondPost(doc));
      }
    } catch (err) {
      console.error("adminListReportedPosts bondPosts failed", err);
      partialErrors.push("bondPosts");
    }

    // 2) partnerGroups/*/posts — 그룹 게시판 (collectionGroup)
    try {
      const snap = await buildQuery(
        db.collectionGroup("posts"),
        filter,
        limit,
      ).get();
      for (const doc of snap.docs) {
        // collectionGroup('posts') 는 partnerGroups 외 다른 위치의 posts 도
        // 매치될 수 있으므로 경로로 한 번 더 필터한다.
        if (!doc.ref.path.startsWith("partnerGroups/")) continue;
        items.push(summarizePartnerPost(doc));
      }
    } catch (err) {
      console.error("adminListReportedPosts partnerPosts failed", err);
      partialErrors.push("partnerPosts");
    }

    // 정렬: 최근 신고 시각 → 신고 누적 → 작성 시각 역순
    items.sort((a, b) => {
      const at = a.lastReportedAtMs ?? a.createdAtMs ?? 0;
      const bt = b.lastReportedAtMs ?? b.createdAtMs ?? 0;
      if (bt !== at) return bt - at;
      if (b.reportCount !== a.reportCount) {
        return b.reportCount - a.reportCount;
      }
      return (b.createdAtMs ?? 0) - (a.createdAtMs ?? 0);
    });

    return {items: items.slice(0, limit), partialErrors};
  },
);

interface GetInput {
  documentPath: string;
}

interface GetOutput {
  summary: ReportedPostSummary;
  body: string;
  imageUrls: string[];
  reports: ReportEntry[];
  metadata: Record<string, unknown>;
}

export const adminGetReportedItem = adminCallable<GetInput, GetOutput>(
  {
    name: "adminGetReportedItem",
    logArgs: (i) => ({documentPath: i?.documentPath ?? ""}),
    resolveTarget: (i) => i?.documentPath ?? null,
  },
  async (input) => {
    const path = String(input?.documentPath ?? "").trim();
    assertSupportedPath(path);

    const db = getDb();
    const docRef = db.doc(path);
    const docSnap = await docRef.get();
    if (!docSnap.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "해당 게시물이 존재하지 않습니다.",
      );
    }

    const data = docSnap.data() ?? {};
    const summary = path.startsWith("bondPosts/") ?
      summarizeBondPost(
        docSnap as admin.firestore.QueryDocumentSnapshot,
      ) :
      summarizePartnerPost(
        docSnap as admin.firestore.QueryDocumentSnapshot,
      );

    // 신고자 리스트 (작성순)
    const reports: ReportEntry[] = [];
    try {
      const reportsSnap = await docRef
        .collection("reports")
        .orderBy("createdAt", "asc")
        .limit(200)
        .get();
      for (const r of reportsSnap.docs) {
        const rd = r.data();
        reports.push({
          reporterUid: String(rd.reporterUid ?? r.id),
          reason: String(rd.reason ?? ""),
          reasonDisplay: String(rd.reasonDisplay ?? ""),
          additionalInfo: rd.additionalInfo ?
            String(rd.additionalInfo) :
            null,
          createdAtMs: timestampMs(rd.createdAt),
        });
      }
    } catch (err) {
      console.error("adminGetReportedItem reports fetch failed", err);
      // reports 가 비어 있더라도 본문은 보여줘야 하므로 throw 하지 않는다.
    }

    const imageUrls = Array.isArray(data.imageUrls) ?
      data.imageUrls.map((u: unknown) => String(u ?? "")) :
      [];

    const safeMeta: Record<string, unknown> = {
      uid: data.uid ?? null,
      createdAt: timestampMs(data.createdAt) ?? timestampMs(data.timestamp),
      updatedAt: timestampMs(data.updatedAt),
      likeCount: data.likeCount ?? null,
      commentCount: data.commentCount ?? null,
      moderation: data.moderation ?? null,
    };

    return {
      summary,
      body: String(data.text ?? data.content ?? data.body ?? ""),
      imageUrls,
      reports,
      metadata: safeMeta,
    };
  },
);

interface ResolveInput {
  documentPath: string;
  action: "restore" | "permanent_delete" | "keep_hidden";
  note?: string;
}

interface ResolveOutput {
  success: boolean;
  message: string;
  documentPath: string;
  action: string;
}

export const adminResolveReportedPost = adminCallable<
  ResolveInput,
  ResolveOutput
>(
  {
    name: "adminResolveReportedPost",
    destructive: true,
    logArgs: (i) => ({
      documentPath: i?.documentPath ?? "",
      action: i?.action ?? "",
      hasNote: typeof i?.note === "string" && (i?.note as string).length > 0,
    }),
    resolveTarget: (i) => i?.documentPath ?? null,
  },
  async (input, ctx) => {
    const path = String(input?.documentPath ?? "").trim();
    const action = input?.action;
    if (!action || !["restore", "permanent_delete", "keep_hidden"]
      .includes(action)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "action 값이 유효하지 않습니다.",
      );
    }
    assertSupportedPath(path);

    const note = typeof input?.note === "string" ?
      (input.note as string).slice(0, 500) :
      null;

    const db = getDb();
    const docRef = db.doc(path);
    const snap = await docRef.get();
    if (!snap.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "이미 삭제된 게시물입니다.",
      );
    }

    const now = admin.firestore.FieldValue.serverTimestamp();
    const moderationStamp = {
      reviewedBy: ctx.uid,
      reviewedAt: now,
      action,
      note: note ?? null,
    };

    if (action === "permanent_delete") {
      // 신고 서브컬렉션부터 정리 후 본 문서 삭제 (배치).
      // reports 외 다른 서브컬렉션(likes, comments 등) 은 클라이언트가
      // 더 이상 닿지 못하므로 그대로 두어도 안전하지만, 향후 정리 작업
      // 단순화를 위해 reports 만 명시적으로 비운다.
      try {
        const reports = await docRef.collection("reports").get();
        const batch = db.batch();
        for (const r of reports.docs) batch.delete(r.ref);
        if (!reports.empty) await batch.commit();
      } catch (err) {
        console.error("adminResolveReportedPost reports cleanup failed", err);
      }
      await docRef.delete();
      return {
        success: true,
        message: "게시물을 영구 삭제했습니다.",
        documentPath: path,
        action,
      };
    }

    if (action === "restore") {
      await docRef.update({
        isHidden: false,
        hiddenReason: admin.firestore.FieldValue.delete(),
        restoredAt: now,
        moderation: moderationStamp,
      });
      return {
        success: true,
        message: "숨김을 해제했습니다.",
        documentPath: path,
        action,
      };
    }

    // keep_hidden — 숨김은 유지하되 검토 완료 마킹
    await docRef.update({
      isHidden: true,
      hiddenReason: snap.data()?.hiddenReason ?? "manual_keep_hidden",
      moderation: moderationStamp,
    });
    return {
      success: true,
      message: "숨김을 유지하고 검토 완료로 기록했습니다.",
      documentPath: path,
      action,
    };
  },
);

// ── 내부 헬퍼 ──────────────────────────────────────────────────

function buildQuery(
  base: admin.firestore.Query,
  filter: ModerationFilter,
  limit: number,
): admin.firestore.Query {
  let q = base;
  if (filter === "hidden_only") {
    q = q.where("isHidden", "==", true).orderBy("hiddenAt", "desc");
  } else {
    // 'all' / 'reported_only' 모두 reports > 0 으로 좁힌다.
    // 전체 게시물을 스캔하면 N+1·비용·페이지네이션 모두 문제.
    q = q.where("reports", ">", 0).orderBy("reports", "desc");
  }
  return q.limit(limit);
}

function summarizeBondPost(
  doc: admin.firestore.QueryDocumentSnapshot |
    admin.firestore.DocumentSnapshot,
): ReportedPostSummary {
  const data = doc.data() ?? {};
  return {
    documentPath: doc.ref.path,
    documentType: "bondPost",
    authorUid: stringOr(data.uid, ""),
    preview: truncate(stringOr(data.text, "")),
    reportCount: toInt(data.reports),
    isHidden: data.isHidden === true,
    hiddenReason: data.hiddenReason ? String(data.hiddenReason) : null,
    hiddenAtMs: timestampMs(data.hiddenAt),
    lastReportedAtMs: timestampMs(data.lastReportedAt),
    lastReportReason: data.lastReportReason ?
      String(data.lastReportReason) :
      null,
    createdAtMs: timestampMs(data.createdAt) ?? timestampMs(data.timestamp),
  };
}

function summarizePartnerPost(
  doc: admin.firestore.QueryDocumentSnapshot |
    admin.firestore.DocumentSnapshot,
): ReportedPostSummary {
  const data = doc.data() ?? {};
  return {
    documentPath: doc.ref.path,
    documentType: "partnerPost",
    authorUid: stringOr(data.uid ?? data.authorUid, ""),
    preview: truncate(stringOr(data.text ?? data.content, "")),
    reportCount: toInt(data.reports),
    isHidden: data.isHidden === true,
    hiddenReason: data.hiddenReason ? String(data.hiddenReason) : null,
    hiddenAtMs: timestampMs(data.hiddenAt),
    lastReportedAtMs: timestampMs(data.lastReportedAt),
    lastReportReason: data.lastReportReason ?
      String(data.lastReportReason) :
      null,
    createdAtMs: timestampMs(data.createdAt) ?? timestampMs(data.timestamp),
  };
}

function assertSupportedPath(path: string): void {
  if (!path) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "documentPath 가 비어 있습니다.",
    );
  }
  const isBond = /^bondPosts\/[^/]+$/.test(path);
  const isPartnerPost =
    /^partnerGroups\/[^/]+\/posts\/[^/]+$/.test(path);
  if (!isBond && !isPartnerPost) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "지원하지 않는 게시물 경로입니다.",
    );
  }
}

function stringOr(v: unknown, fallback: string): string {
  if (typeof v === "string") return v;
  if (v == null) return fallback;
  return String(v);
}

function toInt(v: unknown): number {
  const n = Number(v);
  return Number.isFinite(n) ? Math.trunc(n) : 0;
}

function truncate(s: string, n = 140): string {
  if (s.length <= n) return s;
  return `${s.slice(0, n)}…`;
}

function timestampMs(v: unknown): number | null {
  if (
    v &&
    typeof (v as admin.firestore.Timestamp).toMillis === "function"
  ) {
    return (v as admin.firestore.Timestamp).toMillis();
  }
  return null;
}
