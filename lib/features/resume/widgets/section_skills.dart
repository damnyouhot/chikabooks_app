import 'package:flutter/material.dart';
import '../../../models/resume.dart';

const _kText = Color(0xFF3D4A5C);
const _kBlue = Color(0xFF4A90D9);

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

  // 치과위생사 공통 스킬 프리셋
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
  ];

  static const _softPresets = [
    '환자 상담',
    '보험 청구',
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
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kText),
        ),
        const SizedBox(height: 4),
        Text(
          '보유한 스킬을 선택하고 숙련도를 설정하세요. (1~5)',
          style: TextStyle(fontSize: 12, color: _kText.withOpacity(0.4)),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _clinicalPresets.map((s) {
            final selected = _items.any((sk) => sk.id == s);
            return FilterChip(
              label: Text(s, style: const TextStyle(fontSize: 12)),
              selected: selected,
              selectedColor: _kBlue.withOpacity(0.12),
              checkmarkColor: _kBlue,
              onSelected: (_) => _toggleSkill(s, s),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),
        const Text(
          '소프트 스킬',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kText),
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
              selectedColor: _kBlue.withOpacity(0.12),
              checkmarkColor: _kBlue,
              onSelected: (_) => _toggleSkill(s, s),
            );
          }).toList(),
        ),

        // 선택된 스킬 숙련도 설정
        if (_items.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            '숙련도 설정',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kText),
          ),
          const SizedBox(height: 8),
          ...List.generate(_items.length, (i) {
            final s = _items[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      s.name,
                      style: const TextStyle(fontSize: 13, color: _kText),
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
                      activeColor: _kBlue,
                      onChanged: (v) => _setLevel(i, v.round()),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      _levelLabel(s.level),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _kBlue,
                      ),
                      textAlign: TextAlign.center,
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

  String _levelLabel(int level) {
    switch (level) {
      case 1:
        return '입문';
      case 2:
        return '초급';
      case 3:
        return '중급';
      case 4:
        return '숙련';
      case 5:
        return '전문가';
      default:
        return '중급';
    }
  }
}

