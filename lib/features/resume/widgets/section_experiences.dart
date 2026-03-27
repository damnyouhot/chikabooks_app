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

  static const _taskOptions = [
    '치석 제거/스케일링',
    '치주 관리/보조',
    '예방처치(불소도포 등)',
    '환자 교육/상담',
    '구내진단용 방사선 촬영',
    '진료 협조(임플란트)',
    '진료 협조(교정)',
    '진료 협조(소아)',
    '예약/차트/CS',
    '재고/운영 지원',
  ];

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

        ...List.generate(_items.length, (i) => _ExperienceCard(
              index: i,
              experience: _items[i],
              taskOptions: _taskOptions,
              onUpdate: (exp) => _updateAt(i, exp),
              onRemove: () => _removeAt(i),
            )),

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
  final List<String> taskOptions;
  final ValueChanged<ResumeExperience> onUpdate;
  final VoidCallback onRemove;

  const _ExperienceCard({
    required this.index,
    required this.experience,
    required this.taskOptions,
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
  late TextEditingController _toolsCtrl;
  late TextEditingController _achieveCtrl;
  late List<String> _tasks;

  @override
  void initState() {
    super.initState();
    final e = widget.experience;
    _clinicCtrl = TextEditingController(text: e.clinicName);
    _regionCtrl = TextEditingController(text: e.region);
    _startCtrl = TextEditingController(text: e.start);
    _endCtrl = TextEditingController(text: e.end);
    _toolsCtrl = TextEditingController(text: e.tools.join(', '));
    _achieveCtrl = TextEditingController(text: e.achievementsText ?? '');
    _tasks = List.of(e.tasks);
  }

  @override
  void dispose() {
    _clinicCtrl.dispose();
    _regionCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    _toolsCtrl.dispose();
    _achieveCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onUpdate(ResumeExperience(
      clinicName: _clinicCtrl.text.trim(),
      region: _regionCtrl.text.trim(),
      start: _startCtrl.text.trim(),
      end: _endCtrl.text.trim(),
      tasks: _tasks,
      tools: _toolsCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      achievementsText:
          _achieveCtrl.text.trim().isEmpty ? null : _achieveCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
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

            _field('병원명 *', _clinicCtrl, '예: 서울밝은치과'),
            _field('지역', _regionCtrl, '서울시 강남구'),
            Row(
              children: [
                Expanded(child: _field('시작 (YYYY-MM)', _startCtrl, '2023-03')),
                const SizedBox(width: 10),
                Expanded(
                    child:
                        _field('종료 (YYYY-MM)', _endCtrl, '재직중')),
              ],
            ),

            // 담당업무 체크리스트
            const SizedBox(height: 8),
            Text(
              '담당 업무',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 8.0;
                final cellW = (constraints.maxWidth - gap) / 2;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: widget.taskOptions.map((t) {
                    final selected = _tasks.contains(t);
                    return SizedBox(
                      width: cellW,
                      child: FilterChip(
                        label: Text(
                          t,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.25,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        selected: selected,
                        selectedColor: AppColors.accent.withOpacity(0.12),
                        checkmarkColor: AppColors.accent,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        side: BorderSide(
                          color: selected
                              ? AppColors.accent.withOpacity(0.45)
                              : AppColors.divider,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              _tasks.add(t);
                            } else {
                              _tasks.remove(t);
                            }
                          });
                          _emit();
                        },
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 10),
            _field('사용 툴/장비 (콤마 구분)', _toolsCtrl, 'CEREC, Medit i700'),
            _field('성과 (선택)', _achieveCtrl, '하루 평균 환자 30명 처치'),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
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

