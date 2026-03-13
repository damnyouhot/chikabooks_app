import 'package:flutter/material.dart';
import '../../models/partner_group.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_muted_card.dart';

/// 파트너 시스템 상태별 엣지케이스 UI
class BondEmptyStateWidget extends StatelessWidget {
  final String state; // 'no_group', 'pause', 'expiring_soon'
  final VoidCallback? onAction;

  const BondEmptyStateWidget({super.key, required this.state, this.onAction});

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case 'no_group':      return _buildNoGroupState();
      case 'pause':         return _buildPauseState();
      case 'expiring_soon': return _buildExpiringSoonState();
      default:              return const SizedBox.shrink();
    }
  }

  Widget _buildNoGroupState() {
    return AppMutedCard(
      radius: AppRadius.xl,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withOpacity(0.10),
            ),
            child: const Icon(
              Icons.auto_stories_outlined,
              size: 40,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '조용한 페이지',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '이번 주는 아직 페이지가 열리지 않았어.\n월요일 오전 9시,\n새로운 동행이 자동으로 이어져.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_note, size: 16, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Text(
                  '파트너가 없어도 오늘을 남길 수 있어',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPauseState() {
    return AppMutedCard(
      radius: AppRadius.xl,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.warning.withOpacity(0.10),
            ),
            child: const Icon(
              Icons.pause_circle_outline,
              size: 40,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '지금은 쉬는 중',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '결 탭은 읽기만 가능해요\n언제든 다시 시작할 수 있어요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiringSoonState() {
    return AppMutedCard(
      radius: AppRadius.md,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          const Icon(Icons.access_time, size: 22, color: AppColors.warning),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '이번 주가 곧 끝나요',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '월요일 오전 9시에 새 파트너와 함께해요',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 파트너 그룹 상태 체크 헬퍼
class BondStateHelper {
  static bool isGroupActive(PartnerGroup? group) {
    if (group == null) return false;
    final now    = DateTime.now().toUtc();
    final endsAt = group.endsAt.toUtc();
    if (endsAt.isBefore(now)) return false;
    if (!group.isActiveGroup) return false;
    if (group.memberUids.isEmpty) return false;
    return true;
  }

  static bool isExpiringSoon(PartnerGroup? group) {
    if (group == null || !isGroupActive(group)) return false;
    final kst       = DateTime.now().toUtc().add(const Duration(hours: 9));
    final dayOfWeek = kst.weekday;
    final hour      = kst.hour;
    if (dayOfWeek == 7 && hour >= 18) return true;
    if (dayOfWeek == 1 && hour < 9) return true;
    return false;
  }

  static bool canSelectContinue(PartnerGroup? group) {
    if (group == null || !isGroupActive(group) || group.memberUids.length < 2) {
      return false;
    }
    return isExpiringSoon(group);
  }

  static bool isPaused(String partnerStatus) => partnerStatus == 'pause';

  static String getGroupStateString(PartnerGroup? group, String partnerStatus) {
    if (isPaused(partnerStatus)) return 'pause';
    if (group == null || !isGroupActive(group)) return 'no_group';
    if (isExpiringSoon(group)) return 'expiring_soon';
    return 'active';
  }

  static bool hasActivePartner(PartnerGroup? group, String partnerStatus) {
    final state = getGroupStateString(group, partnerStatus);
    return state == 'active' || state == 'expiring_soon';
  }
}
