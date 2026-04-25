import 'package:flutter/material.dart';
import '../../../models/resume.dart';
import '../../../core/theme/app_colors.dart';
import 'resume_ocr_prompt.dart';

/// E. 임상 스킬 / 소프트 스킬 섹션
class SectionSkills extends StatefulWidget {
  final List<ResumeSkill> skills;
  final ValueChanged<List<ResumeSkill>> onChanged;

  const SectionSkills({super.key, required this.skills, required this.onChanged});

  @override
  State<SectionSkills> createState() => _SectionSkillsState();
}

class _SectionSkillsState extends State<SectionSkills> {
  late List<ResumeSkill> _items;
  bool _showCustomInput = false;
  final _customCtrl = TextEditingController();

  // 프리셋과 skillMaster를 통일 — career_profile_service.dart skillMaster와 동기화
  static const _clinicalPresets = [
    '스케일링',
    '치주 관리',
    '불소도포',
    '방사선 촬영',
    '인상 채득',
    '임시치아 제작',
    '교정 와이어 교체',
    '임플란트 보조',
    '근관치료 보조',
    '소아 진료 보조',
    '레진/실란트',
    '치아미백',
    '구강스캐너',
    '구내,구외 포토',
  ];

  static const _softPresets = [
    '환자 상담',
    '보험청구',
    '차트 관리',
    '감염 관리',
    '재고 관리',
    '팀 리더십',
    '신규 직원 교육',
    '고객 CS',
  ];

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.skills);
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  void _toggleSkill(String id, String name) {
    setState(() {
      final idx = _items.indexWhere((s) => s.id == id);
      if (idx >= 0) {
        _items.removeAt(idx);
      } else {
        _items.add(ResumeSkill(id: id, name: name, level: 3));
      }
    });
    widget.onChanged(_items);
  }

  void _addCustomSkill() {
    final text = _customCtrl.text.trim();
    if (text.isEmpty) return;
    // 중복 체크
    if (_items.any((s) => s.name == text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 추가된 스킬이에요.'), duration: Duration(seconds: 1)),
      );
      return;
    }
    setState(() {
      _items.add(ResumeSkill(id: 'custom_$text', name: text, level: 3));
      _customCtrl.clear();
      _showCustomInput = false;
    });
    widget.onChanged(_items);
  }

  void _setLevel(int idx, int level) {
    setState(() {
      final old = _items[idx];
      _items[idx] = ResumeSkill(id: old.id, name: old.name, level: level);
    });
    widget.onChanged(_items);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        const Text(
          '임상 스킬',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          '보유한 스킬을 선택하고 숙련도를 설정하세요. (1~5)',
          style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
        ),
        const SizedBox(height: 12),
        const ResumeOcrPrompt(),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _clinicalPresets.map((s) {
            final selected = _items.any((sk) => sk.id == s);
            return FilterChip(
              label: Text(s, style: const TextStyle(fontSize: 12)),
              selected: selected,
              selectedColor: AppColors.accent.withOpacity(0.12),
              checkmarkColor: AppColors.accent,
              onSelected: (_) => _toggleSkill(s, s),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),
        const Text(
          '소프트 스킬',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _softPresets.map((s) {
            final selected = _items.any((sk) => sk.id == s);
            return FilterChip(
              label: Text(s, style: const TextStyle(fontSize: 12)),
              selected: selected,
              selectedColor: AppColors.accent.withOpacity(0.12),
              checkmarkColor: AppColors.accent,
              onSelected: (_) => _toggleSkill(s, s),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        // ── 직접입력 추가하기 ──────────────────────────────
        if (!_showCustomInput)
          OutlinedButton.icon(
            onPressed: () => setState(() => _showCustomInput = true),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('직접 추가하기', style: TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: BorderSide(color: AppColors.accent.withOpacity(0.4)),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          )
        else
          _buildCustomInput(),

        // ── 선택된 스킬 숙련도 설정 ────────────────────────
        if (_items.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            '숙련도 설정',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          ...List.generate(_items.length, (i) {
            final s = _items[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      s.name,
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: s.level.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: _levelLabel(s.level),
                      activeColor: AppColors.accent,
                      onChanged: (v) => _setLevel(i, v.round()),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      _levelLabel(s.level),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // 커스텀 스킬만 삭제 버튼 표시
                  if (s.id.startsWith('custom_'))
                    GestureDetector(
                      onTap: () {
                        setState(() => _items.removeAt(i));
                        widget.onChanged(_items);
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.close, size: 16, color: AppColors.textDisabled),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildCustomInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '스킬 직접 입력',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customCtrl,
                  autofocus: true,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '예: 틀니 보조, 치과CT 촬영 등',
                    hintStyle: TextStyle(fontSize: 12, color: AppColors.textDisabled),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.accent),
                    ),
                    filled: true,
                    fillColor: AppColors.white,
                  ),
                  onSubmitted: (_) => _addCustomSkill(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addCustomSkill,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.onAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: const Text('추가', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => setState(() {
              _showCustomInput = false;
              _customCtrl.clear();
            }),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('취소', style: TextStyle(fontSize: 12, color: AppColors.textDisabled)),
          ),
        ],
      ),
    );
  }

  String _levelLabel(int level) {
    switch (level) {
      case 1: return '입문';
      case 2: return '초급';
      case 3: return '중급';
      case 4: return '숙련';
      case 5: return '전문가';
      default: return '중급';
    }
  }
}
