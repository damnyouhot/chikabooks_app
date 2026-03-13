import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_muted_card.dart';

/// 지도에 마커가 없을 때 표시되는 안내 카드
///
/// 원칙: Shadow 없음 / Border 없음 → AppMutedCard
class MapEmptyStateCard extends StatelessWidget {
  final VoidCallback onExpandRadius;
  final VoidCallback onEnableNotification;
  final VoidCallback onCreateJob;

  const MapEmptyStateCard({
    super.key,
    required this.onExpandRadius,
    required this.onEnableNotification,
    required this.onCreateJob,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: AppMutedCard(
          radius: AppRadius.xl + 4,
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 아이콘 원형 배지
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.disabledBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_off_outlined,
                  size: 28,
                  color: AppColors.textDisabled,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 제목
              const Text(
                '근처에 공고가 아직 없어요',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),

              // 서브 텍스트
              Text(
                '반경을 넓히거나 알림을 켜두면\n바로 알려드릴게요',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),

              // 버튼들
              Column(
                children: [
                  // 1. 반경 확장 — 주요 액션 → accent (Blue)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onExpandRadius,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onAccent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      icon: const Icon(Icons.zoom_out_map, size: 18),
                      label: const Text(
                        '반경 10km로 보기',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // 2. 알림 켜기 — 보조 액션 → surfaceMuted (Border 없음)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onEnableNotification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceMuted,
                        foregroundColor: AppColors.textSecondary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      icon: const Icon(
                        Icons.notifications_outlined,
                        size: 18,
                      ),
                      label: const Text(
                        '주변 구인 알림 켜기',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // 3. 공고 등록 — 텍스트 버튼
                  TextButton.icon(
                    onPressed: onCreateJob,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                  ),
                    icon: const Icon(Icons.add_circle_outline, size: 16),
                    label: const Text(
                      '공고 등록하기',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
