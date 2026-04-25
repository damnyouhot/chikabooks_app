import 'package:cloud_firestore/cloud_firestore.dart';

/// 사업자 인증 상태
/// Firestore / Cloud Functions 문자열과 동기화 (`pending` 은 `pendingAuto` 로 매핑)
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

  /// 운영팀 최종 승인까지 끝남 (정식 인증 마크 표시)
  bool get isVerified => this == BizVerificationStatus.verified;

  /// 자동 1~4단계는 통과했고 운영팀 최종 검토만 남은 상태
  bool get isProvisional => this == BizVerificationStatus.provisional;

  /// 공고 게시 가능 여부 — provisional / verified 모두 가능
  bool get canPublishJobs =>
      this == BizVerificationStatus.verified ||
      this == BizVerificationStatus.provisional;

  /// OCR 완료 후 국세청 등 검증 대기
  bool get isPendingVerification => this == BizVerificationStatus.pendingAuto;
}

/// 사업자 인증 정보
class BusinessVerification {
  final BizVerificationStatus status;
  final String bizNo;
  final String? docUrl;
  final Map<String, dynamic>? ocrResult;
  final DateTime? verifiedAt;
  /// OCR: `gemini_v1` 등 / 검증: `nts`, `mock`, `mock_hira` 등
  final String? method;
  /// 서버 전용 사유 코드 (예: `ocr_failed`, `nts_api_error`, `hira_mismatch`)
  final String? failReason;
  final DateTime? lastCheckAt;
  /// `nts` | `mock` | `mock_hira` | `nts_error` | `server_skip` …
  final String? checkMethod;
  final DateTime? openedAt;

  /// 심평원 병원정보 보조 대조
  final bool? hiraMatched;
  final String? hiraNote;

  /// `strict` | `partial` | `none` — 서버 B안 단계형
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
      verifiedAt: (data['verifiedAt'] as Timestamp?)?.toDate(),
      method: data['method'] as String?,
      failReason: data['failReason'] as String?,
      lastCheckAt: (data['lastCheckAt'] as Timestamp?)?.toDate(),
      checkMethod: data['checkMethod'] as String?,
      openedAt: (data['openedAt'] as Timestamp?)?.toDate() ??
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
        if (verifiedAt != null)
          'verifiedAt': Timestamp.fromDate(verifiedAt!),
        if (method != null) 'method': method,
        if (failReason != null) 'failReason': failReason,
        if (lastCheckAt != null)
          'lastCheckAt': Timestamp.fromDate(lastCheckAt!),
        if (checkMethod != null) 'checkMethod': checkMethod,
        if (openedAt != null) 'openedAt': Timestamp.fromDate(openedAt!),
        if (hiraMatched != null) 'hiraMatched': hiraMatched,
        if (hiraNote != null) 'hiraNote': hiraNote,
        if (hiraMatchLevel != null) 'hiraMatchLevel': hiraMatchLevel,
        if (policyReason != null) 'policyReason': policyReason,
        if (newClinicGraceDaysSinceOpened != null)
          'newClinicGraceDaysSinceOpened': newClinicGraceDaysSinceOpened,
      };
}

DateTime? _parseOpenedAtFromOcr(Object? raw) {
  if (raw is! Map) return null;
  final value = raw['openedAt'];
  if (value == null) return null;
  final text = value.toString().trim();
  final match = RegExp(r'^(\d{4})[-./년\s]?(\d{1,2})[-./월\s]?(\d{1,2})')
      .firstMatch(text);
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

/// 치과 프로필 (clinic_profiles 서브컬렉션 문서)
///
/// Firestore: `clinics_accounts/{uid}/clinic_profiles/{profileId}`
class ClinicProfile {
  final String id;
  final String ownerUid;

  /// 사업자등록증 기준 공식 상호명
  final String clinicName;

  /// 구직자에게 노출되는 치과명 (사용자가 수정 가능)
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

  factory ClinicProfile.fromDoc(DocumentSnapshot doc, {required String ownerUid}) {
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

  /// 공고에 노출할 치과명 (displayName 우선, 없으면 clinicName)
  String get effectiveName =>
      displayName.isNotEmpty ? displayName : clinicName;

  bool get isBusinessVerified => businessVerification.status.isVerified;

  /// 공고 게시 가능 여부 — 정식 인증(verified) 또는 조건부 승인(provisional)
  bool get canPublishJobs => businessVerification.status.canPublishJobs;

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
      businessVerification:
          businessVerification ?? this.businessVerification,
      bizRegImageUrl: bizRegImageUrl ?? this.bizRegImageUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Stepper·UI용: 인증 진행 중 (OCR 후 검증 대기)
  bool get isBusinessVerificationPending =>
      businessVerification.status.isPendingVerification;
}
