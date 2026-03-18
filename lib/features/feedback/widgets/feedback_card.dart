import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../models/feedback_post.dart';

/// 피드백 목록 카드
class FeedbackCard extends StatelessWidget {
  final FeedbackPost post;
  final VoidCallback onTap;

  const FeedbackCard({super.key, required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 상단 메타 행 ──────────────────────────────────────
            Row(
              children: [
                _TypeBadge(post.type),
                const SizedBox(width: 6),
                _PriorityBadge(post.priority),
                const SizedBox(width: 6),
                if (post.visibility == FeedbackVisibility.private)
                  _PrivateBadge(),
                const Spacer(),
                _AdminStatusChip(post.adminStatus),
              ],
            ),
            const SizedBox(height: 10),

            // ── 본문 (전체 표시 — 트위터형) ────────────────────
            Text(
              post.text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),

            // ── 이미지 (있을 때만 — 전체 너비로 표시) ─────────
            if (post.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Column(
                  children: post.imageUrls
                      .map(
                        (url) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Image.network(
                            url,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 80,
                              color: AppColors.surfaceMuted,
                              child: const Icon(Icons.broken_image_outlined,
                                  size: 20, color: AppColors.textDisabled),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],

            // ── 하단 정보 행 ────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 13, color: AppColors.textDisabled),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    post.displayName.isNotEmpty
                        ? post.displayName
                        : post.authNickname.isNotEmpty
                            ? post.authNickname
                            : '익명',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textDisabled,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.location_on_outlined,
                    size: 13, color: AppColors.textDisabled),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    post.sourceScreenLabel.isNotEmpty
                        ? post.sourceScreenLabel
                        : post.sourceRoute,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textDisabled,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                if (post.commentCount > 0) ...[
                  const Icon(Icons.chat_bubble_outline,
                      size: 13, color: AppColors.textDisabled),
                  const SizedBox(width: 3),
                  Text(
                    '${post.commentCount}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textDisabled,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  _timeAgo(post.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textDisabled,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 30) return '${diff.inDays}일 전';
    return '${dt.month}/${dt.day}';
  }
}

// ── 뱃지 위젯들 ──────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final FeedbackType type;
  const _TypeBadge(this.type);

  @override
  Widget build(BuildContext context) {
    final isImprovement = type == FeedbackType.improvement;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isImprovement
            ? AppColors.accent.withOpacity(0.1)
            : AppColors.success.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isImprovement ? AppColors.accent : AppColors.success,
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final FeedbackPriority priority;
  const _PriorityBadge(this.priority);

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      FeedbackPriority.high => AppColors.error,
      FeedbackPriority.medium => AppColors.warning,
      FeedbackPriority.low => AppColors.textDisabled,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        priority.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _PrivateBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.textDisabled.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 10, color: AppColors.textDisabled),
          SizedBox(width: 2),
          Text(
            '비공개',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminStatusChip extends StatelessWidget {
  final FeedbackAdminStatus status;
  const _AdminStatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    if (status == FeedbackAdminStatus.pending) return const SizedBox.shrink();
    final color = status == FeedbackAdminStatus.done
        ? AppColors.success
        : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
