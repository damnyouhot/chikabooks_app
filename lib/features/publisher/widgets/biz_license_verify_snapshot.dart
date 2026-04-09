import '../../../models/clinic_profile.dart';

/// [verifyBusinessLicense] Callable 응답 파싱 — 2·3단 UI용
class BizLicenseVerifySnapshot {
  const BizLicenseVerifySnapshot({
    this.status,
    this.failReason,
    this.checkMethod,
    this.skipped = false,
    this.hiraMatched,
    this.hiraNote,
    this.hiraMatchLevel,
  });

  final String? status;
  final String? failReason;
  final String? checkMethod;
  final bool skipped;

  /// 심평원 병원정보 보조 대조
  final bool? hiraMatched;
  final String? hiraNote;

  /// `strict` | `partial` | `none`
  final String? hiraMatchLevel;

  factory BizLicenseVerifySnapshot.fromCallable(Map<String, dynamic> data) {
    final hm = data['hiraMatched'];
    return BizLicenseVerifySnapshot(
      status: data['status']?.toString(),
      failReason: data['failReason']?.toString(),
      checkMethod: data['checkMethod']?.toString(),
      skipped: data['skipped'] == true,
      hiraMatched: hm is bool ? hm : null,
      hiraNote: data['hiraNote']?.toString(),
      hiraMatchLevel: data['hiraMatchLevel']?.toString(),
    );
  }

  /// 이미 인증된 프로필(Firestore)에서 3단 패널 복원용
  factory BizLicenseVerifySnapshot.fromPersistedClinicProfile(
    ClinicProfile profile,
  ) {
    final bv = profile.businessVerification;
    return BizLicenseVerifySnapshot(
      status: 'verified',
      failReason: bv.failReason,
      checkMethod: bv.checkMethod,
      skipped: false,
      hiraMatched: bv.hiraMatched,
      hiraNote: bv.hiraNote,
      hiraMatchLevel: bv.hiraMatchLevel,
    );
  }

  /// 프로필 반영 CTA — 국세청 단계 통과 시에만 허용
  bool get canApplyToProfileAfterNts {
    return (status ?? '') == 'verified';
  }

  String get lineNormalBusiness {
    final s = status ?? '';
    final fr = failReason ?? '';
    if (skipped) return '예 (기존 인증 유지)';
    if (s == 'verified') return '예';
    if (s == 'rejected') {
      if (fr == 'business_closed' || fr == 'nts_not_matched') return '아니오';
      if (fr == 'ocr_failed') return '확인 불가';
      return '아니오';
    }
    if (s == 'pending_auto') return '확인 중';
    if (s == 'manual_review') return '확인 불가(수동 검토)';
    return '—';
  }

  String get lineClosedBusiness {
    final s = status ?? '';
    final fr = failReason ?? '';
    if (skipped) return '해당 없음';
    if (s == 'verified') return '아니오 (사업 중)';
    if (fr == 'business_closed') return '예 (폐업·휴업 등)';
    if (s == 'rejected' && fr == 'nts_not_matched') return '확인 불가';
    if (fr == 'ocr_failed') return '—';
    if (s == 'pending_auto') return '확인 중';
    return '—';
  }

  String get lineQuerySummary {
    if (skipped) {
      return '이미 완료된 사업자 인증이 있어 조회를 건너뛰었습니다.';
    }
    final s = status ?? '';
    final fr = failReason ?? '';
    if (s == 'verified') {
      return '사업자등록번호가 국세청 사업자 상태 조회에 존재하며, 폐업·휴업 상태가 아닙니다.';
    }
    if (s == 'rejected') {
      switch (fr) {
        case 'business_closed':
          return '국세청 정보상 폐업·휴업 등으로 판단되었습니다.';
        case 'nts_not_matched':
          return '등록번호에 해당하는 사업자 정보를 찾을 수 없습니다.';
        case 'ocr_failed':
          return 'OCR 단계에서 중단되어 국세청 조회를 수행하지 않았습니다.';
        default:
          return '사업자 상태 확인에 실패했습니다.';
      }
    }
    if (s == 'pending_auto' && fr == 'nts_api_error') {
      return '국세청 API 일시 오류로 결과를 확정하지 못했습니다.';
    }
    if (s == 'pending_auto') {
      return '사업자 상태 확인 처리 중입니다.';
    }
    if (s == 'manual_review') {
      return '추가 검토가 필요할 수 있습니다.';
    }
    return '—';
  }

  String get lineFailReasonDisplay {
    final s = status ?? '';
    if (s == 'verified' || skipped) return '—';
    final fr = failReason ?? '';
    if (fr.isEmpty) return '—';
    return _failReasonKo(fr);
  }

  static String _failReasonKo(String code) {
    switch (code) {
      case 'business_closed':
        return '폐업·휴업 등';
      case 'nts_not_matched':
        return '등록번호 미조회';
      case 'ocr_failed':
        return '등록증 OCR 실패';
      case 'nts_api_error':
        return '국세청 API 오류';
      case 'missing_or_invalid_biz_no':
        return '사업자번호 누락·형식 오류';
      case 'hira_mismatch':
        return '내부 검토 필요(모의)';
      default:
        return code;
    }
  }

  String get methodFootnote {
    final m = checkMethod ?? '';
    if (m.isEmpty) return '';
    if (m == 'nts') {
      return '조회: 국세청 오픈API · 사업자등록번호만 전송';
    }
    if (m.startsWith('mock')) {
      return '조회: 개발용 시뮬레이션(운영은 국세청 API)';
    }
    if (m == 'nts_error') {
      return '조회: API 오류(재시도 가능)';
    }
    if (m == 'server_skip') {
      return '조회: 서버에서 건너뜀';
    }
    return m;
  }
}
