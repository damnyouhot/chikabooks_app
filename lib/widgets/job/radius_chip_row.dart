import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// 반경 선택 칩 행 (지도 전용)
///
/// [1km] [3km] [5km] [10km]
/// 원칙: Shadow 없음 / Border 없음
/// 선택 칩 → segmentSelected(Blue), 미선택 → surfaceMuted
class RadiusChipRow extends StatelessWidget {
  final double selectedRadius;
  final Function(double) onRadiusChanged;

  const RadiusChipRow({
    super.key,
    required this.selectedRadius,
    required this.onRadiusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final radiusOptions = [1.0, 3.0, 5.0, 10.0];

    return Positioned(
      top: 140,
      left: AppSpacing.md,
      right: AppSpacing.md,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // "반경" 라벨 칩
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: const Text(
                '반경',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),

            // 반경 칩들
            ...radiusOptions.map((radius) {
              final isSelected = selectedRadius == radius;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: GestureDetector(
                  onTap: () => onRadiusChanged(radius),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      // 선택 → Blue / 미선택 → surfaceMuted (Border 없음)
                      color: isSelected
                          ? AppColors.segmentSelected
                          : AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      '${radius.toStringAsFixed(0)}km',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? AppColors.onSegmentSelected
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
