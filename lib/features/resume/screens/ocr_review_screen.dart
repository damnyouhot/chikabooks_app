import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../../models/resume_import_draft.dart';

// ── 디자인 상수 ──────────────────────────────────────────
const _kBg = Color(0xFFF8F6F9);
const _kText = Color(0xFF3D4A5C);
const _kBlue = Color(0xFF4A90D9);
const _kGreen = Color(0xFF4CAF50);
const _kOrange = Color(0xFFF57C00);
const _kRed = Color(0xFFE57373);

/// OCR 자동입력 검수 화면
///
/// 설계서 2.1.3 / 2.1.4 기준:
/// 1. 사진 선택/촬영 (복수 페이지)
/// 2. 업로드 → 개인정보 고지 모달
/// 3. Cloud Function(OCR) 처리 대기
/// 4. 추출 결과 검수 (필드별 수정 + 신뢰도 배지)
/// 5. 확정 → 이력서에 반영
class OcrReviewScreen extends StatefulWidget {
  const OcrReviewScreen({super.key});

  @override
  State<OcrReviewScreen> createState() => _OcrReviewScreenState();
}

class _OcrReviewScreenState extends State<OcrReviewScreen> {
  // ── 상태 ──
  _OcrStep _step = _OcrStep.selectImages;
  List<XFile> _selectedImages = [];
  bool _autoDeleteOriginal = true;
  bool _uploading = false;
  String? _draftId;
  ResumeImportDraft? _draft;

  final _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '이력서 사진 자동입력',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _kText,
          ),
        ),
        centerTitle: false,
        iconTheme: const IconThemeData(color: _kText),
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
  // Step 1: 이미지 선택
  // ═══════════════════════════════════════════════════════════

  Widget _buildSelectImages() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 안내
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kBlue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '이력서 사진을 촬영하거나 갤러리에서 선택하세요.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _kText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '여러 페이지를 한번에 선택할 수 있어요.\nAI가 자동으로 정보를 추출합니다.',
                style: TextStyle(
                  fontSize: 12,
                  color: _kText.withOpacity(0.5),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 이미지 미리보기
        if (_selectedImages.isNotEmpty) ...[
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length + 1,
              itemBuilder: (_, i) {
                if (i == _selectedImages.length) {
                  return _addMoreButton();
                }
                return _imagePreviewCard(i);
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${_selectedImages.length}장 선택됨',
            style: TextStyle(
              fontSize: 13,
              color: _kText.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // 선택 버튼
        if (_selectedImages.isEmpty) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              // 웹에서는 카메라 버튼 숨김 (브라우저 제한)
              if (!kIsWeb)
                Expanded(
                  child: _actionButton(
                    icon: Icons.camera_alt_outlined,
                    label: '카메라 촬영',
                    color: _kBlue,
                    onTap: _pickFromCamera,
                  ),
                ),
              if (!kIsWeb) const SizedBox(width: 12),
              Expanded(
                child: _actionButton(
                  icon: Icons.photo_library_outlined,
                  label: kIsWeb ? '파일 선택' : '갤러리에서 선택',
                  color: _kGreen,
                  onTap: _pickFromGallery,
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 32),

        // 다음 단계 버튼
        if (_selectedImages.isNotEmpty)
          FilledButton(
            onPressed: () => setState(() => _step = _OcrStep.privacy),
            style: FilledButton.styleFrom(
              backgroundColor: _kBlue,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
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
      onTap: _pickFromGallery,
      child: Container(
        width: 90,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: _kText.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kText.withOpacity(0.1)),
        ),
        child: Icon(Icons.add, color: _kText.withOpacity(0.3)),
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
            borderRadius: BorderRadius.circular(10),
            child: FutureBuilder<Uint8List>(
              future: _selectedImages[idx].readAsBytes(),
              builder: (_, snap) {
                if (!snap.hasData) {
                  return Container(
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }
                return Image.memory(
                  snap.data!,
                  width: 90,
                  height: 120,
                  fit: BoxFit.cover,
                );
              },
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () {
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${idx + 1}',
                style:
                    const TextStyle(fontSize: 10, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kText,
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
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kOrange.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_outlined, size: 20, color: _kOrange),
                  const SizedBox(width: 8),
                  const Text(
                    '개인정보 보호 안내',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _noticeItem(
                '이력서 이미지에는 연락처/주소 등 민감정보가 포함될 수 있어요.',
              ),
              _noticeItem(
                '자동입력 검수가 끝나면 원본 이미지는 자동 삭제돼요 (기본 설정).',
              ),
              _noticeItem(
                '원본을 보관하려면 아래 \'원본 유지\' 옵션을 켤 수 있어요.',
              ),
              const SizedBox(height: 16),

              // 원본 삭제 토글
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _kBg,
                  borderRadius: BorderRadius.circular(10),
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
                              color: _kText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '확인 후 원본 이미지를 서버에서 삭제합니다.',
                            style: TextStyle(
                              fontSize: 11,
                              color: _kText.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _autoDeleteOriginal,
                      onChanged: (v) =>
                          setState(() => _autoDeleteOriginal = v),
                      activeColor: _kGreen,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        FilledButton(
          onPressed: _uploading ? null : _startOcr,
          style: FilledButton.styleFrom(
            backgroundColor: _kBlue,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _uploading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  '동의하고 자동입력 시작',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _step = _OcrStep.selectImages),
            child: Text(
              '이전으로 돌아가기',
              style: TextStyle(
                fontSize: 13,
                color: _kText.withOpacity(0.5),
              ),
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
          Text('•',
              style: TextStyle(
                  fontSize: 14, color: _kText.withOpacity(0.5))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: _kText.withOpacity(0.7),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          const Text(
            'AI가 이력서를 분석하고 있어요...',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _kText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '보통 30초~1분 정도 걸려요.',
            style: TextStyle(
              fontSize: 13,
              color: _kText.withOpacity(0.4),
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _kGreen.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, size: 18, color: _kGreen),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'AI 분석이 완료되었어요. 내용을 확인하고 수정해주세요.',
                  style: TextStyle(fontSize: 13, color: _kText),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 필드별 카드
        ...fields.entries.map((entry) {
          final key = entry.key;
          final value = entry.value?.toString() ?? '';
          final conf = confidence[key] ?? 0.0;
          final isLow = conf < 0.7;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isLow
                    ? _kOrange.withOpacity(0.3)
                    : _kText.withOpacity(0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      key,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kText.withOpacity(0.5),
                      ),
                    ),
                    const Spacer(),
                    if (isLow)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _kOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '신뢰도 낮음 ${(conf * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _kOrange,
                          ),
                        ),
                      )
                    else
                      Text(
                        '${(conf * 100).round()}%',
                        style: TextStyle(
                          fontSize: 10,
                          color: _kGreen.withOpacity(0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  value.isEmpty ? '(추출되지 않음)' : value,
                  style: TextStyle(
                    fontSize: 14,
                    color: value.isEmpty
                        ? _kText.withOpacity(0.3)
                        : _kText,
                  ),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 24),

        FilledButton(
          onPressed: _confirmDraft,
          style: FilledButton.styleFrom(
            backgroundColor: _kGreen,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            '이력서에 반영하기',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Step 5: 완료
  // ═══════════════════════════════════════════════════════════

  Widget _buildDone() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _kGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check, size: 36, color: _kGreen),
          ),
          const SizedBox(height: 20),
          const Text(
            '자동입력이 완료되었어요!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _kText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '이력서 편집 화면에서 내용을 확인해주세요.',
            style: TextStyle(
              fontSize: 13,
              color: _kText.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              if (kIsWeb) {
                context.go('/applicant/resumes');
              } else {
                Navigator.pop(context, true);
              }
            },
            child: const Text('이력서 목록으로'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Error
  // ═══════════════════════════════════════════════════════════

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48,
              color: _kRed.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            'OCR 처리 중 오류가 발생했어요.',
            style: TextStyle(fontSize: 15, color: _kText),
          ),
          const SizedBox(height: 8),
          Text(
            'OpenAI 키가 설정되지 않았거나 서버 오류입니다.',
            style: TextStyle(
              fontSize: 13,
              color: _kText.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () =>
                setState(() => _step = _OcrStep.selectImages),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 액션
  // ═══════════════════════════════════════════════════════════

  Future<void> _pickFromCamera() async {
    try {
      final photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null && mounted) {
        setState(() => _selectedImages.add(photo));
      }
    } catch (e) {
      debugPrint('⚠️ Camera error: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final images = await _picker.pickMultiImage();
      if (images.isNotEmpty && mounted) {
        setState(() => _selectedImages.addAll(images));
      }
    } catch (e) {
      debugPrint('⚠️ Gallery error: $e');
    }
  }

  Future<void> _startOcr() async {
    setState(() => _uploading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('로그인 필요');

      // 1. Firestore에 드래프트 문서 생성
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

      // 2. 처리 화면으로 전환
      setState(() {
        _uploading = false;
        _step = _OcrStep.processing;
      });

      // 3. Cloud Function이 처리할 때까지 대기 (실시간 리스닝)
      // TODO: 실제로는 Storage에 이미지 업로드 후 Cloud Function 트리거
      // 현재는 플레이스홀더로 5초 후 mock 데이터 표시
      await Future.delayed(const Duration(seconds: 3));

      // Mock 데이터 (OpenAI 키 연동 전까지)
      if (mounted) {
        setState(() {
          _draft = ResumeImportDraft(
            id: _draftId!,
            ownerUid: uid,
            autoDeleteOriginal: _autoDeleteOriginal,
            status: ImportDraftStatus.ready,
            suggestedFields: {
              '이름': '',
              '연락처': '',
              '이메일': '',
              '거주지': '',
              '면허': '치과위생사',
              '경력': '',
              '스킬': '',
            },
            confidence: {
              '이름': 0.0,
              '연락처': 0.0,
              '이메일': 0.0,
              '거주지': 0.0,
              '면허': 0.5,
              '경력': 0.0,
              '스킬': 0.0,
            },
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          _step = _OcrStep.review;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ OCR은 OpenAI 키 연동 후 실제 데이터가 추출됩니다.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ startOcr error: $e');
      if (mounted) {
        setState(() {
          _uploading = false;
          _step = _OcrStep.error;
        });
      }
    }
  }

  Future<void> _confirmDraft() async {
    // TODO: 추출 결과 → 이력서 섹션에 매핑
    // 현재는 플레이스홀더
    if (_draftId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('resumeImportDrafts')
            .doc(_draftId)
            .update({
          'status': 'confirmed',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('⚠️ confirmDraft error: $e');
      }
    }

    if (mounted) setState(() => _step = _OcrStep.done);
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

