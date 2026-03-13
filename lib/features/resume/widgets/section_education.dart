import 'package:flutter/material.dart';
import '../../../models/resume.dart';
import '../../../core/theme/app_colors.dart';

/// F. 학력/실습 섹션
class SectionEducation extends StatefulWidget {
  final List<ResumeEducation> education;
  final ValueChanged<List<ResumeEducation>> onChanged;

  const SectionEducation({
    super.key,
    required this.education,
    required this.onChanged,
  });

  @override
  State<SectionEducation> createState() => _SectionEducationState();
}

class _SectionEducationState extends State<SectionEducation> {
  late List<ResumeEducation> _items;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.education);
  }

  void _add() {
    setState(() {
      _items.add(const ResumeEducation());
    });
    widget.onChanged(_items);
  }

  void _removeAt(int i) {
    setState(() => _items.removeAt(i));
    widget.onChanged(_items);
  }

  void _updateAt(int i, ResumeEducation updated) {
    setState(() => _items[i] = updated);
    widget.onChanged(_items);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        const Text(
          '학력',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '치위생과 졸업 및 실습 정보를 입력해주세요.',
          style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
        ),
        const SizedBox(height: 16),

        ...List.generate(_items.length, (i) => _EducationCard(
              index: i,
              item: _items[i],
              onUpdate: (e) => _updateAt(i, e),
              onRemove: () => _removeAt(i),
            )),

        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('학력 추가'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accent,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _EducationCard extends StatefulWidget {
  final int index;
  final ResumeEducation item;
  final ValueChanged<ResumeEducation> onUpdate;
  final VoidCallback onRemove;

  const _EducationCard({
    required this.index,
    required this.item,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  State<_EducationCard> createState() => _EducationCardState();
}

class _EducationCardState extends State<_EducationCard> {
  late TextEditingController _schoolCtrl;
  late TextEditingController _majorCtrl;
  late TextEditingController _yearCtrl;

  @override
  void initState() {
    super.initState();
    _schoolCtrl = TextEditingController(text: widget.item.school);
    _majorCtrl = TextEditingController(text: widget.item.major);
    _yearCtrl = TextEditingController(
      text: widget.item.gradYear?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _schoolCtrl.dispose();
    _majorCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onUpdate(ResumeEducation(
      school: _schoolCtrl.text.trim(),
      major: _majorCtrl.text.trim(),
      gradYear: int.tryParse(_yearCtrl.text.trim()),
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
                  '학력 ${widget.index + 1}',
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
            _field('학교명', _schoolCtrl, '예: OO대학교'),
            _field('전공', _majorCtrl, '치위생학과'),
            _field('졸업년도', _yearCtrl, '2021',
                keyboard: TextInputType.number),
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

