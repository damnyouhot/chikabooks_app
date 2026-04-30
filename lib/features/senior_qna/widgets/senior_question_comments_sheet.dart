import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../data/senior_stickers.dart';
import '../models/senior_question.dart';
import '../services/senior_question_image_service.dart';
import '../services/senior_question_service.dart';
import '../services/senior_sticker_usage_service.dart';
import 'senior_sticker_widgets.dart';

class SeniorQuestionCommentsSheet extends StatefulWidget {
  final SeniorQuestion question;
  final bool isAdmin;

  const SeniorQuestionCommentsSheet({
    super.key,
    required this.question,
    required this.isAdmin,
  });

  static Future<void> show(
    BuildContext context, {
    required SeniorQuestion question,
    required bool isAdmin,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder:
          (_) =>
              SeniorQuestionCommentsSheet(question: question, isAdmin: isAdmin),
    );
  }

  @override
  State<SeniorQuestionCommentsSheet> createState() =>
      _SeniorQuestionCommentsSheetState();
}

class _SeniorQuestionCommentsSheetState
    extends State<SeniorQuestionCommentsSheet> {
  final _inputCtrl = TextEditingController();
  String? _replyToCommentId;
  String? _replyToName;
  XFile? _image;
  String? _stickerId;
  bool _anonymous = false;
  bool _submitting = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _inputCtrl.text.trim();
    if ((body.isEmpty && _image == null && _stickerId == null) || _submitting) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _submitting = true);
    final ok =
        _replyToCommentId == null
            ? await SeniorQuestionService.addComment(
              questionId: widget.question.id,
              body: body,
              isAnonymous: _anonymous,
              image: _image,
              stickerId: _stickerId,
            )
            : await SeniorQuestionService.addReply(
              questionId: widget.question.id,
              commentId: _replyToCommentId!,
              body: body,
              isAnonymous: _anonymous,
              image: _image,
              stickerId: _stickerId,
            );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (ok) {
        _inputCtrl.clear();
        _image = null;
        _stickerId = null;
        _replyToCommentId = null;
        _replyToName = null;
        _anonymous = false;
      }
    });
    if (!ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('등록에 실패했어요. 다시 시도해 주세요.')));
    }
  }

  Future<void> _pickImage() async {
    final picked = await SeniorQuestionImageService.pickImages(remaining: 1);
    if (!mounted || picked.isEmpty) return;
    setState(() => _image = picked.first);
  }

  Future<void> _pickSticker() async {
    final id = await showSeniorStickerPicker(context, selectedId: _stickerId);
    if (!mounted || id == null) return;
    await SeniorStickerUsageService.recordSticker(id);
    if (!mounted) return;
    setState(() => _stickerId = id);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.86,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  const Text(
                    '댓글',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<SeniorComment>>(
                stream: SeniorQuestionService.watchComments(widget.question.id),
                builder: (_, snap) {
                  final comments = snap.data ?? [];
                  if (snap.connectionState == ConnectionState.waiting &&
                      comments.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (comments.isEmpty) {
                    return const Center(
                      child: Text(
                        '아직 댓글이 없어요.',
                        style: TextStyle(color: AppColors.textDisabled),
                      ),
                    );
                  }
                  return ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    itemCount: comments.length,
                    itemBuilder:
                        (_, i) => _CommentTile(
                          questionId: widget.question.id,
                          comment: comments[i],
                          isAdmin: widget.isAdmin,
                          onReply:
                              () => setState(() {
                                _replyToCommentId = comments[i].id;
                                _replyToName = comments[i].displayName;
                              }),
                        ),
                  );
                },
              ),
            ),
            _InputBar(
              controller: _inputCtrl,
              replyToName: _replyToName,
              anonymous: _anonymous,
              submitting: _submitting,
              image: _image,
              stickerId: _stickerId,
              onCancelReply:
                  () => setState(() {
                    _replyToCommentId = null;
                    _replyToName = null;
                  }),
              onAnonymousChanged: (v) => setState(() => _anonymous = v),
              onPickImage: _pickImage,
              onRemoveImage: () => setState(() => _image = null),
              onPickSticker: _pickSticker,
              onRemoveSticker: () => setState(() => _stickerId = null),
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final String questionId;
  final SeniorComment comment;
  final bool isAdmin;
  final VoidCallback onReply;

  const _CommentTile({
    required this.questionId,
    required this.comment,
    required this.isAdmin,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final hiddenForUser = comment.isHidden && !isAdmin;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Bubble(
            name: comment.displayName,
            body: hiddenForUser ? '신고 누적으로 숨김 처리된 댓글입니다.' : comment.body,
            imageUrls: hiddenForUser ? const [] : comment.imageUrls,
            stickerId: hiddenForUser ? null : comment.stickerId,
            isHiddenForAdmin: comment.isHidden && isAdmin,
            actions: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StreamBuilder<bool>(
                  stream: SeniorQuestionService.watchCommentLikeSelected(
                    questionId: questionId,
                    commentId: comment.id,
                  ),
                  builder: (_, snap) {
                    final selected = snap.data ?? false;
                    return _TinyAction(
                      icon: selected ? Icons.favorite : Icons.favorite_border,
                      iconColor:
                          selected ? AppColors.error : AppColors.textSecondary,
                      label: '좋아요 ${comment.likeCount}',
                      onTap:
                          () => SeniorQuestionService.toggleCommentLike(
                            questionId: questionId,
                            commentId: comment.id,
                          ),
                    );
                  },
                ),
                _TinyAction(label: '답글 ${comment.replyCount}', onTap: onReply),
                _TinyAction(label: '신고', onTap: () => _reportComment(context)),
                if (comment.isHidden && isAdmin)
                  _TinyAction(
                    label: '복구',
                    onTap: () => _restoreComment(context),
                  ),
              ],
            ),
          ),
          StreamBuilder<List<SeniorReply>>(
            stream: SeniorQuestionService.watchReplies(
              questionId: questionId,
              commentId: comment.id,
            ),
            builder: (_, snap) {
              final replies = snap.data ?? [];
              if (replies.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xl, top: 4),
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

  Future<void> _reportComment(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('댓글 신고'),
            content: const Text(
              '이 댓글을 신고할까요?\n신고가 일정 수준 이상 누적되면 자동으로 숨김 처리됩니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('신고'),
              ),
            ],
          ),
    );
    if (confirm != true) return;
    final ok = await SeniorQuestionService.reportComment(
      questionId: questionId,
      commentId: comment.id,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '신고가 접수되었어요.' : '이미 신고했거나 처리에 실패했어요.')),
    );
  }

  Future<void> _restoreComment(BuildContext context) async {
    final ok = await SeniorQuestionService.restoreDocument(
      SeniorQuestionService.commentRef(questionId, comment.id),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(ok ? '댓글을 복구했어요.' : '복구에 실패했어요.')));
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
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final isAuthor = myUid != null && reply.uid == myUid;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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
            actions: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StreamBuilder<bool>(
                  stream: SeniorQuestionService.watchReplyLikeSelected(
                    questionId: questionId,
                    commentId: commentId,
                    replyId: reply.id,
                  ),
                  builder: (_, snap) {
                    final selected = snap.data ?? false;
                    return _TinyAction(
                      icon: selected ? Icons.favorite : Icons.favorite_border,
                      iconColor:
                          selected ? AppColors.error : AppColors.textSecondary,
                      label: '좋아요 ${reply.likeCount}',
                      onTap:
                          () => SeniorQuestionService.toggleReplyLike(
                            questionId: questionId,
                            commentId: commentId,
                            replyId: reply.id,
                          ),
                    );
                  },
                ),
                _TinyAction(label: '신고', onTap: () => _reportReply(context)),
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
                      if (value == 'delete') _confirmDelete(context);
                    },
                    itemBuilder:
                        (_) => const [
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              '삭제',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                  ),
                if (reply.isHidden && isAdmin)
                  _TinyAction(label: '복구', onTap: () => _restoreReply(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('답글 삭제'),
            content: const Text('이 답글을 삭제할까요?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('삭제'),
              ),
            ],
          ),
    );
    if (ok != true) return;
    final success = await SeniorQuestionService.deleteReply(
      questionId: questionId,
      commentId: commentId,
      replyId: reply.id,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? '답글을 삭제했어요.' : '삭제에 실패했어요.')),
    );
  }

  Future<void> _reportReply(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('답글 신고'),
            content: const Text(
              '이 답글을 신고할까요?\n신고가 일정 수준 이상 누적되면 자동으로 숨김 처리됩니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('신고'),
              ),
            ],
          ),
    );
    if (confirm != true) return;
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

  Future<void> _restoreReply(BuildContext context) async {
    final ok = await SeniorQuestionService.restoreDocument(
      SeniorQuestionService.replyRef(questionId, commentId, reply.id),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(ok ? '답글을 복구했어요.' : '복구에 실패했어요.')));
  }
}

class _Bubble extends StatelessWidget {
  final String name;
  final String body;
  final List<String> imageUrls;
  final String? stickerId;
  final bool isHiddenForAdmin;
  final bool compact;
  final Widget? actions;

  const _Bubble({
    required this.name,
    required this.body,
    required this.imageUrls,
    required this.stickerId,
    required this.isHiddenForAdmin,
    this.compact = false,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final visibleBody =
        isSeniorStickerFallbackBody(body, stickerId) ? '' : body;
    final basePadding = compact ? AppSpacing.sm : AppSpacing.md;
    final bottomPadding = actions == null ? basePadding : (compact ? 2.0 : 4.0);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        basePadding,
        basePadding,
        basePadding,
        bottomPadding,
      ),
      decoration: BoxDecoration(
        color:
            isHiddenForAdmin
                ? AppColors.error.withValues(alpha: 0.06)
                : AppColors.surfaceMuted,
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
                  fontSize: 12,
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
            const SizedBox(height: 4),
            Text(
              visibleBody,
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                height: 1.45,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          if (imageUrls.isNotEmpty) ...[
            SizedBox(
              height: visibleBody.isEmpty ? AppSpacing.xs : AppSpacing.sm,
            ),
            _AttachedImage(url: imageUrls.first),
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
          if (actions != null) ...[
            SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
            Align(alignment: Alignment.centerRight, child: actions!),
          ],
        ],
      ),
    );
  }
}

class _AttachedImage extends StatelessWidget {
  final String url;

  const _AttachedImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      height: 125,
      decoration: BoxDecoration(
        color: AppColors.white,
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
    );
  }
}

class _TinyAction extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final String label;
  final VoidCallback onTap;

  const _TinyAction({
    this.icon,
    this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        foregroundColor: AppColors.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(width: 3),
          ],
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final String? replyToName;
  final bool anonymous;
  final bool submitting;
  final XFile? image;
  final String? stickerId;
  final VoidCallback onCancelReply;
  final ValueChanged<bool> onAnonymousChanged;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final VoidCallback onPickSticker;
  final VoidCallback onRemoveSticker;
  final VoidCallback onSubmit;

  const _InputBar({
    required this.controller,
    required this.replyToName,
    required this.anonymous,
    required this.submitting,
    required this.image,
    required this.stickerId,
    required this.onCancelReply,
    required this.onAnonymousChanged,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onPickSticker,
    required this.onRemoveSticker,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (replyToName != null)
              Row(
                children: [
                  Text(
                    '$replyToName님에게 답글 작성 중',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.accent,
                    ),
                  ),
                  const Spacer(),
                  TextButton(onPressed: onCancelReply, child: const Text('취소')),
                ],
              ),
            if (image != null) ...[
              const SizedBox(height: AppSpacing.xs),
              _ImagePreview(file: image!, onRemove: onRemoveImage),
            ],
            if (stickerId != null) ...[
              const SizedBox(height: AppSpacing.xs),
              SeniorStickerChip(
                stickerId: stickerId!,
                onRemove: onRemoveSticker,
              ),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    onTapOutside:
                        (_) => FocusManager.instance.primaryFocus?.unfocus(),
                    minLines: 1,
                    maxLines: 3,
                    maxLength: SeniorQuestionService.maxCommentLength,
                    decoration: const InputDecoration(
                      hintText: '댓글을 입력하세요',
                      counterText: '',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  onPressed: submitting ? null : onSubmit,
                  icon:
                      submitting
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.send_rounded),
                  color: AppColors.accent,
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  onPressed: submitting ? null : onPickImage,
                  icon: Icon(
                    image == null ? Icons.image_outlined : Icons.image,
                    size: 19,
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
                    size: 19,
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
                  onTap:
                      submitting ? null : () => onAnonymousChanged(!anonymous),
                  child: const Text(
                    '닉네임 비공개',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
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

class _ImagePreview extends StatelessWidget {
  final XFile file;
  final VoidCallback onRemove;

  const _ImagePreview({required this.file, required this.onRemove});

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
