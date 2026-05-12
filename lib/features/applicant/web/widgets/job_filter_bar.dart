import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../notifiers/job_filter_notifier.dart';

/// 공고 보드 상단 필터 바.
///
/// Phase 1 범위:
///  - 키워드 검색
///  - 지역 드롭다운
///  - 직종/경력 칩
///  - 정렬 드롭다운
///
/// 더 풍부한 필터(급여/근무요일/지하철 라인 등)는 [JobFilterNotifier]에 이미
/// 정의돼 있으므로 Phase 2 에서 모달 형태로 노출 예정.
class JobFilterBar extends StatefulWidget {
  const JobFilterBar({super.key});

  @override
  State<JobFilterBar> createState() => _JobFilterBarState();
}

class _JobFilterBarState extends State<JobFilterBar> {
  late final TextEditingController _searchCtrl;

  static const _regions = <String>[
    '전체',
    '서울',
    '경기',
    '인천',
    '부산',
    '대구',
    '대전',
    '광주',
    '울산',
    '세종',
    '강원',
    '충북',
    '충남',
    '전북',
    '전남',
    '경북',
    '경남',
    '제주',
  ];

  static const _positions = <String>['전체', '치과위생사', '간호조무사', '치과의사', '기타'];
  static const _careers = <String>['전체', '신입', '경력'];
  static const _sorts = <String>['최신순', '매칭높은순', '마감임박순', '급여높은순'];

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(
      text: context.read<JobFilterNotifier>().searchQuery,
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = context.watch<JobFilterNotifier>();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppApplicant.cardRadius),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 검색 입력 ──
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: '공고 제목, 치과 이름, 키워드로 검색',
              hintStyle: GoogleFonts.notoSansKr(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textDisabled,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        filter.setSearchQuery('');
                        setState(() {});
                      },
                    ),
              filled: true,
              fillColor: AppColors.surfaceMuted,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) {
              filter.setSearchQuery(v);
              setState(() {});
            },
          ),

          const SizedBox(height: 12),

          // ── 칩 + 드롭다운 행 ──
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Dropdown(
                label: '지역',
                value: filter.regionFilter,
                items: _regions,
                onChanged: (v) =>
                    filter.setRegionFilter(v ?? '전체'),
              ),
              _Dropdown(
                label: '직종',
                value: filter.positionFilter,
                items: _positions,
                onChanged: (v) =>
                    filter.setPositionFilter(v ?? '전체'),
              ),
              _Dropdown(
                label: '경력',
                value: filter.careerFilter,
                items: _careers,
                onChanged: (v) =>
                    filter.setCareerFilter(v ?? '전체'),
              ),
              const Spacer(),
              _Dropdown(
                label: '정렬',
                value: filter.sortBy,
                items: _sorts,
                onChanged: (v) => filter.setSortBy(v ?? '최신순'),
                trailingIcon: Icons.swap_vert_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.trailingIcon,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final active = value != items.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? AppColors.accent.withValues(alpha: 0.08)
            : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: active
              ? AppColors.accent.withValues(alpha: 0.4)
              : Colors.transparent,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: Icon(
            trailingIcon ?? Icons.expand_more_rounded,
            size: 18,
            color: active ? AppColors.accent : AppColors.textSecondary,
          ),
          style: GoogleFonts.notoSansKr(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? AppColors.accent : AppColors.textPrimary,
          ),
          items: [
            for (final v in items)
              DropdownMenuItem<String>(
                value: v,
                child: Text(
                  v == items.first ? label : v,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
          selectedItemBuilder: (_) => [
            for (final v in items)
              Center(
                child: Text(
                  v == items.first ? label : '$label · $v',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color:
                        active ? AppColors.accent : AppColors.textPrimary,
                  ),
                ),
              ),
          ],
          onChanged: onChanged,
          dropdownColor: AppColors.white,
        ),
      ),
    );
  }
}
