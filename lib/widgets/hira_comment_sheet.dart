import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/hira_update.dart';
import '../services/hira_comment_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';

/// HIRA 댓글 BottomSheet
class HiraCommentSheet extends StatefulWidget {
  final HiraUpdate update;

  const HiraCommentSheet({super.key, required this.update});

  @override
  State<HiraCommentSheet> createState() => _HiraCommentSheetState();
}

class _HiraCommentSheetState extends State<HiraCommentSheet> {
  final _controller = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _controller.text.trim();
    debugPrint('🔍 _sendComment 시작: text="$text", isSending=$_isSending');
    
    if (text.isEmpty || _isSending) {
      debugPrint('⚠️ 텍스트가 비어있거나 이미 전송 중');
      return;
    }

    setState(() => _isSending = true);
    debugPrint('🔍 HiraCommentService.addComment 호출...');

    final success = await HiraCommentService.addComment(
      widget.update.id,
      text,
    );

    debugPrint('🔍 addComment 결과: success=$success');

    if (mounted) {
      setState(() => _isSending = false);
      if (success) {
        _controller.clear();
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('댓글이 등록되었습니다'),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('댓글 등록에 실패했습니다')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.divider),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  '댓글',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.close,
                    size: 22,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // 댓글 목록
          Expanded(
            child: StreamBuilder<List<HiraComment>>(
              stream: HiraCommentService.watchComments(widget.update.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accent,
                    ),
                  );
                }

                final comments = snapshot.data ?? [];
                if (comments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.comment_outlined,
                          size: 48,
                          color: AppColors.textDisabled,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '첫 댓글을 남겨보세요',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: comments.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    color: AppColors.divider,
                  ),
                  itemBuilder: (context, i) {
                    final comment = comments[i];
                    return _CommentItem(
                      comment: comment,
                      updateId: widget.update.id,
                    );
                  },
                );
              },
            ),
          ),

          // 입력창
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surfaceMuted,
              border: Border(
                top: BorderSide(color: AppColors.divider),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(
                        color: AppColors.divider,
                      ),
                    ),
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      maxLength: 200,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: '댓글을 입력하세요...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: AppColors.textDisabled,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        counterText: '',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isSending ? null : _sendComment,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _isSending
                          ? AppColors.disabledBg
                          : AppColors.accent.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(
                      Icons.send,
                      size: 20,
                      color: _isSending
                          ? AppColors.textDisabled
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 개별 댓글 아이템 (이모지 반응 포함)
class _CommentItem extends StatelessWidget {
  final HiraComment comment;
  final String updateId;

  const _CommentItem({
    required this.comment,
    required this.updateId,
  });

  static const _emojiList = ['👍', '❤️', '😊', '💪', '🎉'];

  Future<void> _deleteComment(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('댓글 삭제'),
        content: const Text('댓글을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '삭제',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await HiraCommentService.deleteComment(
        updateId,
        comment.id,
        comment.uid,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '댓글이 삭제되었습니다' : '댓글 삭제에 실패했습니다'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return '방금';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}분 전';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}시간 전';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}일 전';
    } else {
      return DateFormat('MM/dd HH:mm').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isMyComment = currentUid == comment.uid;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 아바타
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: const Icon(
              Icons.person_outline,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          // 댓글 내용
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.userName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(comment.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textDisabled,
                      ),
                    ),
                    const Spacer(),
                    if (isMyComment)
                      GestureDetector(
                        onTap: () => _deleteComment(context),
                        child: const Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: AppColors.textDisabled,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  comment.text,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                // 이모지 반응 영역
                StreamBuilder<Map<String, dynamic>>(
                  stream: HiraCommentService.watchCommentReactions(
                    updateId,
                    comment.id,
                  ),
                  builder: (context, snap) {
                    final data = snap.data;
                    final counts =
                        (data?['counts'] as Map<String, int>?) ?? {};
                    final myEmoji = data?['myEmoji'] as String?;

                    return Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        // 이모지 칩들 (카운트가 있는 것만 먼저 표시)
                        for (final emoji in _emojiList)
                          if ((counts[emoji] ?? 0) > 0)
                            _ReactionChip(
                              emoji: emoji,
                              count: counts[emoji] ?? 0,
                              isSelected: myEmoji == emoji,
                              onTap: () =>
                                  HiraCommentService.toggleCommentReaction(
                                updateId,
                                comment.id,
                                emoji,
                              ),
                            ),
                        // "+" 버튼으로 이모지 추가
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _showEmojiPicker(
                              context, myEmoji),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Text(
                              '😀+',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEmojiPicker(BuildContext context, String? myEmoji) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이모지 선택', style: TextStyle(fontSize: 14)),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _emojiList.map((emoji) {
            final isSelected = myEmoji == emoji;
            return GestureDetector(
              onTap: () {
                HiraCommentService.toggleCommentReaction(
                  updateId,
                  comment.id,
                  emoji,
                );
                Navigator.pop(ctx);
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accent.withOpacity(0.4)
                      : AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// 이모지 반응 칩 (bond_post_card와 동일 사이즈)
class _ReactionChip extends StatelessWidget {
  final String emoji;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withOpacity(0.3)
              : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: isSelected
              ? Border.all(color: AppColors.accent, width: 1)
              : null,
        ),
        child: Text(
          '$emoji$count',
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}

