import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// 반경 선택 칩 행 (지도 하단, 검색바 바로 위)
///
/// [반경] [3km] [5km] [10km] [20km]  ···  [목록]
/// 검색바 높이(패딩·큰 아이콘 기준 약 56px) + 칩행 간격 — [FloatingSearchBar]와 맞춤
/// 키보드 대응: viewInsets.bottom을 동일하게 반영
class RadiusChipRow extends StatelessWidget {
  final double selectedRadius;
  final Function(double) onRadiusChanged;

  /// 목록보기로 전환하는 콜백 (null이면 버튼 숨김)
  final VoidCallback? onListToggle;

  // 검색바 전체 높이 — [FloatingSearchBar] (패딩 10*2 + 행 높이) 와 동기화
  static const double _searchBarH = 56.0;
  static const double _bottomGap = AppSpacing.md + _searchBarH + 6;

  const RadiusChipRow({
    super.key,
    required this.selectedRadius,
    required this.onRadiusChanged,
    this.onListToggle,
  });

  @override
  Widget build(BuildContext context) {
    final keyboardH = MediaQuery.of(context).viewInsets.bottom;
    final bottomPos = keyboardH > 0
        ? keyboardH + AppSpacing.sm + _searchBarH + 6
        : _bottomGap;

    const radiusOptions = [3.0, 5.0, 10.0, 20.0];

    return Positioned(
      left: AppSpacing.md,
      right: AppSpacing.md,
      bottom: bottomPos,
      child: Row(
        children: [
          // ── 반경 칩들 (가로 스크롤) ──
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // "반경" 라벨 칩
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: const Text(
                      '반경',
                      style: TextStyle(
                        fontSize: 11,
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
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.segmentSelected
                                : AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            '${radius.toStringAsFixed(0)}km',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
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
          ),

          // ── 목록 버튼 (항상 우측 끝에 고정, accent 색상으로 눈에 띄게) ──
          if (onListToggle != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onListToggle,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.30),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.list_alt_rounded,
                      size: 14,
                      color: AppColors.onAccent,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '목록',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onAccent,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
