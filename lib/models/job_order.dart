import 'package:cloud_firestore/cloud_firestore.dart';

/// 주문 상태
enum OrderStatus {
  created,
  paymentPending,
  paid,
  failed,
  refunded,
  cancelled;

  static OrderStatus fromString(String? s) {
    switch (s) {
      case 'created':
        return OrderStatus.created;
      case 'payment_pending':
        return OrderStatus.paymentPending;
      case 'paid':
        return OrderStatus.paid;
      case 'failed':
        return OrderStatus.failed;
      case 'refunded':
        return OrderStatus.refunded;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.created;
    }
  }

  String get value {
    switch (this) {
      case OrderStatus.created:
        return 'created';
      case OrderStatus.paymentPending:
        return 'payment_pending';
      case OrderStatus.paid:
        return 'paid';
      case OrderStatus.failed:
        return 'failed';
      case OrderStatus.refunded:
        return 'refunded';
      case OrderStatus.cancelled:
        return 'cancelled';
    }
  }

  bool get isTerminal =>
      this == OrderStatus.paid ||
      this == OrderStatus.refunded ||
      this == OrderStatus.cancelled;
}

/// 주문 목적 — 같은 `orders` 컬렉션을 첫 결제·연장·업그레이드·자동연장이 공유한다.
enum OrderPurpose {
  /// 신규 공고 생성 결제 (디폴트, 기존 흐름)
  create,

  /// 기존 캠페인의 노출 기간 연장 결제
  extend,

  /// 기존 캠페인의 등급 변경(차액 결제)
  upgrade,

  /// 자동연장(스케줄러가 D-N 시점에 자동 청구)
  autoRenew;

  static OrderPurpose fromString(String? s) {
    switch (s) {
      case 'extend':
        return OrderPurpose.extend;
      case 'upgrade':
        return OrderPurpose.upgrade;
      case 'auto_renew':
        return OrderPurpose.autoRenew;
      case 'create':
      default:
        return OrderPurpose.create;
    }
  }

  String get value {
    switch (this) {
      case OrderPurpose.create:
        return 'create';
      case OrderPurpose.extend:
        return 'extend';
      case OrderPurpose.upgrade:
        return 'upgrade';
      case OrderPurpose.autoRenew:
        return 'auto_renew';
    }
  }
}

/// 공고 게시 주문 엔티티
///
/// Firestore: `orders/{orderId}`
/// 서버에서만 생성·수정.
class JobOrder {
  final String id;
  final String ownerUid;
  final String draftId;
  final String clinicProfileId;
  final OrderStatus status;

  /// 결제 금액 (원). 공고권 적용 시 0
  final int amount;
  final String currency;

  /// 적용된 공고권 ID (없으면 null)
  final String? voucherId;

  /// 결제 제공사 ('toss' | 'voucher_only')
  final String? paymentProvider;

  /// PG사 트랜잭션 ID
  final String? providerTxId;

  /// 생성된 jobs/{jobId} (결제 완료 후 서버가 설정)
  final String? jobId;

  /// 공고 노출 기간(일)
  final int exposureDays;

  // ── M1: 광고 대시보드 도입을 위한 가격/정책 스냅샷 필드 ──
  //
  // 모두 옵셔널. 기존 주문(이전 스키마)와의 하위 호환을 위해 nullable 또는 디폴트값.

  /// 결제 시점 등급 키 ("premium"|"standard"|"basic"). 카탈로그(`productCatalog/{tierKey}`) 키.
  final String? tierKey;

  /// 결제 시점 가격 ID (`productCatalog/{tier}/prices/{priceId}`).
  /// 가격이 변경되어도 이 주문은 결제 시점 가격을 영구 보존한다.
  final String? priceId;

  /// 주문 목적. 디폴트 [OrderPurpose.create].
  final OrderPurpose purpose;

  /// 연장/업그레이드/자동연장 시 원본 캠페인. 신규 결제일 때 null.
  final String? parentCampaignId;

  /// 자동연장 등 할인이 적용되는 경우 0.0 ~ 1.0.
  final double discountRate;

  /// 서버에서 검증한 공고권 적용 가능 여부 (UI 표시·감사용).
  final bool? voucherEligible;

  /// 결제 동의 스냅샷 ({termsVersion, privacyVersion, refundVersion, autoRenewVersion}).
  final Map<String, dynamic>? consentSnapshot;

  final DateTime? createdAt;
  final DateTime? paidAt;

  const JobOrder({
    required this.id,
    required this.ownerUid,
    required this.draftId,
    required this.clinicProfileId,
    this.status = OrderStatus.created,
    this.amount = 0,
    this.currency = 'KRW',
    this.voucherId,
    this.paymentProvider,
    this.providerTxId,
    this.jobId,
    this.exposureDays = 30,
    this.tierKey,
    this.priceId,
    this.purpose = OrderPurpose.create,
    this.parentCampaignId,
    this.discountRate = 0.0,
    this.voucherEligible,
    this.consentSnapshot,
    this.createdAt,
    this.paidAt,
  });

  factory JobOrder.fromMap(Map<String, dynamic> data, {required String id}) {
    return JobOrder(
      id: id,
      ownerUid: data['ownerUid'] as String? ?? '',
      draftId: data['draftId'] as String? ?? '',
      clinicProfileId: data['clinicProfileId'] as String? ?? '',
      status: OrderStatus.fromString(data['status'] as String?),
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      currency: data['currency'] as String? ?? 'KRW',
      voucherId: data['voucherId'] as String?,
      paymentProvider: data['paymentProvider'] as String?,
      providerTxId: data['providerTxId'] as String?,
      jobId: data['jobId'] as String?,
      exposureDays: (data['exposureDays'] as num?)?.toInt() ?? 30,
      tierKey: data['tierKey'] as String?,
      priceId: data['priceId'] as String?,
      purpose: OrderPurpose.fromString(data['purpose'] as String?),
      parentCampaignId: data['parentCampaignId'] as String?,
      discountRate: (data['discountRate'] as num?)?.toDouble() ?? 0.0,
      voucherEligible: data['voucherEligible'] as bool?,
      consentSnapshot: (data['consentSnapshot'] as Map?)?.cast<String, dynamic>(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
    );
  }

  factory JobOrder.fromDoc(DocumentSnapshot doc) {
    return JobOrder.fromMap(doc.data() as Map<String, dynamic>, id: doc.id);
  }

  bool get isPaid => status == OrderStatus.paid;
  bool get isFreeWithVoucher => voucherId != null && amount == 0;
}
