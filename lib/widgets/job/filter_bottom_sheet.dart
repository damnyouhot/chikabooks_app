import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/job.dart';
import '../../notifiers/job_filter_notifier.dart';

/// 상세 필터 바텀시트
///
/// 원칙: Shadow 없음 / Border 없음
/// - 칩 선택: segmentSelected(Blue) / surfaceMuted(미선택), Border 제거
/// - 적용 버튼: accent(Blue) + onAccent
/// - 슬라이더: accent(Blue)
class FilterBottomSheet extends StatefulWidget {
  final JobFilterNotifier filter;

  const FilterBottomSheet({super.key, required this.filter});

  static Future<void> show(BuildContext context, JobFilterNotifier filter) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterBottomSheet(filter: filter),
    );
  }

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late String _sortBy;
  late String _positionFilter;
  late String _careerFilter;
  late String _employmentType;
  late String _regionFilter;
  late RangeValues _salaryRange;
  late Set<String> _conditions;
  late String _hospitalType;
  late Set<String> _selectedWorkDays;
  late Set<String> _selectedSubwayLines;

  @override
  void initState() {
    super.initState();
    _sortBy = widget.filter.sortBy;
    _positionFilter = widget.filter.positionFilter;
    _careerFilter = widget.filter.careerFilter;
    _employmentType = widget.filter.employmentType;
    _regionFilter = widget.filter.regionFilter;
    _salaryRange = widget.filter.salaryRange;
    _conditions = Set.from(widget.filter.conditions);
    _hospitalType = widget.filter.hospitalType;
    _selectedWorkDays = Set.from(widget.filter.selectedWorkDays);
    _selectedSubwayLines = Set.from(widget.filter.selectedSubwayLines);
  }

  void _applyFilters() {
    widget.filter.setSortBy(_sortBy);
    widget.filter.setPositionFilter(_positionFilter);
    widget.filter.setCareerFilter(_careerFilter);
    widget.filter.setEmploymentType(_employmentType);
    widget.filter.setRegionFilter(_regionFilter);
    widget.filter.setSalaryRange(_salaryRange);
    widget.filter.setConditions(_conditions);
    widget.filter.setHospitalType(_hospitalType);
    widget.filter.setSelectedWorkDays(_selectedWorkDays);
    widget.filter.setSelectedSubwayLines(_selectedSubwayLines);
    Navigator.pop(context);
  }

  void _resetFilters() {
    setState(() {
      _sortBy = '최신순';
      _positionFilter = '전체';
      _careerFilter = '전체';
      _employmentType = '전체';
      _regionFilter = '전체';
      _salaryRange = const RangeValues(0, 10000);
      _conditions.clear();
      _hospitalType = '전체';
      _selectedWorkDays.clear();
      _selectedSubwayLines.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들
          const SizedBox(height: AppSpacing.md),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.disabledBg,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // 헤더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Row(
              children: [
                const Text(
                  '상세 필터',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _resetFilters,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(48, 32),
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text(
                    '초기화',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),

          // 스크롤 가능 필터 내용
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                18,
                AppSpacing.xl,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ① 정렬
                  const _SectionTitle(title: '정렬'),
                  const SizedBox(height: AppSpacing.sm),
                  _ChipGroup(
                    options: const ['최신순', '매칭높은순', '마감임박순', '급여높은순'],
                    selected: _sortBy,
                    onTap: (v) => setState(() => _sortBy = v),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ② 직종
                  const _SectionTitle(title: '직종'),
                  const SizedBox(height: AppSpacing.sm),
                  _ChipGroup(
                    options: const [
                      '전체', '치위생사', '치과조무사', '치과의사', '기공사', '기타',
                    ],
                    selected: _positionFilter,
                    onTap: (v) => setState(() => _positionFilter = v),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ③ 경력
                  const _SectionTitle(title: '경력'),
                  const SizedBox(height: AppSpacing.sm),
                  _ChipGroup(
                    options: const ['전체', '신입', '1년 이상', '3년 이상', '5년 이상'],
                    selected: _careerFilter,
                    onTap: (v) => setState(() => _careerFilter = v),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ④ 근무형태
                  const _SectionTitle(title: '근무형태'),
                  const SizedBox(height: AppSpacing.sm),
                  _ChipGroup(
                    options: const ['전체', '풀타임', '파트타임', '계약직'],
                    selected: _employmentType,
                    onTap: (v) => setState(() => _employmentType = v),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ⑤ 지역
                  const _SectionTitle(title: '지역'),
                  const SizedBox(height: AppSpacing.sm),
                  _RegionDropdown(
                    value: _regionFilter,
                    onChanged: (v) => setState(() => _regionFilter = v),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ⑥ 급여 범위
                  const _SectionTitle(title: '급여 범위'),
                  const SizedBox(height: AppSpacing.xs),
                  _SalaryRangeSlider(
                    range: _salaryRange,
                    onChanged: (v) => setState(() => _salaryRange = v),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ⑦ 병원 유형
                  const _SectionTitle(title: '병원 유형'),
                  const SizedBox(height: AppSpacing.sm),
                  _ChipGroup(
                    options: const ['전체', '개인의원', '네트워크', '치과병원', '종합병원/대학병원'],
                    selected: Job.hospitalTypeLabels[_hospitalType] ?? _hospitalType,
                    onTap: (v) {
                      final key = Job.hospitalTypeLabels.entries
                          .firstWhere((e) => e.value == v,
                              orElse: () => const MapEntry('전체', '전체'))
                          .key;
                      setState(() => _hospitalType = key == '전체' ? '전체' : key);
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ⑧ 근무 요일
                  const _SectionTitle(title: '근무 요일'),
                  const SizedBox(height: AppSpacing.sm),
                  _MultiChipGroup(
                    options: Job.workDayLabels,
                    selected: _selectedWorkDays,
                    onToggle: (code) => setState(() {
                      if (_selectedWorkDays.contains(code)) {
                        _selectedWorkDays.remove(code);
                      } else {
                        _selectedWorkDays.add(code);
                      }
                    }),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ⑨ 지하철 노선
                  const _SectionTitle(title: '지하철 노선'),
                  const SizedBox(height: AppSpacing.sm),
                  _MultiChipGroup(
                    options: const {
                      '1호선': '1호선', '2호선': '2호선', '3호선': '3호선',
                      '4호선': '4호선', '5호선': '5호선', '6호선': '6호선',
                      '7호선': '7호선', '8호선': '8호선', '9호선': '9호선',
                    },
                    selected: _selectedSubwayLines,
                    onToggle: (line) => setState(() {
                      if (_selectedSubwayLines.contains(line)) {
                        _selectedSubwayLines.remove(line);
                      } else {
                        _selectedSubwayLines.add(line);
                      }
                    }),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ⑩ 기타 조건
                  const _SectionTitle(title: '기타 조건'),
                  const SizedBox(height: AppSpacing.sm),
                  _ConditionsChips(
                    conditions: _conditions,
                    onToggle: (c) => setState(() {
                      if (_conditions.contains(c)) {
                        _conditions.remove(c);
                      } else {
                        _conditions.add(c);
                      }
                    }),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ),

          // 하단 적용 버튼 — 주요 액션 → accent(Blue)
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(
                top: BorderSide(color: AppColors.divider),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _applyFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.onAccent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: const Text(
                  '적용하기',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 섹션 타이틀 ──────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
      ),
    );
  }
}

// ── 단일 선택 칩 그룹 ────────────────────────────────────────────
// 선택 → segmentSelected(Blue) fill + onSegmentSelected(White) 텍스트
// 미선택 → surfaceMuted fill + textSecondary 텍스트 (Border 없음)
class _ChipGroup extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onTap;

  const _ChipGroup({
    required this.options,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: options.map((opt) {
        final isSelected = opt == selected;
        return GestureDetector(
          onTap: () => onTap(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.segmentSelected
                  : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              opt,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected
                    ? AppColors.onSegmentSelected
                    : AppColors.textSecondary,
                letterSpacing: -0.2,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── 기타 조건 칩 (다중 선택) ─────────────────────────────────────
class _ConditionsChips extends StatelessWidget {
  final Set<String> conditions;
  final ValueChanged<String> onToggle;

  const _ConditionsChips({required this.conditions, required this.onToggle});

  static const _allConditions = [
    '신입가능', '야간없음', '주4일', '파트타임 가능', '역세권',
    '즉시지원', '4대보험', '퇴직금', '연차', '식비지원',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: _allConditions.map((c) {
        final isSelected = conditions.contains(c);
        return GestureDetector(
          onTap: () => onToggle(c),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.segmentSelected
                  : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              c,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected
                    ? AppColors.onSegmentSelected
                    : AppColors.textSecondary,
                letterSpacing: -0.2,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── 다중 선택 칩 (Map<code, label> 기반) ──────────────────────────
class _MultiChipGroup extends StatelessWidget {
  final Map<String, String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _MultiChipGroup({
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: options.entries.map((e) {
        final isSelected = selected.contains(e.key);
        return GestureDetector(
          onTap: () => onToggle(e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.segmentSelected
                  : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              e.value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected
                    ? AppColors.onSegmentSelected
                    : AppColors.textSecondary,
                letterSpacing: -0.2,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── 지역 드롭다운 ─────────────────────────────────────────────────
class _RegionDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _RegionDropdown({required this.value, required this.onChanged});

  static const _regions = [
    '전체', '서울', '경기', '인천', '부산', '대구',
    '광주', '대전', '울산', '세종', '강원',
    '충북', '충남', '전북', '전남', '경북', '경남', '제주',
  ];

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
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
          borderSide: const BorderSide(color: AppColors.accent, width: 1.0),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 10,
        ),
        filled: true,
        fillColor: AppColors.surfaceMuted,
      ),
      items: _regions
          .map((r) => DropdownMenuItem(
                value: r,
                child: Text(r, style: const TextStyle(fontSize: 13)),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

// ── 급여 범위 슬라이더 ───────────────────────────────────────────
class _SalaryRangeSlider extends StatelessWidget {
  final RangeValues range;
  final ValueChanged<RangeValues> onChanged;

  const _SalaryRangeSlider({required this.range, required this.onChanged});

  String _label(double v) {
    if (v >= 10000) return '협의';
    return '${v.round()}만';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_label(range.start)} ~ ${_label(range.end)}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: -0.3,
          ),
        ),
        RangeSlider(
          values: range,
          min: 0,
          max: 10000,
          divisions: 20,
          // activeColor → accent(Blue)
          activeColor: AppColors.accent,
          inactiveColor: AppColors.disabledBg,
          labels: RangeLabels(_label(range.start), _label(range.end)),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
