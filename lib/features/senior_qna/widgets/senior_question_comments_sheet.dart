import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../models/senior_question.dart';
import '../services/senior_question_service.dart';

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
  bool _anonymous = false;
  bool _submitting = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _inputCtrl.text.trim();
    if (body.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    final ok =
        _replyToCommentId == null
            ? await SeniorQuestionService.addComment(
              questionId: widget.question.id,
              body: body,
              isAnonymous: _anonymous,
            )
            : await SeniorQuestionService.addReply(
              questionId: widget.question.id,
              commentId: _replyToCommentId!,
              body: body,
              isAnonymous: _anonymous,
            );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (ok) {
        _inputCtrl.clear();
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
                    onPressed: () => Navigator.pop(context),
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
              onCancelReply:
                  () => setState(() {
                    _replyToCommentId = null;
                    _replyToName = null;
                  }),
              onAnonymousChanged: (v) => setState(() => _anonymous = v),
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
              _TinyAction(label: '답글 ${comment.replyCount}', onTap: onReply),
              _TinyAction(label: '신고', onTap: () => _reportComment(context)),
              if (comment.isHidden && isAdmin)
                _TinyAction(label: '복구', onTap: () => _restoreComment(context)),
            ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Bubble(
            name: reply.displayName,
            body: hiddenForUser ? '신고 누적으로 숨김 처리된 답글입니다.' : reply.body,
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
              _TinyAction(label: '신고', onTap: () => _reportReply(context)),
              if (reply.isHidden && isAdmin)
                _TinyAction(label: '복구', onTap: () => _restoreReply(context)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _reportReply(BuildContext context) async {
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
  final bool isHiddenForAdmin;
  final bool compact;

  const _Bubble({
    required this.name,
    required this.body,
    required this.isHiddenForAdmin,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
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
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(
              fontSize: compact ? 12 : 13,
              height: 1.45,
              color: AppColors.textPrimary,
            ),
          ),
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 32),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final String? replyToName;
  final bool anonymous;
  final bool submitting;
  final VoidCallback onCancelReply;
  final ValueChanged<bool> onAnonymousChanged;
  final VoidCallback onSubmit;

  const _InputBar({
    required this.controller,
    required this.replyToName,
    required this.anonymous,
    required this.submitting,
    required this.onCancelReply,
    required this.onAnonymousChanged,
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
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
