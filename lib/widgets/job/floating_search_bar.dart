import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// 지도 위에 떠있는 검색바
///
/// 검색창 + 필터 버튼 + 필터 요약
/// 원칙: Shadow 없음 / Border 없음
/// - 배경: AppColors.white (지도 위 플로팅 → opacity 제거, 완전 불투명)
/// - 필터 버튼: surfaceMuted (Border 없음)
/// - 구분선: AppColors.divider
class FloatingSearchBar extends StatelessWidget {
  final String searchQuery;
  final Function(String) onSearchChanged;
  final VoidCallback onFilterPressed;
  final String filterSummary;

  const FloatingSearchBar({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onFilterPressed,
    required this.filterSummary,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: AppSpacing.md,
      left: AppSpacing.md,
      right: AppSpacing.md,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 검색창 + 필터 버튼
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  // 검색 아이콘
                  const Icon(
                    Icons.search,
                    color: AppColors.textDisabled,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),

                  // 검색 입력
                  Expanded(
                    child: TextField(
                      onChanged: onSearchChanged,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: '치과명, 동네로 검색',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: AppColors.textDisabled,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),

                  // 필터 버튼 → surfaceMuted (Border 없음)
                  InkWell(
                    onTap: onFilterPressed,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(
                        Icons.tune,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 필터 요약 (있을 때만)
            if (filterSummary.isNotEmpty) ...[
              const Divider(color: AppColors.divider, height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  10,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 12,
                      color: AppColors.textDisabled,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        filterSummary,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
