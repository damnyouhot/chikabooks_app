import 'package:flutter/material.dart';
import '../../../models/resume.dart';
import '../../../core/theme/app_colors.dart';
import 'resume_ocr_prompt.dart';
import 'resume_inline_underline_field.dart';

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
        const SizedBox(height: 12),
        const ResumeOcrPrompt(),

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
      color: AppColors.white,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
            Divider(height: 1, color: AppColors.divider.withOpacity(0.6)),
            const SizedBox(height: 14),
            ResumeInlineUnderlineField(
              label: '학교명',
              hint: '예: OO대학교',
              controller: _schoolCtrl,
              onChanged: (_) => _emit(),
            ),
            ResumeInlineUnderlineField(
              label: '전공',
              hint: '치위생학과',
              controller: _majorCtrl,
              onChanged: (_) => _emit(),
            ),
            ResumeInlineUnderlineField(
              label: '졸업년도',
              hint: '2021',
              controller: _yearCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => _emit(),
            ),
          ],
        ),
      ),
    );
  }

}

