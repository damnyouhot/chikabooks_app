import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/hira_update.dart';
import '../services/hira_update_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/app_muted_card.dart';
import '../core/widgets/app_muted_button.dart';
import '../core/widgets/app_badge.dart';
import 'hira_comment_sheet.dart';
import 'hira_update_detail_sheet.dart';
import 'hira_web_view_sheet.dart';

/// HIRA 업데이트 카드
///
/// 디자인 원칙:
///   - boxShadow 없음 / Border 없음
///   - 배경: AppMutedCard (surfaceMuted)
///   - 텍스트: AppColors.textPrimary / textSecondary
///   - 버튼: AppMutedButton
///   - 배지: AppStatusBadge
class HiraUpdateCard extends StatelessWidget {
  final HiraUpdate update;

  const HiraUpdateCard({super.key, required this.update});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppMutedCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        onTap: () => _openDetail(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 상단: 배지 + 제목 + 날짜 ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppStatusBadge(
                  badgeLevel: update.getBadgeLevel(),
                  badgeText: update.getBadgeText(),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        update.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _formatDate(update.publishedAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // ── 업무 영향 체크 (actionHints) ──
            ...update.actionHints
                .take(3)
                .map(
                  (hint) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 14,
                          color: AppColors.textDisabled,
                        ),
                        const SizedBox(width: AppSpacing.sm - 2),
                        Expanded(
                          child: Text(
                            hint,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

            const SizedBox(height: AppSpacing.md),

            // ── 하단: 원문 보기 + 저장 + 댓글 버튼 ──
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: AppMutedButton(
                    onTap: () => _openWebView(context),
                    icon: Icons.open_in_new,
                    label: '원문 보기',
                    fontWeight: FontWeight.w700,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: _SaveButton(update: update)),
                const SizedBox(width: AppSpacing.sm),
                _CommentButton(
                  commentCount: update.commentCount,
                  onTap: () => _openCommentSheet(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HiraUpdateDetailSheet(update: update),
    );
  }

  void _openWebView(BuildContext context) {
    HiraWebViewSheet.show(context, url: update.link, title: update.title);
  }

  void _openCommentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => HiraCommentSheet(update: update),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return '오늘 ${DateFormat('HH:mm').format(date)}';
    if (diff.inDays == 1) return '어제 ${DateFormat('HH:mm').format(date)}';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return DateFormat('yyyy.MM.dd').format(date);
  }
}

// ── 저장 버튼 (StreamBuilder 분리) ──────────────────────────────
class _SaveButton extends StatelessWidget {
  final HiraUpdate update;
  const _SaveButton({required this.update});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: HiraUpdateService.watchSaved(update.id),
      builder: (context, snapshot) {
        final isSaved = snapshot.data ?? false;
        return AppMutedButton(
          onTap: () => _toggleSave(context, isSaved),
          icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
          label: isSaved ? '저장됨' : '저장',
          isActive: isSaved,
          fontWeight: FontWeight.w700,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        );
      },
    );
  }

  Future<void> _toggleSave(BuildContext context, bool currentlySaved) async {
    final success =
        currentlySaved
            ? await HiraUpdateService.unsaveUpdate(update.id)
            : await HiraUpdateService.saveUpdate(update);
    if (context.mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentlySaved ? '저장이 취소되었습니다' : '저장되었습니다'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }
}

// ── 댓글 버튼 ───────────────────────────────────────────────────
class _CommentButton extends StatelessWidget {
  final int commentCount;
  final VoidCallback onTap;
  const _CommentButton({required this.commentCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppMutedButton(
      onTap: onTap,
      icon: Icons.mode_comment_outlined,
      label: commentCount > 0 ? '$commentCount' : null,
      fontWeight: FontWeight.w700,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}
