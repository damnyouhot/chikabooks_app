import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// 채용 소탭 상단 고정 검색/요약 바 (Sticky)
///
/// 원칙: Shadow 없음 / Border(하단 구분선만 유지)
/// - 검색창: surfaceMuted fill, 포커스 시 accent border
/// - 필터 버튼: 비활성 → surfaceMuted / 활성 → accent fill
/// - 배지: accent + onAccent
class JobSearchBarDelegate extends SliverPersistentHeaderDelegate {
  final String searchQuery;
  final String careerSummary;
  final int activeFilterCount;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilterPressed;
  final VoidCallback onMapToggle;

  const JobSearchBarDelegate({
    required this.searchQuery,
    required this.careerSummary,
    required this.activeFilterCount,
    required this.onSearchChanged,
    required this.onFilterPressed,
    required this.onMapToggle,
  });

  static const double height = 76.0;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  bool shouldRebuild(covariant JobSearchBarDelegate oldDelegate) {
    return oldDelegate.searchQuery != searchQuery ||
        oldDelegate.careerSummary != careerSummary ||
        oldDelegate.activeFilterCount != activeFilterCount;
  }

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return _JobSearchBarContent(
      searchQuery: searchQuery,
      careerSummary: careerSummary,
      activeFilterCount: activeFilterCount,
      onSearchChanged: onSearchChanged,
      onFilterPressed: onFilterPressed,
      onMapToggle: onMapToggle,
    );
  }
}

class _JobSearchBarContent extends StatefulWidget {
  final String searchQuery;
  final String careerSummary;
  final int activeFilterCount;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilterPressed;
  final VoidCallback onMapToggle;

  const _JobSearchBarContent({
    required this.searchQuery,
    required this.careerSummary,
    required this.activeFilterCount,
    required this.onSearchChanged,
    required this.onFilterPressed,
    required this.onMapToggle,
  });

  @override
  State<_JobSearchBarContent> createState() => _JobSearchBarContentState();
}

class _JobSearchBarContentState extends State<_JobSearchBarContent> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _JobSearchBarContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery &&
        _ctrl.text != widget.searchQuery) {
      _ctrl.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: JobSearchBarDelegate.height,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 10,
      ),
      // 하단 구분선만 유지 (Border.all 제거)
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── 1행: 검색창 + 필터 + 지도 버튼 ──
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _ctrl,
                    onChanged: widget.onSearchChanged,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                    decoration: InputDecoration(
                      hintText: '치과명, 동네로 검색',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textDisabled,
                        letterSpacing: -0.3,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: AppColors.textDisabled,
                      ),
                      suffixIcon: _ctrl.text.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _ctrl.clear();
                                widget.onSearchChanged('');
                              },
                              child: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: AppColors.textDisabled,
                              ),
                            )
                          : null,
                      // 기본/활성 border 제거, 포커스만 accent
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
                        horizontal: 10,
                        vertical: 0,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // 필터 버튼
              _IconBadgeButton(
                icon: Icons.tune_rounded,
                badgeCount: widget.activeFilterCount,
                isActive: widget.activeFilterCount > 0,
                onTap: widget.onFilterPressed,
                tooltip: '상세 필터',
              ),
              const SizedBox(width: 6),

              // 지도 전환 버튼
              _MapToggleButton(onTap: widget.onMapToggle),
            ],
          ),

          // ── 2행: 커리어 요약 ──
          Align(
            alignment: Alignment.centerLeft,
            child: widget.careerSummary.isNotEmpty
                ? Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 12,
                        color: AppColors.textDisabled,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        widget.careerSummary,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  )
                : const Text(
                    '커리어 카드를 등록하면 맞춤 공고를 추천해드려요',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textDisabled,
                      letterSpacing: -0.2,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── 필터 아이콘 + 배지 버튼 ──────────────────────────────────────
class _IconBadgeButton extends StatelessWidget {
  final IconData icon;
  final int badgeCount;
  final bool isActive;
  final VoidCallback onTap;
  final String tooltip;

  const _IconBadgeButton({
    required this.icon,
    required this.badgeCount,
    required this.isActive,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                // 활성 → accent fill / 비활성 → surfaceMuted (Border 없음)
                color: isActive
                    ? AppColors.accent
                    : AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isActive
                    ? AppColors.onAccent
                    : AppColors.textSecondary,
              ),
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onAccent,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 지도 전환 버튼 ────────────────────────────────────────────────
class _MapToggleButton extends StatelessWidget {
  final VoidCallback onTap;

  const _MapToggleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        // surfaceMuted fill (Border 없음)
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 15,
              color: AppColors.textSecondary,
            ),
            SizedBox(width: AppSpacing.xs),
            Text(
              '지도',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
