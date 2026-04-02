import 'package:cloud_firestore/cloud_firestore.dart';

/// 공고권 유형
enum VoucherType {
  signupFree,
  promo,
  invite;

  static VoucherType fromString(String? s) {
    switch (s) {
      case 'signup_free':
        return VoucherType.signupFree;
      case 'promo':
        return VoucherType.promo;
      case 'invite':
        return VoucherType.invite;
      default:
        return VoucherType.signupFree;
    }
  }

  String get value {
    switch (this) {
      case VoucherType.signupFree:
        return 'signup_free';
      case VoucherType.promo:
        return 'promo';
      case VoucherType.invite:
        return 'invite';
    }
  }

  String get label {
    switch (this) {
      case VoucherType.signupFree:
        return '가입 축하 무료 공고권';
      case VoucherType.promo:
        return '프로모션 공고권';
      case VoucherType.invite:
        return '초대 공고권';
    }
  }
}

/// 공고권 상태
enum VoucherStatus {
  active,
  used,
  expired;

  static VoucherStatus fromString(String? s) {
    switch (s) {
      case 'active':
        return VoucherStatus.active;
      case 'used':
        return VoucherStatus.used;
      case 'expired':
        return VoucherStatus.expired;
      default:
        return VoucherStatus.active;
    }
  }

  String get value {
    switch (this) {
      case VoucherStatus.active:
        return 'active';
      case VoucherStatus.used:
        return 'used';
      case VoucherStatus.expired:
        return 'expired';
    }
  }
}

/// 무료 공고권 엔티티
///
/// Firestore: `vouchers/{voucherId}`
class Voucher {
  final String id;
  final String ownerUid;
  final VoucherType type;
  final VoucherStatus status;
  final String? usedForOrderId;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final DateTime? usedAt;

  /// 'system' (자동 발급) 또는 관리자 uid (수동 발급)
  final String issuedBy;

  const Voucher({
    required this.id,
    required this.ownerUid,
    this.type = VoucherType.signupFree,
    this.status = VoucherStatus.active,
    this.usedForOrderId,
    this.issuedAt,
    this.expiresAt,
    this.usedAt,
    this.issuedBy = 'system',
  });

  factory Voucher.fromMap(Map<String, dynamic> data, {required String id}) {
    return Voucher(
      id: id,
      ownerUid: data['ownerUid'] as String? ?? '',
      type: VoucherType.fromString(data['type'] as String?),
      status: VoucherStatus.fromString(data['status'] as String?),
      usedForOrderId: data['usedForOrderId'] as String?,
      issuedAt: (data['issuedAt'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      usedAt: (data['usedAt'] as Timestamp?)?.toDate(),
      issuedBy: data['issuedBy'] as String? ?? 'system',
    );
  }

  factory Voucher.fromDoc(DocumentSnapshot doc) {
    return Voucher.fromMap(doc.data() as Map<String, dynamic>, id: doc.id);
  }

  bool get isUsable =>
      status == VoucherStatus.active &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  int? get daysUntilExpiry {
    if (expiresAt == null) return null;
    return expiresAt!.difference(DateTime.now()).inDays;
  }

  String get displayLabel => type.label;
}
