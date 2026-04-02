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
