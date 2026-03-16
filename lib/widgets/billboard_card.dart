import 'package:flutter/material.dart';
import '../models/enthrone.dart';
import '../services/enthrone_service.dart';
import '../services/report_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';

/// 전광판 카드 위젯
class BillboardCard extends StatelessWidget {
  final BillboardPost post;
  final VoidCallback? onTap;

  const BillboardCard({super.key, required this.post, this.onTap});

  String _formatRemaining(DateTime expiresAt) {
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return '노출 종료';
    if (remaining.inHours >= 1) {
      return '${remaining.inHours}시간 ${remaining.inMinutes % 60}분 남음';
    }
    return '${remaining.inMinutes.clamp(0, 59)}분 남음';
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
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
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
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: _buildAuthorLabel(),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatRemaining(post.expiresAt),
                  style: const TextStyle(fontSize: 10, color: AppColors.textDisabled),
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
                  color: AppColors.textPrimary,
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
                    color: AppColors.textPrimary.withOpacity(0.3),
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
          color: AppColors.accent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
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
            color: AppColors.textPrimary,
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
            color: AppColors.textPrimary,
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
              color: AppColors.textPrimary,
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
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  // TODO: 전광판 전체 보기 페이지로 이동
                },
                child: Text(
                  '더보기',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.auto_awesome_outlined,
                        size: 48,
                        color: AppColors.textDisabled,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '아직 추대된 글이 없어요',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '좋은 글에 추대를 보내보세요',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
