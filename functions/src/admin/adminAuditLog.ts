/**
 * 어드민 액션 감사 로그 — `adminAuditLog/{auto_id}` 적재 헬퍼.
 *
 * ── 설계 원칙 ────────────────────────────────────────────────────
 * 1. 모든 어드민 callable 의 ① 시도 / ② 성공 / ③ 실패 를 같은 컬렉션에
 *    기록한다. 컬렉션 자체는 클라이언트 쓰기 금지 (firestore.rules 참조).
 * 2. PII (이름, 이메일, 사업자번호, 결제 토큰 등) 는 절대 args 에 넣지 않는다.
 *    호출자가 `logArgs` 콜백에서 화이트리스트 필드만 추출하도록 책임진다.
 * 3. 로그 적재 자체가 실패해도 본래 콜러블 동작은 방해하지 않는다.
 *    감사 로그는 부수 효과로 처리하며, 실패 시 콘솔에만 기록한다.
 * ────────────────────────────────────────────────────────────────
 */
import * as admin from "firebase-admin";

const getDb = (): admin.firestore.Firestore => admin.firestore();

export interface AdminAuditEntry {
  actorUid: string;
  actorEmail?: string | null;
  actionName: string;
  args?: Record<string, unknown>;
  target?: string | null;
  destructive?: boolean;
  success: boolean;
  error?: string | null;
  elapsedMs?: number;
}

/**
 * 감사 로그 1건을 적재한다. 실패해도 throw 하지 않는다.
 * @param {AdminAuditEntry} entry 적재할 항목
 * @return {Promise<void>} 항상 resolve
 */
export async function logAdminAction(entry: AdminAuditEntry): Promise<void> {
  try {
    await getDb().collection("adminAuditLog").add({
      actorUid: entry.actorUid,
      actorEmail: entry.actorEmail ?? null,
      actionName: entry.actionName,
      args: entry.args ?? {},
      target: entry.target ?? null,
      destructive: entry.destructive === true,
      success: entry.success,
      error: entry.error ?? null,
      elapsedMs: entry.elapsedMs ?? null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (e) {
    // 감사 로그 적재 실패는 본 작업을 막지 않는다.
    // eslint-disable-next-line no-console
    console.error(
      `❌ [adminAuditLog] write failed (action=${entry.actionName})`, e
    );
  }
}
