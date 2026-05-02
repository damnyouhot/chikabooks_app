import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/hira_update.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/app_muted_card.dart';
import '../core/widgets/app_badge.dart';
import '../core/widgets/app_modal_scaffold.dart';
import 'hira_update_detail_sheet.dart';

/// HIRA 업데이트 간단 리스트 아이템 (4번째 이후)
///
/// 디자인 원칙:
///   - boxShadow 없음 / Border 없음
///   - 배경: AppMutedCard (surfaceMuted)
///   - 텍스트: AppColors.textPrimary / textDisabled
///   - 배지: AppStatusBadge
class HiraUpdateCompactItem extends StatelessWidget {
  final HiraUpdate update;

  const HiraUpdateCompactItem({super.key, required this.update});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppMutedCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg - 2,
          vertical: AppSpacing.sm + 2,
        ),
        onTap: () => _showDetail(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 배지
            AppStatusBadge(
              badgeLevel: update.getBadgeLevel(),
              badgeText: update.getBadgeText(),
            ),
            const SizedBox(width: AppSpacing.sm + 2),

            // 제목
            Expanded(
              child: Text(
                update.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 2),

            // 날짜
            Text(
              _formatDate(update.publishedAt),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textDisabled,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),

            // 화살표
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: AppColors.textDisabled,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) => DateFormat('MM.dd').format(date);

  void _showDetail(BuildContext context) {
    showAppModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => HiraUpdateDetailSheet(update: update),
    );
  }
}
