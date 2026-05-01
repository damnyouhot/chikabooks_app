import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../models/clinic_profile.dart';
import 'biz_license_verification_three_tier_panel.dart';
import 'biz_license_verify_snapshot.dart';

/// 사업자등록증 업로드 — OCR · 국세청 · HIRA(안내) 3단 스냅샷
class BizLicenseUploadSection extends StatefulWidget {
  final String profileId;
  final VoidCallback? onCompleted;
  final ValueChanged<Map<String, String>>? onOcrResult;

  final bool publisherStyleOcrLabelWidth;
  final bool replacementMode;
  final VoidCallback? onReplacementCancel;

  /// 인증 완료 후에도 Firestore 기준 3단 스냅샷을 복원할 때 전달
  final ClinicProfile? persistedProfile;

  /// 부모(예: 공고 에디터)에서 확인 다이얼로그 후 `replacementMode` 로 전환
  final Future<void> Function()? onReplaceLicenseWithDialog;

  const BizLicenseUploadSection({
    super.key,
    required this.profileId,
    this.onCompleted,
    this.onOcrResult,
    this.publisherStyleOcrLabelWidth = false,
    this.replacementMode = false,
    this.onReplacementCancel,
    this.persistedProfile,
    this.onReplaceLicenseWithDialog,
  });

  @override
  State<BizLicenseUploadSection> createState() =>
      _BizLicenseUploadSectionState();
}

class _BizLicenseUploadSectionState extends State<BizLicenseUploadSection> {
  bool _isUploading = false;
  double _uploadProgress = 0;

  Map<String, String>? _ocrResult;
  BizLicenseVerifySnapshot? _verifySnapshot;
  bool _ocrReadFailed = false;
  bool _ocrEmpty = false;

  /// `프로필에 반영하기` 성공 후 — 스냅샷은 유지하고 버튼만 완료 상태로
  bool _profileApplied = false;

  /// Firestore에서만 채운 스냅샷(업로드 세션 없음) — 「반영 안 함」 숨김용
  bool _hydratedFromProfile = false;

  static String _contentTypeForExt(String ext) {
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }

  bool get _canApplyToProfile {
    if (_profileApplied) return false;
    final snap = _verifySnapshot;
    if (snap == null) return false;
    if (_ocrReadFailed || _ocrEmpty) return false;
    if (_ocrResult == null || _ocrResult!.isEmpty) return false;
    return snap.canApplyToProfileAfterNts;
  }

  void _resetLocalVerificationState() {
    _verifySnapshot = null;
    _ocrResult = null;
    _ocrReadFailed = false;
    _ocrEmpty = false;
    _profileApplied = false;
    _hydratedFromProfile = false;
    _uploadProgress = 0;
  }

  Map<String, String>? _buildOcrMapFromProfile(ClinicProfile p) {
    final o = p.businessVerification.ocrResult ?? {};
    String pick(String key) {
      final ov = o[key];
      if (ov != null && ov.toString().trim().isNotEmpty) {
        return ov.toString().trim();
      }
      switch (key) {
        case 'clinicName':
          return p.clinicName.trim();
        case 'ownerName':
          return p.ownerName.trim();
        case 'address':
          return p.address.trim();
        case 'bizNo':
          return p.businessVerification.bizNo.trim();
        default:
          return '';
      }
    }

    final m = <String, String>{};
    for (final k in ['clinicName', 'ownerName', 'bizNo', 'address']) {
      final v = pick(k);
      if (v.isNotEmpty) m[k] = v;
    }
    return m.isEmpty ? null : m;
  }

  void _maybeSeedFromPersistedProfile() {
    final p = widget.persistedProfile;
    if (p == null ||
        !p.businessVerification.hasStoredData ||
        widget.replacementMode) {
      return;
    }
    if (_verifySnapshot != null || _isUploading) return;
    setState(() {
      _verifySnapshot = BizLicenseVerifySnapshot.fromPersistedClinicProfile(p);
      _ocrResult = _buildOcrMapFromProfile(p);
      _ocrReadFailed = false;
      _ocrEmpty = _ocrResult == null || _ocrResult!.isEmpty;
      _profileApplied = p.canPublishJobs;
      _hydratedFromProfile = true;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeSeedFromPersistedProfile();
    });
  }

  @override
  void didUpdateWidget(covariant BizLicenseUploadSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId) {
      setState(() {
        _isUploading = false;
        _resetLocalVerificationState();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeSeedFromPersistedProfile();
      });
      return;
    }
    if (!oldWidget.replacementMode && widget.replacementMode) {
      setState(_resetLocalVerificationState);
    } else if (oldWidget.replacementMode && !widget.replacementMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeSeedFromPersistedProfile();
      });
    }
    _syncHydratedSnapshotIfNeeded();
  }

  void _syncHydratedSnapshotIfNeeded() {
    if (!_hydratedFromProfile || widget.replacementMode || _isUploading) return;
    final p = widget.persistedProfile;
    if (p == null || !p.businessVerification.hasStoredData) return;
    final next = BizLicenseVerifySnapshot.fromPersistedClinicProfile(p);
    final ocr = _buildOcrMapFromProfile(p);
    final cur = _verifySnapshot;
    if (cur == null) return;
    if (cur.status == next.status &&
        cur.failReason == next.failReason &&
        cur.hiraNote == next.hiraNote &&
        cur.checkMethod == next.checkMethod &&
        cur.hiraMatched == next.hiraMatched &&
        cur.hiraMatchLevel == next.hiraMatchLevel) {
      return;
    }
    setState(() {
      _verifySnapshot = next;
      _ocrResult = ocr;
      _ocrReadFailed = false;
      _ocrEmpty = ocr == null || ocr.isEmpty;
      _profileApplied = p.canPublishJobs;
    });
  }

  Future<void> _pickAndUpload() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: !kIsWeb ? false : true,
    );
    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.first;
    Uint8List? bytes = file.bytes;
    if (bytes == null && !kIsWeb && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (bytes == null || bytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('파일을 읽을 수 없습니다.')));
      }
      return;
    }

    const maxBytes = 10 * 1024 * 1024;
    if (bytes.length > maxBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('파일은 10MB 이하만 업로드할 수 있어요.')),
        );
      }
      return;
    }

    final rawExt = (file.extension ?? '').toLowerCase();
    final ext =
        rawExt.isNotEmpty
            ? rawExt
            : (file.name.contains('.')
                ? file.name.split('.').last.toLowerCase()
                : 'jpg');
    if (!const {'pdf', 'jpg', 'jpeg', 'png'}.contains(ext)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF 또는 JPG, PNG만 선택할 수 있어요.')),
        );
      }
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _ocrResult = null;
      _verifySnapshot = null;
      _ocrReadFailed = false;
      _ocrEmpty = false;
      _profileApplied = false;
      _hydratedFromProfile = false;
    });

    try {
      final contentType = _contentTypeForExt(ext);
      final ref = FirebaseStorage.instance.ref(
        'clinicVerifications/$uid/${widget.profileId}/bizreg.$ext',
      );

      final meta = SettableMetadata(contentType: contentType);
      final task = ref.putData(bytes, meta);

      task.snapshotEvents.listen((s) {
        if (s.totalBytes > 0 && mounted) {
          setState(() => _uploadProgress = s.bytesTransferred / s.totalBytes);
        }
      });
      await task;
      final docUrl = await ref.getDownloadURL();

      // verifyBusinessLicense 는 asia-northeast3 리전에 배포되어 있음
      // (functions/src/biz-license-verify.ts).
      final fn = FirebaseFunctions.instanceFor(
        region: 'asia-northeast3',
      ).httpsCallable('verifyBusinessLicense');
      final result = await fn.call({
        'docUrl': docUrl,
        'profileId': widget.profileId,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final snapshot = BizLicenseVerifySnapshot.fromCallable(data);
      final extracted = <String, String>{
        if ((data['clinicName'] ?? '').toString().isNotEmpty)
          'clinicName': data['clinicName'].toString(),
        if ((data['ownerName'] ?? '').toString().isNotEmpty)
          'ownerName': data['ownerName'].toString(),
        if ((data['address'] ?? '').toString().isNotEmpty)
          'address': data['address'].toString(),
        if ((data['bizNo'] ?? '').toString().isNotEmpty)
          'bizNo': data['bizNo'].toString(),
      };

      final empty = extracted.isEmpty;
      final readFailed =
          empty &&
          (snapshot.failReason == 'ocr_failed' ||
              snapshot.failReason == 'not_business_registration' ||
              snapshot.failReason == 'image_download_failed');

      if (mounted) {
        setState(() {
          _verifySnapshot = snapshot;
          _ocrReadFailed = readFailed;
          _ocrEmpty = empty;
          _ocrResult = empty ? null : extracted;
        });
        if (!empty) {
          widget.onOcrResult?.call(extracted);
        }

        // 사용자에게 즉시 피드백 — OCR 이 사업자번호를 충분히 읽지 못한 경우.
        if (snapshot.failReason == 'not_business_registration') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('등록증 정보를 충분히 읽지 못했어요. 더 선명한 파일로 다시 시도해 주세요.'),
            ),
          );
        } else if (snapshot.isDifferentBusiness ||
            snapshot.failReason == 'different_business_number') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              duration: Duration(seconds: 7),
              content: Text(
                '기존 지점과 다른 사업자번호입니다. 기존 병원 정보는 바꾸지 않았어요. 새 지점 추가 또는 기존 사업자 교체를 선택해 주세요.',
              ),
            ),
          );
        } else if (!empty) {
          // bizNo 가 현재 프로필의 기존 bizNo 와 다르면 "다른 사업자" 가능성 안내.
          final newBiz = (extracted['bizNo'] ?? '').replaceAll(
            RegExp(r'[^0-9]'),
            '',
          );
          final oldBiz = (widget.persistedProfile?.businessVerification.bizNo ??
                  '')
              .replaceAll(RegExp(r'[^0-9]'), '');
          if (newBiz.isNotEmpty && oldBiz.isNotEmpty && newBiz != oldBiz) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 6),
                content: const Text(
                  '인식된 사업자번호가 기존과 달라요. 같은 지점이 맞다면 그대로 진행하고, '
                  '다른 치과라면 상단의 지점 칩에서 "새 지점 추가" 를 사용해 주세요.',
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('업로드 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _applyOcrToProfile() async {
    if (!_canApplyToProfile) return;
    if (_ocrResult == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final profileRef = FirebaseFirestore.instance
          .collection('clinics_accounts')
          .doc(uid)
          .collection('clinic_profiles')
          .doc(widget.profileId);

      await profileRef.update({
        if (_ocrResult!.containsKey('clinicName'))
          'clinicName': _ocrResult!['clinicName'],
        if (_ocrResult!.containsKey('clinicName'))
          'displayName': FieldValue.delete(),
        if (_ocrResult!.containsKey('ownerName'))
          'ownerName': _ocrResult!['ownerName'],
        if (_ocrResult!.containsKey('address'))
          'address': _ocrResult!['address'],
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _profileApplied = true);
        widget.onCompleted?.call();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('프로필에 반영했어요.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('반영 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.04),
        border: Border(left: BorderSide(color: AppColors.accent, width: 3)),
      ),
      child:
          _verifySnapshot != null && !_isUploading
              ? _buildResultPanel()
              : _isUploading
              ? _buildProgress()
              : _buildPrompt(),
    );
  }

  Widget _buildPrompt() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_fix_high, size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.replacementMode
                    ? '새 등록증을 올려 주세요'
                    : '등록증을 올리면 치과 정보를 자동으로 채워드려요',
                style: GoogleFonts.notoSansKr(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          widget.replacementMode
              ? '새 파일을 올리면 사업자 정보를 다시 확인합니다. 이전 등록증은 내부 인증 기록으로만 남으며 외부에 공개되지 않습니다. (PDF·JPG·PNG)'
              : '상호명, 대표자명, 주소, 사업자번호를 자동으로 입력해요 (PDF·JPG·PNG)',
          style: GoogleFonts.notoSansKr(
            fontSize: 12,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '※ 업로드된 사업자등록증은 내부 인증 목적으로만 사용되며, 외부에 공개되지 않습니다.',
          style: GoogleFonts.notoSansKr(
            fontSize: 11,
            color: AppColors.textDisabled,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              height: AppPublisher.ctaHeight,
              child: ElevatedButton.icon(
                onPressed: _pickAndUpload,
                icon: const Icon(Icons.upload_file, size: 16),
                label: Text(
                  widget.replacementMode ? '파일 선택' : '등록증 업로드',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppPublisher.buttonRadius,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (widget.replacementMode && widget.onReplacementCancel != null)
              TextButton(
                onPressed: widget.onReplacementCancel,
                child: Text(
                  '취소',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 12,
                    color: AppColors.textDisabled,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultPanel() {
    final snap = _verifySnapshot!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '인증 결과 요약',
          style: GoogleFonts.notoSansKr(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        BizLicenseVerificationThreeTierPanel(
          snapshot: snap,
          ocrReadFailed: _ocrReadFailed,
          ocrEmpty: _ocrEmpty,
          ocrResult: _ocrResult,
          publisherStyleOcrLabelWidth: widget.publisherStyleOcrLabelWidth,
        ),
        if (_profileApplied) ...[
          const SizedBox(height: 8),
          Text(
            '프로필에 반영했습니다. 등록증상 상호는 잠금 처리되고, 노출명만 수정할 수 있습니다.',
            style: GoogleFonts.notoSansKr(
              fontSize: 11,
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ] else if (!_canApplyToProfile) ...[
          const SizedBox(height: 8),
          Text(
            snap.isDifferentBusiness ||
                    snap.failReason == 'different_business_number'
                ? '기존 지점과 다른 사업자입니다. 기존 병원 정보는 그대로 유지됩니다. 새 지점으로 추가하거나, 정말 교체할 때만 별도 확인 후 진행하세요.'
                : _ocrReadFailed || _ocrEmpty
                ? '등록증에서 정보를 읽고, 국세청 사업자 인증이 완료되어야 프로필에 반영할 수 있어요.'
                : snap.failReason == 'hira_mismatch_after_grace' ||
                    snap.failReason == 'hira_mismatch_opened_at_unknown'
                ? '국세청 사업자 정보는 확인됐지만, 심평원에서 치과 기관으로 자동 확인되지 않아 공고 게시 전 검토가 필요해요.'
                : '국세청 사업자 인증이 완료된 뒤 프로필에 반영할 수 있어요.',
            style: GoogleFonts.notoSansKr(
              fontSize: 11,
              color: AppColors.textDisabled,
              height: 1.4,
            ),
          ),
        ],
        if (!_profileApplied && _canApplyToProfile) ...[
          const SizedBox(height: 8),
          Text(
            '인증 상호는 자동 반영 후 수정할 수 없고, 구직자에게 보이는 노출명만 별도로 관리합니다.',
            style: GoogleFonts.notoSansKr(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (widget.onReplaceLicenseWithDialog != null &&
            widget.persistedProfile?.canPublishJobs == true &&
            !widget.replacementMode) ...[
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: AppPublisher.ctaHeight,
                  child: OutlinedButton(
                    onPressed: () async {
                      await widget.onReplaceLicenseWithDialog!.call();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: const BorderSide(color: AppColors.accent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppPublisher.buttonRadius,
                        ),
                      ),
                    ),
                    child: Text(
                      '등록증 다시 올리기',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              height: AppPublisher.ctaHeight,
              child: ElevatedButton(
                onPressed:
                    _profileApplied
                        ? null
                        : (_canApplyToProfile ? _applyOcrToProfile : null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  disabledBackgroundColor: AppColors.divider,
                  disabledForegroundColor: AppColors.textDisabled,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppPublisher.buttonRadius,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: Text(
                  _profileApplied
                      ? (_hydratedFromProfile ? '현재 프로필 기준' : '프로필에 반영됨')
                      : '프로필에 반영하기',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed:
                  widget.replacementMode ||
                          widget.persistedProfile?.hasStoredVerification != true
                      ? _pickAndUpload
                      : widget.onReplaceLicenseWithDialog,
              child: Text(
                '다른 파일로 올리기',
                style: GoogleFonts.notoSansKr(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgress() {
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              '등록증을 처리하고 있어요...',
              style: GoogleFonts.notoSansKr(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: _uploadProgress,
          backgroundColor: AppColors.divider,
          color: AppColors.accent,
          minHeight: 3,
        ),
      ],
    );
  }
}
