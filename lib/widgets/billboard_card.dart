import 'package:flutter/material.dart';
import '../models/enthrone.dart';
import '../services/enthrone_service.dart';
import '../services/report_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── 디자인 팔레트 (bond_page와 통일) ──
const _kText = Color(0xFF5D6B6B);
const _kShadow2 = Color(0xFFD5E5E5);
const _kCardBg = Colors.white;
const _kAccent = Color(0xFFF7CBCA); // 털어놔 카드와 동일

/// 전광판 카드 위젯
class BillboardCard extends StatelessWidget {
  final BillboardPost post;
  final VoidCallback? onTap;

  const BillboardCard({super.key, required this.post, this.onTap});

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return '${diff.inDays}일 전';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}시간 전';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}분 전';
    } else {
      return '방금';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // "털어놔" 카드(BondPostCard)와 동일한 체감 사이즈
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // 헤더: 작성자 + 작성일 (익명 금지)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _kShadow2.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _buildAuthorLabel(),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDate(post.createdAt),
                  style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 본문 (고정 높이 2줄)
            SizedBox(
              height: 40,
              child: Text(
                post.textSnapshot,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Color(0xFF333333),
                ),
              ),
            ),

            const SizedBox(height: 6),

            // 이모지 반응 + 신고 아이콘
            Row(
              children: [
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _buildReactionChip(
                      context,
                      '👏',
                      post.reactions?['👏'] ?? 0,
                    ),
                    _buildReactionChip(
                      context,
                      '❤️',
                      post.reactions?['❤️'] ?? 0,
                    ),
                    _buildReactionChip(
                      context,
                      '🔥',
                      post.reactions?['🔥'] ?? 0,
                    ),
                    _buildReactionChip(
                      context,
                      '😢',
                      post.reactions?['😢'] ?? 0,
                    ),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    _showReportDialog(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.report_outlined,
                      size: 18,
                      color: _kText.withOpacity(0.3),
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

  Widget _buildReactionChip(BuildContext context, String emoji, int count) {
    // pill 배경/테두리 없이: 이모지 + 카운트만 표시
    final label = count > 0 ? '$emoji$count' : emoji; // 눌린 횟수는 이모지에 붙여 표시

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final ok = await EnthroneService.toggleBillboardReaction(
          billboardPostId: post.id,
          emoji: emoji,
        );
        if (!context.mounted) return;
        if (!ok) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('반응을 저장하지 못했어요.')));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: _kAccent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: _kText,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  Widget _buildAuthorLabel() {
    // 1) billboardPosts에 닉네임 스냅샷이 있으면 그걸 우선 표시
    final snapName = post.authorNickname;
    if (snapName != null && snapName.isNotEmpty) {
      return Text(
        snapName,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _kText,
        ),
      );
    }

    // 2) 없으면 authorId(uid)로 users/{uid}.nickname 조회 (기존 글 호환)
    final authorUid = post.authorId;
    if (authorUid == null || authorUid.isEmpty) {
      return const Text(
        '치과인',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _kText,
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance
              .collection('publicProfiles')
              .doc(authorUid)
              .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final nickname = (data?['nickname'] as String?)?.trim();
        final label =
            (nickname != null && nickname.isNotEmpty) ? nickname : authorUid;
        return Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _kText,
          ),
        );
      },
    );
  }

  Future<void> _showReportDialog(BuildContext context) async {
    final reason = await showDialog<ReportReason>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('신고하기'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children:
                ReportReason.values.map((r) {
                  return ListTile(
                    title: Text(r.displayName),
                    onTap: () => Navigator.of(ctx).pop(r),
                  );
                }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소'),
            ),
          ],
        );
      },
    );

    if (reason == null) return;

    final ok = await ReportService.reportPost(
      documentPath: 'billboardPosts/${post.id}',
      reason: reason,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '신고가 접수되었습니다.' : '이미 신고한 게시물입니다.')),
    );
  }
}

/// 전광판 섹션 위젯 (Bond 페이지에 삽입)
class BillboardSection extends StatelessWidget {
  const BillboardSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 섹션 헤더
          Row(
            children: [
              const Text(
                '🎯 전광판',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5D6B6B),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  // TODO: 전광판 전체 보기 페이지로 이동
                },
                child: Text(
                  '더보기',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 전광판 카드 (StreamBuilder로 실시간 데이터)
          StreamBuilder<List<BillboardPost>>(
            stream: EnthroneService.watchActiveBillboard(limit: 3),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final posts = snapshot.data ?? [];

              if (posts.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.auto_awesome_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '아직 추대된 글이 없어요',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '좋은 글에 추대를 보내보세요',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children:
                    posts.map((post) {
                      return BillboardCard(
                        post: post,
                        onTap: () {
                          // TODO: 상세 보기
                        },
                      );
                    }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
