// lib/widgets/filter_bar.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../notifiers/job_filter_notifier.dart';

class FilterBar extends StatelessWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final jobFilter = context.watch<JobFilterNotifier>();
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
      '세종',
    ];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Text("경력:"),
                // ▼▼▼ 불필요한 toList() 제거 ▼▼▼
                ...['전체', '신입', '경력'].map(
                  (career) => _Chip(
                    label: career,
                    isSelected: jobFilter.careerFilter == career,
                    onPressed: () => jobFilter.setCareerFilter(career),
                  ),
                ),
                const SizedBox(width: 16),
                const Text("지역:"),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: jobFilter.regionFilter,
                  items:
                      regions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      jobFilter.setRegionFilter(newValue);
                    }
                  },
                  underline: const SizedBox(),
                ),
              ],
            ),
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    '급여(만): ${jobFilter.salaryRange.start.round()} ~ ${jobFilter.salaryRange.end.round() >= 10000 ? '1억+' : jobFilter.salaryRange.end.round()}',
                  ),
                ),
                Expanded(
                  child: RangeSlider(
                    values: jobFilter.salaryRange,
                    min: 0,
                    max: 10000,
                    divisions: 20,
                    labels: RangeLabels(
                      jobFilter.salaryRange.start.round().toString(),
                      jobFilter.salaryRange.end.round().toString(),
                    ),
                    onChanged: (RangeValues values) {
                      jobFilter.setSalaryRange(values);
                    },
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

class _Chip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  const _Chip({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onPressed(),
      showCheckmark: false,
      // ▼▼▼ deprecated 된 withOpacity 대신 올바른 방법으로 수정 ▼▼▼
      selectedColor: Theme.of(context).primaryColorLight.withAlpha(128),
    ),
  );
}
