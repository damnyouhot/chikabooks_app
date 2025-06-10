import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../notifiers/job_filter_notifier.dart';

class FilterBar extends StatelessWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final filter = context.watch<JobFilterNotifier>();

    const regions = [
      '전체',
      '서울',
      '경기',
      '인천',
      '부산',
      '대구',
      '광주',
      '대전',
      '울산',
      '세종'
    ];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            /* ── 경력 & 지역 ── */
            Row(
              children: [
                const Text('경력:'),
                const SizedBox(width: 8),
                _Chip(
                  label: '전체',
                  selected: filter.careerFilter == '전체',
                  onTap: () => filter.setCareerFilter('전체'),
                ),
                _Chip(
                  label: '신입',
                  selected: filter.careerFilter == '신입',
                  onTap: () => filter.setCareerFilter('신입'),
                ),
                _Chip(
                  label: '경력',
                  selected: filter.careerFilter == '경력',
                  onTap: () => filter.setCareerFilter('경력'),
                ),
                const Spacer(),
                const Text('지역:'),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: filter.regionFilter,
                  underline: const SizedBox(),
                  items: regions
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => filter.setRegionFilter(v!),
                ),
              ],
            ),

            /* ── 급여 슬라이더 ── */
            Row(
              children: [
                Text(
                    '급여(만): ${filter.salaryRange.start.round()} ~ ${filter.salaryRange.end.round()}'),
                Expanded(
                  child: RangeSlider(
                    values: filter.salaryRange,
                    min: 0,
                    max: 10000,
                    divisions: 100,
                    labels: RangeLabels(
                      filter.salaryRange.start.round().toString(),
                      filter.salaryRange.end.round().toString(),
                    ),
                    onChanged: filter.setSalaryRange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/* 재사용 Chip */
class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
