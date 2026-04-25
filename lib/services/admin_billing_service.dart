import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// 운영팀(admin) 전용 — 결제·세금계산서·현금영수증 큐 처리 서비스
///
/// 1차 운영 정책:
///   - 사용자가 충전 클릭 → `paymentRequests/{id}` 에 status='pending_manual' 적재
///   - 사용자가 세금계산서/현금영수증 요청 → `taxRequests` / `cashReceiptRequests`
///     에 status='queued' 적재
///   - 운영팀이 admin 화면에서 큐를 보고 "처리 완료" 버튼을 누르면
///     서버 Callable 이 실제 잔액 적용 / 상태 변경
class AdminBillingService {
  AdminBillingService._();

  static final _db = FirebaseFirestore.instance;
  static final _fns =
      FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  // ── 충전 요청 (paymentRequests) ─────────────────────────
  static Stream<List<PaymentRequestRow>> watchPaymentRequests({
    String status = 'pending_manual',
    int limit = 100,
  }) {
    return _db
        .collection('paymentRequests')
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map(PaymentRequestRow.fromDoc).toList());
  }

  /// 입금 확인 후 잔액 적용 — admin 전용 Callable
  static Future<void> applyPendingPayment(String requestId) async {
    try {
      await _fns
          .httpsCallable('applyPendingPayment')
          .call({'requestId': requestId});
    } catch (e) {
      debugPrint('⚠️ AdminBillingService.applyPendingPayment: $e');
      rethrow;
    }
  }

  // ── 세금계산서 (taxRequests) ────────────────────────────
  static Stream<List<TaxRequestRow>> watchTaxRequests({
    String status = 'queued',
    int limit = 100,
  }) {
    return _db
        .collection('taxRequests')
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(TaxRequestRow.fromDoc).toList());
  }

  /// 운영팀이 토스 콘솔에서 발급 완료 후 호출 — status='issued' 로 변경
  static Future<void> markTaxIssued({
    required String requestId,
    String? externalId,
    String? note,
  }) async {
    try {
      await _fns.httpsCallable('markTaxIssued').call({
        'requestId': requestId,
        if (externalId != null) 'externalId': externalId,
        if (note != null) 'note': note,
      });
    } catch (e) {
      debugPrint('⚠️ AdminBillingService.markTaxIssued: $e');
      rethrow;
    }
  }

  // ── 현금영수증 (cashReceiptRequests) ──────────────────
  static Stream<List<CashReceiptRequestRow>> watchCashReceiptRequests({
    String status = 'queued',
    int limit = 100,
  }) {
    return _db
        .collection('cashReceiptRequests')
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map(CashReceiptRequestRow.fromDoc).toList());
  }

  static Future<void> markCashReceiptIssued({
    required String requestId,
    String? externalId,
    String? note,
  }) async {
    try {
      await _fns.httpsCallable('markCashReceiptIssued').call({
        'requestId': requestId,
        if (externalId != null) 'externalId': externalId,
        if (note != null) 'note': note,
      });
    } catch (e) {
      debugPrint('⚠️ AdminBillingService.markCashReceiptIssued: $e');
      rethrow;
    }
  }

  // ── 카운트 (배지/요약용) ────────────────────────────────
  static Stream<({int payment, int tax, int cash})> watchCounts() {
    return _db.collection('paymentRequests')
        .where('status', isEqualTo: 'pending_manual')
        .snapshots()
        .map((s) => s.size)
        .asyncMap((paymentN) async {
      final tax = await _db
          .collection('taxRequests')
          .where('status', isEqualTo: 'queued')
          .count()
          .get();
      final cash = await _db
          .collection('cashReceiptRequests')
          .where('status', isEqualTo: 'queued')
          .count()
          .get();
      return (
        payment: paymentN,
        tax: tax.count ?? 0,
        cash: cash.count ?? 0,
      );
    });
  }
}

// ══════════════════════════════════════════════════════════════
// 공통 행 모델 — UI 에서 동일한 카드 패턴으로 렌더할 수 있도록 단순화
// ══════════════════════════════════════════════════════════════

class PaymentRequestRow {
  final String id;
  final String ownerUid;
  final String kind; // 'voucher_package' | 'credit_package'
  final String packageId;
  final int amount;
  final String status;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;

  const PaymentRequestRow({
    required this.id,
    required this.ownerUid,
    required this.kind,
    required this.packageId,
    required this.amount,
    required this.status,
    required this.metadata,
    this.createdAt,
  });

  factory PaymentRequestRow.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return PaymentRequestRow(
      id: doc.id,
      ownerUid: d['ownerUid'] as String? ?? '',
      kind: d['kind'] as String? ?? '',
      packageId: d['packageId'] as String? ?? '',
      amount: (d['amount'] as num?)?.toInt() ?? 0,
      status: d['status'] as String? ?? '',
      metadata: Map<String, dynamic>.from(
          (d['metadata'] as Map?) ?? const {}),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  bool get isVoucher => kind == 'voucher_package';
  bool get isCredit => kind == 'credit_package';
  int get bonus => (metadata['bonus'] as num?)?.toInt() ?? 0;
  int get qty => (metadata['qty'] as num?)?.toInt() ?? 0;
}

class TaxRequestRow {
  final String id;
  final String ownerUid;
  final String clinicId;
  final String orderRef;
  final String bizNo;
  final String clinicName;
  final String ownerName;
  final String address;
  final String? bizType;
  final String? bizItem;
  final int amount;
  final String email;
  final String status;
  final DateTime? createdAt;

  const TaxRequestRow({
    required this.id,
    required this.ownerUid,
    required this.clinicId,
    required this.orderRef,
    required this.bizNo,
    required this.clinicName,
    required this.ownerName,
    required this.address,
    required this.bizType,
    required this.bizItem,
    required this.amount,
    required this.email,
    required this.status,
    this.createdAt,
  });

  factory TaxRequestRow.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return TaxRequestRow(
      id: doc.id,
      ownerUid: d['ownerUid'] as String? ?? '',
      clinicId: d['clinicId'] as String? ?? '',
      orderRef: d['orderRef'] as String? ?? '',
      bizNo: d['bizNo'] as String? ?? '',
      clinicName: d['clinicName'] as String? ?? '',
      ownerName: d['ownerName'] as String? ?? '',
      address: d['address'] as String? ?? '',
      bizType: d['bizType'] as String?,
      bizItem: d['bizItem'] as String?,
      amount: (d['amount'] as num?)?.toInt() ?? 0,
      email: d['email'] as String? ?? '',
      status: d['status'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class CashReceiptRequestRow {
  final String id;
  final String ownerUid;
  final String clinicId;
  final String orderRef;
  final String receiptType; // 'income' | 'business'
  final String identifier;
  final int amount;
  final String status;
  final DateTime? createdAt;

  const CashReceiptRequestRow({
    required this.id,
    required this.ownerUid,
    required this.clinicId,
    required this.orderRef,
    required this.receiptType,
    required this.identifier,
    required this.amount,
    required this.status,
    this.createdAt,
  });

  factory CashReceiptRequestRow.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return CashReceiptRequestRow(
      id: doc.id,
      ownerUid: d['ownerUid'] as String? ?? '',
      clinicId: d['clinicId'] as String? ?? '',
      orderRef: d['orderRef'] as String? ?? '',
      receiptType: d['receiptType'] as String? ?? 'business',
      identifier: d['identifier'] as String? ?? '',
      amount: (d['amount'] as num?)?.toInt() ?? 0,
      status: d['status'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
