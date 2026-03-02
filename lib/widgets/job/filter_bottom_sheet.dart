import 'package:flutter/material.dart';
import '../../notifiers/job_filter_notifier.dart';

// ── 디자인 팔레트 ──
const _kAccent = Color(0xFFF7CBCA);
const _kText = Color(0xFF5D6B6B);
const _kShadow = Color(0xFFD5E5E5);
const _kBlue = Color(0xFF90CAF9);

/// 상세 필터 바텀시트
///
/// ## 섹션 구성
/// 1. 정렬 (최신순 / 매칭높은순 / 마감임박순 / 급여높은순)
/// 2. 직종
/// 3. 경력
/// 4. 근무형태
/// 5. 지역
/// 6. 급여 범위
/// 7. 기타 조건
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
  }

  void _applyFilters() {
    widget.filter.setSortBy(_sortBy);
    widget.filter.setPositionFilter(_positionFilter);
    widget.filter.setCareerFilter(_careerFilter);
    widget.filter.setEmploymentType(_employmentType);
    widget.filter.setRegionFilter(_regionFilter);
    widget.filter.setSalaryRange(_salaryRange);
    widget.filter.setConditions(_conditions);
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _kText.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // 헤더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  '상세 필터',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _kText,
                    letterSpacing: -0.4,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _resetFilters,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(48, 32),
                  ),
                  child: Text(
                    '초기화',
                    style: TextStyle(
                      fontSize: 13,
                      color: _kText.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: _kShadow.withValues(alpha: 0.5)),

          // 스크롤 가능 필터 내용
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ① 정렬
                  _SectionTitle(title: '정렬'),
                  const SizedBox(height: 8),
                  _ChipGroup(
                    options: const ['최신순', '매칭높은순', '마감임박순', '급여높은순'],
                    selected: _sortBy,
                    onTap: (v) => setState(() => _sortBy = v),
                    accentColor: _kBlue,
                  ),
                  const SizedBox(height: 20),

                  // ② 직종
                  _SectionTitle(title: '직종'),
                  const SizedBox(height: 8),
                  _ChipGroup(
                    options: const [
                      '전체',
                      '치위생사',
                      '치과조무사',
                      '치과의사',
                      '기공사',
                      '기타',
                    ],
                    selected: _positionFilter,
                    onTap: (v) => setState(() => _positionFilter = v),
                  ),
                  const SizedBox(height: 20),

                  // ③ 경력
                  _SectionTitle(title: '경력'),
                  const SizedBox(height: 8),
                  _ChipGroup(
                    options: const ['전체', '신입', '1년 이상', '3년 이상', '5년 이상'],
                    selected: _careerFilter,
                    onTap: (v) => setState(() => _careerFilter = v),
                  ),
                  const SizedBox(height: 20),

                  // ④ 근무형태
                  _SectionTitle(title: '근무형태'),
                  const SizedBox(height: 8),
                  _ChipGroup(
                    options: const ['전체', '풀타임', '파트타임', '계약직'],
                    selected: _employmentType,
                    onTap: (v) => setState(() => _employmentType = v),
                  ),
                  const SizedBox(height: 20),

                  // ⑤ 지역
                  _SectionTitle(title: '지역'),
                  const SizedBox(height: 8),
                  _RegionDropdown(
                    value: _regionFilter,
                    onChanged: (v) => setState(() => _regionFilter = v),
                  ),
                  const SizedBox(height: 20),

                  // ⑥ 급여 범위
                  _SectionTitle(title: '급여 범위'),
                  const SizedBox(height: 4),
                  _SalaryRangeSlider(
                    range: _salaryRange,
                    onChanged: (v) => setState(() => _salaryRange = v),
                  ),
                  const SizedBox(height: 20),

                  // ⑦ 기타 조건
                  _SectionTitle(title: '기타 조건'),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // 하단 적용 버튼
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: _kShadow.withValues(alpha: 0.4)),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _applyFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent,
                  foregroundColor: _kText,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
        color: _kText,
        letterSpacing: -0.3,
      ),
    );
  }
}

// ── 단일 선택 칩 그룹 ────────────────────────────────────────────
class _ChipGroup extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onTap;
  final Color accentColor;

  const _ChipGroup({
    required this.options,
    required this.selected,
    required this.onTap,
    this.accentColor = _kAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = opt == selected;
        return GestureDetector(
          onTap: () => onTap(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.18)
                  : _kShadow.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? accentColor : _kShadow,
                width: isSelected ? 1.5 : 0.5,
              ),
            ),
            child: Text(
              opt,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected ? _kText : _kText.withValues(alpha: 0.65),
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
    '신입가능',
    '야간없음',
    '주4일',
    '파트타임 가능',
    '역세권',
    '즉시지원',
    '4대보험',
    '퇴직금',
    '연차',
    '식비지원',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _allConditions.map((c) {
        final isSelected = conditions.contains(c);
        return GestureDetector(
          onTap: () => onToggle(c),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected
                  ? _kAccent.withValues(alpha: 0.18)
                  : _kShadow.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? _kAccent : _kShadow,
                width: isSelected ? 1.5 : 0.5,
              ),
            ),
            child: Text(
              c,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected ? _kText : _kText.withValues(alpha: 0.6),
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _kShadow, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _kShadow, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kAccent, width: 1.0),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: _kShadow.withValues(alpha: 0.15),
      ),
      items: _regions
          .map(
            (r) => DropdownMenuItem(
              value: r,
              child: Text(r, style: const TextStyle(fontSize: 13)),
            ),
          )
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
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _kText.withValues(alpha: 0.75),
            letterSpacing: -0.3,
          ),
        ),
        RangeSlider(
          values: range,
          min: 0,
          max: 10000,
          divisions: 20,
          activeColor: _kAccent,
          inactiveColor: _kShadow,
          labels: RangeLabels(_label(range.start), _label(range.end)),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
