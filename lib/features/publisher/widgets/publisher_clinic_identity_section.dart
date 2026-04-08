import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../models/clinic_profile.dart';
import '../services/clinic_profile_service.dart';

/// STEP 2: 사업자/OCR 관련 치과 정보 확인·수정 (프로필 문서 반영)
class PublisherClinicIdentitySection extends StatefulWidget {
  final ClinicProfile profile;
  final VoidCallback onSaved;

  /// 웹 공고 에디터 3단계(치과 인증) — [JobPostForm] step3와 동일: 라벨 열 + 입력 한 줄
  final bool inlineFieldLabels;

  const PublisherClinicIdentitySection({
    super.key,
    required this.profile,
    required this.onSaved,
    this.inlineFieldLabels = false,
  });

  @override
  State<PublisherClinicIdentitySection> createState() =>
      _PublisherClinicIdentitySectionState();
}

class _PublisherClinicIdentitySectionState
    extends State<PublisherClinicIdentitySection> {
  late final TextEditingController _clinicNameCtrl;
  late final TextEditingController _displayNameCtrl;
  late final TextEditingController _ownerNameCtrl;
  late final TextEditingController _addressCtrl;
  bool _saving = false;

  /// 직전에 반영한 OCR 스냅샷(등록증 재업로드·스트림 갱신 감지용)
  late String _lastOcrSignature;

  static String _ocrStr(ClinicProfile p, String key) {
    final v = p.businessVerification.ocrResult?[key];
    if (v == null) return '';
    return v.toString().trim();
  }

  /// 등록증 OCR이 있으면 **항상 OCR 우선** (예전 테스트로 남은 최상위 필드보다 우선)
  static String _mergedOcrFirst(ClinicProfile p, String direct, String ocrKey) {
    final o = _ocrStr(p, ocrKey);
    if (o.isNotEmpty) return o;
    return direct.trim();
  }

  /// 구직자 노출명: OCR `displayName` → OCR `clinicName` → 저장된 displayName
  static String _mergedDisplayNameOcrFirst(ClinicProfile p) {
    final oDisp = _ocrStr(p, 'displayName');
    if (oDisp.isNotEmpty) return oDisp;
    final oClinic = _ocrStr(p, 'clinicName');
    if (oClinic.isNotEmpty) return oClinic;
    return p.displayName.trim();
  }

  /// ocrResult 내용 변화 감지(같은 프로필에서 등록증만 바뀐 경우 등)
  static String _ocrResultSignature(ClinicProfile p) {
    final m = p.businessVerification.ocrResult;
    if (m == null || m.isEmpty) return '';
    const keys = ['bizNo', 'clinicName', 'ownerName', 'address', 'displayName'];
    final b = StringBuffer();
    for (final k in keys) {
      b.write(k);
      b.write('=');
      b.write((m[k] ?? '').toString().trim());
      b.write('\x1e');
    }
    return b.toString();
  }

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _lastOcrSignature = _ocrResultSignature(p);
    _clinicNameCtrl = TextEditingController(
      text: _mergedOcrFirst(p, p.clinicName, 'clinicName'),
    );
    _displayNameCtrl = TextEditingController(
      text: _mergedDisplayNameOcrFirst(p),
    );
    _ownerNameCtrl = TextEditingController(
      text: _mergedOcrFirst(p, p.ownerName, 'ownerName'),
    );
    _addressCtrl = TextEditingController(
      text: _mergedOcrFirst(p, p.address, 'address'),
    );
  }

  /// OCR·프로필 스냅샷을 칸에 그대로 반영 (등록증 데이터 우선)
  void _applyOcrFirstFromProfile(ClinicProfile p) {
    final cn = _mergedOcrFirst(p, p.clinicName, 'clinicName');
    if (cn.isNotEmpty) _clinicNameCtrl.text = cn;
    final disp = _mergedDisplayNameOcrFirst(p);
    if (disp.isNotEmpty) _displayNameCtrl.text = disp;
    final ow = _mergedOcrFirst(p, p.ownerName, 'ownerName');
    if (ow.isNotEmpty) _ownerNameCtrl.text = ow;
    final ad = _mergedOcrFirst(p, p.address, 'address');
    if (ad.isNotEmpty) _addressCtrl.text = ad;
  }

  @override
  void didUpdateWidget(covariant PublisherClinicIdentitySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final p = widget.profile;
    if (oldWidget.profile.id != p.id) {
      _lastOcrSignature = _ocrResultSignature(p);
      _applyOcrFirstFromProfile(p);
      return;
    }
    final sig = _ocrResultSignature(p);
    if (sig != _lastOcrSignature) {
      _lastOcrSignature = sig;
      _applyOcrFirstFromProfile(p);
    }
  }

  @override
  void dispose() {
    _clinicNameCtrl.dispose();
    _displayNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: GoogleFonts.notoSansKr(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textDisabled,
      ),
      labelStyle: GoogleFonts.notoSansKr(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      isDense: true,
      border: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.divider),
      ),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.divider),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.accent, width: 2),
      ),
    );
  }

  /// 인라인 행용 — 라벨은 [Row] 왼쪽 열에 두고 필드에는 힌트만
  InputDecoration _decValueOnly(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.notoSansKr(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textDisabled,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      isDense: true,
      border: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.divider),
      ),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.divider),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.accent, width: 2),
      ),
    );
  }

  TextStyle get _fieldLabelStyle => GoogleFonts.notoSansKr(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  Widget _inlineLabeledField({
    required String label,
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: AppPublisher.formInlineLabelWidth,
          child: Padding(
            padding: EdgeInsets.only(top: maxLines > 1 ? 10 : 10),
            child: Text(label, style: _fieldLabelStyle),
          ),
        ),
        Expanded(
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            style: GoogleFonts.notoSansKr(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            decoration: _decValueOnly(hint),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ClinicProfileService.updateProfile(
        widget.profile.id,
        clinicName: _clinicNameCtrl.text.trim(),
        displayName: _displayNameCtrl.text.trim(),
        ownerName: _ownerNameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
      );
      widget.onSaved();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bv = widget.profile.businessVerification;
    final bizNo =
        bv.bizNo.isNotEmpty
            ? bv.bizNo
            : (bv.ocrResult?['bizNo'] as String? ?? '');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '치과 · 사업자 정보',
            style: GoogleFonts.notoSansKr(
              fontSize: AppPublisher.formSectionTitleSize,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppPublisher.formSectionTitleGap),
          Text(
            '등록증 OCR 값을 확인하고 필요 시 수정해 주세요.',
            style: GoogleFonts.notoSansKr(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          if (widget.inlineFieldLabels) ...[
            _inlineLabeledField(
              label: '상호(등록증 기준)',
              hint: '예) 서울○○치과의원',
              controller: _clinicNameCtrl,
            ),
            const SizedBox(height: 12),
            _inlineLabeledField(
              label: '구직자에게 보이는 치과명',
              hint: '비우면 상호와 동일하게 표시됩니다',
              controller: _displayNameCtrl,
            ),
            const SizedBox(height: 12),
            _inlineLabeledField(
              label: '대표자명',
              hint: '',
              controller: _ownerNameCtrl,
            ),
            const SizedBox(height: 12),
            _inlineLabeledField(
              label: '사업장 주소',
              hint: '',
              controller: _addressCtrl,
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: AppPublisher.formInlineLabelWidth,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('사업자등록번호', style: _fieldLabelStyle),
                  ),
                ),
                Expanded(
                  child: Text(
                    bizNo.isEmpty ? '(등록증 업로드 후 표시됩니다)' : bizNo,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color:
                          bizNo.isEmpty
                              ? AppColors.textDisabled
                              : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            TextFormField(
              controller: _clinicNameCtrl,
              style: GoogleFonts.notoSansKr(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              decoration: _dec('상호(등록증 기준)', '예) 서울○○치과의원'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _displayNameCtrl,
              style: GoogleFonts.notoSansKr(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              decoration: _dec('구직자에게 보이는 치과명', '비우면 상호와 동일하게 표시됩니다'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ownerNameCtrl,
              style: GoogleFonts.notoSansKr(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              decoration: _dec('대표자명', ''),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressCtrl,
              maxLines: 2,
              style: GoogleFonts.notoSansKr(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              decoration: _dec('사업장 주소', ''),
            ),
            const SizedBox(height: 12),
            Text(
              '사업자등록번호',
              style: GoogleFonts.notoSansKr(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              bizNo.isEmpty ? '(등록증 업로드 후 표시됩니다)' : bizNo,
              style: GoogleFonts.notoSansKr(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color:
                    bizNo.isEmpty
                        ? AppColors.textDisabled
                        : AppColors.textPrimary,
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: AppPublisher.ctaHeight,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppPublisher.buttonRadius,
                  ),
                ),
              ),
              child:
                  _saving
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                      : Text(
                        '이 단계 저장',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
