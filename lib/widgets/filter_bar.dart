import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../notifiers/job_filter_notifier.dart';

class FilterBar extends StatelessWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    // '디자이너'를 불러와서 현재 선택된 필터 값을 알아냅니다.
    final currentCareerFilter = context.watch<JobFilterNotifier>().careerFilter;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼ 이 부분 수정 ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
          _Chip(
            label: '전체',
            isSelected: currentCareerFilter == '전체',
            onPressed: () =>
                context.read<JobFilterNotifier>().setCareerFilter('전체'),
          ),
          _Chip(
            label: '신입',
            isSelected: currentCareerFilter == '신입',
            onPressed: () =>
                context.read<JobFilterNotifier>().setCareerFilter('신입'),
          ),
          _Chip(
            label: '경력',
            isSelected: currentCareerFilter == '경력',
            onPressed: () =>
                context.read<JobFilterNotifier>().setCareerFilter('경력'),
          ),
          // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲ 이 부분 수정 ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲
        ],
      ),
    );
  }
}

// 칩 위젯도 선택 상태를 표시할 수 있도록 수정
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
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (_) => onPressed(),
          selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
          checkmarkColor: Theme.of(context).primaryColor,
        ),
      );
}
