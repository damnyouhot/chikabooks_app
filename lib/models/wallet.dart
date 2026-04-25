import 'package:cloud_firestore/cloud_firestore.dart';

/// 지갑(공고권 + 충전 잔액) 모델
///
/// Firestore: `wallets/{uid}`
///  - 공고권 잔여 수량(`vouchers`) + 공고권별 만료 큐(`voucherEntries`)
///  - 충전 잔액(`creditBalance`) + 마지막 사용일(`creditLastUsedAt`)
///
/// 정책(만료 개월 수, 패키지)은 `MeSession.billingPolicy` 에서 가져온다.
/// 차감/충전 트랜잭션은 모두 서버 Cloud Function 에서만 수행하고,
/// 클라이언트는 읽기 전용으로 본다(보안 룰로 강제).
class Wallet {
  final String uid;

  /// 사용 가능 공고권 총수량
  final int vouchers;

  /// 충전 잔액 (원)
  final int creditBalance;

  /// 충전 잔액 마지막 사용일 (만료 카운트 기준)
  final DateTime? creditLastUsedAt;

  /// 곧 만료될 공고권 (가까운 만료일 순)
  final List<VoucherEntry> voucherEntries;

  final DateTime? updatedAt;

  const Wallet({
    required this.uid,
    this.vouchers = 0,
    this.creditBalance = 0,
    this.creditLastUsedAt,
    this.voucherEntries = const [],
    this.updatedAt,
  });

  /// 빈 지갑 — 문서가 없는 신규 사용자에게 사용
  factory Wallet.empty(String uid) => Wallet(uid: uid);

  factory Wallet.fromMap(Map<String, dynamic> data, {required String uid}) {
    final entries = ((data['voucherEntries'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(VoucherEntry.fromMap)
        .toList()
      ..sort((a, b) {
        if (a.expiresAt == null) return 1;
        if (b.expiresAt == null) return -1;
        return a.expiresAt!.compareTo(b.expiresAt!);
      });
    return Wallet(
      uid: uid,
      vouchers: (data['vouchers'] as num?)?.toInt() ?? 0,
      creditBalance: (data['creditBalance'] as num?)?.toInt() ?? 0,
      creditLastUsedAt: (data['creditLastUsedAt'] as Timestamp?)?.toDate(),
      voucherEntries: entries,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// 충전 잔액 만료 예정일 — `creditLastUsedAt + expiryMonthsFromLastUse`
  DateTime? creditExpiryAt(int expiryMonthsFromLastUse) {
    if (creditLastUsedAt == null) return null;
    return DateTime(
      creditLastUsedAt!.year,
      creditLastUsedAt!.month + expiryMonthsFromLastUse,
      creditLastUsedAt!.day,
    );
  }
}

/// 공고권 1장(또는 패키지 단위) — 만료일 추적용
class VoucherEntry {
  /// 발급 출처: 'purchase' | 'promo' | 'refund'
  final String source;
  final int qty;
  final DateTime? issuedAt;
  final DateTime? expiresAt;

  const VoucherEntry({
    required this.source,
    required this.qty,
    this.issuedAt,
    this.expiresAt,
  });

  factory VoucherEntry.fromMap(Map<String, dynamic> m) => VoucherEntry(
        source: m['source'] as String? ?? 'purchase',
        qty: (m['qty'] as num?)?.toInt() ?? 0,
        issuedAt: (m['issuedAt'] as Timestamp?)?.toDate(),
        expiresAt: (m['expiresAt'] as Timestamp?)?.toDate(),
      );
}

/// 지갑 변동 이력 (사용/충전/환불)
///
/// Firestore: `wallets/{uid}/ledger/{autoId}` — 서버에서만 기록
class WalletLedgerEntry {
  final String id;

  /// 'voucher_use' | 'voucher_charge' | 'credit_use' | 'credit_charge' | 'credit_refund'
  final String type;

  /// 변동량(부호 포함). 공고권은 장수, 충전 잔액은 원.
  final int delta;

  /// 변동 후 잔액
  final int balanceAfter;

  /// 연결된 주문 ID (있으면)
  final String? orderId;

  /// 사용자에게 표시할 라벨 (예: "공고 게시", "공고권 3장 패키지 충전")
  final String label;

  final DateTime? createdAt;

  const WalletLedgerEntry({
    required this.id,
    required this.type,
    required this.delta,
    required this.balanceAfter,
    this.orderId,
    this.label = '',
    this.createdAt,
  });

  factory WalletLedgerEntry.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalletLedgerEntry(
      id: doc.id,
      type: data['type'] as String? ?? '',
      delta: (data['delta'] as num?)?.toInt() ?? 0,
      balanceAfter: (data['balanceAfter'] as num?)?.toInt() ?? 0,
      orderId: data['orderId'] as String?,
      label: data['label'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  bool get isCharge => delta > 0;
  bool get isVoucher => type.startsWith('voucher_');
  bool get isCredit => type.startsWith('credit_');
}
