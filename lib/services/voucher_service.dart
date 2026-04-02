import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/voucher.dart';

/// 공고권(Voucher) 서비스
///
/// 공고권은 서버(Cloud Functions)에서만 생성·사용·만료 처리.
/// 클라이언트는 조회만 가능하다.
///
/// Firestore: `vouchers/{voucherId}`
class VoucherService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('vouchers');

  // ── 조회 ──────────────────────────────────────────────

  /// 사용 가능한 공고권 목록 (active + 미만료)
  static Future<List<Voucher>> getAvailableVouchers() async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final snap = await _col
          .where('ownerUid', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .orderBy('expiresAt')
          .get();
      return snap.docs
          .map((d) => Voucher.fromDoc(d))
          .where((v) => v.isUsable)
          .toList();
    } catch (e) {
      debugPrint('⚠️ VoucherService.getAvailableVouchers: $e');
      return [];
    }
  }

  /// 전체 공고권 이력 (사용·만료 포함)
  static Future<List<Voucher>> getAllVouchers() async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final snap = await _col
          .where('ownerUid', isEqualTo: uid)
          .orderBy('issuedAt', descending: true)
          .get();
      return snap.docs.map((d) => Voucher.fromDoc(d)).toList();
    } catch (e) {
      debugPrint('⚠️ VoucherService.getAllVouchers: $e');
      return [];
    }
  }

  /// 사용 가능한 공고권 실시간 스트림
  static Stream<List<Voucher>> watchAvailableVouchers() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return _col
        .where('ownerUid', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Voucher.fromDoc(d))
            .where((v) => v.isUsable)
            .toList());
  }

  /// 사용 가능한 공고권 개수
  static Future<int> getAvailableCount() async {
    final vouchers = await getAvailableVouchers();
    return vouchers.length;
  }
}
