import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_muted_card.dart';

/// 도전하기 탭 메인 타이틀 카드
///
/// 내 주변 구인 현황을 한눈에 보여주는 대시보드 카드
/// 원칙: Shadow 없음 / Border 없음 → AppMutedCard
class MainTitleCard extends StatelessWidget {
  final int nearbyJobCount;
  final double currentRadius;
  final int newJobsCount;
  final bool notificationEnabled;
  final int watchedClinicsCount;
  final int weeklyJobPoints;
  final VoidCallback onRadiusChange;
  final Function(bool) onNotificationToggle;
  final VoidCallback onWatchedClinicsPressed;

  const MainTitleCard({
    super.key,
    required this.nearbyJobCount,
    required this.currentRadius,
    required this.newJobsCount,
    required this.notificationEnabled,
    required this.watchedClinicsCount,
    this.weeklyJobPoints = 0,
    required this.onRadiusChange,
    required this.onNotificationToggle,
    required this.onWatchedClinicsPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: AppMutedCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 타이틀
            const Text(
              '내 주변 치과 구인 현황',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 1행: 반경 + 공고 수
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '반경 ${currentRadius.toStringAsFixed(0)}km',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  '· $nearbyJobCount건',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onRadiusChange,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppColors.accent,
                  ),
                  child: const Text(
                    '반경 변경',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // 2행: 신규 공고
            if (newJobsCount > 0) ...[
              Row(
                children: [
                  Icon(
                    Icons.fiber_new,
                    size: 16,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '새 공고 ${newJobsCount}건',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '(24시간)',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textDisabled,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ] else
              const SizedBox(height: AppSpacing.xs),

            Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: AppSpacing.md),

            // 3행: 알림 토글 + 관심 치과
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_outlined,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '주변 구인 알림',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Transform.scale(
                        scale: 0.8,
                        // Switch activeColor → accent (Blue)
                        child: Switch(
                          value: notificationEnabled,
                          onChanged: onNotificationToggle,
                          activeColor: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: onWatchedClinicsPressed,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite_border,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '관심 치과 $watchedClinicsCount',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 14,
                          color: AppColors.textDisabled,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // 이번 주 구직 활동 포인트
            if (weeklyJobPoints > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_outline,
                      size: 12,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '이번 주 구직 활동으로 +${weeklyJobPoints.toStringAsFixed(1)}P 적립',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
