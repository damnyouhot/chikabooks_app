import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/job_order.dart';

/// 공고 게시 주문 서비스
///
/// 주문 생성·결제 확인은 서버 Callable을 통해 처리.
/// 클라이언트는 조회 + 서버 호출 래퍼 역할만 한다.
///
/// Firestore: `orders/{orderId}`
class OrderService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('orders');

  // ── 조회 ──────────────────────────────────────────────

  /// 단일 주문 조회
  static Future<JobOrder?> getOrder(String orderId) async {
    try {
      final doc = await _col.doc(orderId).get();
      if (!doc.exists) return null;
      return JobOrder.fromDoc(doc);
    } catch (e) {
      debugPrint('⚠️ OrderService.getOrder: $e');
      return null;
    }
  }

  /// 주문 상태 실시간 감시
  static Stream<JobOrder?> watchOrder(String orderId) {
    return _col.doc(orderId).snapshots().map(
          (doc) => doc.exists ? JobOrder.fromDoc(doc) : null,
        );
  }

  /// 내 주문 목록 (최근순)
  static Future<List<JobOrder>> getMyOrders() async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final snap = await _col
          .where('ownerUid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs.map((d) => JobOrder.fromDoc(d)).toList();
    } catch (e) {
      debugPrint('⚠️ OrderService.getMyOrders: $e');
      return [];
    }
  }

  /// 특정 Draft에 연결된 활성 주문이 있는지 확인
  static Future<JobOrder?> getActiveOrderForDraft(String draftId) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final snap = await _col
          .where('ownerUid', isEqualTo: uid)
          .where('draftId', isEqualTo: draftId)
          .where('status', whereIn: ['created', 'payment_pending'])
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return JobOrder.fromDoc(snap.docs.first);
    } catch (e) {
      debugPrint('⚠️ OrderService.getActiveOrderForDraft: $e');
      return null;
    }
  }

  // ── 서버 Callable 래퍼 ─────────────────────────────────

  /// 주문 생성 요청 → 서버가 Order 문서를 만들고 orderId 반환
  ///
  /// 서버에서 Draft 유효성·계정 상태·사업자 인증 등을 검증한 뒤
  /// 공고권 적용 시 amount=0 처리까지 수행.
  static Future<CreateOrderResult> createOrder({
    required String draftId,
    required String clinicProfileId,
    String? voucherId,
    Map<String, dynamic>? consents,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('createOrder');
      final result = await callable.call({
        'draftId': draftId,
        'clinicProfileId': clinicProfileId,
        if (voucherId != null) 'voucherId': voucherId,
        if (consents != null) 'consents': consents,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      return CreateOrderResult(
        orderId: data['orderId'] as String,
        amount: (data['amount'] as num?)?.toInt() ?? 0,
        requiresPayment: data['requiresPayment'] as bool? ?? true,
      );
    } catch (e) {
      debugPrint('⚠️ OrderService.createOrder: $e');
      rethrow;
    }
  }

  /// 결제 완료 확인 요청 → 서버가 PG 검증 후 jobs 생성
  ///
  /// 공고권 전용(amount=0)인 경우에도 이 메서드를 호출하여
  /// 서버가 최종 게시 처리를 수행하도록 한다.
  static Future<ConfirmPaymentResult> confirmPayment({
    required String orderId,
    String? paymentKey,
  }) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('confirmPayment');
      final result = await callable.call({
        'orderId': orderId,
        if (paymentKey != null) 'paymentKey': paymentKey,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      return ConfirmPaymentResult(
        jobId: data['jobId'] as String,
        success: data['success'] as bool? ?? true,
      );
    } catch (e) {
      debugPrint('⚠️ OrderService.confirmPayment: $e');
      rethrow;
    }
  }
}

/// createOrder Callable 응답
class CreateOrderResult {
  final String orderId;
  final int amount;

  /// false면 공고권 전용 → confirmPayment만 호출하면 됨
  final bool requiresPayment;

  const CreateOrderResult({
    required this.orderId,
    required this.amount,
    required this.requiresPayment,
  });
}

/// confirmPayment Callable 응답
class ConfirmPaymentResult {
  final String jobId;
  final bool success;

  const ConfirmPaymentResult({
    required this.jobId,
    required this.success,
  });
}
