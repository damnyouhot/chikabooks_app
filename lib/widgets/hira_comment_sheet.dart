import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/hira_update.dart';
import '../services/hira_comment_service.dart';

// ── 디자인 팔레트 (기존 탭과 통일) ──
const _kText = Color(0xFF5D6B6B);
const _kBg = Color(0xFFF1F7F7);
const _kShadow1 = Color(0xFFDDD3D8);
const _kShadow2 = Color(0xFFD5E5E5);
const _kCardBg = Colors.white;
const _kAccent = Color(0xFFF7CBCA);

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
    if (_controller.text.trim().isEmpty || _isSending) return;

    setState(() => _isSending = true);

    final success = await HiraCommentService.addComment(
      widget.update.id,
      _controller.text,
    );

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
        color: _kCardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: _kShadow2.withOpacity(0.5)),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  '댓글',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _kText,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(
                    Icons.close,
                    size: 22,
                    color: _kText.withOpacity(0.5),
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
                      color: Color(0xFF7BA5A5),
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
                          color: _kShadow1,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '첫 댓글을 남겨보세요',
                          style: TextStyle(
                            fontSize: 14,
                            color: _kText.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: comments.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: _kShadow2.withOpacity(0.3),
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
            decoration: BoxDecoration(
              color: _kBg,
              border: Border(
                top: BorderSide(color: _kShadow2.withOpacity(0.5)),
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
                      color: _kCardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _kShadow2.withOpacity(0.5),
                      ),
                    ),
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      maxLength: 200,
                      style: const TextStyle(
                        fontSize: 14,
                        color: _kText,
                      ),
                      decoration: InputDecoration(
                        hintText: '댓글을 입력하세요...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: _kText.withOpacity(0.4),
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
                          ? _kShadow2
                          : _kAccent.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(
                      Icons.send,
                      size: 20,
                      color: _isSending
                          ? _kText.withOpacity(0.3)
                          : _kText.withOpacity(0.7),
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

/// 개별 댓글 아이템
class _CommentItem extends StatelessWidget {
  final HiraComment comment;
  final String updateId;

  const _CommentItem({
    required this.comment,
    required this.updateId,
  });

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
              style: TextStyle(color: Colors.red),
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
              color: _kAccent.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.person_outline,
              size: 18,
              color: _kText.withOpacity(0.5),
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
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _kText.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(comment.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: _kText.withOpacity(0.4),
                      ),
                    ),
                    const Spacer(),
                    if (isMyComment)
                      GestureDetector(
                        onTap: () => _deleteComment(context),
                        child: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: _kText.withOpacity(0.3),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  comment.text,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _kText,
                    height: 1.4,
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

