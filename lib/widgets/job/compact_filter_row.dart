import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// 목록용 컴팩트 필터 행 (1줄)
///
/// 검색창 + 필터 버튼 + 정렬 드롭다운
/// 원칙: Shadow 없음 / Border 없음
/// - 검색창: surfaceMuted fill, 포커스 시 accent border만 유지
/// - 필터 버튼: 비활성 → surfaceMuted / 활성 → accent
/// - 배지: AppColors.accent + onAccent
class CompactFilterRow extends StatelessWidget {
  final String searchQuery;
  final Function(String) onSearchChanged;
  final VoidCallback onFilterPressed;
  final String sortBy;
  final Function(String) onSortChanged;
  final int activeFilterCount;

  const CompactFilterRow({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onFilterPressed,
    required this.sortBy,
    required this.onSortChanged,
    this.activeFilterCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isFilterActive = activeFilterCount > 0;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      // 하단 구분선만 유지 (Border.all 제거)
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // 검색창
          Expanded(
            flex: 3,
            child: TextField(
              onChanged: onSearchChanged,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: '검색',
                hintStyle: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textDisabled,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 18,
                  color: AppColors.textDisabled,
                ),
                // 기본/활성 border 제거, 포커스 border만 accent
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(
                    color: AppColors.accent,
                    width: 1.0,
                  ),
                ),
                filled: true,
                fillColor: AppColors.surfaceMuted,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 10,
                ),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // 필터 버튼 (배지 포함)
          Stack(
            children: [
              InkWell(
                onTap: onFilterPressed,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    // 활성 → accent / 비활성 → surfaceMuted (Border 없음)
                    color: isFilterActive
                        ? AppColors.accent
                        : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.tune,
                    size: 18,
                    color: isFilterActive
                        ? AppColors.onAccent
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              // 활성 필터 수 배지
              if (isFilterActive)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$activeFilterCount',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onAccent,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),

          // 정렬 드롭다운
          DropdownButton<String>(
            value: sortBy,
            onChanged: (value) {
              if (value != null) onSortChanged(value);
            },
            items: ['거리순', '최신순', '급여순'].map((sort) {
              return DropdownMenuItem(
                value: sort,
                child: Text(
                  sort,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              );
            }).toList(),
            underline: const SizedBox.shrink(),
            icon: const Icon(
              Icons.arrow_drop_down,
              color: AppColors.textSecondary,
            ),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
            dropdownColor: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ],
      ),
    );
  }
}
