import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/report_service.dart';

/// "결을 같이하기" 게시물 카드
/// 수정/삭제/신고 기능 포함
class BondPostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final String postId;

  const BondPostCard({
    super.key,
    required this.post,
    required this.postId,
  });

  @override
  State<BondPostCard> createState() => _BondPostCardState();
}

class _BondPostCardState extends State<BondPostCard> {
  final _db = FirebaseFirestore.instance;
  String? _currentUid;

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid;
  }

  bool get _isMyPost => widget.post['uid'] == _currentUid;

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('신고하기'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ReportReason.values.map((reason) {
              return ListTile(
                title: Text(reason.displayName),
                onTap: () async {
                  Navigator.pop(context);
                  
                  final success = await ReportService.reportPost(
                    collection: 'bondPosts',
                    postId: widget.postId,
                    reason: reason,
                  );
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success 
                              ? '신고가 접수되었습니다.' 
                              : '이미 신고한 게시물입니다.',
                        ),
                      ),
                    );
                  }
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
          ],
        );
      },
    );
  }

  void _showEditDialog() {
    final controller = TextEditingController(text: widget.post['text']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('수정하기'),
          content: TextField(
            controller: controller,
            maxLength: 200,
            maxLines: 5,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('내용을 입력해 주세요.')),
                  );
                  return;
                }
                await _db.collection('bondPosts').doc(widget.postId).update({
                  'text': text,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('수정되었습니다.')),
                  );
                }
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('삭제하기'),
          content: const Text('정말 삭제하시겠어요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                await _db.collection('bondPosts').doc(widget.postId).delete();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('삭제되었습니다.')),
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = (timestamp as Timestamp).toDate();
      final now = DateTime.now();
      final diff = now.difference(dt);
      
      if (diff.inMinutes < 1) return '방금 전';
      if (diff.inHours < 1) return '${diff.inMinutes}분 전';
      if (diff.inDays < 1) return '${diff.inHours}시간 전';
      if (diff.inDays < 7) return '${diff.inDays}일 전';
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final updatedAt = widget.post['updatedAt'];
    final createdAt = widget.post['createdAt'];
    final timeStr = _formatTimestamp(updatedAt ?? createdAt);

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 본문
          Text(
            widget.post['text'] ?? '',
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Color(0xFF333333),
            ),
          ),

          const SizedBox(height: 12),

          // 하단 액션
          Row(
            children: [
              if (updatedAt != null)
                Text(
                  '(수정됨)',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              const SizedBox(width: 4),
              Text(
                timeStr,
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
              const Spacer(),

              if (_isMyPost) ...[
                TextButton.icon(
                  onPressed: _showEditDialog,
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('수정', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                TextButton.icon(
                  onPressed: _confirmDelete,
                  icon: const Icon(Icons.delete, size: 14),
                  label: const Text('삭제', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ] else ...[
                TextButton.icon(
                  onPressed: _showReportDialog,
                  icon: const Icon(Icons.report, size: 14),
                  label: const Text('신고', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

