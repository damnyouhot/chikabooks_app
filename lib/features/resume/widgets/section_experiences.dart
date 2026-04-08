import 'package:flutter/material.dart';
import '../../../models/resume.dart';
import '../../../core/theme/app_colors.dart';
import 'resume_ocr_prompt.dart';

/// D. 경력 섹션 (근무지별)
class SectionExperiences extends StatefulWidget {
  final List<ResumeExperience> experiences;
  final ValueChanged<List<ResumeExperience>> onChanged;

  const SectionExperiences({
    super.key,
    required this.experiences,
    required this.onChanged,
  });

  @override
  State<SectionExperiences> createState() => _SectionExperiencesState();
}

class _SectionExperiencesState extends State<SectionExperiences> {
  late List<ResumeExperience> _items;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.experiences);
  }

  void _addExperience() {
    setState(() {
      _items.add(const ResumeExperience(clinicName: ''));
    });
    widget.onChanged(_items);
  }

  void _removeAt(int i) {
    setState(() => _items.removeAt(i));
    widget.onChanged(_items);
  }

  void _updateAt(int i, ResumeExperience updated) {
    setState(() => _items[i] = updated);
    widget.onChanged(_items);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        const Text(
          '경력 (근무지별)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '최신 경력부터 입력해주세요.',
          style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
        ),
        const SizedBox(height: 12),
        const ResumeOcrPrompt(),

        ...List.generate(
          _items.length,
          (i) => _ExperienceCard(
            index: i,
            experience: _items[i],
            onUpdate: (exp) => _updateAt(i, exp),
            onRemove: () => _removeAt(i),
          ),
        ),

        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _addExperience,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('경력 추가'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accent,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _ExperienceCard extends StatefulWidget {
  final int index;
  final ResumeExperience experience;
  final ValueChanged<ResumeExperience> onUpdate;
  final VoidCallback onRemove;

  const _ExperienceCard({
    required this.index,
    required this.experience,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  State<_ExperienceCard> createState() => _ExperienceCardState();
}

class _ExperienceCardState extends State<_ExperienceCard> {
  late TextEditingController _clinicCtrl;
  late TextEditingController _regionCtrl;
  late TextEditingController _startCtrl;
  late TextEditingController _endCtrl;
  late TextEditingController _achieveCtrl;

  @override
  void initState() {
    super.initState();
    final e = widget.experience;
    _clinicCtrl = TextEditingController(text: e.clinicName);
    _regionCtrl = TextEditingController(text: e.region);
    _startCtrl = TextEditingController(text: e.start);
    _endCtrl = TextEditingController(text: e.end);
    _achieveCtrl = TextEditingController(text: e.achievementsText ?? '');
  }

  @override
  void dispose() {
    _clinicCtrl.dispose();
    _regionCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    _achieveCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onUpdate(ResumeExperience(
      clinicName: _clinicCtrl.text.trim(),
      region: _regionCtrl.text.trim(),
      start: _startCtrl.text.trim(),
      end: _endCtrl.text.trim(),
      achievementsText:
          _achieveCtrl.text.trim().isEmpty ? null : _achieveCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.resumeFormSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.resumeFormBlockBorder),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '경력 ${widget.index + 1}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                color: AppColors.error.withValues(alpha: 0.75),
                onPressed: widget.onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 14),
          _field('병원명 *', _clinicCtrl, '예: 서울밝은치과'),
          _field('지역', _regionCtrl, '서울시 강남구'),
          Row(
            children: [
              Expanded(child: _field('시작 (YYYY-MM)', _startCtrl, '2023-03')),
              const SizedBox(width: 10),
              Expanded(child: _field('종료 (YYYY-MM)', _endCtrl, '재직중')),
            ],
          ),
          _field(
            '소속, 담당, 성과',
            _achieveCtrl,
            '치주과 소속 / 스케일링 담당 / 하루 평균 환자 30명',
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        onChanged: (_) => _emit(),
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textDisabled),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
      ),
    );
  }
}
