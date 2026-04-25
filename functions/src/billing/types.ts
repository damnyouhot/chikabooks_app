/**
 * billing/types.ts
 *
 * 세금계산서·현금영수증 외주(Toss / 별도 외주) 어댑터의 공용 타입.
 *
 * 운영 1차(현재): 사용자가 화면에서 "발급 요청" 클릭 → Cloud Function이
 * 요청 문서를 `taxRequests` / `cashReceiptRequests` 컬렉션에 적재 + 운영팀
 * 알림 채널(슬랙/이메일)로 전달 → 운영팀 수동 처리.
 *
 * 운영 2차(외주 API 발급 완료 후): 동일한 인터페이스를 만족하는 실제
 * 어댑터 구현체(`tossInvoiceAdapter`, `cashReceiptAdapter`)로 교체. 화면 변경 0.
 */

/** 세금계산서 발급 요청 입력 */
export interface TaxInvoiceRequestInput {
  uid: string;
  clinicId: string;
  /** 결제 식별자 (orders/{orderId} 또는 toss paymentKey) */
  orderRef: string;
  /** 공급받는자 사업자번호 (10자리 숫자, '-' 제거) */
  bizNo: string;
  /** 상호 */
  clinicName: string;
  /** 대표자명 */
  ownerName: string;
  /** 사업장 주소 */
  address: string;
  /** 업태 */
  bizType?: string;
  /** 종목 */
  bizItem?: string;
  /** 청구 금액 (원, 부가세 포함) */
  amount: number;
  /** 세금계산서 수신 이메일 */
  email: string;
}

/** 현금영수증 발급 요청 입력 */
export interface CashReceiptRequestInput {
  uid: string;
  clinicId: string;
  orderRef: string;
  /** 발급 유형: 소득공제 | 지출증빙 */
  receiptType: "income" | "business";
  /** 신원 식별자 — 소득공제: 휴대폰번호 / 지출증빙: 사업자번호 */
  identifier: string;
  amount: number;
}

/** 처리 결과 — Firestore 요청 문서에도 동일 형태로 기록 */
export interface BillingAdapterResult {
  /** queued: 1차 운영 — 요청만 적재 / issued: 2차 — 외주 API 발급 완료 */
  status: "queued" | "issued" | "failed";
  requestId: string;
  /** 외주 API 발급 식별자 (2차 운영 시) */
  externalId?: string;
  message?: string;
  /** 실패 시 사유 */
  errorCode?: string;
}

/** 어댑터 공통 인터페이스 — 운영 단계별 구현체가 이를 만족해야 한다. */
export interface TaxInvoiceAdapter {
  request(input: TaxInvoiceRequestInput): Promise<BillingAdapterResult>;
}

export interface CashReceiptAdapter {
  request(input: CashReceiptRequestInput): Promise<BillingAdapterResult>;
}
