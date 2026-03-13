import 'package:flutter/material.dart';
import '../../../models/resume.dart';
import '../../../core/theme/app_colors.dart';

/// G. 보수교육/세미나 섹션
class SectionTrainings extends StatefulWidget {
  final List<ResumeTraining> trainings;
  final ValueChanged<List<ResumeTraining>> onChanged;

  const SectionTrainings({
    super.key,
    required this.trainings,
    required this.onChanged,
  });

  @override
  State<SectionTrainings> createState() => _SectionTrainingsState();
}

class _SectionTrainingsState extends State<SectionTrainings> {
  late List<ResumeTraining> _items;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.trainings);
  }

  void _add() {
    setState(() => _items.add(const ResumeTraining()));
    widget.onChanged(_items);
  }

  void _removeAt(int i) {
    setState(() => _items.removeAt(i));
    widget.onChanged(_items);
  }

  void _updateAt(int i, ResumeTraining updated) {
    setState(() => _items[i] = updated);
    widget.onChanged(_items);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        const Text(
          '보수교육 / 세미나',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '이수한 보수교육, 세미나, 연수 등을 입력해주세요.',
          style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
        ),
        const SizedBox(height: 16),

        ...List.generate(_items.length, (i) => _TrainingCard(
              index: i,
              item: _items[i],
              onUpdate: (t) => _updateAt(i, t),
              onRemove: () => _removeAt(i),
            )),

        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('교육 추가'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accent,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _TrainingCard extends StatefulWidget {
  final int index;
  final ResumeTraining item;
  final ValueChanged<ResumeTraining> onUpdate;
  final VoidCallback onRemove;

  const _TrainingCard({
    required this.index,
    required this.item,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  State<_TrainingCard> createState() => _TrainingCardState();
}

class _TrainingCardState extends State<_TrainingCard> {
  late TextEditingController _titleCtrl;
  late TextEditingController _orgCtrl;
  late TextEditingController _hoursCtrl;
  late TextEditingController _yearCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.item.title);
    _orgCtrl = TextEditingController(text: widget.item.org);
    _hoursCtrl = TextEditingController(
      text: widget.item.hours?.toString() ?? '',
    );
    _yearCtrl = TextEditingController(
      text: widget.item.year?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _orgCtrl.dispose();
    _hoursCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onUpdate(ResumeTraining(
      title: _titleCtrl.text.trim(),
      org: _orgCtrl.text.trim(),
      hours: int.tryParse(_hoursCtrl.text.trim()),
      year: int.tryParse(_yearCtrl.text.trim()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '교육 ${widget.index + 1}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: AppColors.error.withOpacity(0.6),
                  onPressed: widget.onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _field('교육명', _titleCtrl, '예: 보수교육 8시간'),
            _field('교육기관', _orgCtrl, '대한치과위생사협회'),
            Row(
              children: [
                Expanded(
                  child: _field('시간', _hoursCtrl, '8',
                      keyboard: TextInputType.number),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _field('연도', _yearCtrl, '2025',
                      keyboard: TextInputType.number),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    String hint, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        onChanged: (_) => _emit(),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
            hintStyle: TextStyle(color: AppColors.textDisabled),
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}

