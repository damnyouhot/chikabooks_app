import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import 'biz_license_verify_snapshot.dart';

/// 등록증 인증 결과 스냅샷 — 1:OCR · 2:국세청(강조) · 3:HIRA(보조·연한 톤)
class BizLicenseVerificationThreeTierPanel extends StatelessWidget {
  const BizLicenseVerificationThreeTierPanel({
    super.key,
    required this.snapshot,
    required this.ocrReadFailed,
    required this.ocrEmpty,
    this.ocrResult,
    required this.publisherStyleOcrLabelWidth,
  });

  final BizLicenseVerifySnapshot snapshot;

  /// `failReason == ocr_failed` 이고 추출 행이 없을 때
  final bool ocrReadFailed;

  /// 추출된 OCR 행이 하나도 없을 때
  final bool ocrEmpty;
  final Map<String, String>? ocrResult;
  final bool publisherStyleOcrLabelWidth;

  static const _tier1Order = ['clinicName', 'ownerName', 'bizNo', 'address'];

  static const _tier1Labels = {
    'clinicName': '상호',
    'ownerName': '대표자',
    'bizNo': '사업자번호',
    'address': '주소',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tier1Ocr(),
        SizedBox(height: AppSpacing.md),
        _tier2Nts(),
        SizedBox(height: AppSpacing.md),
        _tier3Hira(),
      ],
    );
  }

  Widget _tier1Ocr() {
    return _softCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1. 등록증에서 읽은 정보',
            style: GoogleFonts.notoSansKr(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '업로드한 등록증에서 자동으로 읽은 정보입니다.',
            style: GoogleFonts.notoSansKr(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          if (ocrReadFailed)
            Text(
              '등록증에서 상호·사업자번호 등을 읽지 못했습니다. 선명한 이미지로 다시 올려 주세요.',
              style: GoogleFonts.notoSansKr(
                fontSize: 12,
                color: AppColors.textPrimary,
                height: 1.45,
              ),
            )
          else if (ocrEmpty)
            Text(
              '추출된 항목이 없습니다. 다른 파일로 다시 시도해 주세요.',
              style: GoogleFonts.notoSansKr(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            )
          else
            ..._tier1Order.map((key) {
              final v = ocrResult?[key] ?? '';
              if (v.isEmpty) return const SizedBox.shrink();
              final labelW =
                  publisherStyleOcrLabelWidth
                      ? AppPublisher.formInlineLabelWidth
                      : 88.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: labelW,
                      child: Text(
                        _tier1Labels[key] ?? key,
                        style: GoogleFonts.notoSansKr(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        v,
                        style: GoogleFonts.notoSansKr(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _tier2Nts() {
    final ntsOk = snapshot.canApplyToProfileAfterNts || snapshot.skipped;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.accent, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  '핵심',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '2. 국세청 사업자 인증 상태',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (ntsOk)
                Icon(Icons.verified, size: 20, color: AppColors.accent),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '공고 등록 가능 여부를 판단하는 핵심 인증 단계입니다.',
            style: GoogleFonts.notoSansKr(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          _ntsRow('정상 사업자 여부', snapshot.lineNormalBusiness),
          _ntsRow('휴업/폐업 여부', snapshot.lineClosedBusiness),
          _ntsRow('조회 결과', snapshot.lineQuerySummary),
          _ntsRow('실패 사유', snapshot.lineFailReasonDisplay),
          if (snapshot.methodFootnote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              snapshot.methodFootnote,
              style: GoogleFonts.notoSansKr(
                fontSize: 10,
                color: AppColors.textDisabled,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ntsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: publisherStyleOcrLabelWidth ? 120 : 108,
            child: Text(
              label,
              style: GoogleFonts.notoSansKr(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.notoSansKr(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tier3Hira() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.divider.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '3. HIRA 의료기관 대조',
            style: GoogleFonts.notoSansKr(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '의료기관 정보와의 일치 여부를 보조적으로 확인합니다.',
            style: GoogleFonts.notoSansKr(
              fontSize: 10,
              color: AppColors.textDisabled,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          ..._hiraDynamicBullets(),
        ],
      ),
    );
  }

  List<Widget> _hiraDynamicBullets() {
    final note = (snapshot.hiraNote ?? '').trim();
    final hm = snapshot.hiraMatched;
    final lv = snapshot.hiraMatchLevel?.toLowerCase();
    final matchLine = _hiraTierBullet(lv, hm);

    return [
      if (note.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            note,
            style: GoogleFonts.notoSansKr(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.45,
            ),
          ),
        )
      else
        _hiraBullet('심평원 병원정보 연동 메모가 없습니다. 인증 완료 후 저장된 값이 여기 표시됩니다.'),
      _hiraBullet(matchLine),
      _hiraBullet(
        '건강보험심사평가원 공공데이터는 보조 참고용이며, 최종 판단과 다를 수 있습니다.',
      ),
    ];
  }

  /// 서버 B안 `hiraMatchLevel` 우선, 구버전은 [hiraMatched] 로 보조
  String _hiraTierBullet(String? level, bool? hiraMatched) {
    switch (level) {
      case 'strict':
        return '대조 등급(보조): 자동 조회상 일치. 공개데이터 기준·보조 확인이며 최종 인증 수단이 아닙니다.';
      case 'partial':
        return '대조 등급(보조): 부분 일치·표기 차이 가능. 공개데이터 기준 참고용입니다.';
      case 'none':
        return '대조 등급(보조): 자동 확인 어려움. 공개데이터 기준 보조 참고만 가능합니다.';
      default:
        break;
    }
    if (hiraMatched == true) {
      return '대조 결과(보조): 심평원 목록에서 치과 요양기관으로 조회됨(구버전 응답). 공개데이터 기준 참고용입니다.';
    }
    if (hiraMatched == false) {
      return '대조 결과(보조): 치과 항목 없음·상호·주소 불일치 가능 — 운영 검토 권장';
    }
    return '대조 결과(보조): 키 미설정·API 오류 등으로 자동 판정 불가';
  }

  Widget _hiraBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '· ',
            style: GoogleFonts.notoSansKr(
              fontSize: 11,
              color: AppColors.textDisabled,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.notoSansKr(
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _softCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }
}
