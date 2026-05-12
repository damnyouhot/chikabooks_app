/**
 * 어드민 전용 callable 공통 가드.
 *
 * 모든 신규 어드민 callable 은 [adminCallable] 로 래핑한다.
 *
 * ── 책임 ────────────────────────────────────────────────────────
 * 1. `request.auth` 확인 → 미인증이면 `unauthenticated` 에러
 * 2. `users/{uid}.isAdmin === true` 확인 → 일반 유저면 `permission-denied`
 * 3. 핸들러 호출 전·후로 감사 로그(`adminAuditLog`) 자동 적재
 * 4. 핸들러 내부 예외는 그대로 전파(callable Error → 클라이언트에 표시)
 *    하되, 실패 사실은 감사 로그에 success=false 로 기록
 *
 * ── 기존 콜러블과의 관계 ────────────────────────────────────────
 * 기존 `admin-verification.ts` 등은 자체 `requireAdmin` 헬퍼를 가진다.
 * 호환을 위해 이번 페이즈에서는 기존 함수를 강제로 교체하지 않는다.
 * 신규 콜러블만 본 래퍼를 사용하고, 기존 코드는 추후 점진적으로 마이그레이션.
 * ────────────────────────────────────────────────────────────────
 */
import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";

import {logAdminAction} from "./adminAuditLog";

const getDb = (): admin.firestore.Firestore => admin.firestore();

export interface AdminGuardOptions<TIn> {
  /** 콜러블 이름 (감사 로그 actionName 으로 그대로 들어감) */
  name: string;
  /** 파괴적 액션 여부 (삭제, 결제 차감, 발송 등) */
  destructive?: boolean;
  /**
   * 입력 데이터에서 감사 로그에 남길 안전 필드만 추출한다.
   * PII 가 들어있는 필드는 절대 반환하면 안 된다.
   * 미지정 시 빈 객체가 기록된다.
   */
  logArgs?: (input: TIn) => Record<string, unknown>;
  /**
   * 영향 받은 대상 id (예: docId, collection/docId).
   * 핸들러가 결과로 반환해도 되고, 입력에서 추출해도 된다.
   */
  resolveTarget?: (input: TIn) => string | null | undefined;
}

export interface AdminContext {
  uid: string;
  email: string | null;
}

/**
 * 인증된 사용자 컨텍스트에서 어드민 권한을 검증한다.
 * 사용자가 운영 권한을 잃은 직후 callable 호출을 막기 위해 매 호출마다
 * Firestore 의 `users/{uid}.isAdmin` 을 직접 조회한다.
 *
 * @param {functions.https.CallableContext} context callable 컨텍스트
 * @return {Promise<AdminContext>} 검증된 어드민 uid/email
 */
export async function requireAdminUid(
  context: functions.https.CallableContext,
): Promise<AdminContext> {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "로그인이 필요합니다.");
  }
  const uid = context.auth.uid;
  const doc = await getDb().collection("users").doc(uid).get();
  if (doc.data()?.isAdmin !== true) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "어드민 권한이 필요합니다.",
    );
  }
  return {
    uid,
    email: (context.auth.token?.email as string | undefined) ?? null,
  };
}

/**
 * 신규 어드민 callable 을 만들 때 사용하는 표준 래퍼.
 *
 * @template TIn  callable 입력 타입
 * @template TOut callable 반환 타입
 * @param {AdminGuardOptions<TIn>} options 가드/감사 로그 메타
 * @param {(input: TIn, ctx: AdminContext) => Promise<TOut>} handler 본체
 * @return {functions.HttpsFunction & functions.Runnable<unknown>} v1 onCall 함수
 */
export function adminCallable<TIn, TOut>(
  options: AdminGuardOptions<TIn>,
  handler: (input: TIn, ctx: AdminContext) => Promise<TOut>,
): functions.HttpsFunction & functions.Runnable<unknown> {
  return functions.https.onCall(async (rawData, context) => {
    const start = Date.now();
    let adminCtx: AdminContext;
    try {
      adminCtx = await requireAdminUid(context);
    } catch (e) {
      // 인증 실패도 감사 로그에 남기되, 실패 사실 본체는 throw 한다.
      const auth = context.auth;
      await logAdminAction({
        actorUid: auth?.uid ?? "anonymous",
        actorEmail: (auth?.token?.email as string | undefined) ?? null,
        actionName: options.name,
        args: safeLogArgs(options.logArgs, rawData as TIn),
        target: safeResolveTarget(options.resolveTarget, rawData as TIn),
        destructive: options.destructive === true,
        success: false,
        error: errorMessage(e),
        elapsedMs: Date.now() - start,
      });
      throw e;
    }

    const input = rawData as TIn;
    const args = safeLogArgs(options.logArgs, input);
    const target = safeResolveTarget(options.resolveTarget, input);

    try {
      const result = await handler(input, adminCtx);
      await logAdminAction({
        actorUid: adminCtx.uid,
        actorEmail: adminCtx.email,
        actionName: options.name,
        args,
        target,
        destructive: options.destructive === true,
        success: true,
        elapsedMs: Date.now() - start,
      });
      return result;
    } catch (e) {
      await logAdminAction({
        actorUid: adminCtx.uid,
        actorEmail: adminCtx.email,
        actionName: options.name,
        args,
        target,
        destructive: options.destructive === true,
        success: false,
        error: errorMessage(e),
        elapsedMs: Date.now() - start,
      });
      throw e;
    }
  });
}

function safeLogArgs<TIn>(
  fn: ((input: TIn) => Record<string, unknown>) | undefined,
  input: TIn,
): Record<string, unknown> {
  if (!fn) return {};
  try {
    return fn(input) ?? {};
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error("⚠️ [adminCallable] logArgs threw", e);
    return {__logArgsError: errorMessage(e)};
  }
}

function safeResolveTarget<TIn>(
  fn: ((input: TIn) => string | null | undefined) | undefined,
  input: TIn,
): string | null {
  if (!fn) return null;
  try {
    return fn(input) ?? null;
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error("⚠️ [adminCallable] resolveTarget threw", e);
    return null;
  }
}

function errorMessage(e: unknown): string {
  if (e instanceof Error) return e.message;
  if (typeof e === "string") return e;
  try {
    return JSON.stringify(e);
  } catch {
    return String(e);
  }
}
