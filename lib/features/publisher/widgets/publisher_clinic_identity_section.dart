import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import '../../../models/clinic_profile.dart';
import '../services/clinic_profile_service.dart';

/// STEP 2: 사업자/OCR 관련 치과 정보 확인·수정 (프로필 문서 반영)
class PublisherClinicIdentitySection extends StatefulWidget {
  final ClinicProfile profile;
  final VoidCallback onSaved;

  /// 웹 공고 에디터 3단계(치과 인증) — [JobPostForm] step3와 동일: 라벨 열 + 입력 한 줄
  final bool inlineFieldLabels;

  /// 에디터 스티키 바를 쓸 때 하단 저장 버튼 숨김
  final bool hideSaveButton;

  const PublisherClinicIdentitySection({
    super.key,
    required this.profile,
    required this.onSaved,
    this.inlineFieldLabels = false,
    this.hideSaveButton = false,
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
  bool _requestingAdminReview = false;

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
    _displayNameCtrl.addListener(_onDisplayNameChanged);
    _ownerNameCtrl = TextEditingController(
      text: _mergedOcrFirst(p, p.ownerName, 'ownerName'),
    );
    _addressCtrl = TextEditingController(
      text: _mergedOcrFirst(p, p.address, 'address'),
    );
  }

  void _onDisplayNameChanged() {
    if (mounted) setState(() {});
  }

  /// OCR·프로필 스냅샷을 칸에 그대로 반영 (등록증 데이터 우선)
  void _applyOcrFirstFromProfile(ClinicProfile p) {
    final cn = _mergedOcrFirst(p, p.clinicName, 'clinicName');
    _clinicNameCtrl.text = cn;
    final disp = _mergedDisplayNameOcrFirst(p);
    _displayNameCtrl.text = disp;
    _onDisplayNameChanged();
    final ow = _mergedOcrFirst(p, p.ownerName, 'ownerName');
    _ownerNameCtrl.text = ow;
    final ad = _mergedOcrFirst(p, p.address, 'address');
    _addressCtrl.text = ad;
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
    _displayNameCtrl.removeListener(_onDisplayNameChanged);
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
    String? helperText,
    Widget? trailing,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: trailing,
                    ),
                  ],
                ],
              ),
              if (helperText != null && helperText.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  helperText,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDisabled,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _inlineReadOnlyValue({
    required String label,
    required String value,
    required String emptyText,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: AppPublisher.formInlineLabelWidth,
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(label, style: _fieldLabelStyle),
          ),
        ),
        Expanded(
          child: _readOnlyValueSurface(
            value: value,
            emptyText: emptyText,
            trailing: trailing,
          ),
        ),
      ],
    );
  }

  Widget _readOnlyValueBlock({
    required String label,
    required String value,
    required String emptyText,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _fieldLabelStyle),
        const SizedBox(height: 6),
        _readOnlyValueSurface(
          value: value,
          emptyText: emptyText,
          trailing: trailing,
        ),
      ],
    );
  }

  Widget _readOnlyValueSurface({
    required String value,
    required String emptyText,
    Widget? trailing,
  }) {
    final hasValue = value.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.webPublisherPageBg,
        borderRadius: BorderRadius.circular(AppPublisher.buttonRadius),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: hasValue ? AppColors.accent : AppColors.textDisabled,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasValue ? value : emptyText,
              style: GoogleFonts.notoSansKr(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color:
                    hasValue ? AppColors.textPrimary : AppColors.textDisabled,
              ),
            ),
          ),
          Text(
            '수정 불가',
            style: GoogleFonts.notoSansKr(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textDisabled,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }

  Widget _adminReviewButton() {
    return OutlinedButton.icon(
      onPressed: _requestingAdminReview ? null : _requestAdminNameReview,
      icon:
          _requestingAdminReview
              ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : const Icon(Icons.admin_panel_settings_outlined, size: 16),
      label: const Text('관리자 확인 요청'),
    );
  }

  Widget _ocrNameReviewButton() {
    return TextButton.icon(
      onPressed:
          _requestingAdminReview
              ? null
              : () => _requestAdminNameReview(registeredNameOcrIssue: true),
      icon: const Icon(Icons.report_problem_outlined, size: 15),
      label: const Text('상호 확인 요청'),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ClinicProfileService.updateProfile(
        widget.profile.id,
        displayName: _displayNameCtrl.text.trim(),
        ownerName: _ownerNameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
      );
      widget.onSaved();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _showAdminNameReview {
    final registered = _clinicNameCtrl.text.trim();
    final display = _displayNameCtrl.text.trim();
    if (registered.isEmpty || display.isEmpty) return false;
    return _compact(registered) != _compact(display);
  }

  String _compact(String value) =>
      value.replaceAll(RegExp(r'\s+'), '').toLowerCase();

  Future<void> _requestAdminNameReview({
    bool registeredNameOcrIssue = false,
  }) async {
    final registered = _clinicNameCtrl.text.trim();
    final display = _displayNameCtrl.text.trim();
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AppConfirmModal(
            title:
                registeredNameOcrIssue ? 'OCR 상호 확인 요청' : '관리자 확인 요청',
            message:
                registeredNameOcrIssue
                    ? '등록증 OCR이 상호를 실제와 다르게 읽었다면 관리자에게 확인을 요청할 수 있어요.\n\n'
                        '현재 등록증상 상호: $registered\n\n'
                        '운영팀이 등록증 원본과 OCR 결과를 확인해 처리합니다.'
                    : '등록증상 상호와 노출 치과명이 다릅니다.\n\n'
                        '등록증상 상호: $registered\n'
                        '노출 치과명: $display\n\n'
                        '실제 운영명 또는 간판명으로 쓰는 이름이라면 관리자에게 확인을 요청할 수 있어요. '
                        '요청 후 운영팀이 대시보드에서 확인하고 승인/반려 기록을 남깁니다.',
            confirmLabel: '확인 요청',
          ),
    );
    if (ok != true || !mounted) return;
    setState(() => _requestingAdminReview = true);
    try {
      final fn = FirebaseFunctions.instance.httpsCallable(
        'requestBusinessNameReview',
      );
      await fn.call({
        'profileId': widget.profile.id,
        'registeredClinicName': registered,
        'displayName': display.isEmpty ? registered : display,
        'reviewReason':
            registeredNameOcrIssue
                ? 'registered_name_ocr_error'
                : 'display_name_mismatch',
        'ownerName': _ownerNameCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('관리자 확인 요청을 보냈어요. 처리 결과 알림은 준비 중입니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('확인 요청에 실패했어요: $e')));
    } finally {
      if (mounted) setState(() => _requestingAdminReview = false);
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
          if (widget.profile.bizRegImageUrl != null ||
              widget.profile.businessVerification.docUrl != null ||
              (widget.profile.businessVerification.ocrResult != null &&
                  widget
                      .profile
                      .businessVerification
                      .ocrResult!
                      .isNotEmpty)) ...[
            const SizedBox(height: 8),
            Text(
              '등록증을 바꾸려면 위 단계에서 새 파일을 올려 주세요.',
              style: GoogleFonts.notoSansKr(
                fontSize: 11,
                color: AppColors.textDisabled,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (widget.inlineFieldLabels) ...[
            _inlineReadOnlyValue(
              label: '상호(등록증 기준)',
              value: _clinicNameCtrl.text.trim(),
              emptyText: '등록증 업로드 후 자동 표시됩니다',
              trailing:
                  _clinicNameCtrl.text.trim().isNotEmpty
                      ? _ocrNameReviewButton()
                      : null,
            ),
            const SizedBox(height: 12),
            _inlineLabeledField(
              label: '구직자에게 보이는 치과명',
              hint: '비우면 상호와 동일하게 표시됩니다',
              controller: _displayNameCtrl,
              helperText: '인증 상호와 너무 다르면 검토 과정에서 공고가 반려될 수 있어요.',
              trailing: _showAdminNameReview ? _adminReviewButton() : null,
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
            _readOnlyValueBlock(
              label: '상호(등록증 기준)',
              value: _clinicNameCtrl.text.trim(),
              emptyText: '등록증 업로드 후 자동 표시됩니다',
              trailing:
                  _clinicNameCtrl.text.trim().isNotEmpty
                      ? _ocrNameReviewButton()
                      : null,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _displayNameCtrl,
                    onChanged: (_) => _onDisplayNameChanged(),
                    style: GoogleFonts.notoSansKr(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    decoration: _dec('구직자에게 보이는 치과명', '비우면 상호와 동일하게 표시됩니다'),
                  ),
                ),
                if (_showAdminNameReview) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _adminReviewButton(),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '인증 상호와 너무 다르면 검토 과정에서 공고가 반려될 수 있어요.',
              style: GoogleFonts.notoSansKr(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textDisabled,
                height: 1.35,
              ),
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
          if (!widget.hideSaveButton)
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
