import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_muted_card.dart';

/// 상태 안내 배너
class BondStateBanner extends StatelessWidget {
  final String state;
  final int memberCount;

  const BondStateBanner({
    super.key,
    required this.state,
    this.memberCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (state == 'active' && memberCount != 2) return const SizedBox.shrink();

    return AppMutedCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getIconBgColor(),
            ),
            child: Icon(_getIcon(), size: 20, color: _getIconColor()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getTitle(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                if (_getSubtitle().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _getSubtitle(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getIconBgColor() {
    switch (state) {
      case 'pause':         return AppColors.warning.withOpacity(0.10);
      case 'expiring_soon': return AppColors.warning.withOpacity(0.10);
      case 'two_person':    return AppColors.accent.withOpacity(0.12);
      default:              return AppColors.accent.withOpacity(0.10); // no_group
    }
  }

  Color _getIconColor() {
    switch (state) {
      case 'pause':         return AppColors.warning;
      case 'expiring_soon': return AppColors.warning;
      case 'two_person':    return AppColors.textPrimary;
      default:              return AppColors.accent;
    }
  }

  IconData _getIcon() {
    switch (state) {
      case 'no_group':      return Icons.auto_stories_outlined;
      case 'pause':         return Icons.pause_circle_outline;
      case 'expiring_soon': return Icons.access_time;
      case 'two_person':    return Icons.people;
      default:              return Icons.info_outline;
    }
  }

  String _getTitle() {
    switch (state) {
      case 'no_group':      return '이번 주는 조용한 페이지야';
      case 'pause':         return '지금은 쉬는 중이야';
      case 'expiring_soon': return '이번 주가 곧 끝나';
      case 'two_person':    return '이번 주는 두 사람의 페이지야';
      default:              return '';
    }
  }

  String _getSubtitle() {
    switch (state) {
      case 'no_group':      return '월요일 오전 9시, 새로운 동행이 자동으로 이어져';
      case 'pause':         return '언제든 다시 시작할 수 있어';
      case 'expiring_soon': return '월요일 오전 9시에 새 파트너와 함께해';
      case 'two_person':    return '가끔은 조용한 주도 좋지';
      default:              return '';
    }
  }
}
