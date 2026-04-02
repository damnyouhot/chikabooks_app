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

/// 사업자등록증 업로드 인라인 섹션
///
/// UX 포지셔닝: "인증"이 아니라 "치과 정보 자동입력 편의 기능"
/// OCR 결과를 사용자에게 확인받은 후 프로필에 반영
class BizLicenseUploadSection extends StatefulWidget {
  final String profileId;
  final VoidCallback? onCompleted;

  const BizLicenseUploadSection({
    super.key,
    required this.profileId,
    this.onCompleted,
  });

  @override
  State<BizLicenseUploadSection> createState() =>
      _BizLicenseUploadSectionState();
}

class _BizLicenseUploadSectionState extends State<BizLicenseUploadSection> {
  bool _dismissed = false;
  bool _isUploading = false;
  double _uploadProgress = 0;
  Map<String, String>? _ocrResult;

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('파일을 읽을 수 없습니다.')),
        );
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
    final ext = rawExt.isNotEmpty
        ? rawExt
        : (file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'jpg');
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

      final fn = FirebaseFunctions.instance.httpsCallable(
        'verifyBusinessLicense',
      );
      final result = await fn.call({
        'docUrl': docUrl,
        'profileId': widget.profileId,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
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

      if (extracted.isEmpty) {
        widget.onCompleted?.call();
      } else {
        setState(() => _ocrResult = extracted);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('업로드 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _applyOcrToProfile() async {
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
        if (_ocrResult!.containsKey('ownerName'))
          'ownerName': _ocrResult!['ownerName'],
        if (_ocrResult!.containsKey('address'))
          'address': _ocrResult!['address'],
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() => _ocrResult = null);
      widget.onCompleted?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('반영 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.04),
        border: Border(
          left: BorderSide(color: AppColors.accent, width: 3),
        ),
      ),
      child: _ocrResult != null
          ? _buildConfirmation()
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
                '등록증을 올리면 치과 정보를 자동으로 채워드려요',
                style: GoogleFonts.notoSansKr(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _dismissed = true),
              child: Icon(Icons.close, size: 16, color: AppColors.textDisabled),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '상호명, 대표자명, 주소, 사업자번호를 자동으로 입력해요 (PDF·JPG·PNG)',
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
              height: 36,
              child: ElevatedButton.icon(
                onPressed: _pickAndUpload,
                icon: const Icon(Icons.upload_file, size: 16),
                label: Text(
                  '등록증 업로드',
                  style: GoogleFonts.notoSansKr(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => setState(() => _dismissed = true),
              child: Text(
                '나중에 할게요',
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

  static const _ocrLabels = {
    'clinicName': '상호명',
    'ownerName': '대표자명',
    'address': '주소',
    'bizNo': '사업자번호',
  };

  Widget _buildConfirmation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_outline, size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '등록증에서 아래 정보를 읽었어요',
                style: GoogleFonts.notoSansKr(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._ocrResult!.entries.map((e) {
          final label = _ocrLabels[e.key] ?? e.key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    label,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    e.value,
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
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: _applyOcrToProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: Text(
                  '프로필에 반영하기',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                setState(() => _ocrResult = null);
                widget.onCompleted?.call();
              },
              child: Text(
                '반영 안 함',
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
