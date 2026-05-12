import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 자동결제 카드(빌링키) 등록 / 해지 / 메타 조회 wrapper.
///
/// **저장 위치 (서버 전용)**: `billingKeys/{uid}` — `tossBillingKey` 등 비밀
/// 정보. 클라이언트는 절대 직접 read/write 할 수 없다 (firestore.rules 거부).
///
/// **클라이언트 노출 메타**: `users/{uid}/billingMeta/profile` — 카드사,
/// 마지막 4자리, 등록일 등. 본인만 read 가능, write 는 서버 Callable 만.
///
/// 호출 시점:
///   - 자동연장 다이얼로그 진입 시 → [hasBillingKey()] 로 등록 여부 확인.
///   - 카드 등록 페이지에서 Toss successUrl 콜백 후 → [registerBillingKey].
///   - 결제수단 관리 페이지에서 카드 해지 → [deleteBillingKey].
class BillingKeyService {
  BillingKeyService._();

  static FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'asia-northeast3');
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// 등록된 카드(billingKey) 메타. 없으면 null.
  /// 본인 uid 기준 — 다른 uid 의 메타는 룰상 read 거부됨.
  static Stream<BillingKeyMeta?> watchMyBillingMeta() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('users')
        .doc(uid)
        .collection('billingMeta')
        .doc('profile')
        .snapshots()
        .map((snap) {
      if (!snap.exists) return null;
      return BillingKeyMeta.fromMap(snap.data() ?? const {});
    });
  }

  /// 가장 최근 등록 메타를 한 번 조회. 자동연장 다이얼로그 진입 가드용.
  static Future<BillingKeyMeta?> fetchMyBillingMeta() async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('billingMeta')
          .doc('profile')
          .get();
      if (!snap.exists) return null;
      return BillingKeyMeta.fromMap(snap.data() ?? const {});
    } catch (e) {
      debugPrint('⚠️ fetchMyBillingMeta: $e');
      return null;
    }
  }

  /// 결제 카드가 활성 상태로 등록돼 있는지.
  static Future<bool> hasBillingKey() async {
    final meta = await fetchMyBillingMeta();
    return meta != null && meta.hasBillingKey;
  }

  /// Toss 빌링 인증 successUrl 콜백에서 호출.
  /// `customerKey` 는 반드시 인증 uid 와 동일해야 한다 (서버에서 검증).
  static Future<RegisterBillingKeyResult> registerBillingKey({
    required String authKey,
    required String customerKey,
    String? customerEmail,
    String? customerName,
  }) async {
    final res = await _functions.httpsCallable('registerBillingKey').call({
      'authKey': authKey,
      'customerKey': customerKey,
      if (customerEmail != null && customerEmail.isNotEmpty)
        'customerEmail': customerEmail,
      if (customerName != null && customerName.isNotEmpty)
        'customerName': customerName,
    });
    final data = Map<String, dynamic>.from(res.data as Map);
    return RegisterBillingKeyResult(
      mode: data['mode']?.toString() ?? 'issued',
      hasBillingKey: data['hasBillingKey'] == true,
      cardCompany: data['cardCompany']?.toString() ?? '',
      cardNumberMasked: data['cardNumberMasked']?.toString() ?? '',
      cardType: data['cardType']?.toString() ?? '',
    );
  }

  /// 카드 해지. 자동연장이 켜진 캠페인은 서버에서 함께 OFF 로 전환됨.
  static Future<DeleteBillingKeyResult> deleteBillingKey() async {
    final res = await _functions.httpsCallable('deleteBillingKey').call({});
    final data = Map<String, dynamic>.from(res.data as Map);
    return DeleteBillingKeyResult(
      hasBillingKey: data['hasBillingKey'] == true,
      autoRenewDisabledCount:
          (data['autoRenewDisabledCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 클라이언트가 표시할 카드 메타 (`users/{uid}/billingMeta/profile`).
class BillingKeyMeta {
  const BillingKeyMeta({
    required this.hasBillingKey,
    required this.cardCompany,
    required this.cardNumberMasked,
    required this.cardType,
    required this.method,
    required this.status,
    required this.registeredAt,
    required this.deletedAt,
  });

  final bool hasBillingKey;
  final String cardCompany;
  final String cardNumberMasked;
  final String cardType;
  final String method;

  /// 'active' | 'deleted' | ''
  final String status;

  final DateTime? registeredAt;
  final DateTime? deletedAt;

  factory BillingKeyMeta.fromMap(Map<String, dynamic> map) {
    DateTime? toDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    return BillingKeyMeta(
      hasBillingKey: map['hasBillingKey'] == true,
      cardCompany: map['cardCompany']?.toString() ?? '',
      cardNumberMasked: map['cardNumberMasked']?.toString() ?? '',
      cardType: map['cardType']?.toString() ?? '',
      method: map['method']?.toString() ?? 'CARD',
      status: map['status']?.toString() ?? '',
      registeredAt: toDate(map['registeredAt']),
      deletedAt: toDate(map['deletedAt']),
    );
  }

  /// 사용자에게 표시할 카드명 + 마지막 4자리 (예: "신한카드 ****-1234").
  String get displayLabel {
    if (!hasBillingKey) return '등록된 카드 없음';
    final last4 = _last4();
    if (cardCompany.isEmpty && last4.isEmpty) return '등록된 카드';
    if (last4.isEmpty) return cardCompany.isEmpty ? '등록된 카드' : cardCompany;
    return '${cardCompany.isEmpty ? "카드" : cardCompany} ****-$last4';
  }

  String _last4() {
    final s = cardNumberMasked.replaceAll(RegExp(r'[^0-9*]'), '');
    if (s.length < 4) return '';
    return s.substring(s.length - 4);
  }
}

class RegisterBillingKeyResult {
  const RegisterBillingKeyResult({
    required this.mode,
    required this.hasBillingKey,
    required this.cardCompany,
    required this.cardNumberMasked,
    required this.cardType,
  });

  /// 'issued' | 'mock' (운영전 secret 미설정)
  final String mode;
  final bool hasBillingKey;
  final String cardCompany;
  final String cardNumberMasked;
  final String cardType;
}

class DeleteBillingKeyResult {
  const DeleteBillingKeyResult({
    required this.hasBillingKey,
    required this.autoRenewDisabledCount,
  });

  final bool hasBillingKey;
  final int autoRenewDisabledCount;
}
