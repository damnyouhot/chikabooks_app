import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../services/user_profile_service.dart';
import '../models/senior_question.dart';
import '../services/senior_question_image_service.dart';
import '../services/senior_question_service.dart';
import 'senior_question_card.dart';

class SeniorQuestionFeed extends StatefulWidget {
  const SeniorQuestionFeed({super.key});

  @override
  State<SeniorQuestionFeed> createState() => _SeniorQuestionFeedState();
}

class _SeniorQuestionFeedState extends State<SeniorQuestionFeed> {
  final _bodyCtrl = TextEditingController();
  final List<XFile> _images = [];
  bool _isAdmin = false;
  bool _isAnonymous = false;
  String? _category;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _loadAdmin();
  }

  Future<void> _loadAdmin() async {
    final admin = await UserProfileService.isAdmin();
    if (mounted) setState(() => _isAdmin = admin);
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = SeniorQuestionImageService.maxImages - _images.length;
    if (remaining <= 0) {
      _snack('이미지는 최대 ${SeniorQuestionImageService.maxImages}장까지 첨부할 수 있어요.');
      return;
    }
    final picked = await SeniorQuestionImageService.pickImages(
      remaining: remaining,
    );
    if (picked.isNotEmpty && mounted) setState(() => _images.addAll(picked));
  }

  Future<void> _submit() async {
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty || _posting) return;
    final category = _category;
    if (category == null) {
      _snack('질문 유형을 선택해 주세요.');
      return;
    }
    setState(() => _posting = true);
    final id = await SeniorQuestionService.createQuestion(
      body: body,
      category: category,
      isAnonymous: _isAnonymous,
      images: _images,
    );
    if (!mounted) return;
    setState(() => _posting = false);
    if (id == null) {
      _snack('등록에 실패했어요. 다시 시도해 주세요.');
      return;
    }
    _bodyCtrl.clear();
    _images.clear();
    setState(() {
      _isAnonymous = false;
      _category = null;
    });
    FocusScope.of(context).unfocus();
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SeniorQuestion>>(
      stream: SeniorQuestionService.watchQuestions(),
      builder: (context, snap) {
        final questions = snap.data ?? [];
        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              48,
            ),
            children: [
              if (snap.connectionState == ConnectionState.waiting &&
                  questions.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (questions.isEmpty)
                const _EmptyState()
              else
                ...questions.map(
                  (q) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: SeniorQuestionCard(question: q, isAdmin: _isAdmin),
                  ),
                ),
              if (questions.isNotEmpty) const SizedBox(height: AppSpacing.sm),
              _Composer(
                controller: _bodyCtrl,
                images: _images,
                category: _category,
                isAnonymous: _isAnonymous,
                posting: _posting,
                onCategoryChanged: (v) => setState(() => _category = v),
                onAnonymousChanged: (v) => setState(() => _isAnonymous = v),
                onPickImages: _pickImages,
                onRemoveImage: (i) => setState(() => _images.removeAt(i)),
                onSubmit: _submit,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final List<XFile> images;
  final String? category;
  final bool isAnonymous;
  final bool posting;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<bool> onAnonymousChanged;
  final VoidCallback onPickImages;
  final ValueChanged<int> onRemoveImage;
  final VoidCallback onSubmit;

  const _Composer({
    required this.controller,
    required this.images,
    required this.category,
    required this.isAnonymous,
    required this.posting,
    required this.onCategoryChanged,
    required this.onAnonymousChanged,
    required this.onPickImages,
    required this.onRemoveImage,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CategoryDropdown(
                value: category,
                enabled: !posting,
                onChanged: onCategoryChanged,
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Text(
                  '선배나 동료에게 조언을 구해봐요',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: controller,
            minLines: 2,
            maxLines: 8,
            maxLength: SeniorQuestionService.maxBodyLength,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.45,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: '예: 면접에서 이런 질문을 받으면 어떻게 답하면 좋을까요?',
              hintStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textDisabled.withValues(alpha: 0.8),
              ),
              border: InputBorder.none,
              counterText: '',
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          if (images.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder:
                    (_, __) => const SizedBox(width: AppSpacing.sm),
                itemBuilder:
                    (_, i) => _ImagePreview(
                      file: images[i],
                      onRemove: () => onRemoveImage(i),
                    ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              _ComposerAction(
                icon: Icons.image_outlined,
                label:
                    '이미지 ${images.length}/${SeniorQuestionImageService.maxImages}',
                onTap: posting ? null : onPickImages,
              ),
              const SizedBox(width: AppSpacing.sm),
              Checkbox(
                value: isAnonymous,
                onChanged:
                    posting ? null : (v) => onAnonymousChanged(v ?? false),
                visualDensity: VisualDensity.compact,
                activeColor: AppColors.accent,
              ),
              GestureDetector(
                onTap: posting ? null : () => onAnonymousChanged(!isAnonymous),
                child: const Text(
                  '닉네임 비공개',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: posting ? null : onSubmit,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child:
                    posting
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('올리기'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final String? value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _CategoryDropdown({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      enabled: enabled,
      initialValue: value,
      tooltip: '질문 종류',
      color: AppColors.appBg,
      elevation: 4,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      onSelected: onChanged,
      itemBuilder:
          (_) =>
              SeniorQuestionService.categories
                  .map(
                    (c) => PopupMenuItem(
                      value: c,
                      child: Text(
                        c,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.cardEmphasis,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value ?? '질문 유형',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.onCardEmphasis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: AppColors.onCardEmphasis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ComposerAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final XFile file;
  final VoidCallback onRemove;

  const _ImagePreview({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FutureBuilder(
          future: file.readAsBytes(),
          builder: (_, snap) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child:
                  snap.hasData
                      ? Image.memory(
                        snap.data!,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      )
                      : Container(
                        width: 72,
                        height: 72,
                        color: AppColors.surfaceMuted,
                      ),
            );
          },
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: const Column(
        children: [
          Icon(Icons.forum_outlined, color: AppColors.textDisabled),
          SizedBox(height: AppSpacing.sm),
          Text(
            '아직 질문이 없어요.\n첫 질문을 남겨보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}
