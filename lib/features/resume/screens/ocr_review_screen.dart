import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import '../../../core/media/safe_image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../models/resume.dart';
import '../../../models/resume_import_draft.dart';
import '../../../services/resume_service.dart';
import 'resume_edit_screen.dart';

/// OCR 진입 소스 — 홈 화면에서 어떤 버튼으로 들어왔는지
enum OcrInputSource {
  /// 사진(카메라 촬영 / 갤러리 선택)
  photo,
  /// 파일(file_picker: JPG·PNG·PDF)
  file,
}

/// OCR 자동입력 검수 화면
///
/// 설계서 2.1.3 / 2.1.4 기준:
/// 1. 이미지 선택/촬영 or 파일 선택
/// 2. 개인정보 고지 확인
/// 3. Firebase Storage 업로드 + Cloud Function(Gemini) 처리 대기
/// 4. Firestore 실시간 리스닝 → 추출 결과 검수 (필드별 신뢰도 배지)
/// 5. 확정 → 이력서에 반영
class OcrReviewScreen extends StatefulWidget {
  final OcrInputSource source;

  const OcrReviewScreen({
    super.key,
    this.source = OcrInputSource.photo,
  });

  @override
  State<OcrReviewScreen> createState() => _OcrReviewScreenState();
}

class _OcrReviewScreenState extends State<OcrReviewScreen> {
  _OcrStep _step = _OcrStep.selectImages;
  List<XFile> _selectedImages = [];
  bool _autoDeleteOriginal = true;
  bool _uploading = false;
  bool _confirming = false;
  double _uploadProgress = 0;
  String? _draftId;
  ResumeImportDraft? _draft;
  String? _errorDetail;

  final _picker = ImagePicker();

  // ── title ────────────────────────────────────────────────
  String get _screenTitle => widget.source == OcrInputSource.file
      ? '파일로 이력서 추출'
      : '사진으로 이력서 추출';

  // ── accent colors (진입 소스에 따라 아이콘 색 분기) ──────
  Color get _sourceAccent => widget.source == OcrInputSource.file
      ? AppColors.resumeEmphasis
      : AppColors.accent;

  @override
  void initState() {
    super.initState();
    // 파일 진입 시 첫 선택 자동 실행
    if (widget.source == OcrInputSource.file) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickFile());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          _screenTitle,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case _OcrStep.selectImages:
        return _buildSelectImages();
      case _OcrStep.privacy:
        return _buildPrivacyNotice();
      case _OcrStep.processing:
        return _buildProcessing();
      case _OcrStep.review:
        return _buildReview();
      case _OcrStep.done:
        return _buildDone();
      case _OcrStep.error:
        return _buildError();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Step 1: 이미지/파일 선택
  // ═══════════════════════════════════════════════════════════

  Widget _buildSelectImages() {
    final isFile = widget.source == OcrInputSource.file;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // 안내 박스
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: _sourceAccent.withOpacity(0.06),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isFile
                    ? '이력서 파일(JPG·PNG)을 선택하세요.'
                    : '이력서 사진을 촬영하거나 갤러리에서 선택하세요.',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isFile
                    ? '여러 장 선택 가능해요. AI가 자동으로 정보를 추출합니다.'
                    : '여러 페이지를 한번에 선택할 수 있어요.\nAI가 자동으로 정보를 추출합니다.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // 선택된 이미지 미리보기
        if (_selectedImages.isNotEmpty) ...[
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length + 1,
              itemBuilder: (_, i) {
                if (i == _selectedImages.length) return _addMoreButton();
                return _imagePreviewCard(i);
              },
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${_selectedImages.length}장 선택됨',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // 선택 버튼 (이미지가 없을 때만 표시)
        if (_selectedImages.isEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          if (isFile)
            _squarePickButton(
              icon: Icons.folder_open_outlined,
              label: '파일 선택',
              color: _sourceAccent,
              onTap: _pickFile,
            )
          else
            Row(
              children: [
                if (!kIsWeb) ...[
                  Expanded(
                    child: _squarePickButton(
                      icon: Icons.camera_alt_outlined,
                      label: '카메라 촬영',
                      color: AppColors.accent,
                      onTap: _pickFromCamera,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: _squarePickButton(
                    icon: Icons.photo_library_outlined,
                    label: kIsWeb ? '파일 선택' : '갤러리에서 선택',
                    color: AppColors.accent,
                    onTap: _pickFromGallery,
                  ),
                ),
              ],
            ),
        ],

        const SizedBox(height: AppSpacing.xl),

        // 다음 단계 버튼
        if (_selectedImages.isNotEmpty)
          FilledButton(
            onPressed: () => setState(() => _step = _OcrStep.privacy),
            style: FilledButton.styleFrom(
              backgroundColor: _sourceAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
            child: const Text(
              '다음: 개인정보 고지 확인',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }

  Widget _addMoreButton() {
    return GestureDetector(
      onTap: widget.source == OcrInputSource.file ? _pickFile : _pickFromGallery,
      child: Container(
        width: 90,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Icon(Icons.add, color: AppColors.textDisabled),
      ),
    );
  }

  Widget _imagePreviewCard(int idx) {
    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: FutureBuilder<Uint8List>(
              future: _selectedImages[idx].readAsBytes(),
              builder: (_, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return Container(
                    color: AppColors.surfaceMuted,
                    height: 120,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError || !snap.hasData || snap.data!.isEmpty) {
                  return Container(
                    color: AppColors.surfaceMuted,
                    height: 120,
                    child: const Icon(Icons.broken_image_outlined,
                        color: AppColors.textDisabled),
                  );
                }
                return Image.memory(snap.data!,
                    width: 90, height: 120, fit: BoxFit.cover);
              },
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () {
                if (!mounted) return;
                setState(() => _selectedImages.removeAt(idx));
              },
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${idx + 1}',
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _squarePickButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Step 2: 개인정보 고지
  // ═══════════════════════════════════════════════════════════

  Widget _buildPrivacyNotice() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.warning.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_outlined,
                      size: 20, color: AppColors.warning),
                  const SizedBox(width: 8),
                  const Text(
                    '개인정보 수집 · 이용 안내',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _noticeItem(
                '수집 항목: 이력서 이미지에 포함된 이름, 연락처, 주소, 생년월일, 면허번호 등 개인정보',
              ),
              _noticeItem(
                '수집 목적: AI 자동입력 — 이미지에서 이력서 필드를 추출하여 작성을 도와드립니다.',
              ),
              _noticeItem(
                '제3자 처리: 이미지는 Google Gemini AI 서버로 전송되어 분석됩니다. Google의 개인정보처리방침이 적용됩니다.',
              ),
              _noticeItem(
                '보존 기간: 검수 완료 후 원본 이미지는 즉시 삭제됩니다(기본 설정). 아래 옵션으로 유지도 가능합니다.',
              ),
              _noticeItem(
                '거부 권리: 동의하지 않으셔도 이력서를 직접 작성하실 수 있으며, 서비스 이용에 불이익이 없습니다.',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.appBg,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '검수 완료 후 원본 자동 삭제 (권장)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            '분석 완료 후 서버의 원본 이미지를 즉시 삭제합니다.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textDisabled,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _autoDeleteOriginal,
                      onChanged: (v) =>
                          setState(() => _autoDeleteOriginal = v),
                      activeColor: AppColors.success,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        FilledButton(
          onPressed: _uploading ? null : _startOcr,
          style: FilledButton.styleFrom(
            backgroundColor: _sourceAccent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
          child: _uploading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Text(
                  '위 내용에 동의하고 자동입력 시작',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _step = _OcrStep.selectImages),
            child: const Text(
              '동의하지 않고 돌아가기',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _noticeItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•',
              style: TextStyle(fontSize: 14, color: AppColors.textDisabled)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Step 3: 처리 중
  // ═══════════════════════════════════════════════════════════

  Widget _buildProcessing() {
    return _ResumeAiLoadingView(
      isUploading: _uploading,
      uploadProgress: _uploadProgress,
      accentColor: _sourceAccent,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Step 4: 검수 결과
  // ═══════════════════════════════════════════════════════════

  Widget _buildReview() {
    if (_draft == null) return _buildProcessing();

    final fields = _draft!.suggestedFields;
    final confidence = _draft!.confidence;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // 상태 배너
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.06),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle,
                  size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'AI 분석이 완료되었어요. 내용을 확인하고 수정해주세요.',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // 필드별 카드
        ..._buildFieldCards(fields, confidence),

        const SizedBox(height: AppSpacing.xl),

        FilledButton(
          onPressed: _confirming ? null : _confirmDraft,
          style: FilledButton.styleFrom(
            backgroundColor: _sourceAccent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
          child: _confirming
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.white,
                  ),
                )
              : const Text(
                  '이력서에 반영하기',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
        ),
      ],
    );
  }

  List<Widget> _buildFieldCards(
    Map<String, dynamic> fields,
    Map<String, double> confidence,
  ) {
    final displayKeys = [
      '이름|name',
      '연락처|phone',
      '이메일|email',
      '거주지|address',
      '생년월일|birthDate',
      '성별|gender',
      '경력|experiences',
      '스킬|skills',
      '학력|education',
      '자기소개|summary',
    ];

    return displayKeys.map((entry) {
      final parts = entry.split('|');
      final label = parts[0];
      final key = parts[1];
      final raw = fields[key];
      final conf = confidence[key] ?? 0.0;
      final isLow = conf < 0.7;

      String displayValue;
      if (raw == null) {
        displayValue = '';
      } else if (raw is List) {
        if (raw.isEmpty) {
          displayValue = '';
        } else if (raw.first is Map) {
          displayValue = raw
              .map((e) {
                final m = e as Map<String, dynamic>;
                return [
                  m['clinicName'] ?? m['school'] ?? '',
                  m['role'] ?? m['major'] ?? '',
                  m['startDate'] ?? '',
                  if ((m['endDate'] ?? '').isNotEmpty)
                    '~ ${m['endDate']}',
                ].where((s) => s.toString().isNotEmpty).join(' / ');
              })
              .join('\n');
        } else {
          displayValue = raw.join(', ');
        }
      } else {
        displayValue = raw.toString();
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isLow
                ? AppColors.resumeEmphasis.withOpacity(0.3)
                : AppColors.divider,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDisabled,
                  ),
                ),
                const Spacer(),
                if (isLow)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.resumeEmphasis.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Text(
                      '신뢰도 낮음 ${(conf * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.resumeEmphasis,
                      ),
                    ),
                  )
                else if (displayValue.isNotEmpty)
                  Text(
                    '${(conf * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              displayValue.isEmpty ? '(추출되지 않음)' : displayValue,
              style: TextStyle(
                fontSize: 14,
                color: displayValue.isEmpty
                    ? AppColors.textDisabled
                    : AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════
  // Step 5: 완료
  // ═══════════════════════════════════════════════════════════

  Widget _buildDone() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check,
                  size: 36, color: AppColors.success),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              '자동입력이 완료되었어요!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '이력서 편집 화면에서 내용을 확인해주세요.',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: () {
                if (kIsWeb) {
                  context.go('/applicant/resumes');
                } else {
                  Navigator.pop(context, true);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: _sourceAccent,
              ),
              child: const Text('이력서 목록으로'),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Error
  // ═══════════════════════════════════════════════════════════

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: AppColors.error.withOpacity(0.6)),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'OCR 처리 중 오류가 발생했어요.',
              style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            if (_errorDetail != null) ...[
              const SizedBox(height: 6),
              Text(
                _errorDetail!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textDisabled),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton(
              onPressed: () => setState(() {
                _step = _OcrStep.selectImages;
                _selectedImages = [];
                _errorDetail = null;
              }),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 이미지/파일 선택 액션
  // ═══════════════════════════════════════════════════════════

  Future<void> _pickFromCamera() async {
    if (kIsWeb) return;
    final photo = await SafeImagePicker.pickSingleFromCamera(
      context: context,
      picker: _picker,
    );
    if (photo == null || !mounted) return;
    setState(() => _selectedImages.add(photo));
  }

  Future<void> _pickFromGallery() async {
    final images = await SafeImagePicker.pickMultiFromGallery(
      context: context,
      picker: _picker,
    );
    if (images.isEmpty || !mounted) return;
    setState(() => _selectedImages.addAll(images));
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
        withData: false,
        withReadStream: false,
      );
      if (result == null || !mounted) return;

      final file = result.files.first;
      if (file.path == null) return;

      final ext = (file.extension ?? '').toLowerCase();

      if (ext == 'pdf') {
        // PDF → 페이지별 이미지 변환
        await _addPdfAsImages(file.path!);
      } else {
        // JPG / PNG 직접 추가
        setState(() => _selectedImages.add(XFile(file.path!)));
      }
    } catch (e) {
      debugPrint('⚠️ _pickFile error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일 선택 오류: $e')),
        );
      }
    }
  }

  /// PDF 파일을 페이지별로 PNG 이미지로 변환 후 [_selectedImages]에 추가
  Future<void> _addPdfAsImages(String pdfPath) async {
    if (!mounted) return;
    setState(() => _uploading = true);

    try {
      final doc = await PdfDocument.openFile(pdfPath);
      final pageCount = doc.pagesCount;
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final converted = <XFile>[];

      for (int i = 1; i <= pageCount; i++) {
        final page = await doc.getPage(i);
        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: PdfPageImageFormat.png,
        );
        await page.close();

        if (pageImage?.bytes != null) {
          final outPath = '${tempDir.path}/pdf_${timestamp}_p$i.png';
          await File(outPath).writeAsBytes(pageImage!.bytes);
          converted.add(XFile(outPath));
        }
      }

      await doc.close();

      if (mounted) {
        setState(() {
          _selectedImages.addAll(converted);
          _uploading = false;
        });

        if (converted.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'PDF ${pageCount}페이지를 이미지로 변환했어요.',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ PDF 변환 오류: $e');
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF 변환 오류: $e')),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // OCR 파이프라인: Storage 업로드 → CF 호출 → Firestore 리스닝
  // ═══════════════════════════════════════════════════════════

  Future<void> _startOcr() async {
    if (_selectedImages.isEmpty) return;
    setState(() {
      _uploading = true;
      _uploadProgress = 0;
      _step = _OcrStep.processing;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('로그인 필요');

      // 1. Firestore 드래프트 문서 생성
      final draftData = ResumeImportDraft(
        id: '',
        ownerUid: uid,
        autoDeleteOriginal: _autoDeleteOriginal,
        status: ImportDraftStatus.processing,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final ref = await FirebaseFirestore.instance
          .collection('resumeImportDrafts')
          .add(draftData.toMap());
      _draftId = ref.id;

      // 2. 이미지들을 Firebase Storage에 업로드
      final storageRef = FirebaseStorage.instance
          .ref('resumeImports/$uid/${_draftId}');

      final downloadUrls = <String>[];
      for (int i = 0; i < _selectedImages.length; i++) {
        final img = _selectedImages[i];
        final ext = img.name.split('.').last.toLowerCase();
        final mimeType = _mimeTypeFromExt(ext);
        final fileRef = storageRef.child('page_$i.$ext');

        final bytes = await img.readAsBytes();
        final task = fileRef.putData(
          bytes,
          SettableMetadata(contentType: mimeType),
        );

        task.snapshotEvents.listen((snap) {
          if (!mounted) return;
          final total = snap.totalBytes > 0 ? snap.totalBytes : 1;
          final base = i / _selectedImages.length;
          final perFile = 1.0 / _selectedImages.length;
          setState(() {
            _uploadProgress =
                base + perFile * (snap.bytesTransferred / total);
          });
        });

        await task;
        final url = await fileRef.getDownloadURL();
        downloadUrls.add(url);
      }

      setState(() {
        _uploading = false;
        _uploadProgress = 1.0;
      });

      // 3. Cloud Function 호출
      final callable = FirebaseFunctions.instance
          .httpsCallable('extractResumeFromImages');
      await callable.call(<String, dynamic>{
        'draftId': _draftId,
        'imageUrls': downloadUrls,
      });

      // 4. Firestore 실시간 리스닝 → status=ready 대기
      _listenForResult();
    } catch (e) {
      debugPrint('⚠️ _startOcr error: $e');
      if (mounted) {
        setState(() {
          _uploading = false;
          _errorDetail = e.toString();
          _step = _OcrStep.error;
        });
      }
    }
  }

  void _listenForResult() {
    if (_draftId == null) return;

    FirebaseFirestore.instance
        .collection('resumeImportDrafts')
        .doc(_draftId)
        .snapshots()
        .listen(
      (snap) {
        if (!snap.exists || !mounted) return;
        final draft = ResumeImportDraft.fromDoc(snap);
        if (draft.status == ImportDraftStatus.ready) {
          setState(() {
            _draft = draft;
            _step = _OcrStep.review;
          });
        } else if (draft.status == ImportDraftStatus.failed) {
          setState(() {
            _errorDetail = snap.data()?['failReason'] as String? ?? '서버 오류';
            _step = _OcrStep.error;
          });
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _errorDetail = e.toString();
            _step = _OcrStep.error;
          });
        }
      },
    );
  }

  Future<void> _confirmDraft() async {
    if (_draftId == null || _draft == null) return;
    setState(() => _confirming = true);

    try {
      final fields = _draft!.suggestedFields;

      // ── 1. 이름 추출 (이력서 제목 및 프로필)
      final name = (fields['name'] as String? ?? '').trim();

      // ── 2. ResumeProfile 매핑
      final profile = ResumeProfile(
        name: name,
        phone: (fields['phone'] as String? ?? '').trim(),
        email: (fields['email'] as String? ?? '').trim(),
        region: (fields['address'] as String? ?? '').trim(),
        summary: (fields['summary'] as String? ?? '').trim(),
      );

      // ── 3. 경력 매핑
      final rawExp = fields['experiences'];
      final experiences = <ResumeExperience>[];
      if (rawExp is List) {
        for (final item in rawExp) {
          if (item is Map) {
            final m = Map<String, dynamic>.from(item);
            final clinic =
                (m['clinicName'] ?? m['company'] ?? '').toString().trim();
            if (clinic.isNotEmpty) {
              experiences.add(ResumeExperience(
                clinicName: clinic,
                region: (m['region'] ?? '').toString().trim(),
                start: (m['startDate'] ?? m['start'] ?? '').toString().trim(),
                end: (m['endDate'] ?? m['end'] ?? '').toString().trim(),
                achievementsText: (m['description'] ?? '').toString().trim().isNotEmpty
                    ? (m['description'] ?? '').toString().trim()
                    : null,
              ));
            }
          }
        }
      }

      // ── 4. 스킬 매핑
      final rawSkills = fields['skills'];
      final skills = <ResumeSkill>[];
      if (rawSkills is List) {
        for (int i = 0; i < rawSkills.length; i++) {
          final item = rawSkills[i];
          final skillName = item is String
              ? item.trim()
              : (item is Map ? (item['name'] ?? '').toString().trim() : '');
          if (skillName.isNotEmpty) {
            skills.add(ResumeSkill(
              id: 'ocr_skill_$i',
              name: skillName,
            ));
          }
        }
      }

      // ── 5. 학력 매핑
      final rawEdu = fields['education'];
      final education = <ResumeEducation>[];
      if (rawEdu is List) {
        for (final item in rawEdu) {
          if (item is Map) {
            final m = Map<String, dynamic>.from(item);
            final school =
                (m['school'] ?? m['name'] ?? '').toString().trim();
            if (school.isNotEmpty) {
              final gradRaw = m['gradYear'] ?? m['endDate'] ?? '';
              int? gradYear;
              if (gradRaw != null) {
                final yearStr = gradRaw.toString().length >= 4
                    ? gradRaw.toString().substring(0, 4)
                    : gradRaw.toString();
                gradYear = int.tryParse(yearStr);
              }
              education.add(ResumeEducation(
                school: school,
                major: (m['major'] ?? m['department'] ?? '')
                    .toString()
                    .trim(),
                gradYear: gradYear,
              ));
            }
          }
        }
      }

      // ── 6. 이력서 생성 및 저장
      final title = name.isNotEmpty ? '$name의 이력서' : 'AI로 불러온 이력서';
      final resumeId = await ResumeService.createResume(title: title);
      if (resumeId == null) {
        debugPrint('⚠️ createResume 실패');
        return;
      }

      final resume = Resume(
        id: resumeId,
        ownerUid: FirebaseAuth.instance.currentUser!.uid,
        title: title,
        profile: profile,
        experiences: experiences,
        skills: skills,
        education: education,
      );
      await ResumeService.updateResume(resume);

      // ── 7. 드래프트 상태 confirmed 처리
      await FirebaseFirestore.instance
          .collection('resumeImportDrafts')
          .doc(_draftId)
          .update({
        'status': 'confirmed',
        'linkedResumeId': resumeId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ── 8. 편집 화면으로 바로 이동
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ResumeEditScreen(resumeId: resumeId),
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ confirmDraft error: $e');
      if (mounted) {
        setState(() => _confirming = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이력서 저장 중 오류가 발생했어요: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _mimeTypeFromExt(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}

enum _OcrStep {
  selectImages,
  privacy,
  processing,
  review,
  done,
  error,
}

// ═══════════════════════════════════════════════════════════
// AI 처리 단계별 로딩 뷰
// ═══════════════════════════════════════════════════════════
class _ResumeAiLoadingView extends StatefulWidget {
  final bool isUploading;
  final double uploadProgress;
  final Color accentColor;

  const _ResumeAiLoadingView({
    required this.isUploading,
    required this.uploadProgress,
    required this.accentColor,
  });

  @override
  State<_ResumeAiLoadingView> createState() => _ResumeAiLoadingViewState();
}

class _ResumeAiLoadingViewState extends State<_ResumeAiLoadingView> {
  // 각 단계: 시작 경과 초, 아이콘, 메시지
  static const _stages = [
    (sec: 0,  icon: Icons.cloud_upload_outlined,       msg: '이미지를 서버에\n올리는 중이에요...'),
    (sec: 6,  icon: Icons.image_search_outlined,        msg: 'AI가 이력서를\n읽고 있어요...'),
    (sec: 18, icon: Icons.manage_search_outlined,       msg: '경력·면허 정보를\n추출하는 중이에요...'),
    (sec: 45, icon: Icons.playlist_add_check_outlined,  msg: '학력·스킬 정보를\n정리하는 중이에요...'),
    (sec: 90, icon: Icons.check_circle_outline_rounded, msg: '거의 다 됐어요!\n조금만 기다려주세요...'),
  ];

  // 하단 팁 (5초마다 전환)
  static const _tips = [
    '이력서 장수가 많을수록\n시간이 더 걸릴 수 있어요',
    '추출이 끝나면 각 항목을\n꼭 한 번 확인해 주세요',
    '면허번호·연락처는\n정확히 입력됐는지 확인하세요',
  ];

  // 함수 타임아웃(180초)에 맞춰 최대 95%까지만 채움
  static const _maxSec = 170.0;

  late final DateTime _startTime;
  Timer? _ticker;
  Timer? _tipTicker;
  int _elapsed = 0;
  int _tipIndex = 0;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed = DateTime.now().difference(_startTime).inSeconds);
    });
    _tipTicker = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() => _tipIndex = (_tipIndex + 1) % _tips.length);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _tipTicker?.cancel();
    super.dispose();
  }

  int get _stageIndex {
    for (var i = _stages.length - 1; i >= 0; i--) {
      if (_elapsed >= _stages[i].sec) return i;
    }
    return 0;
  }

  // easeOut: 빠르게 오르다 느려짐
  double get _aiProgress {
    final raw = (_elapsed / _maxSec).clamp(0.0, 0.95);
    return 1 - (1 - raw) * (1 - raw);
  }

  @override
  Widget build(BuildContext context) {
    final stage = _stages[_stageIndex];
    final isUploadPhase = widget.isUploading && widget.uploadProgress < 1.0;
    final displayProgress =
        isUploadPhase ? widget.uploadProgress : _aiProgress;
    final pct = (displayProgress * 100).toInt();

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 60),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final barW = constraints.maxWidth * 2 / 3;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 단계 아이콘 (업로드 중에는 고정)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Icon(
                    isUploadPhase
                        ? Icons.cloud_upload_outlined
                        : stage.icon,
                    key: ValueKey(isUploadPhase ? -1 : _stageIndex),
                    size: 48,
                    color: widget.accentColor,
                  ),
                ),
                const SizedBox(height: 24),

                // 단계 메시지
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    isUploadPhase
                        ? '이미지를 서버에\n올리는 중이에요...'
                        : stage.msg,
                    key: ValueKey(isUploadPhase ? -1 : _stageIndex),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // 진행 바
                SizedBox(
                  width: barW,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: displayProgress),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOut,
                      builder: (_, value, __) => LinearProgressIndicator(
                        value: value,
                        minHeight: 6,
                        backgroundColor: AppColors.divider,
                        valueColor:
                            AlwaysStoppedAnimation(widget.accentColor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // 퍼센트
                SizedBox(
                  width: barW,
                  child: Text(
                    '$pct%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textDisabled,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 팁 로테이션
                SizedBox(
                  width: constraints.maxWidth,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: Text(
                      _tips[_tipIndex],
                      key: ValueKey(_tipIndex),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
