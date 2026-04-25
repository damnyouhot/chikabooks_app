import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// /me 페이지 전역 세션 — 활성 지점 ID, 청구 정책 모드 등 화면 간 공유 상태
///
/// 정책 모드/패키지 가격 등은 모두 Firestore `config/billingPolicy` 문서에서
/// 가져오며, 운영자가 admin에서 코드 수정 없이 조정 가능하다.
///
/// 기본값으로 `both` (공고권 + 충전액 동시 운영)를 사용한다 — 실제 사용
/// 데이터를 보고 매출이 잘 나오는 모델로 점진적으로 좁히는 것을 권장한다.
class MeSession {
  MeSession._();

  /// 현재 선택된 지점(`clinic_profiles/{id}`) — 다지점 운영자에서만 사용
  static final ValueNotifier<String?> activeBranchId =
      ValueNotifier<String?>(null);

  /// 청구 정책 모드 — 운영자가 admin에서 변경 가능 (`config/billingPolicy.mode`)
  static final ValueNotifier<BillingMode> billingMode =
      ValueNotifier<BillingMode>(BillingMode.both);

  /// 정책 패키지·만료 등 상세값 (Sprint 3에서 충전·결제 화면이 사용)
  static final ValueNotifier<BillingPolicyConfig> billingPolicy =
      ValueNotifier<BillingPolicyConfig>(BillingPolicyConfig.fallback);

  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  static StreamSubscription<User?>? _authSub;

  /// 직전에 관찰된 사용자 uid. 같은 사용자가 다시 emit 되면 리셋을 건너뛴다.
  static String? _lastUid;

  /// 앱 부팅 시 1회 호출 — Firestore `config/billingPolicy` 문서 구독을 시작.
  ///
  /// 또한 `authStateChanges` 를 구독해서 **사용자가 바뀔 때마다 모든 세션
  /// ValueNotifier 를 기본값으로 리셋**한다. 이전 사용자의 활성 지점 ID 가
  /// 다른 사용자 화면에 새어나가는 것을 막는 핵심 안전장치.
  static void start() {
    _authSub ??= FirebaseAuth.instance.authStateChanges().listen((user) {
      final uid = user?.uid;
      if (_lastUid == uid) return;
      _lastUid = uid;
      // 사용자 전환(로그인/로그아웃/계정변경) 시 무조건 세션 상태 초기화.
      activeBranchId.value = null;
      // billingPolicy 는 사용자별이 아니라 전역(config 문서)이지만,
      // 안전을 위해 fallback 을 강제하지는 않는다 — 별도 stream 이 갱신함.
    });

    _sub ??= FirebaseFirestore.instance
        .collection('config')
        .doc('billingPolicy')
        .snapshots()
        .listen(
      (snap) {
        if (!snap.exists) {
          // 운영자가 아직 설정 안 한 경우 — 추천 fallback 유지
          billingMode.value = BillingPolicyConfig.fallback.mode;
          billingPolicy.value = BillingPolicyConfig.fallback;
          return;
        }
        try {
          final cfg = BillingPolicyConfig.fromMap(snap.data()!);
          billingMode.value = cfg.mode;
          billingPolicy.value = cfg;
        } catch (e) {
          debugPrint('⚠️ MeSession.billingPolicy parse failed: $e');
        }
      },
      onError: (e) =>
          debugPrint('⚠️ MeSession.billingPolicy stream error: $e'),
    );
  }

  static void setActiveBranch(String? id) {
    if (activeBranchId.value == id) return;
    activeBranchId.value = id;
  }

  static void setBillingMode(BillingMode mode) {
    if (billingMode.value == mode) return;
    billingMode.value = mode;
  }
}

/// 청구 정책 모드.
///
/// Firestore `config/billingPolicy.mode` 와 1:1 매핑되며,
/// UI 카피·잔액 표시 단위·결제 흐름 분기를 결정한다.
enum BillingMode {
  voucher,
  credit,
  both;

  static BillingMode fromString(String? s) {
    switch (s) {
      case 'voucher':
        return BillingMode.voucher;
      case 'credit':
        return BillingMode.credit;
      case 'both':
      default:
        return BillingMode.both;
    }
  }

  /// 화면 라벨 — 메뉴·헤더 카피에 사용
  String get label {
    switch (this) {
      case BillingMode.voucher:
        return '공고권';
      case BillingMode.credit:
        return '충전 잔액';
      case BillingMode.both:
        return '공고권 / 충전 잔액';
    }
  }
}

/// `config/billingPolicy` 문서 1:1 매핑 모델
///
/// 예시 문서:
/// ```json
/// {
///   "mode": "both",
///   "voucher": {
///     "expiryMonths": 12,
///     "packages": [
///       { "id": "v1",  "qty": 1,  "price": 88000  },
///       { "id": "v3",  "qty": 3,  "price": 240000 },
///       { "id": "v10", "qty": 10, "price": 700000 }
///     ]
///   },
///   "credit": {
///     "expiryMonthsFromLastUse": 24,
///     "packages": [
///       { "id": "c10",  "amount": 100000,  "bonus": 0     },
///       { "id": "c30",  "amount": 300000,  "bonus": 15000 },
///       { "id": "c100", "amount": 1000000, "bonus": 120000 }
///     ]
///   },
///   "autoRecharge": {
///     "thresholdVouchers": 1,
///     "thresholdCredit":   50000
///   }
/// }
/// ```
class BillingPolicyConfig {
  final BillingMode mode;
  final List<VoucherPackage> voucherPackages;
  final int voucherExpiryMonths;
  final List<CreditPackage> creditPackages;
  final int creditExpiryMonthsFromLastUse;
  final int autoRechargeThresholdVouchers;
  final int autoRechargeThresholdCredit;

  const BillingPolicyConfig({
    required this.mode,
    required this.voucherPackages,
    required this.voucherExpiryMonths,
    required this.creditPackages,
    required this.creditExpiryMonthsFromLastUse,
    required this.autoRechargeThresholdVouchers,
    required this.autoRechargeThresholdCredit,
  });

  /// 운영자가 아직 정책을 설정하지 않은 상황에서의 안전한 기본값.
  /// 실제 가격은 admin 화면에서 언제든 변경 가능.
  static const BillingPolicyConfig fallback = BillingPolicyConfig(
    mode: BillingMode.both,
    voucherPackages: [
      VoucherPackage(id: 'v1', qty: 1, price: 88000),
      VoucherPackage(id: 'v3', qty: 3, price: 240000),
      VoucherPackage(id: 'v10', qty: 10, price: 700000),
    ],
    voucherExpiryMonths: 12,
    creditPackages: [
      CreditPackage(id: 'c10', amount: 100000, bonus: 0),
      CreditPackage(id: 'c30', amount: 300000, bonus: 15000),
      CreditPackage(id: 'c100', amount: 1000000, bonus: 120000),
    ],
    creditExpiryMonthsFromLastUse: 24,
    autoRechargeThresholdVouchers: 1,
    autoRechargeThresholdCredit: 50000,
  );

  factory BillingPolicyConfig.fromMap(Map<String, dynamic> data) {
    final v = (data['voucher'] as Map<String, dynamic>?) ?? const {};
    final c = (data['credit'] as Map<String, dynamic>?) ?? const {};
    final auto = (data['autoRecharge'] as Map<String, dynamic>?) ?? const {};

    final vouchers = ((v['packages'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(VoucherPackage.fromMap)
        .toList();
    final credits = ((c['packages'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CreditPackage.fromMap)
        .toList();

    return BillingPolicyConfig(
      mode: BillingMode.fromString(data['mode'] as String?),
      voucherPackages:
          vouchers.isNotEmpty ? vouchers : fallback.voucherPackages,
      voucherExpiryMonths:
          (v['expiryMonths'] as num?)?.toInt() ?? fallback.voucherExpiryMonths,
      creditPackages: credits.isNotEmpty ? credits : fallback.creditPackages,
      creditExpiryMonthsFromLastUse:
          (c['expiryMonthsFromLastUse'] as num?)?.toInt() ??
              fallback.creditExpiryMonthsFromLastUse,
      autoRechargeThresholdVouchers:
          (auto['thresholdVouchers'] as num?)?.toInt() ??
              fallback.autoRechargeThresholdVouchers,
      autoRechargeThresholdCredit:
          (auto['thresholdCredit'] as num?)?.toInt() ??
              fallback.autoRechargeThresholdCredit,
    );
  }
}

class VoucherPackage {
  final String id;
  final int qty;
  final int price;
  const VoucherPackage(
      {required this.id, required this.qty, required this.price});

  factory VoucherPackage.fromMap(Map<String, dynamic> m) => VoucherPackage(
        id: m['id'] as String? ?? '',
        qty: (m['qty'] as num?)?.toInt() ?? 0,
        price: (m['price'] as num?)?.toInt() ?? 0,
      );
}

class CreditPackage {
  final String id;
  final int amount;
  final int bonus;
  const CreditPackage(
      {required this.id, required this.amount, required this.bonus});

  factory CreditPackage.fromMap(Map<String, dynamic> m) => CreditPackage(
        id: m['id'] as String? ?? '',
        amount: (m['amount'] as num?)?.toInt() ?? 0,
        bonus: (m['bonus'] as num?)?.toInt() ?? 0,
      );
}
