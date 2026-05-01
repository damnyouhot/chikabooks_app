import 'package:cloud_firestore/cloud_firestore.dart';

/// 사업자 인증 상태 (Firestore / Cloud Functions 문자열과 동기화)
enum BizVerificationStatus {
  none,
  pendingAuto,
  provisional,
  verified,
  rejected,
  manualReview;

  static BizVerificationStatus fromString(String? s) {
    switch (s) {
      case 'pending':
      case 'pending_auto':
        return BizVerificationStatus.pendingAuto;
      // 레거시(구 verifyBusinessLicense)
      case 'auto_verified':
      case 'pending_manual':
        return BizVerificationStatus.provisional;
      case 'provisional':
        return BizVerificationStatus.provisional;
      case 'verified':
        return BizVerificationStatus.verified;
      case 'rejected':
        return BizVerificationStatus.rejected;
      case 'manual_review':
        return BizVerificationStatus.manualReview;
      default:
        return BizVerificationStatus.none;
    }
  }

  String get value {
    switch (this) {
      case BizVerificationStatus.none:
        return 'none';
      case BizVerificationStatus.pendingAuto:
        return 'pending_auto';
      case BizVerificationStatus.provisional:
        return 'provisional';
      case BizVerificationStatus.verified:
        return 'verified';
      case BizVerificationStatus.rejected:
        return 'rejected';
      case BizVerificationStatus.manualReview:
        return 'manual_review';
    }
  }

  bool get isVerified => this == BizVerificationStatus.verified;

  bool get isProvisional => this == BizVerificationStatus.provisional;

  bool get canPublishJobs =>
      this == BizVerificationStatus.verified ||
      this == BizVerificationStatus.provisional;

  bool get isPendingVerification => this == BizVerificationStatus.pendingAuto;
}

class BusinessVerification {
  final BizVerificationStatus status;
  final String bizNo;
  final String? docUrl;
  final Map<String, dynamic>? ocrResult;
  final DateTime? verifiedAt;
  final String? method;
  final String? failReason;
  final DateTime? lastCheckAt;
  final String? checkMethod;
  final DateTime? openedAt;

  final bool? hiraMatched;
  final String? hiraNote;
  final String? hiraMatchLevel;
  final String? policyReason;
  final int? newClinicGraceDaysSinceOpened;

  const BusinessVerification({
    this.status = BizVerificationStatus.none,
    this.bizNo = '',
    this.docUrl,
    this.ocrResult,
    this.verifiedAt,
    this.method,
    this.failReason,
    this.lastCheckAt,
    this.checkMethod,
    this.openedAt,
    this.hiraMatched,
    this.hiraNote,
    this.hiraMatchLevel,
    this.policyReason,
    this.newClinicGraceDaysSinceOpened,
  });

  factory BusinessVerification.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const BusinessVerification();
    return BusinessVerification(
      status: BizVerificationStatus.fromString(data['status'] as String?),
      bizNo: data['bizNo'] as String? ?? '',
      docUrl: data['docUrl'] as String?,
      ocrResult: data['ocrResult'] as Map<String, dynamic>?,
      verifiedAt: _parseFlexibleDate(data['verifiedAt']),
      method: data['method'] as String?,
      failReason: data['failReason'] as String?,
      lastCheckAt: _parseFlexibleDate(data['lastCheckAt']),
      checkMethod: data['checkMethod'] as String?,
      openedAt:
          _parseFlexibleDate(data['openedAt']) ??
          _parseOpenedAtFromOcr(data['ocrResult']),
      hiraMatched: data['hiraMatched'] as bool?,
      hiraNote: data['hiraNote'] as String?,
      hiraMatchLevel: data['hiraMatchLevel'] as String?,
      policyReason: data['policyReason'] as String?,
      newClinicGraceDaysSinceOpened:
          (data['newClinicGraceDaysSinceOpened'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
    'status': status.value,
    'bizNo': bizNo,
    if (docUrl != null) 'docUrl': docUrl,
    if (ocrResult != null) 'ocrResult': ocrResult,
    if (verifiedAt != null) 'verifiedAt': Timestamp.fromDate(verifiedAt!),
    if (method != null) 'method': method,
    if (failReason != null) 'failReason': failReason,
    if (lastCheckAt != null) 'lastCheckAt': Timestamp.fromDate(lastCheckAt!),
    if (checkMethod != null) 'checkMethod': checkMethod,
    if (openedAt != null) 'openedAt': Timestamp.fromDate(openedAt!),
    if (hiraMatched != null) 'hiraMatched': hiraMatched,
    if (hiraNote != null) 'hiraNote': hiraNote,
    if (hiraMatchLevel != null) 'hiraMatchLevel': hiraMatchLevel,
    if (policyReason != null) 'policyReason': policyReason,
    if (newClinicGraceDaysSinceOpened != null)
      'newClinicGraceDaysSinceOpened': newClinicGraceDaysSinceOpened,
  };

  bool get hasStoredData =>
      status != BizVerificationStatus.none ||
      bizNo.trim().isNotEmpty ||
      (docUrl?.trim().isNotEmpty ?? false) ||
      (ocrResult?.isNotEmpty == true) ||
      [
        verifiedAt,
        method,
        failReason,
        lastCheckAt,
        checkMethod,
        openedAt,
        hiraMatched,
        hiraNote,
        hiraMatchLevel,
        policyReason,
        newClinicGraceDaysSinceOpened,
      ].any((v) => v != null);
}

DateTime? _parseFlexibleDate(Object? raw) {
  if (raw == null) return null;
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  final text = raw.toString().trim();
  if (text.isEmpty) return null;
  final direct = DateTime.tryParse(text);
  if (direct != null) return direct;
  return _parseYmdText(text);
}

DateTime? _parseOpenedAtFromOcr(Object? raw) {
  if (raw is! Map) return null;
  final value = raw['openedAt'];
  if (value == null) return null;
  return _parseYmdText(value.toString().trim());
}

DateTime? _parseYmdText(String text) {
  final match = RegExp(
    r'^(\d{4})[-./년\s]?(\d{1,2})[-./월\s]?(\d{1,2})',
  ).firstMatch(text);
  if (match == null) return null;
  final year = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final day = int.tryParse(match.group(3)!);
  if (year == null || month == null || day == null) return null;
  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}

/// Firestore: `clinics_accounts/{uid}/clinic_profiles/{profileId}`
class ClinicProfile {
  final String id;
  final String ownerUid;

  final String clinicName;
  final String displayName;

  final String address;
  final String ownerName;
  final String phone;
  final BusinessVerification businessVerification;
  final String? bizRegImageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ClinicProfile({
    required this.id,
    required this.ownerUid,
    this.clinicName = '',
    this.displayName = '',
    this.address = '',
    this.ownerName = '',
    this.phone = '',
    this.businessVerification = const BusinessVerification(),
    this.bizRegImageUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory ClinicProfile.fromMap(
    Map<String, dynamic> data, {
    required String id,
    required String ownerUid,
  }) {
    return ClinicProfile(
      id: id,
      ownerUid: ownerUid,
      clinicName: data['clinicName'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      address: data['address'] as String? ?? '',
      ownerName: data['ownerName'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      businessVerification: BusinessVerification.fromMap(
        data['businessVerification'] as Map<String, dynamic>?,
      ),
      bizRegImageUrl: data['bizRegImageUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory ClinicProfile.fromDoc(
    DocumentSnapshot doc, {
    required String ownerUid,
  }) {
    return ClinicProfile.fromMap(
      doc.data() as Map<String, dynamic>,
      id: doc.id,
      ownerUid: ownerUid,
    );
  }

  Map<String, dynamic> toMap() => {
    'clinicName': clinicName,
    'displayName': displayName,
    'address': address,
    'ownerName': ownerName,
    'phone': phone,
    'businessVerification': businessVerification.toMap(),
    if (bizRegImageUrl != null) 'bizRegImageUrl': bizRegImageUrl,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  String get effectiveName => displayName.isNotEmpty ? displayName : clinicName;

  bool get isBusinessVerified => businessVerification.status.isVerified;

  bool get canPublishJobs => businessVerification.status.canPublishJobs;

  bool get hasStoredVerification =>
      businessVerification.hasStoredData ||
      (bizRegImageUrl?.trim().isNotEmpty ?? false);

  bool get hasEnteredInfo =>
      clinicName.trim().isNotEmpty ||
      displayName.trim().isNotEmpty ||
      address.trim().isNotEmpty ||
      ownerName.trim().isNotEmpty ||
      phone.trim().isNotEmpty;

  bool get isBlankPlaceholder => !hasEnteredInfo && !hasStoredVerification;

  ClinicProfile copyWith({
    String? clinicName,
    String? displayName,
    String? address,
    String? ownerName,
    String? phone,
    BusinessVerification? businessVerification,
    String? bizRegImageUrl,
  }) {
    return ClinicProfile(
      id: id,
      ownerUid: ownerUid,
      clinicName: clinicName ?? this.clinicName,
      displayName: displayName ?? this.displayName,
      address: address ?? this.address,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      businessVerification: businessVerification ?? this.businessVerification,
      bizRegImageUrl: bizRegImageUrl ?? this.bizRegImageUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
