import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:math';

import '../core/theme/app_colors.dart';
import '../pages/diary_timeline_page.dart';
import '../services/diary_image_service.dart';

/// 나만 보는 기록 (BottomSheet)
///
/// - 본문 입력 (최대 500자)
/// - 사진 첨부 (최대 3장, 업로드 전 압축)
/// - 사진 없이 글만 저장 가능
class DiaryInputSheet extends StatefulWidget {
  final Function(String) onSaved;

  const DiaryInputSheet({super.key, required this.onSaved});

  static Future<void> show(BuildContext context, Function(String) onSaved) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DiaryInputSheet(onSaved: onSaved),
    );
  }

  @override
  State<DiaryInputSheet> createState() => _DiaryInputSheetState();
}

class _DiaryInputSheetState extends State<DiaryInputSheet> {
  final _controller = TextEditingController();
  final _selectedImages = <XFile>[];
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── 사진 선택 ──
  Future<void> _pickImages() async {
    final remaining = DiaryImageService.maxImages - _selectedImages.length;
    if (remaining <= 0) {
      _showSnack('사진은 최대 ${DiaryImageService.maxImages}장까지 첨부할 수 있어요.');
      return;
    }

    final picked = await DiaryImageService.pickImages(remaining: remaining);
    if (picked.isEmpty) return;

    final total = _selectedImages.length + picked.length;
    if (total > DiaryImageService.maxImages) {
      _showSnack('사진은 최대 ${DiaryImageService.maxImages}장까지 첨부할 수 있어요.');
      final allowed = DiaryImageService.maxImages - _selectedImages.length;
      setState(() => _selectedImages.addAll(picked.take(allowed)));
    } else {
      setState(() => _selectedImages.addAll(picked));
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  // ── 저장 ──
  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _selectedImages.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('로그인 필요');

      // 1) Firestore 문서 먼저 생성 (noteId 확보)
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notes')
          .doc();
      final noteId = docRef.id;

      // 2) 사진 업로드
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        imageUrls = await DiaryImageService.uploadAll(
          uid: uid,
          noteId: noteId,
          files: _selectedImages,
        );
      }

      // 3) Firestore 저장
      await docRef.set({
        'text': text,
        'imageUrls': imageUrls,
        'createdAt': FieldValue.serverTimestamp(),
        'visibility': 'private',
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved(text);
      }
    } catch (e) {
      debugPrint('❌ [DiaryInput] 저장 실패: $e');
      if (mounted) _showSnack('저장 실패: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasContent =
        _controller.text.trim().isNotEmpty || _selectedImages.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 제목 + 기록 보기 ──
            Row(
              children: [
                const Text(
                  '오늘, 지금',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DiaryTimelinePage(),
                      ),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.history, size: 16, color: AppColors.accent),
                        const SizedBox(width: 4),
                        const Text(
                          '어제',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.accent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '오늘 하루를 가볍게 남겨보세요.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),

            // ── 본문 입력 ──
            TextField(
              controller: _controller,
              maxLength: 500,
              maxLines: 4,
              minLines: 2,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '지금 마음을 한 문장으로 남겨볼까?',
                hintStyle:
                    TextStyle(color: AppColors.textDisabled, fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.accent, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.divider),
                ),
              ),
            ),

            // ── 사진 미리보기 ──
            if (_selectedImages.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => _ImageThumb(
                    file: _selectedImages[i],
                    onRemove: () => _removeImage(i),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),

            // ── 사진 추가 + 안내문구 ──
            Row(
              children: [
                GestureDetector(
                  onTap: _isSaving ? null : _pickImages,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.camera_alt_outlined,
                            size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          '사진 ${_selectedImages.length}/${DiaryImageService.maxImages}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                if (_selectedImages.length >= DiaryImageService.maxImages)
                  Text(
                    '최대 ${DiaryImageService.maxImages}장',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textDisabled),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // ── 버튼 ──
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  child: const Text('취소',
                      style: TextStyle(color: AppColors.textPrimary)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSaving || !hasContent ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.white,
                    disabledBackgroundColor: AppColors.disabledBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.white),
                        )
                      : const Text('저장'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 선택한 사진 썸네일 (삭제 버튼 포함)
class _ImageThumb extends StatelessWidget {
  final XFile file;
  final VoidCallback onRemove;
  const _ImageThumb({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: kIsWeb
              ? FutureBuilder<Uint8List>(
                  future: file.readAsBytes(),
                  builder: (ctx, snap) {
                    if (!snap.hasData) {
                      return const SizedBox(
                          width: 80, height: 80, child: Placeholder());
                    }
                    return Image.memory(snap.data!,
                        width: 80, height: 80, fit: BoxFit.cover);
                  },
                )
              : Image.file(File(file.path),
                  width: 80, height: 80, fit: BoxFit.cover),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

/// 저장 후 캐릭터 응답 멘트 선택
class DiaryResponseService {
  static final List<String> _responses = [
    "좋아, 이 문장… 오늘의 너를 잘 담았어.",
    "적어줘서 고마워. 마음이 조금은 가벼워졌으면.",
    "그 마음, 내가 기억해둘게.",
    "한 줄이면 충분해. 오늘은 이 정도면 돼.",
    "지금의 너를 있는 그대로 인정해주자.",
    "음… 이 말 속에 '참고 있음'이 보여.",
    "오늘의 기분은 오늘에 두고, 내일은 새로 시작하자.",
    "그 감정, 나한테는 꽤 선명하게 들렸어.",
    "괜찮아. 너는 늘 최선을 다하고 있어.",
    "좋은 날이든 나쁜 날이든, 기록은 힘이 돼.",
    "이 문장 덕분에 너 마음에 의자가 하나 놓인 느낌이야.",
    "오늘은 '버틴 날'로 체크해둘게.",
    "지금까지 온 것만으로도 충분히 멋져.",
    "너는 생각보다 훨씬 단단해.",
    "이 말, 나중에 너에게 위로가 될 거야.",
    "조금 울컥했어… 너 마음이 느껴져서.",
    "좋아! 이 흐름 유지해보자. 아주 작은 것부터.",
    "오늘의 너를 내가 토닥토닥.",
    "내가 옆에서 조용히 응원할게.",
    "완벽한 문장 아니어도 돼. 솔직해서 좋아.",
    "그래… 그랬구나. 그럼 오늘은 쉬운 것만 하자.",
    "너무 세게 자신을 몰아붙이지 마.",
    "한 문장인데, 오늘 하루가 보이는 것 같아.",
    "적어둔 건 사라지지 않아. 너의 편이 되어줄 거야.",
  ];

  static String getRandomResponse(String inputText) {
    final text = inputText.toLowerCase();

    if (inputText.length < 10) {
      return "짧게 말했지만 마음이 느껴져.";
    }

    if (text.contains('힘들') ||
        text.contains('지쳐') ||
        text.contains('불안') ||
        text.contains('우울') ||
        text.contains('슬프')) {
      final stressedPool = [
        "괜찮아. 너는 늘 최선을 다하고 있어.",
        "오늘은 '버틴 날'로 체크해둘게.",
        "지금까지 온 것만으로도 충분히 멋져.",
        "음… 이 말 속에 '참고 있음'이 보여.",
        "그래… 그랬구나. 그럼 오늘은 쉬운 것만 하자.",
        "너무 세게 자신을 몰아붙이지 마.",
      ];
      return stressedPool[Random().nextInt(stressedPool.length)];
    }

    if (text.contains('좋아') ||
        text.contains('행복') ||
        text.contains('뿌듯') ||
        text.contains('기쁘') ||
        text.contains('감사')) {
      final positivePool = [
        "좋아! 이 흐름 유지해보자. 아주 작은 것부터.",
        "오늘의 너를 내가 토닥토닥.",
        "내가 옆에서 조용히 응원할게.",
      ];
      return positivePool[Random().nextInt(positivePool.length)];
    }

    return _responses[Random().nextInt(_responses.length)];
  }
}
