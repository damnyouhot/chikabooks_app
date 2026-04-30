import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../data/senior_stickers.dart';
import '../models/senior_question.dart';
import '../services/senior_question_image_service.dart';
import '../services/senior_question_service.dart';
import 'senior_question_share_capture.dart';
import 'senior_sticker_widgets.dart';

class SeniorQuestionCard extends StatefulWidget {
  final SeniorQuestion question;
  final bool isAdmin;

  const SeniorQuestionCard({
    super.key,
    required this.question,
    required this.isAdmin,
  });

  @override
  State<SeniorQuestionCard> createState() => _SeniorQuestionCardState();
}

class _SeniorQuestionCardState extends State<SeniorQuestionCard> {
  final _commentCtrl = TextEditingController();
  late final TextEditingController _editCtrl;
  XFile? _commentImage;
  String? _commentStickerId;
  XFile? _editReplacementImage;
  String? _editStickerId;
  String? _replyToCommentId;
  String? _replyToName;
  bool _isEditing = false;
  bool _editAnonymous = false;
  bool _editRemoveImages = false;
  String _editCategory = SeniorQuestionService.categories.first;
  bool _commentsExpanded = false;
  bool _commentAnonymous = false;
  bool _submittingComment = false;

  SeniorQuestion get question => widget.question;

  @override
  void initState() {
    super.initState();
    _editCtrl = TextEditingController(text: question.body);
    _editAnonymous = question.isAnonymous;
    _editCategory = _categoryOrDefault(question.category);
  }

  @override
  void didUpdateWidget(covariant SeniorQuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing) {
      _editCtrl.text = question.body;
      _editAnonymous = question.isAnonymous;
      _editCategory = _categoryOrDefault(question.category);
      _editReplacementImage = null;
      _editRemoveImages = false;
      _editStickerId = question.stickerId;
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _editCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final body = _commentCtrl.text.trim();
    if ((body.isEmpty && _commentImage == null && _commentStickerId == null) ||
        _submittingComment) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _submittingComment = true);
    final ok =
        _replyToCommentId == null
            ? await SeniorQuestionService.addComment(
              questionId: question.id,
              body: body,
              isAnonymous: _commentAnonymous,
              image: _commentImage,
              stickerId: _commentStickerId,
            )
            : await SeniorQuestionService.addReply(
              questionId: question.id,
              commentId: _replyToCommentId!,
              body: body,
              isAnonymous: _commentAnonymous,
              image: _commentImage,
              stickerId: _commentStickerId,
            );
    if (!mounted) return;
    setState(() {
      _submittingComment = false;
      if (ok) {
        _commentCtrl.clear();
        _commentImage = null;
        _commentStickerId = null;
        _replyToCommentId = null;
        _replyToName = null;
        _commentAnonymous = false;
        _commentsExpanded = true;
      }
    });
    if (!ok) _snack('등록에 실패했어요. 다시 시도해 주세요.');
  }

  Future<void> _pickCommentImage() async {
    final picked = await SeniorQuestionImageService.pickImages(remaining: 1);
    if (!mounted || picked.isEmpty) return;
    setState(() => _commentImage = picked.first);
  }

  Future<void> _pickCommentSticker() async {
    final id = await showSeniorStickerPicker(
      context,
      selectedId: _commentStickerId,
    );
    if (!mounted || id == null) return;
    setState(() => _commentStickerId = id);
  }

  Future<void> _pickEditSticker() async {
    final id = await showSeniorStickerPicker(
      context,
      selectedId: _editStickerId,
    );
    if (!mounted || id == null) return;
    setState(() => _editStickerId = id);
  }

  Future<void> _pickEditReplacementImage() async {
    final picked = await SeniorQuestionImageService.pickImages(remaining: 1);
    if (!mounted || picked.isEmpty) return;
    setState(() {
      _editReplacementImage = picked.first;
      _editRemoveImages = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hiddenForUser = question.isHidden && !widget.isAdmin;
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final isAuthor = myUid != null && question.uid == myUid;
    final hasMoreActions = isAuthor || (question.isHidden && widget.isAdmin);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color:
              question.isHidden
                  ? AppColors.error.withValues(alpha: 0.35)
                  : AppColors.divider.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _SmallBadge(
                label: _isEditing ? '수정 중' : question.category,
                dark: true,
              ),
              const Spacer(),
              if (!(question.isHidden && widget.isAdmin))
                TextButton.icon(
                  onPressed: _confirmReport,
                  icon: const Icon(Icons.flag_outlined, size: 14),
                  label: const Text('신고'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: const Size(0, 24),
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (hasMoreActions)
                PopupMenuButton<String>(
                  color: AppColors.appBg,
                  elevation: 4,
                  position: PopupMenuPosition.under,
                  offset: const Offset(0, 6),
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  icon: const Icon(
                    Icons.more_horiz,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  onSelected: (value) {
                    if (value == 'edit') _startEditing();
                    if (value == 'delete') _confirmDelete();
                    if (value == 'restore') _restore();
                  },
                  itemBuilder:
                      (_) => [
                        if (isAuthor)
                          const PopupMenuItem(
                            value: 'edit',
                            child: _MenuItemText('수정'),
                          ),
                        if (isAuthor)
                          const PopupMenuItem(
                            value: 'delete',
                            child: _MenuItemText('삭제', destructive: true),
                          ),
                        if (question.isHidden && widget.isAdmin)
                          const PopupMenuItem(
                            value: 'restore',
                            child: _MenuItemText('복구'),
                          ),
                      ],
                ),
            ],
          ),
          const SizedBox(height: 2),
          if (_isEditing)
            SizedBox(
              width: double.infinity,
              child: _InlineEditBox(
                controller: _editCtrl,
                category: _editCategory,
                isAnonymous: _editAnonymous,
                currentImageUrls: question.imageUrls,
                replacementImage: _editReplacementImage,
                removeImages: _editRemoveImages,
                stickerId: _editStickerId,
                onCategoryChanged: (v) => setState(() => _editCategory = v),
                onAnonymousChanged: (v) => setState(() => _editAnonymous = v),
                onPickImage: _pickEditReplacementImage,
                onRemoveCurrentImages:
                    () => setState(() {
                      _editReplacementImage = null;
                      _editRemoveImages = true;
                    }),
                onRemoveReplacement:
                    () => setState(() => _editReplacementImage = null),
                onPickSticker: _pickEditSticker,
                onRemoveSticker: () => setState(() => _editStickerId = null),
                onCancel: _cancelEditing,
                onSave: _saveEditing,
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: _QuestionBodyWithMeta(
                body: hiddenForUser ? '신고 누적으로 숨김 처리된 글입니다.' : question.body,
                authorName: question.displayName,
                metaText: _metaText(),
                muted: hiddenForUser,
              ),
            ),
          if (!hiddenForUser && question.isHidden && widget.isAdmin) ...[
            const SizedBox(height: AppSpacing.sm),
            const _AdminHiddenBanner(),
          ],
          if (!hiddenForUser &&
              !_isEditing &&
              question.imageUrls.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _ImageGrid(urls: question.imageUrls),
          ],
          if (!hiddenForUser && !_isEditing && question.stickerId != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SeniorStickerView(stickerId: question.stickerId!, size: 62),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Spacer(),
              _ActionButton(
                icon: Icons.favorite_border,
                iconColor: AppColors.cardEmphasis,
                label: '좋아요',
                count: question.likeCount,
                onTap:
                    () => SeniorQuestionService.toggleQuestionReaction(
                      questionId: question.id,
                      type: 'likes',
                    ),
              ),
              _ActionButton(
                icon: Icons.local_fire_department_outlined,
                iconColor: AppColors.warning,
                label: '힘내요',
                count: question.cheerCount,
                onTap:
                    () => SeniorQuestionService.toggleQuestionReaction(
                      questionId: question.id,
                      type: 'cheers',
                    ),
              ),
              _ActionButton(
                icon: Icons.mode_comment_outlined,
                iconColor: AppColors.textSecondary,
                label: '댓글',
                count: question.commentCount,
                onTap: () => setState(() => _commentsExpanded = true),
              ),
              if (!hiddenForUser && !_isEditing)
                _ActionButton(
                  icon: Icons.share_outlined,
                  iconColor: AppColors.textSecondary,
                  label: '공유',
                  onTap: _shareQuestion,
                ),
            ],
          ),
          if (!_commentsExpanded && question.commentCount > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            _buildCommentPreview(),
          ],
          if (_commentsExpanded) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildComments(),
            _InlineCommentInput(
              controller: _commentCtrl,
              replyToName: _replyToName,
              anonymous: _commentAnonymous,
              submitting: _submittingComment,
              onAnonymousChanged: (v) => setState(() => _commentAnonymous = v),
              onCancelReply:
                  () => setState(() {
                    _replyToCommentId = null;
                    _replyToName = null;
                  }),
              image: _commentImage,
              stickerId: _commentStickerId,
              onPickImage: !_submittingComment ? _pickCommentImage : null,
              onRemoveImage: () => setState(() => _commentImage = null),
              onPickSticker: !_submittingComment ? _pickCommentSticker : null,
              onRemoveSticker: () => setState(() => _commentStickerId = null),
              onSubmit: _submitComment,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComments() {
    return StreamBuilder<List<SeniorComment>>(
      stream: SeniorQuestionService.watchComments(question.id),
      builder: (_, snap) {
        final comments = snap.data ?? [];
        if (snap.connectionState == ConnectionState.waiting &&
            comments.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (comments.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              '첫 댓글을 남겨보세요.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textDisabled,
              ),
            ),
          );
        }
        return Column(
          children:
              comments
                  .map(
                    (comment) => _CommentTile(
                      questionId: question.id,
                      comment: comment,
                      isAdmin: widget.isAdmin,
                      showReplies: true,
                      onReply:
                          () => setState(() {
                            _replyToCommentId = comment.id;
                            _replyToName = comment.displayName;
                            _commentImage = null;
                            _commentsExpanded = true;
                          }),
                    ),
                  )
                  .toList(),
        );
      },
    );
  }

  Widget _buildCommentPreview() {
    return StreamBuilder<List<SeniorComment>>(
      stream: SeniorQuestionService.watchComments(question.id),
      builder: (_, snap) {
        final comments = snap.data ?? [];
        if (comments.isEmpty) return const SizedBox.shrink();
        final moreCount = comments.length - 1;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CommentTile(
              questionId: question.id,
              comment: comments.first,
              isAdmin: widget.isAdmin,
              showReplies: false,
              onReply:
                  () => setState(() {
                    _replyToCommentId = comments.first.id;
                    _replyToName = comments.first.displayName;
                    _commentImage = null;
                    _commentsExpanded = true;
                  }),
            ),
            if (moreCount > 0)
              InkWell(
                onTap: () => setState(() => _commentsExpanded = true),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.xs,
                  ),
                  child: Text(
                    '댓글 $moreCount개 더 보기',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _startEditing() {
    setState(() {
      _editCtrl.text = question.body;
      _editAnonymous = question.isAnonymous;
      _editCategory = _categoryOrDefault(question.category);
      _editReplacementImage = null;
      _editRemoveImages = false;
      _editStickerId = question.stickerId;
      _isEditing = true;
    });
  }

  void _cancelEditing() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _editCtrl.text = question.body;
      _editAnonymous = question.isAnonymous;
      _editCategory = _categoryOrDefault(question.category);
      _editReplacementImage = null;
      _editRemoveImages = false;
      _editStickerId = question.stickerId;
      _isEditing = false;
    });
  }

  Future<void> _saveEditing() async {
    final body = _editCtrl.text.trim();
    if (body.isEmpty) {
      _snack('내용을 입력해 주세요.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final ok = await SeniorQuestionService.updateQuestion(
      questionId: question.id,
      body: body,
      category: _editCategory,
      isAnonymous: _editAnonymous,
      removeImages: _editRemoveImages,
      replacementImage: _editReplacementImage,
      stickerId: _editStickerId,
    );
    if (!mounted) return;
    if (ok) {
      setState(() {
        _editReplacementImage = null;
        _editRemoveImages = false;
        _isEditing = false;
      });
    }
    _snack(ok ? '글을 수정했어요.' : '수정에 실패했어요.');
  }

  Future<void> _confirmDelete() async {
    final ok = await _showConfirmDialog(
      title: '글 삭제',
      message: '이 글을 삭제할까요?\n댓글과 답글도 함께 보이지 않게 됩니다.',
      confirmLabel: '삭제',
      destructive: true,
    );
    if (ok != true) return;
    final success = await SeniorQuestionService.deleteQuestion(question.id);
    if (!mounted) return;
    _snack(success ? '글을 삭제했어요.' : '삭제에 실패했어요.');
  }

  Future<void> _shareQuestion() async {
    try {
      await SeniorQuestionShareCapture.share(context, question: question);
    } catch (e) {
      if (!mounted) return;
      _snack('공유에 실패했어요. $e');
    }
  }

  Future<void> _confirmReport() async {
    final ok = await _showConfirmDialog(
      title: '신고하기',
      message: '이 글을 신고할까요?\n신고가 5개 이상 누적되면 자동으로 숨김 처리됩니다.',
      confirmLabel: '신고',
      destructive: true,
    );
    if (ok != true) return;
    final success = await SeniorQuestionService.reportQuestion(question.id);
    if (!mounted) return;
    _snack(success ? '신고가 접수되었어요.' : '이미 신고했거나 처리에 실패했어요.');
  }

  Future<void> _restore() async {
    final success = await SeniorQuestionService.restoreDocument(
      SeniorQuestionService.questionRef(question.id),
    );
    if (!mounted) return;
    _snack(success ? '글을 복구했어요.' : '복구에 실패했어요.');
  }

  String _metaText() {
    final edited = question.updatedAt != null ? ' · 수정됨' : '';
    return '${_timeAgo(question.createdAt)}$edited';
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(AppSpacing.xl),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.appBg,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(
                  color: AppColors.divider.withValues(alpha: 0.7),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            backgroundColor: AppColors.surfaceMuted,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          child: const Text('취소'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.onCardEmphasis,
                            backgroundColor:
                                destructive
                                    ? AppColors.cardEmphasis
                                    : AppColors.cardPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          child: Text(confirmLabel),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  String _categoryOrDefault(String raw) {
    return SeniorQuestionService.categories.contains(raw)
        ? raw
        : SeniorQuestionService.categories.first;
  }
}

class _CommentTile extends StatefulWidget {
  final String questionId;
  final SeniorComment comment;
  final bool isAdmin;
  final bool showReplies;
  final VoidCallback onReply;

  const _CommentTile({
    required this.questionId,
    required this.comment,
    required this.isAdmin,
    required this.showReplies,
    required this.onReply,
  });

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  late final TextEditingController _editCtrl;
  XFile? _editReplacementImage;
  bool _isEditing = false;
  bool _editAnonymous = false;
  bool _editRemoveImages = false;
  bool _saving = false;

  String get questionId => widget.questionId;
  SeniorComment get comment => widget.comment;
  bool get isAdmin => widget.isAdmin;

  @override
  void initState() {
    super.initState();
    _editCtrl = TextEditingController(text: comment.body);
    _editAnonymous = comment.isAnonymous;
  }

  @override
  void didUpdateWidget(covariant _CommentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing) {
      _editCtrl.text = comment.body;
      _editAnonymous = comment.isAnonymous;
      _editReplacementImage = null;
      _editRemoveImages = false;
    }
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hiddenForUser = comment.isHidden && !isAdmin;
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final isAuthor = myUid != null && comment.uid == myUid;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isEditing)
            _CommentEditBox(
              controller: _editCtrl,
              anonymous: _editAnonymous,
              saving: _saving,
              currentImageUrls: comment.imageUrls,
              replacementImage: _editReplacementImage,
              removeImages: _editRemoveImages,
              onAnonymousChanged: (v) => setState(() => _editAnonymous = v),
              onPickImage: _pickReplacementImage,
              onRemoveCurrentImages:
                  () => setState(() {
                    _editReplacementImage = null;
                    _editRemoveImages = true;
                  }),
              onRemoveReplacement:
                  () => setState(() => _editReplacementImage = null),
              onCancel:
                  () => setState(() {
                    _editCtrl.text = comment.body;
                    _editAnonymous = comment.isAnonymous;
                    _editReplacementImage = null;
                    _editRemoveImages = false;
                    _isEditing = false;
                  }),
              onSave: _save,
            )
          else
            _Bubble(
              name: comment.displayName,
              body: hiddenForUser ? '신고 누적으로 숨김 처리된 댓글입니다.' : comment.body,
              imageUrls: hiddenForUser ? const [] : comment.imageUrls,
              stickerId: hiddenForUser ? null : comment.stickerId,
              isHiddenForAdmin: comment.isHidden && isAdmin,
            ),
          Row(
            children: [
              _TinyAction(
                label: '좋아요 ${comment.likeCount}',
                onTap:
                    () => SeniorQuestionService.toggleCommentLike(
                      questionId: questionId,
                      commentId: comment.id,
                    ),
              ),
              _TinyAction(
                label: '답글 ${comment.replyCount}',
                onTap: widget.onReply,
              ),
              _TinyAction(label: '신고', onTap: () => _report(context)),
              if (isAuthor)
                PopupMenuButton<String>(
                  color: AppColors.appBg,
                  elevation: 4,
                  position: PopupMenuPosition.under,
                  offset: const Offset(0, 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  icon: const Icon(
                    Icons.more_horiz,
                    size: 17,
                    color: AppColors.textSecondary,
                  ),
                  onSelected: (value) {
                    if (value == 'edit') setState(() => _isEditing = true);
                    if (value == 'delete') _confirmDelete(context);
                  },
                  itemBuilder:
                      (_) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: _MenuItemText('수정'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: _MenuItemText('삭제', destructive: true),
                        ),
                      ],
                ),
              if (comment.isHidden && isAdmin)
                _TinyAction(label: '복구', onTap: () => _restore(context)),
            ],
          ),
          if (widget.showReplies)
            StreamBuilder<List<SeniorReply>>(
              stream: SeniorQuestionService.watchReplies(
                questionId: questionId,
                commentId: comment.id,
              ),
              builder: (_, snap) {
                final replies = snap.data ?? [];
                if (replies.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xl, top: 2),
                  child: Column(
                    children:
                        replies
                            .map(
                              (reply) => _ReplyTile(
                                questionId: questionId,
                                commentId: comment.id,
                                reply: reply,
                                isAdmin: isAdmin,
                              ),
                            )
                            .toList(),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final body = _editCtrl.text.trim();
    final hasImageAfterSave =
        _editReplacementImage != null ||
        (!_editRemoveImages && comment.imageUrls.isNotEmpty);
    if ((body.isEmpty && !hasImageAfterSave) || _saving) {
      _snack('내용을 입력해 주세요.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    final ok = await SeniorQuestionService.updateComment(
      questionId: questionId,
      commentId: comment.id,
      body: body,
      isAnonymous: _editAnonymous,
      removeImages: _editRemoveImages,
      replacementImage: _editReplacementImage,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) {
        _editReplacementImage = null;
        _editRemoveImages = false;
        _isEditing = false;
      }
    });
    _snack(ok ? '댓글을 수정했어요.' : '수정에 실패했어요.');
  }

  Future<void> _pickReplacementImage() async {
    final picked = await SeniorQuestionImageService.pickImages(remaining: 1);
    if (!mounted || picked.isEmpty) return;
    setState(() {
      _editReplacementImage = picked.first;
      _editRemoveImages = false;
    });
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => _ConfirmDialog(
            title: '댓글 삭제',
            message: '이 댓글을 삭제할까요?\n달린 답글도 함께 보이지 않게 됩니다.',
            confirmLabel: '삭제',
            destructive: true,
            onCancel: () => Navigator.pop(ctx, false),
            onConfirm: () => Navigator.pop(ctx, true),
          ),
    );
    if (ok != true) return;
    final success = await SeniorQuestionService.deleteComment(
      questionId: questionId,
      commentId: comment.id,
    );
    if (!mounted) return;
    _snack(success ? '댓글을 삭제했어요.' : '삭제에 실패했어요.');
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _report(BuildContext context) async {
    final ok = await SeniorQuestionService.reportComment(
      questionId: questionId,
      commentId: comment.id,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '신고가 접수되었어요.' : '이미 신고했거나 처리에 실패했어요.')),
    );
  }

  Future<void> _restore(BuildContext context) async {
    final ok = await SeniorQuestionService.restoreDocument(
      SeniorQuestionService.commentRef(questionId, comment.id),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(ok ? '댓글을 복구했어요.' : '복구에 실패했어요.')));
  }
}

class _CommentEditBox extends StatelessWidget {
  final TextEditingController controller;
  final bool anonymous;
  final bool saving;
  final List<String> currentImageUrls;
  final XFile? replacementImage;
  final bool removeImages;
  final ValueChanged<bool> onAnonymousChanged;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveCurrentImages;
  final VoidCallback onRemoveReplacement;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _CommentEditBox({
    required this.controller,
    required this.anonymous,
    required this.saving,
    required this.currentImageUrls,
    required this.replacementImage,
    required this.removeImages,
    required this.onAnonymousChanged,
    required this.onPickImage,
    required this.onRemoveCurrentImages,
    required this.onRemoveReplacement,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            minLines: 2,
            maxLines: 5,
            maxLength: SeniorQuestionService.maxCommentLength,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.45,
            ),
            decoration: const InputDecoration(
              hintText: '댓글을 수정하세요',
              border: InputBorder.none,
              isDense: true,
              counterStyle: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textDisabled,
              ),
            ),
          ),
          _EditImageControls(
            currentImageUrls: currentImageUrls,
            replacementImage: replacementImage,
            removeImages: removeImages,
            onPickImage: onPickImage,
            onRemoveCurrentImages: onRemoveCurrentImages,
            onRemoveReplacement: onRemoveReplacement,
          ),
          Row(
            children: [
              Checkbox(
                value: anonymous,
                onChanged:
                    saving ? null : (v) => onAnonymousChanged(v ?? false),
                visualDensity: VisualDensity.compact,
                activeColor: AppColors.accent,
              ),
              GestureDetector(
                onTap: saving ? null : () => onAnonymousChanged(!anonymous),
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
                onPressed: saving ? null : onCancel,
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: saving ? null : onSave,
                child:
                    saving
                        ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('저장'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.destructive,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.appBg,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.7)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onCancel,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      backgroundColor: AppColors.surfaceMuted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextButton(
                    onPressed: onConfirm,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.onCardEmphasis,
                      backgroundColor:
                          destructive
                              ? AppColors.cardEmphasis
                              : AppColors.cardPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyTile extends StatelessWidget {
  final String questionId;
  final String commentId;
  final SeniorReply reply;
  final bool isAdmin;

  const _ReplyTile({
    required this.questionId,
    required this.commentId,
    required this.reply,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final hiddenForUser = reply.isHidden && !isAdmin;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Bubble(
            name: reply.displayName,
            body: hiddenForUser ? '신고 누적으로 숨김 처리된 답글입니다.' : reply.body,
            imageUrls: hiddenForUser ? const [] : reply.imageUrls,
            stickerId: hiddenForUser ? null : reply.stickerId,
            isHiddenForAdmin: reply.isHidden && isAdmin,
            compact: true,
          ),
          Row(
            children: [
              _TinyAction(
                label: '좋아요 ${reply.likeCount}',
                onTap:
                    () => SeniorQuestionService.toggleReplyLike(
                      questionId: questionId,
                      commentId: commentId,
                      replyId: reply.id,
                    ),
              ),
              _TinyAction(label: '신고', onTap: () => _report(context)),
              if (reply.isHidden && isAdmin)
                _TinyAction(label: '복구', onTap: () => _restore(context)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _report(BuildContext context) async {
    final ok = await SeniorQuestionService.reportReply(
      questionId: questionId,
      commentId: commentId,
      replyId: reply.id,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '신고가 접수되었어요.' : '이미 신고했거나 처리에 실패했어요.')),
    );
  }

  Future<void> _restore(BuildContext context) async {
    final ok = await SeniorQuestionService.restoreDocument(
      SeniorQuestionService.replyRef(questionId, commentId, reply.id),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(ok ? '답글을 복구했어요.' : '복구에 실패했어요.')));
  }
}

class _InlineCommentInput extends StatelessWidget {
  final TextEditingController controller;
  final String? replyToName;
  final bool anonymous;
  final bool submitting;
  final XFile? image;
  final String? stickerId;
  final ValueChanged<bool> onAnonymousChanged;
  final VoidCallback onCancelReply;
  final VoidCallback? onPickImage;
  final VoidCallback? onRemoveImage;
  final VoidCallback? onPickSticker;
  final VoidCallback? onRemoveSticker;
  final VoidCallback onSubmit;

  const _InlineCommentInput({
    required this.controller,
    required this.replyToName,
    required this.anonymous,
    required this.submitting,
    required this.image,
    required this.stickerId,
    required this.onAnonymousChanged,
    required this.onCancelReply,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onPickSticker,
    required this.onRemoveSticker,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyToName != null)
            Row(
              children: [
                Text(
                  '$replyToName님에게 답글',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onCancelReply,
                  child: const Text(
                    '취소',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDisabled,
                    ),
                  ),
                ),
              ],
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onTapOutside:
                      (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  minLines: 1,
                  maxLines: 3,
                  maxLength: SeniorQuestionService.maxCommentLength,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: '댓글을 입력하세요',
                    counterText: '',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                onPressed: submitting ? null : onSubmit,
                icon:
                    submitting
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.send_rounded, size: 18),
                color: AppColors.accent,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (image != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _CommentImagePreview(file: image!, onRemove: onRemoveImage),
          ],
          if (stickerId != null) ...[
            const SizedBox(height: AppSpacing.xs),
            SeniorStickerChip(stickerId: stickerId!, onRemove: onRemoveSticker),
          ],
          Row(
            children: [
              IconButton(
                onPressed: submitting ? null : onPickImage,
                icon: Icon(
                  image == null ? Icons.image_outlined : Icons.image,
                  size: 18,
                ),
                color:
                    image == null
                        ? AppColors.textSecondary
                        : AppColors.cardEmphasis,
                visualDensity: VisualDensity.compact,
                tooltip: '사진 첨부',
              ),
              IconButton(
                onPressed: submitting ? null : onPickSticker,
                icon: Icon(
                  stickerId == null
                      ? Icons.emoji_emotions_outlined
                      : Icons.emoji_emotions,
                  size: 18,
                ),
                color:
                    stickerId == null
                        ? AppColors.textSecondary
                        : AppColors.cardEmphasis,
                visualDensity: VisualDensity.compact,
                tooltip: '스티커 첨부',
              ),
              Checkbox(
                value: anonymous,
                onChanged:
                    submitting ? null : (v) => onAnonymousChanged(v ?? false),
                visualDensity: VisualDensity.compact,
                activeColor: AppColors.accent,
              ),
              GestureDetector(
                onTap: submitting ? null : () => onAnonymousChanged(!anonymous),
                child: const Text(
                  '닉네임 비공개',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuestionBodyWithMeta extends StatelessWidget {
  final String body;
  final String authorName;
  final String metaText;
  final bool muted;

  const _QuestionBodyWithMeta({
    required this.body,
    required this.authorName,
    required this.metaText,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          body,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            height: 1.42,
            color: muted ? AppColors.textSecondary : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '$authorName · $metaText',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textDisabled,
          ),
        ),
      ],
    );
  }
}

class _CommentImagePreview extends StatelessWidget {
  final XFile file;
  final VoidCallback? onRemove;

  const _CommentImagePreview({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Stack(
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
                          width: 180,
                          height: 120,
                          fit: BoxFit.contain,
                        )
                        : Container(
                          width: 180,
                          height: 120,
                          color: AppColors.surfaceMuted,
                        ),
              );
            },
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditImageControls extends StatelessWidget {
  final List<String> currentImageUrls;
  final XFile? replacementImage;
  final bool removeImages;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveCurrentImages;
  final VoidCallback onRemoveReplacement;

  const _EditImageControls({
    required this.currentImageUrls,
    required this.replacementImage,
    required this.removeImages,
    required this.onPickImage,
    required this.onRemoveCurrentImages,
    required this.onRemoveReplacement,
  });

  @override
  Widget build(BuildContext context) {
    final hasCurrent = currentImageUrls.isNotEmpty && !removeImages;
    final hasReplacement = replacementImage != null;
    final hasAnyImage = hasCurrent || hasReplacement;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasAnyImage) ...[
          const SizedBox(height: AppSpacing.sm),
          if (hasReplacement)
            _CommentImagePreview(
              file: replacementImage!,
              onRemove: onRemoveReplacement,
            )
          else
            _EditNetworkImagePreview(
              url: currentImageUrls.first,
              onRemove: onRemoveCurrentImages,
            ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            _EditImageAction(
              icon: Icons.image_outlined,
              label: hasAnyImage ? '사진 교체' : '사진 추가',
              onTap: onPickImage,
            ),
            if (hasCurrent)
              _EditImageAction(
                icon: Icons.delete_outline,
                label: '사진 삭제',
                destructive: true,
                onTap: onRemoveCurrentImages,
              ),
          ],
        ),
      ],
    );
  }
}

class _EditNetworkImagePreview extends StatelessWidget {
  final String url;
  final VoidCallback onRemove;

  const _EditNetworkImagePreview({required this.url, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Stack(
        children: [
          Container(
            width: 180,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder:
                  (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image_outlined, size: 18),
                  ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditImageAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool destructive;
  final VoidCallback onTap;

  const _EditImageAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        destructive ? AppColors.cardEmphasis : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineEditBox extends StatelessWidget {
  final TextEditingController controller;
  final String category;
  final bool isAnonymous;
  final List<String> currentImageUrls;
  final XFile? replacementImage;
  final bool removeImages;
  final String? stickerId;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<bool> onAnonymousChanged;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveCurrentImages;
  final VoidCallback onRemoveReplacement;
  final VoidCallback onPickSticker;
  final VoidCallback onRemoveSticker;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _InlineEditBox({
    required this.controller,
    required this.category,
    required this.isAnonymous,
    required this.currentImageUrls,
    required this.replacementImage,
    required this.removeImages,
    required this.stickerId,
    required this.onCategoryChanged,
    required this.onAnonymousChanged,
    required this.onPickImage,
    required this.onRemoveCurrentImages,
    required this.onRemoveReplacement,
    required this.onPickSticker,
    required this.onRemoveSticker,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InlineCategoryDropdown(
            value: category,
            onChanged: onCategoryChanged,
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: controller,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            minLines: 3,
            maxLines: 8,
            maxLength: SeniorQuestionService.maxBodyLength,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.45,
              color: AppColors.textPrimary,
            ),
            decoration: const InputDecoration(
              hintText: '내용을 입력하세요',
              border: InputBorder.none,
              isDense: true,
              counterStyle: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textDisabled,
              ),
            ),
          ),
          _EditImageControls(
            currentImageUrls: currentImageUrls,
            replacementImage: replacementImage,
            removeImages: removeImages,
            onPickImage: onPickImage,
            onRemoveCurrentImages: onRemoveCurrentImages,
            onRemoveReplacement: onRemoveReplacement,
          ),
          if (stickerId != null) ...[
            const SizedBox(height: AppSpacing.xs),
            SeniorStickerChip(stickerId: stickerId!, onRemove: onRemoveSticker),
          ],
          TextButton.icon(
            onPressed: onPickSticker,
            icon: const Icon(Icons.emoji_emotions_outlined, size: 16),
            label: Text(stickerId == null ? '스티커 추가' : '스티커 변경'),
          ),
          Row(
            children: [
              Checkbox(
                value: isAnonymous,
                onChanged: (v) => onAnonymousChanged(v ?? false),
                visualDensity: VisualDensity.compact,
                activeColor: AppColors.accent,
              ),
              GestureDetector(
                onTap: () => onAnonymousChanged(!isAnonymous),
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
              TextButton(onPressed: onCancel, child: const Text('취소')),
              TextButton(onPressed: onSave, child: const Text('저장')),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineCategoryDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _InlineCategoryDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SmallBadge(label: value, dark: true),
          const SizedBox(width: 2),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: AppColors.cardEmphasis,
          ),
        ],
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final bool dark;

  const _SmallBadge({required this.label, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: dark ? AppColors.cardEmphasis : AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border:
            dark
                ? null
                : Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: dark ? AppColors.onCardEmphasis : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _MenuItemText extends StatelessWidget {
  final String text;
  final bool destructive;

  const _MenuItemText(this.text, {this.destructive = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: destructive ? AppColors.cardEmphasis : AppColors.textPrimary,
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String name;
  final String body;
  final List<String> imageUrls;
  final String? stickerId;
  final bool isHiddenForAdmin;
  final bool compact;

  const _Bubble({
    required this.name,
    required this.body,
    required this.imageUrls,
    required this.stickerId,
    required this.isHiddenForAdmin,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final visibleBody =
        isSeniorStickerFallbackBody(body, stickerId) ? '' : body;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
      decoration: BoxDecoration(
        color:
            isHiddenForAdmin
                ? AppColors.error.withValues(alpha: 0.06)
                : AppColors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (isHiddenForAdmin) ...[
                const SizedBox(width: 6),
                const Text(
                  '숨김',
                  style: TextStyle(fontSize: 11, color: AppColors.error),
                ),
              ],
            ],
          ),
          if (visibleBody.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              visibleBody,
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w700,
                height: 1.45,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          if (imageUrls.isNotEmpty) ...[
            SizedBox(
              height: visibleBody.isEmpty ? AppSpacing.xs : AppSpacing.sm,
            ),
            _CommentImage(url: imageUrls.first),
          ],
          if (stickerId != null) ...[
            SizedBox(
              height:
                  visibleBody.isEmpty && imageUrls.isEmpty
                      ? AppSpacing.xs
                      : AppSpacing.sm,
            ),
            SeniorStickerView(stickerId: stickerId!, size: compact ? 50 : 62),
          ],
        ],
      ),
    );
  }
}

class _CommentImage extends StatelessWidget {
  final String url;

  const _CommentImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showImageViewer(context, url),
      child: Container(
        width: 190,
        height: 125,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder:
              (_, __, ___) => const Center(
                child: Icon(Icons.broken_image_outlined, size: 18),
              ),
        ),
      ),
    );
  }
}

class _TinyAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TinyAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        foregroundColor: AppColors.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: const Size(0, 28),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ImageGrid extends StatelessWidget {
  final List<String> urls;

  const _ImageGrid({required this.urls});

  @override
  Widget build(BuildContext context) {
    final visible = urls.take(4).toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visible.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: visible.length == 1 ? 1 : 2,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: visible.length == 1 ? 1.8 : 1,
      ),
      itemBuilder:
          (_, i) => GestureDetector(
            onTap: () => _showImageViewer(context, visible[i]),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                visible[i],
                fit: BoxFit.contain,
                errorBuilder:
                    (_, __, ___) =>
                        const Center(child: Icon(Icons.broken_image_outlined)),
              ),
            ),
          ),
    );
  }
}

void _showImageViewer(BuildContext context, String url) {
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder:
        (ctx) => Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.7,
                  maxScale: 4,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder:
                        (_, __, ___) => const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white,
                        ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: SafeArea(
                  child: IconButton.filled(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                    color: Colors.white,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
  );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final int? count;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14, color: iconColor),
      label: Text(
        count == null ? label : '$label $count',
        overflow: TextOverflow.ellipsis,
      ),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        minimumSize: const Size(0, 26),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _AdminHiddenBanner extends StatelessWidget {
  const _AdminHiddenBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: const Text(
        '관리자에게만 보이는 숨김 글입니다.',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.error,
        ),
      ),
    );
  }
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inHours < 1) return '${diff.inMinutes}분 전';
  if (diff.inDays < 1) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
}
