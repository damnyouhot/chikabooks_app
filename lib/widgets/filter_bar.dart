// lib/widgets/filter_bar.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../notifiers/job_filter_notifier.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';

class FilterBar extends StatefulWidget {
  const FilterBar({super.key});

  @override
  State<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<FilterBar> {
  final _searchController = TextEditingController();
  bool _showAdvancedFilters = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jobFilter = context.watch<JobFilterNotifier>();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.all(8),
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.divider, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // 검색바
            TextField(
              controller: _searchController,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: '병원명, 지역으로 검색',
              hintStyle: const TextStyle(fontSize: 14, color: AppColors.textDisabled),
              prefixIcon: const Icon(Icons.search, color: AppColors.textDisabled),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.textDisabled),
                      onPressed: () {
                        _searchController.clear();
                        jobFilter.setSearchQuery('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.divider, width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.divider, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.accent, width: 1.0),
              ),
              filled: true,
              fillColor: AppColors.surfaceMuted,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
              onChanged: (value) => jobFilter.setSearchQuery(value),
            ),
            const SizedBox(height: 12),

            // 직종 필터 (가로 스크롤 칩)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    '직종: ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ...['전체', '치과위생사', '간호조무사', '치과의사', '기타'].map(
                    (position) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(
                          position,
                          style: TextStyle(
                            fontSize: 13,
                            color: jobFilter.positionFilter == position
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                        selected: jobFilter.positionFilter == position,
                        onSelected: (_) => jobFilter.setPositionFilter(position),
                        showCheckmark: false,
                        selectedColor: AppColors.accent.withOpacity(0.5),
                        backgroundColor: AppColors.surfaceMuted,
                        side: BorderSide(
                          color: jobFilter.positionFilter == position
                              ? AppColors.accent
                              : AppColors.divider,
                          width: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 고급 필터 토글 버튼
            InkWell(
              onTap: () => setState(() => _showAdvancedFilters = !_showAdvancedFilters),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '상세 필터',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(
                      _showAdvancedFilters ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),

            // 고급 필터 (접기/펼치기)
            if (_showAdvancedFilters) ...[
              const Divider(color: AppColors.divider, thickness: 0.5),
              // 경력 필터
              Row(
                children: [
                  Text(
                    '경력: ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ...['전체', '신입', '경력'].map(
                    (career) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(
                          career,
                          style: TextStyle(
                            fontSize: 13,
                            color: jobFilter.careerFilter == career
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                        selected: jobFilter.careerFilter == career,
                        onSelected: (_) => jobFilter.setCareerFilter(career),
                        showCheckmark: false,
                        selectedColor: AppColors.accent.withOpacity(0.5),
                        backgroundColor: AppColors.surfaceMuted,
                        side: BorderSide(
                          color: jobFilter.careerFilter == career
                              ? AppColors.accent
                              : AppColors.divider,
                          width: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 지역 필터
              Row(
                children: [
                  Text(
                    '지역: ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: jobFilter.regionFilter,
                      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                          borderSide: const BorderSide(color: AppColors.divider, width: 0.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                          borderSide: const BorderSide(color: AppColors.divider, width: 0.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.surfaceMuted,
                      ),
                      items: [
                        '전체', '서울', '경기', '인천', '부산', '대구',
                        '광주', '대전', '울산', '세종', '강원', '충북',
                        '충남', '전북', '전남', '경북', '경남', '제주',
                      ].map((region) => DropdownMenuItem(
                        value: region,
                        child: Text(region),
                      )).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          jobFilter.setRegionFilter(value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 급여 필터
              Row(
                children: [
                  Text(
                    '급여: ${jobFilter.salaryRange.start.round()}~${jobFilter.salaryRange.end.round() >= 10000 ? "협의" : "${jobFilter.salaryRange.end.round()}만"}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              RangeSlider(
                values: jobFilter.salaryRange,
                min: 0,
                max: 10000,
                divisions: 20,
                activeColor: AppColors.accent,
                inactiveColor: AppColors.divider,
                labels: RangeLabels(
                  '${jobFilter.salaryRange.start.round()}만',
                  jobFilter.salaryRange.end.round() >= 10000 
                      ? '협의' 
                      : '${jobFilter.salaryRange.end.round()}만',
                ),
                onChanged: (values) => jobFilter.setSalaryRange(values),
              ),

              // 필터 초기화 버튼
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    jobFilter.resetFilters();
                    _searchController.clear();
                  },
                  icon: const Icon(Icons.refresh, size: 18, color: AppColors.textPrimary),
                  label: const Text(
                    '필터 초기화',
                    style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
