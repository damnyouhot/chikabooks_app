import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/report_service.dart';
import '../services/enthrone_service.dart';

// ── 디자인 팔레트 ──
const _kAccent = Color(0xFFF7CBCA);
const _kText = Color(0xFF5D6B6B);
const _kShadow2 = Color(0xFFD5E5E5);

/// "결을 같이하기" 게시물 카드
/// 수정/삭제/신고/추대 기능 포함
class BondPostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final String postId;
  final String? bondGroupId; // 추가: 파트너 그룹 ID

  const BondPostCard({
    super.key,
    required this.post,
    required this.postId,
    this.bondGroupId,
  });

  @override
  State<BondPostCard> createState() => _BondPostCardState();
}

class _BondPostCardState extends State<BondPostCard> {
  final _db = FirebaseFirestore.instance;
  String? _currentUid;
  bool _hasEnthroned = false;
  int _enthroneCount = 0;
  bool _loadingEnthrone = false;
  
  // 리플 관련
  Map<String, String> _replies = {}; // uid -> reply text
  
  // 이모지 리액션
  Map<String, String> _reactions = {}; // uid -> emoji

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid;
    _loadEnthroneStatus();
    _loadReplies();
    _loadReactions();
  }

  @override
  void dispose() {
    super.dispose();
  }

  bool get _isMyPost => widget.post['uid'] == _currentUid;

  // 리플 로드
  Future<void> _loadReplies() async {
    final groupId = widget.bondGroupId ?? widget.post['bondGroupId'];
    if (groupId == null) return;

    try {
      final snapshot = await _db
          .collection('bondGroups')
          .doc(groupId)
          .collection('posts')
          .doc(widget.postId)
          .collection('replies')
          .get();

      if (mounted) {
        setState(() {
          _replies = {
            for (var doc in snapshot.docs)
              doc.id: doc.data()['text'] as String? ?? ''
          };
        });
      }
    } catch (e) {
      debugPrint('⚠️ _loadReplies error: $e');
    }
  }

  // 이모지 리액션 로드
  Future<void> _loadReactions() async{
    final groupId = widget.bondGroupId ?? widget.post['bondGroupId'];
    if (groupId == null) return;

    try {
      final snapshot = await _db
          .collection('bondGroups')
          .doc(groupId)
          .collection('posts')
          .doc(widget.postId)
          .collection('reactions')
          .get();

      if (mounted) {
        setState(() {
          _reactions = {
            for (var doc in snapshot.docs)
              doc.id: doc.data()['emoji'] as String? ?? ''
          };
        });
      }
    } catch (e) {
      debugPrint('⚠️ _loadReactions error: $e');
    }
  }

  // 이모지 추가/변경
  Future<void> _toggleReaction(String emoji) async {
    final groupId = widget.bondGroupId ?? widget.post['bondGroupId'];
    if (groupId == null || _currentUid == null) return;

    try {
      // 같은 이모지면 삭제
      if (_reactions[_currentUid] == emoji) {
        await _db
            .collection('bondGroups')
            .doc(groupId)
            .collection('posts')
            .doc(widget.postId)
            .collection('reactions')
            .doc(_currentUid)
            .delete();

        if (mounted) {
          setState(() {
            _reactions.remove(_currentUid);
          });
        }
      } else {
        // 추가/변경
        await _db
            .collection('bondGroups')
            .doc(groupId)
            .collection('posts')
            .doc(widget.postId)
            .collection('reactions')
            .doc(_currentUid)
            .set({
          'emoji': emoji,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          setState(() {
            _reactions[_currentUid!] = emoji;
          });
        }
      }
    } catch (e) {
      debugPrint('⚠️ _toggleReaction error: $e');
    }
  }

  // 추대 상태 로드
  Future<void> _loadEnthroneStatus() async {
    // bondGroupId가 없으면 추대 기능 비활성화
    final groupId = widget.bondGroupId ?? widget.post['bondGroupId'];
    if (groupId == null) return;

    try {
      final hasEnthroned = await EnthroneService.hasEnthroned(
        bondGroupId: groupId,
        postId: widget.postId,
      );
      final count = await EnthroneService.getEnthroneCount(
        bondGroupId: groupId,
        postId: widget.postId,
      );

      if (mounted) {
        setState(() {
          _hasEnthroned = hasEnthroned;
          _enthroneCount = count;
        });
      }
    } catch (e) {
      debugPrint('⚠️ _loadEnthroneStatus error: $e');
    }
  }

  // 추대 토글
  Future<void> _toggleEnthrone() async {
    final groupId = widget.bondGroupId ?? widget.post['bondGroupId'];
    if (groupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('파트너 그룹에 가입해야 추대할 수 있어요.')),
      );
      return;
    }

    if (_loadingEnthrone) return;

    setState(() => _loadingEnthrone = true);

    try {
      bool success;
      if (_hasEnthroned) {
        success = await EnthroneService.unenthronePost(
          bondGroupId: groupId,
          postId: widget.postId,
        );
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('추대를 취소했어요.')),
          );
        }
      } else {
        success = await EnthroneService.enthronePost(
          bondGroupId: groupId,
          postId: widget.postId,
        );
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✨ 추대했어요!')),
          );
        } else if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이미 추대했어요.')),
          );
        }
      }

      if (success) {
        await _loadEnthroneStatus(); // 상태 새로고침
      }
    } finally {
      if (mounted) {
        setState(() => _loadingEnthrone = false);
      }
    }
  }

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
    
    // 작성자 정보
    final testAuthorName = widget.post['_testAuthorName'] as String?;
    final authorName = testAuthorName ?? '익명';

    return Container(
      padding: const EdgeInsets.all(12),  // 16 → 12
      margin: const EdgeInsets.only(bottom: 8),  // 12 → 8
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),  // 16 → 12
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),  // 0.1 → 0.08
            blurRadius: 6,  // 8 → 6
            offset: const Offset(0, 1),  // (0,2) → (0,1)
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더: 작성자 + 시간
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),  // (10,4) → (8,2)
                decoration: BoxDecoration(
                  color: _kShadow2.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),  // 12 → 10
                ),
                child: Text(
                  authorName,
                  style: const TextStyle(
                    fontSize: 11,  // 12 → 11
                    fontWeight: FontWeight.w600,
                    color: _kText,
                  ),
                ),
              ),
              const SizedBox(width: 6),  // 8 → 6
              Text(
                timeStr,
                style: TextStyle(fontSize: 10, color: Colors.grey[400]),  // 11 → 10
              ),
              if (updatedAt != null) ...[
                const SizedBox(width: 3),  // 4 → 3
                Text(
                  '(수정됨)',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),  // 11 → 10
                ),
              ],
            ],
          ),

          const SizedBox(height: 8),  // 12 → 8

          // 본문 (2줄 제한)
          Text(
            widget.post['text'] ?? '',
            maxLines: 2,  // 추가
            overflow: TextOverflow.ellipsis,  // 추가
            style: const TextStyle(
              fontSize: 14,  // 15 → 14
              height: 1.4,  // 1.5 → 1.4
              color: Color(0xFF333333),
            ),
          ),

          const SizedBox(height: 6),  // 12 → 6

          // 이모지 리액션 (간단하게)
          if (_reactions.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _reactions.entries.take(5).map((entry) {  // 최대 5개만
                  return Container(
                    margin: const EdgeInsets.only(right: 4),  // 간격 축소
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),  // (8,4) → (6,2)
                    decoration: BoxDecoration(
                      color: _kAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),  // 12 → 10
                    ),
                    child: Text(
                      entry.value,
                      style: const TextStyle(fontSize: 14),  // 16 → 14
                    ),
                  );
                }).toList(),
              ),
            ),

          if (_reactions.isNotEmpty) const SizedBox(height: 4),  // 8 → 4

          // 하단 액션 (간결하게)
          Row(
            children: [
              // 추대 버튼
              TextButton.icon(
                onPressed: _loadingEnthrone ? null : _toggleEnthrone,
                icon: Icon(
                  _hasEnthroned ? Icons.auto_awesome : Icons.auto_awesome_outlined,
                  size: 14,  // 16 → 14
                  color: _hasEnthroned ? const Color(0xFF6A5ACD) : Colors.grey[600],
                ),
                label: Text(
                  _enthroneCount > 0 ? '$_enthroneCount' : '추대합니다',  // '추대' → '추대합니다'
                  style: TextStyle(
                    fontSize: 11,  // 12 → 11
                    color: _hasEnthroned ? const Color(0xFF6A5ACD) : Colors.grey[600],
                    fontWeight: _hasEnthroned ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),  // (8,4) → (6,2)
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),

              // 리플 개수만 표시
              if (_replies.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '💬 ${_replies.length}',
                    style: TextStyle(
                      fontSize: 11,  // 작게
                      color: Colors.grey[600],
                    ),
                ),
                ),

              // 이모지 버튼 (아이콘만)
              TextButton(
                onPressed: _showEmojiPicker,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  '😊',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
              ),
              ),

              // 답글 버튼 추가
              TextButton(
                onPressed: _showReplyInput,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Icon(
                  Icons.comment_outlined,
                  size: 14,
                  color: Colors.grey[600],
                ),
              ),

              const Spacer(),

              if (_isMyPost) ...[
                IconButton(
                  onPressed: _showEditDialog,
                  icon: const Icon(Icons.edit, size: 14),  // 16 → 14
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: Colors.grey[600],
                ),
                IconButton(
                  onPressed: _confirmDelete,
                  icon: const Icon(Icons.delete, size: 14),  // 16 → 14
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: Colors.grey[600],
                ),
              ] else ...[
                IconButton(
                  onPressed: _showReportDialog,
                  icon: const Icon(Icons.report, size: 14),  // 16 → 14
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: Colors.grey[600],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // 이모지 선택 다이얼로그
  void _showEmojiPicker() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('이모지 선택', style: TextStyle(fontSize: 14)),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              '👍',
              '❤️',
              '😊',
              '💪',
              '🎉'
            ].map((emoji) {
              final isSelected = _reactions[_currentUid] == emoji;
              return GestureDetector(
                onTap: () {
                  _toggleReaction(emoji);
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _kAccent.withOpacity(0.4)
                        : Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // 답글 입력 다이얼로그
  void _showReplyInput() async {
    if (_currentUid == null) return;
    
    // 이미 답글을 달았는지 확인
    if (_replies.containsKey(_currentUid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 답글을 달았어요. (1인 1답글)')),
      );
      return;
    }

    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('답글 달기', style: TextStyle(fontSize: 14)),
          content: TextField(
            controller: controller,
            maxLength: 100,
            maxLines: 3,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '따뜻한 답글을 남겨보세요',
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
                    const SnackBar(content: Text('내용을 입력해주세요.')),
                  );
                  return;
                }
                await _saveReply(text);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('등록'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveReply(String text) async {
    final groupId = widget.bondGroupId ?? widget.post['bondGroupId'];
    if (groupId == null || _currentUid == null) return;

    try {
      await _db
          .collection('bondGroups')
          .doc(groupId)
          .collection('posts')
          .doc(widget.postId)
          .collection('replies')
          .doc(_currentUid)
          .set({
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _loadReplies();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('답글이 등록되었어요')),
        );
      }
    } catch (e) {
      debugPrint('⚠️ _saveReply error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('답글 등록에 실패했어요')),
        );
      }
    }
  }
}

