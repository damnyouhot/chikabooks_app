import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/wallet.dart';

/// 지갑(공고권/충전 잔액) 조회 + 충전 요청 래퍼.
///
/// 모든 변동(차감/증액)은 서버 Cloud Function 에서만 수행되고,
/// 클라이언트는 읽기 전용이다. 보안 룰로 강제.
class WalletService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  static DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('wallets').doc(uid);

  static CollectionReference<Map<String, dynamic>> _ledger(String uid) =>
      _doc(uid).collection('ledger');

  /// 지갑 실시간 구독. 문서가 없으면 빈 지갑 반환.
  ///
  /// [uid] 를 주입하면 그 사용자에 대한 stream 을 만든다 (계정 격리).
  static Stream<Wallet> watchWallet({String? uid}) {
    final effectiveUid = uid ?? _uid;
    if (effectiveUid == null) return Stream.value(Wallet.empty(''));
    return _doc(effectiveUid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) {
        return Wallet.empty(effectiveUid);
      }
      return Wallet.fromMap(snap.data()!, uid: effectiveUid);
    }).transform(
      StreamTransformer.fromHandlers(
        handleError: (Object e, StackTrace st, EventSink<Wallet> sink) {
          debugPrint('⚠️ WalletService.watchWallet: $e');
          sink.addError(e, st);
        },
      ),
    );
  }

  /// 최근 변동 이력 N건 (createdAt desc)
  static Stream<List<WalletLedgerEntry>> watchLedger({
    int limit = 30,
    String? uid,
  }) {
    final effectiveUid = uid ?? _uid;
    if (effectiveUid == null) return Stream.value(const []);
    return _ledger(effectiveUid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      return snap.docs.map((d) => WalletLedgerEntry.fromDoc(d)).toList();
    }).transform(
      StreamTransformer.fromHandlers(
        handleError: (Object e, StackTrace st,
            EventSink<List<WalletLedgerEntry>> sink) {
          debugPrint('⚠️ WalletService.watchLedger: $e');
          sink.addError(e, st);
        },
      ),
    );
  }

  /// 공고권 패키지 충전 — 서버에서 결제 검증 후 지갑 갱신.
  ///
  /// Sprint 3 1차: 서버 함수가 미배포 상태일 수 있으므로
  /// 클라이언트는 Callable 호출만 하고, 응답 형태로 redirect URL을 받는 것을 가정.
  static Future<RechargeResult> chargeVoucher({
    required String packageId,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('chargeVoucherPackage');
      final result = await callable.call({'packageId': packageId});
      final data = Map<String, dynamic>.from(result.data as Map);
      return RechargeResult(
        orderId: data['orderId'] as String? ?? '',
        checkoutUrl: data['checkoutUrl'] as String?,
      );
    } catch (e) {
      debugPrint('⚠️ WalletService.chargeVoucher: $e');
      rethrow;
    }
  }

  /// 충전 잔액 패키지 충전 — 서버에서 결제 검증 후 지갑 갱신.
  static Future<RechargeResult> chargeCredit({
    required String packageId,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('chargeCreditPackage');
      final result = await callable.call({'packageId': packageId});
      final data = Map<String, dynamic>.from(result.data as Map);
      return RechargeResult(
        orderId: data['orderId'] as String? ?? '',
        checkoutUrl: data['checkoutUrl'] as String?,
      );
    } catch (e) {
      debugPrint('⚠️ WalletService.chargeCredit: $e');
      rethrow;
    }
  }
}

class RechargeResult {
  final String orderId;
  final String? checkoutUrl;
  const RechargeResult({required this.orderId, this.checkoutUrl});
}
