import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme/app_colors.dart';
import '../models/reaction_kind.dart';
import '../services/report_service.dart';
import '../services/enthrone_service.dart';

/// "결을 같이하기" 게시물 카드
/// 수정/삭제/신고/추대 기능 포함
class BondPostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final String postId;
  final String? bondGroupId; // 추가: 파트너 그룹 ID
  final Map<String, String>? memberNicknames; // uid -> nickname (파트너 그룹)

  const BondPostCard({
    super.key,
    required this.post,
    required this.postId,
    this.bondGroupId,
    this.memberNicknames,
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
  Map<String, Map<String, dynamic>> _replies = {}; // uid -> {text, createdAt}
  bool _showingReplies = false; // 댓글 드롭다운 표시 여부

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
      final snapshot =
          await _db
              .collection('partnerGroups')
              .doc(groupId)
              .collection('posts')
              .doc(widget.postId)
              .collection('replies')
              .get();

      if (mounted) {
        setState(() {
          _replies = {
            for (var doc in snapshot.docs)
              doc.id: {
                'text': doc.data()['text'] as String? ?? '',
                'createdAt': doc.data()['createdAt'] as Timestamp?,
              },
          };
        });
      }
    } catch (e) {
      debugPrint('⚠️ _loadReplies error: $e');
    }
  }

  // 이모지 리액션 로드
  Future<void> _loadReactions() async {
    final groupId = widget.bondGroupId ?? widget.post['bondGroupId'];
    if (groupId == null) return;

    try {
      final snapshot =
          await _db
              .collection('partnerGroups')
              .doc(groupId)
              .collection('posts')
              .doc(widget.postId)
              .collection('reactions')
              .get();

      if (mounted) {
        setState(() {
          _reactions = {
            for (var doc in snapshot.docs)
              doc.id: doc.data()['emoji'] as String? ?? '',
          };
        });
      }
    } catch (e) {
      debugPrint('⚠️ _loadReactions error: $e');
    }
  }

  // 이모지 추가/변경
  Future<void> _toggleReaction(String emoji) async {
    final groupId = widget.bondGroupId ?? widget.post['bondGroupId'] as String?;
    final authorUid = widget.post['uid'] as String?;
    if (groupId == null || _currentUid == null || authorUid == null) return;
    if (authorUid == _currentUid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('자기 글은 리액션을 줄 수 없어요')));
      return;
    }

    final reactionRef = _db
        .collection('partnerGroups')
        .doc(groupId)
        .collection('posts')
        .doc(widget.postId)
        .collection('reactions')
        .doc(_currentUid);

    try {
      final existing = await reactionRef.get();
      final existingEmoji = existing.data()?['reactionKey'] as String?;
      final lastScoredAt =
          (existing.data()?['lastScoredAt'] as Timestamp?)?.toDate();
      final now = DateTime.now();
      final hasScoredToday =
          lastScoredAt != null &&
          now.difference(lastScoredAt) < const Duration(days: 1);

      if (existingEmoji == emoji) {
        await reactionRef.delete();
        if (mounted) {
          setState(() => _reactions.remove(_currentUid));
        }
        return;
      }

      final kind = reactionKindFromEmoji(emoji);
      if (kind == null) return; // null 체크
      final shouldScore = !hasScoredToday && kind.isScoring;

      await reactionRef.set({
        'reactionKey': emoji,
        'emoji': emoji,
        'kind': kind.name,
        'updatedAt': FieldValue.serverTimestamp(),
        if (shouldScore) 'lastScoredAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() => _reactions[_currentUid!] = emoji);
      }

      if (shouldScore) {
        await _tryGrantHeartBonus(groupId, authorUid, kind);
        // BondScoreService 메서드가 없으므로 주석 처리
        // await BondScoreService.applyReactionScore(
        //   targetUid: authorUid,
        //   kind: kind,
        //   extraBonus: heartBonus,
        // );
      }
    } catch (e) {
      debugPrint('⚠️ _toggleReaction error: $e');
    }
  }

  Future<double> _tryGrantHeartBonus(
    String groupId,
    String authorUid,
    ReactionKind kind,
  ) async {
    if (kind != ReactionKind.heart) return 0.0;
    final postRef = _db
        .collection('partnerGroups')
        .doc(groupId)
        .collection('posts')
        .doc(widget.postId);

    final postSnap = await postRef.get();
    final alreadyBonus =
        postSnap.data()?['heartBonusApplied'] as bool? ?? false;
    if (alreadyBonus) return 0.0;

    final hearts =
        await postRef
            .collection('reactions')
            .where('kind', isEqualTo: ReactionKind.heart.name)
            .get();

    if (hearts.docs.length >= 5) {
      await postRef.set({'heartBonusApplied': true}, SetOptions(merge: true));
      return 0.1;
    }
    return 0.0;
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('파트너 그룹에 가입해야 추대할 수 있어요.')));
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('추대를 취소했어요.')));
        }
      } else {
        success = await EnthroneService.enthronePost(
          bondGroupId: groupId,
          postId: widget.postId,
        );
        if (success && mounted) {
          if (_isMyPost) {
            // 작성자 본인이 추대한 경우 전국구 게시판 등록 안내
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('나머지 멤버들도 모두 추대하면 전국구 게시판에 등록돼요!'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 4),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✨ 추대했어요!')),
            );
          }
          final groupId =
              widget.bondGroupId ?? widget.post['bondGroupId'] as String?;
          final authorUid = widget.post['uid'] as String?;
          if (groupId != null && authorUid != null) {
            await _applyEnthroneScore(groupId, authorUid);
          }
        } else if (!success && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('이미 추대했어요.')));
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
            children:
                ReportReason.values.map((reason) {
                  return ListTile(
                    title: Text(reason.displayName),
                    onTap: () async {
                      Navigator.pop(context);

                      final groupId =
                          widget.bondGroupId ?? widget.post['bondGroupId'];
                      final collectionPath =
                          groupId == null
                              ? 'bondPosts'
                              : 'partnerGroups/$groupId/posts';

                      final success = await ReportService.reportPost(
                        documentPath: '$collectionPath/${widget.postId}',
                        reason: reason,
                      );

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success ? '신고가 접수되었습니다.' : '이미 신고한 게시물입니다.',
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

  Future<void> _applyEnthroneScore(String groupId, String authorUid) async {
    final postRef = _db
        .collection('partnerGroups')
        .doc(groupId)
        .collection('posts')
        .doc(widget.postId);
    final postSnap = await postRef.get();
    final alreadyBonus =
        postSnap.data()?['enthroneBonusApplied'] as bool? ?? false;
    final count = await EnthroneService.getEnthroneCount(
      bondGroupId: groupId,
      postId: widget.postId,
    );
    if (count >= 3 && !alreadyBonus) {
      await postRef.set({
        'enthroneBonusApplied': true,
      }, SetOptions(merge: true));
    }

    // BondScoreService 메서드가 없으므로 주석 처리
    // await BondScoreService.applyReactionScore(
    //   targetUid: authorUid,
    //   kind: ReactionKind.enthrone,
    //   extraBonus: extraBonus,
    // );
  }

  void _showEditDialog() {
    final groupId = widget.bondGroupId ?? widget.post['bondGroupId'] as String?;
    if (groupId == null) return; // groupId 없으면 수정 불가
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
            decoration: const InputDecoration(border: OutlineInputBorder()),
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
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('내용을 입력해 주세요.')));
                  return;
                }
                await _db
                    .collection('partnerGroups')
                    .doc(groupId)
                    .collection('posts')
                    .doc(widget.postId)
                    .update({
                  'text': text,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('수정되었습니다.')));
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
    final groupId = widget.bondGroupId ?? widget.post['bondGroupId'] as String?;
    if (groupId == null) return; // groupId 없으면 삭제 불가
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
                await _db
                    .collection('partnerGroups')
                    .doc(groupId)
                    .collection('posts')
                    .doc(widget.postId)
                    .delete();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('삭제되었습니다.')));
                }
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final updatedAt = widget.post['updatedAt'];
    final createdAt = widget.post['createdAt'];
    final createdAtClient = widget.post['createdAtClient'];
    final createdAtClientDt =
        (createdAtClient is Timestamp) ? createdAtClient.toDate() : null;
    final baseCreated =
        createdAtClientDt ??
        ((createdAt is Timestamp) ? createdAt.toDate() : DateTime.now());
    final expiresAt = baseCreated.add(const Duration(hours: 6));
    final remaining = expiresAt.difference(DateTime.now());
    final remainingStr =
        remaining.isNegative
            ? '노출 종료'
            : (remaining.inHours >= 1
                ? '${remaining.inHours}시간 ${(remaining.inMinutes % 60)}분 남음'
                : '${remaining.inMinutes.clamp(0, 59)}분 남음');

    // 작성자 정보 (익명 금지)
    final snapAuthorNickname =
        (widget.post['authorNickname'] as String?)?.trim();
    final authorUid = (widget.post['uid'] as String?)?.trim();
    final mapNickname =
        (authorUid != null &&
                authorUid.isNotEmpty &&
                widget.memberNicknames != null)
            ? widget.memberNicknames![authorUid]?.trim()
            : null;

    final testAuthorName = (widget.post['_testAuthorName'] as String?)?.trim();

    final authorName =
        (snapAuthorNickname != null && snapAuthorNickname.isNotEmpty)
            ? snapAuthorNickname
            : ((mapNickname != null && mapNickname.isNotEmpty)
                ? mapNickname
                : ((testAuthorName != null && testAuthorName.isNotEmpty)
                    ? testAuthorName
                    : ((authorUid != null && authorUid.isNotEmpty)
                        ? authorUid
                        : '치과인')));

    return Container(
      padding: const EdgeInsets.all(12), // 16 → 12
      margin: const EdgeInsets.only(bottom: 8), // 12 → 8
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12), // 16 → 12
        boxShadow: [
          BoxShadow(
            color: AppColors.textDisabled.withOpacity(0.08), // 0.1 → 0.08
            blurRadius: 6, // 8 → 6
            offset: const Offset(0, 1), // (0,2) → (0,1)
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ), // (10,4) → (8,2)
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10), // 12 → 10
                ),
                child: Text(
                  authorName,
                  style: const TextStyle(
                    fontSize: 11, // 12 → 11
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6), // 8 → 6
              Text(
                remainingStr,
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textDisabled,
                ), // 11 → 10
              ),
              if (updatedAt != null) ...[
                const SizedBox(width: 3), // 4 → 3
                Text(
                  '(수정됨)',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ), // 11 → 10
                ),
              ],
            ],
          ),

          const SizedBox(height: 8), // 12 → 8
          // 본문 (2줄 제한)
          Text(
            widget.post['text'] ?? '',
            maxLines: 2, // 추가
            overflow: TextOverflow.ellipsis, // 추가
            style: const TextStyle(
              fontSize: 14, // 15 → 14
              height: 1.4, // 1.5 → 1.4
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 6), // 12 → 6
          // 이모지 리액션 (간단하게)
          if (_reactions.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    _reactions.entries.take(5).map((entry) {
                      // 최대 5개만
                      return Container(
                        margin: const EdgeInsets.only(right: 4), // 간격 축소
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ), // (8,4) → (6,2)
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10), // 12 → 10
                        ),
                        child: Text(
                          entry.value,
                          style: const TextStyle(fontSize: 14), // 16 → 14
                        ),
                      );
                    }).toList(),
              ),
            ),

          if (_reactions.isNotEmpty) const SizedBox(height: 4), // 8 → 4
          // 하단 액션 (간결하게)
          Row(
            children: [
              // 추대 버튼
              TextButton.icon(
                onPressed: _loadingEnthrone ? null : _toggleEnthrone,
                icon: Icon(
                  _hasEnthroned
                      ? Icons.auto_awesome
                      : Icons.auto_awesome_outlined,
                  size: 14, // 16 → 14
                  color:
                      _hasEnthroned
                          ? AppColors.accent
                          : AppColors.textSecondary,
                ),
                label: Text(
                  _enthroneCount > 0
                      ? '$_enthroneCount'
                      : '추대합니다', // '추대' → '추대합니다'
                  style: TextStyle(
                    fontSize: 11, // 12 → 11
                    color:
                        _hasEnthroned
                            ? AppColors.accent
                            : AppColors.textSecondary,
                    fontWeight:
                        _hasEnthroned ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ), // (8,4) → (6,2)
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),

              // 리플 개수 (탭하면 댓글 인라인 드롭다운)
              if (_replies.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _showingReplies = !_showingReplies),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '💬 ${_replies.length}',
                          style: TextStyle(
                            fontSize: 11,
                            color: _showingReplies ? AppColors.accent : AppColors.textSecondary,
                          ),
                        ),
                        Icon(
                          _showingReplies ? Icons.expand_less : Icons.expand_more,
                          size: 14,
                          color: _showingReplies ? AppColors.accent : AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),

              // 이모지 버튼 (아이콘만) - 자신의 글에는 표시하지 않음
              if (!_isMyPost)
                TextButton(
                  onPressed: _showEmojiPicker,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    '😊',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ),

              // 답글 버튼 추가
              TextButton(
                onPressed: _showReplyInput,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Icon(
                  Icons.comment_outlined,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
              ),

              const Spacer(),

              if (_isMyPost) ...[
                  IconButton(
                  onPressed: _showEditDialog,
                  icon: const Icon(Icons.edit, size: 14), // 16 → 14
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: AppColors.textSecondary,
                ),
                IconButton(
                  onPressed: _confirmDelete,
                  icon: const Icon(Icons.delete, size: 14), // 16 → 14
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: AppColors.textSecondary,
                ),
              ] else ...[
                // 전국구 게시판과 동일한 모양/크기/위치
                GestureDetector(
                  onTap: _showReportDialog,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.report_outlined,
                      size: 18,
                      color: AppColors.textPrimary.withOpacity(0.3),
                    ),
                  ),
                ),
              ],
            ],
          ),

          // 댓글 인라인 드롭다운
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _showingReplies && _replies.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _replies.entries.map((entry) {
                          final uid = entry.key;
                          final text = entry.value['text'] as String? ?? '';
                          final createdAt = entry.value['createdAt'] as Timestamp?;
                          final nickname = widget.memberNicknames?[uid] ?? '파트너';
                          final isMe = uid == _currentUid;
                          return _buildReplyItem(nickname, text, createdAt, isMe);
                        }).toList(),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
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
            children:
                ['👍', '❤️', '😊', '💪', '🎉'].map((emoji) {
                  final isSelected = _reactions[_currentUid] == emoji;
                  return GestureDetector(
                    onTap: () {
                      _toggleReaction(emoji);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? AppColors.accent.withOpacity(0.3)
                                : AppColors.surfaceMuted,
                        shape: BoxShape.circle,
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  );
                }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildReplyItem(String nickname, String text, Timestamp? createdAt, bool isMe) {
    String timeStr = '';
    if (createdAt != null) {
      final dt = createdAt.toDate();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) {
        timeStr = '방금';
      } else if (diff.inHours < 1) {
        timeStr = '${diff.inMinutes}분 전';
      } else if (diff.inDays < 1) {
        timeStr = '${diff.inHours}시간 전';
      } else {
        timeStr = '${diff.inDays}일 전';
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isMe ? '$nickname (나)' : nickname,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isMe ? AppColors.accent : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              if (timeStr.isNotEmpty)
                Text(
                  timeStr,
                  style: const TextStyle(fontSize: 10, color: AppColors.textDisabled),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // 답글 입력 다이얼로그
  void _showReplyInput() async {
    if (_currentUid == null) return;

    // 이미 답글을 달았는지 확인
    if (_replies.containsKey(_currentUid)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이미 답글을 달았어요. (1인 1답글)')));
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
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('내용을 입력해주세요.')));
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
          .collection('partnerGroups')
          .doc(groupId)
          .collection('posts')
          .doc(widget.postId)
          .collection('replies')
          .doc(_currentUid)
          .set({'text': text, 'createdAt': FieldValue.serverTimestamp()});

      await _loadReplies();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('답글이 등록되었어요')));
      }
    } catch (e) {
      debugPrint('⚠️ _saveReply error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('답글 등록에 실패했어요')));
      }
    }
  }
}
