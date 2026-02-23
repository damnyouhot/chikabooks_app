import 'package:flutter/material.dart';
import '../../notifiers/job_filter_notifier.dart';

// ── 디자인 팔레트 ──
const _kAccent = Color(0xFFF7CBCA);
const _kText = Color(0xFF5D6B6B);
const _kShadow2 = Color(0xFFD5E5E5);

/// 상세 필터 바텀시트
///
/// 직종 / 경력 / 지역 / 급여 / 조건칩
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
  late String _positionFilter;
  late String _careerFilter;
  late String _regionFilter;
  late RangeValues _salaryRange;
  late Set<String> _conditions;

  @override
  void initState() {
    super.initState();
    // 현재 필터 값 복사
    _positionFilter = widget.filter.positionFilter;
    _careerFilter = widget.filter.careerFilter;
    _regionFilter = widget.filter.regionFilter;
    _salaryRange = widget.filter.salaryRange;
    _conditions = Set.from(widget.filter.conditions);
  }

  void _applyFilters() {
    widget.filter.setPositionFilter(_positionFilter);
    widget.filter.setCareerFilter(_careerFilter);
    widget.filter.setRegionFilter(_regionFilter);
    widget.filter.setSalaryRange(_salaryRange);

    // 조건칩 적용
    for (final condition in _conditions) {
      if (!widget.filter.conditions.contains(condition)) {
        widget.filter.toggleCondition(condition);
      }
    }
    for (final condition in widget.filter.conditions.toList()) {
      if (!_conditions.contains(condition)) {
        widget.filter.toggleCondition(condition);
      }
    }

    Navigator.pop(context);
  }

  void _resetFilters() {
    setState(() {
      _positionFilter = '전체';
      _careerFilter = '전체';
      _regionFilter = '전체';
      _salaryRange = const RangeValues(0, 10000);
      _conditions.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
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
              color: _kText.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

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
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _resetFilters,
                  child: Text(
                    '초기화',
                    style: TextStyle(
                      fontSize: 14,
                      color: _kText.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 필터 내용
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 직종 필터
                  _buildSectionTitle('직종'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        ['전체', '치과위생사', '치과조무사', '치과의사', '기타']
                            .map(
                              (position) => _buildChip(
                                label: position,
                                isSelected: _positionFilter == position,
                                onTap:
                                    () => setState(
                                      () => _positionFilter = position,
                                    ),
                              ),
                            )
                            .toList(),
                  ),
                  const SizedBox(height: 20),

                  // 경력 필터
                  _buildSectionTitle('경력'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        ['전체', '신입', '경력']
                            .map(
                              (career) => _buildChip(
                                label: career,
                                isSelected: _careerFilter == career,
                                onTap:
                                    () =>
                                        setState(() => _careerFilter = career),
                              ),
                            )
                            .toList(),
                  ),
                  const SizedBox(height: 20),

                  // 지역 필터
                  _buildSectionTitle('지역'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _regionFilter,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _kShadow2, width: 0.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _kShadow2, width: 0.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: _kShadow2.withOpacity(0.2),
                    ),
                    items:
                        [
                              '전체',
                              '서울',
                              '경기',
                              '인천',
                              '부산',
                              '대구',
                              '광주',
                              '대전',
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
                            ]
                            .map(
                              (region) => DropdownMenuItem(
                                value: region,
                                child: Text(region),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _regionFilter = value);
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  // 급여 범위
                  _buildSectionTitle('급여 범위'),
                  const SizedBox(height: 8),
                  Text(
                    '${_salaryRange.start.round()}~${_salaryRange.end.round() >= 10000 ? "협의" : "${_salaryRange.end.round()}만"}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _kText.withOpacity(0.8),
                    ),
                  ),
                  RangeSlider(
                    values: _salaryRange,
                    min: 0,
                    max: 10000,
                    divisions: 20,
                    activeColor: _kAccent,
                    inactiveColor: _kShadow2,
                    labels: RangeLabels(
                      '${_salaryRange.start.round()}만',
                      _salaryRange.end.round() >= 10000
                          ? '협의'
                          : '${_salaryRange.end.round()}만',
                    ),
                    onChanged:
                        (values) => setState(() => _salaryRange = values),
                  ),
                  const SizedBox(height: 12),

                  // 조건칩
                  _buildSectionTitle('기타 조건'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        ['신입가능', '야간없음', '주4일', '파트타임']
                            .map(
                              (condition) => _buildChip(
                                label: condition,
                                isSelected: _conditions.contains(condition),
                                onTap: () {
                                  setState(() {
                                    if (_conditions.contains(condition)) {
                                      _conditions.remove(condition);
                                    } else {
                                      _conditions.add(condition);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(),
                  ),
                ],
              ),
            ),
          ),

          // 하단 버튼
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: _kShadow2.withOpacity(0.5), width: 0.5),
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: _kText,
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? _kAccent.withOpacity(0.2)
                  : _kShadow2.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _kAccent : _kShadow2,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? _kText : _kText.withOpacity(0.7),
          ),
        ),
      ),
    );
  }
}



