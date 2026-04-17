import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import 'biz_license_verify_snapshot.dart';

/// 등록증 인증 결과 스냅샷 — 각 tier를 3줄 요약 + 드롭다운 형태로 표시
class BizLicenseVerificationThreeTierPanel extends StatefulWidget {
  const BizLicenseVerificationThreeTierPanel({
    super.key,
    required this.snapshot,
    required this.ocrReadFailed,
    required this.ocrEmpty,
    this.ocrResult,
    required this.publisherStyleOcrLabelWidth,
  });

  final BizLicenseVerifySnapshot snapshot;
  final bool ocrReadFailed;
  final bool ocrEmpty;
  final Map<String, String>? ocrResult;
  final bool publisherStyleOcrLabelWidth;

  @override
  State<BizLicenseVerificationThreeTierPanel> createState() =>
      _BizLicenseVerificationThreeTierPanelState();
}

class _BizLicenseVerificationThreeTierPanelState
    extends State<BizLicenseVerificationThreeTierPanel> {
  final _expanded = [false, false, false];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tierPanel(
          index: 0,
          summaryLines: _tier1Summary(),
          headerLabel: '1. 등록증 OCR 정보',
          headerColor: AppColors.textPrimary,
          borderColor: AppColors.divider,
          bgColor: AppColors.white,
          detail: _tier1Detail(),
        ),
        SizedBox(height: AppSpacing.sm),
        _tierPanel(
          index: 1,
          summaryLines: _tier2Summary(),
          headerLabel: '2. 국세청 사업자 인증',
          headerColor: AppColors.accent,
          borderColor: AppColors.accent,
          bgColor: AppColors.accent.withValues(alpha: 0.06),
          leading: (widget.snapshot.canApplyToProfileAfterNts ||
                  widget.snapshot.skipped)
              ? const Icon(Icons.verified, size: 16, color: AppColors.accent)
              : null,
          detail: _tier2Detail(),
        ),
        SizedBox(height: AppSpacing.sm),
        _tierPanel(
          index: 2,
          summaryLines: _tier3Summary(),
          headerLabel: '3. HIRA 의료기관 대조',
          headerColor: AppColors.textSecondary,
          borderColor: AppColors.divider,
          bgColor: AppColors.divider.withValues(alpha: 0.2),
          detail: _tier3Detail(),
        ),
      ],
    );
  }

  // ── Tier 드롭다운 공통 패널 ──────────────────────────────
  Widget _tierPanel({
    required int index,
    required List<String> summaryLines,
    required String headerLabel,
    required Color headerColor,
    required Color borderColor,
    required Color bgColor,
    Widget? leading,
    required Widget detail,
  }) {
    final expanded = _expanded[index];
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: borderColor, width: expanded ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 헤더(항상 표시) ──
          InkWell(
            onTap: () => setState(() => _expanded[index] = !_expanded[index]),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leading != null) ...[
                    leading,
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headerLabel,
                          style: GoogleFonts.notoSansKr(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: headerColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        for (final line in summaryLines)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              line,
                              style: GoogleFonts.notoSansKr(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppColors.textDisabled,
                  ),
                ],
              ),
            ),
          ),
          // ── 상세 내용(확장 시) ──
          if (expanded) ...[
            Divider(height: 1, color: borderColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: detail,
            ),
          ],
        ],
      ),
    );
  }

  // ── Tier 1: OCR ──────────────────────────────────────────
  List<String> _tier1Summary() {
    if (widget.ocrReadFailed) return ['등록증 읽기 실패 — 선명한 이미지로 다시 올려주세요'];
    if (widget.ocrEmpty) return ['추출된 항목 없음 — 다른 파일로 재시도 필요'];
    final r = widget.ocrResult ?? {};
    return [
      '상호: ${r['clinicName'] ?? '(없음)'}',
      '대표자: ${r['ownerName'] ?? '-'} · 사번: ${r['bizNo'] ?? '-'}',
      '주소: ${_truncate(r['address'] ?? '-', 26)}',
    ];
  }

  Widget _tier1Detail() {
    if (widget.ocrReadFailed) {
      return Text(
        '등록증에서 상호·사업자번호 등을 읽지 못했습니다. 선명한 이미지로 다시 올려 주세요.',
        style: GoogleFonts.notoSansKr(
          fontSize: 12,
          color: AppColors.textPrimary,
          height: 1.45,
        ),
      );
    }
    if (widget.ocrEmpty) {
      return Text(
        '추출된 항목이 없습니다. 다른 파일로 다시 시도해 주세요.',
        style: GoogleFonts.notoSansKr(
          fontSize: 12,
          color: AppColors.textSecondary,
          height: 1.45,
        ),
      );
    }
    const order = ['clinicName', 'ownerName', 'bizNo', 'address'];
    const labels = {
      'clinicName': '상호',
      'ownerName': '대표자',
      'bizNo': '사업자번호',
      'address': '주소',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: order.expand((key) {
        final v = widget.ocrResult?[key] ?? '';
        if (v.isEmpty) return <Widget>[];
        return [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 72,
                  child: Text(
                    labels[key] ?? key,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    v,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ];
      }).toList(),
    );
  }

  // ── Tier 2: NTS ──────────────────────────────────────────
  List<String> _tier2Summary() {
    final ok = widget.snapshot.canApplyToProfileAfterNts ||
        widget.snapshot.skipped;
    return [
      ok ? '✓ 인증 완료 — 공고 등록 가능' : '인증 대기 또는 미완료',
      '정상 사업자: ${_short(widget.snapshot.lineNormalBusiness)}',
      '조회 결과: ${_short(widget.snapshot.lineQuerySummary)}',
    ];
  }

  Widget _tier2Detail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '공고 등록 가능 여부를 판단하는 핵심 인증 단계입니다.',
          style: GoogleFonts.notoSansKr(
            fontSize: 11,
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 8),
        _ntsRow('정상 사업자 여부', widget.snapshot.lineNormalBusiness),
        _ntsRow('휴업/폐업 여부', widget.snapshot.lineClosedBusiness),
        _ntsRow('조회 결과', widget.snapshot.lineQuerySummary),
        _ntsRow('실패 사유', widget.snapshot.lineFailReasonDisplay),
        if (widget.snapshot.methodFootnote.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            widget.snapshot.methodFootnote,
            style: GoogleFonts.notoSansKr(
              fontSize: 10,
              color: AppColors.textDisabled,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _ntsRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: GoogleFonts.notoSansKr(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.notoSansKr(
                fontSize: 11,
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

  // ── Tier 3: HIRA ─────────────────────────────────────────
  List<String> _tier3Summary() {
    final lv = widget.snapshot.hiraMatchLevel?.toLowerCase();
    final hm = widget.snapshot.hiraMatched;
    final matchSummary = _hiraLevelShort(lv, hm);
    final note = (widget.snapshot.hiraNote ?? '').trim();
    return [
      '의료기관 정보와의 일치 여부 보조 확인',
      '대조: $matchSummary',
      note.isNotEmpty ? _truncate(note, 28) : '심평원 연동 메모 없음',
    ];
  }

  Widget _tier3Detail() {
    final note = (widget.snapshot.hiraNote ?? '').trim();
    final lv = widget.snapshot.hiraMatchLevel?.toLowerCase();
    final hm = widget.snapshot.hiraMatched;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          note.isNotEmpty
              ? note
              : '심평원 병원정보 연동 메모가 없습니다. 인증 완료 후 저장된 값이 여기 표시됩니다.',
          style: GoogleFonts.notoSansKr(
            fontSize: 11,
            color: AppColors.textPrimary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _hiraTierBullet(lv, hm),
          style: GoogleFonts.notoSansKr(
            fontSize: 11,
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '건강보험심사평가원 공공데이터는 보조 참고용이며, 최종 판단과 다를 수 있습니다.',
          style: GoogleFonts.notoSansKr(
            fontSize: 10,
            color: AppColors.textDisabled,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ── 헬퍼 ─────────────────────────────────────────────────
  String _hiraLevelShort(String? level, bool? hiraMatched) {
    switch (level) {
      case 'strict':
        return '일치';
      case 'partial':
        return '부분 일치';
      case 'none':
        return '확인 어려움';
      default:
        break;
    }
    if (hiraMatched == true) return '조회됨(구버전)';
    if (hiraMatched == false) return '불일치 가능';
    return '판정 불가';
  }

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
      return '대조 결과(보조): 심평원 목록에서 치과 요양기관으로 조회됨. 공개데이터 기준 참고용입니다.';
    }
    if (hiraMatched == false) {
      return '대조 결과(보조): 치과 항목 없음·상호·주소 불일치 가능 — 운영 검토 권장';
    }
    return '대조 결과(보조): 키 미설정·API 오류 등으로 자동 판정 불가';
  }

  String _short(String v) {
    if (v.isEmpty) return '-';
    return v.length > 16 ? '${v.substring(0, 16)}…' : v;
  }

  String _truncate(String v, int max) {
    if (v.isEmpty) return '-';
    return v.length > max ? '${v.substring(0, max)}…' : v;
  }
}
