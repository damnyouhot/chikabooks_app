import 'package:flutter/material.dart';

// ── 디자인 팔레트 ──
const _kText = Color(0xFF5D6B6B);
const _kAccent = Color(0xFFF7CBCA);
const _kShadow = Color(0xFFD5E5E5);
const _kBg = Color(0xFFF5F0F2);

/// 공고보기 탭 상단 고정 검색/요약 바 (Sticky 1)
///
/// - 좌: 검색창 (치과명, 동네로 검색)
/// - 우: 커리어 요약 1줄 + 필터 버튼
/// - 우 끝: 지도 보기 전환 버튼
class JobSearchBarDelegate extends SliverPersistentHeaderDelegate {
  final String searchQuery;
  final String careerSummary;   // 예: "진료실 · 2년차 · 서울"
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: _kShadow.withOpacity(0.6), width: 0.5),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── 1행: 검색창 + 필터 + 지도 버튼 ──
          Row(
            children: [
              // 검색창
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _ctrl,
                    onChanged: widget.onSearchChanged,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _kText,
                      letterSpacing: -0.3,
                    ),
                    decoration: InputDecoration(
                      hintText: '치과명, 동네로 검색',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: _kText.withOpacity(0.4),
                        letterSpacing: -0.3,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: _kText.withOpacity(0.45),
                      ),
                      suffixIcon: _ctrl.text.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _ctrl.clear();
                                widget.onSearchChanged('');
                              },
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: _kText.withOpacity(0.4),
                              ),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: _kShadow, width: 0.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: _kShadow, width: 0.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: _kAccent, width: 1.0),
                      ),
                      filled: true,
                      fillColor: _kBg.withOpacity(0.5),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 0,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 필터 버튼
              _IconBadgeButton(
                icon: Icons.tune_rounded,
                badgeCount: widget.activeFilterCount,
                isActive: widget.activeFilterCount > 0,
                onTap: widget.onFilterPressed,
                tooltip: '상세 필터',
              ),
              const SizedBox(width: 6),

              // 지도 보기 전환 버튼
              _MapToggleButton(onTap: widget.onMapToggle),
            ],
          ),

          // ── 2행: 커리어 요약 ──
          Align(
            alignment: Alignment.centerLeft,
            child: widget.careerSummary.isNotEmpty
                ? Row(
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 12,
                        color: _kText.withOpacity(0.45),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.careerSummary,
                        style: TextStyle(
                          fontSize: 11,
                          color: _kText.withOpacity(0.55),
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  )
                : Text(
                    '커리어 카드를 등록하면 맞춤 공고를 추천해드려요',
                    style: TextStyle(
                      fontSize: 11,
                      color: _kText.withOpacity(0.4),
                      letterSpacing: -0.2,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── 필터 아이콘 + 배지 버튼 ─────────────────────────────────────
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
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isActive
                    ? _kAccent.withOpacity(0.15)
                    : _kShadow.withOpacity(0.25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive ? _kAccent : _kShadow,
                  width: 0.5,
                ),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isActive ? _kAccent : _kText.withOpacity(0.65),
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
                  color: _kAccent,
                  shape: BoxShape.circle,
                ),
                constraints:
                    const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: _kText,
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

// ── 지도 전환 버튼 ───────────────────────────────────────────────
class _MapToggleButton extends StatelessWidget {
  final VoidCallback onTap;

  const _MapToggleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: _kShadow.withOpacity(0.25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kShadow, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 15,
              color: _kText.withOpacity(0.65),
            ),
            const SizedBox(width: 4),
            Text(
              '지도',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _kText.withOpacity(0.7),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
