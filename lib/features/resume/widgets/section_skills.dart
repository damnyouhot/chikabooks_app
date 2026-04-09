import 'package:flutter/material.dart';
import '../../../models/resume.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import 'resume_ocr_prompt.dart';
import 'resume_inline_underline_field.dart';
import 'resume_skill_comment_field.dart';
import 'resume_skill_presets.dart';

/// E. 임상 스킬 / 소프트 스킬 섹션
class SectionSkills extends StatefulWidget {
  final List<ResumeSkill> skills;
  final String clinicalSkillsComment;
  final String softSkillsComment;
  final ValueChanged<List<ResumeSkill>> onSkillsChanged;
  final void Function(String clinical, String soft) onCommentsChanged;

  const SectionSkills({
    super.key,
    required this.skills,
    this.clinicalSkillsComment = '',
    this.softSkillsComment = '',
    required this.onSkillsChanged,
    required this.onCommentsChanged,
  });

  @override
  State<SectionSkills> createState() => _SectionSkillsState();
}

class _SectionSkillsState extends State<SectionSkills> {
  late List<ResumeSkill> _items;
  bool _showCustomInput = false;
  final _customCtrl = TextEditingController();
  late final TextEditingController _clinicalCommentCtrl;
  late final TextEditingController _softCommentCtrl;

  /// 치과 채용 담당자가 바로 이해할 수 있는 예시 문장 (플레이스홀더)
  static const _clinicalCommentHint =
      '치과에서 위에 선택한 임상 스킬을 바탕으로 지원자를 더 잘 파악할 수 있게 적어주세요. '
      '예) 비슷한 경력의 동료 대비 OO 분야에 더 강합니다. '
      'OO 치과 근무 경험을 바탕으로 소아 진료 보조에 특히 강점이 있습니다.';
  static const _softCommentHint =
      '치과에서 위에 선택한 소프트 스킬로 협업·운영에서 어떤 역할을 해왔는지 적어주세요. '
      '예) 비슷한 경력 대비 OO(상담·수납·교육 등)에서 강점이 있습니다. '
      'OO 업무를 맡아 팀 내 OO(재고·감염·클레임 대응 등)에 기여했습니다.';

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.skills);
    _clinicalCommentCtrl =
        TextEditingController(text: widget.clinicalSkillsComment);
    _softCommentCtrl = TextEditingController(text: widget.softSkillsComment);
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    _clinicalCommentCtrl.dispose();
    _softCommentCtrl.dispose();
    super.dispose();
  }

  void _emitComments() {
    widget.onCommentsChanged(
      _clinicalCommentCtrl.text,
      _softCommentCtrl.text,
    );
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
    widget.onSkillsChanged(_items);
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
    widget.onSkillsChanged(_items);
  }

  void _setLevel(int idx, int level) {
    setState(() {
      final old = _items[idx];
      _items[idx] = ResumeSkill(id: old.id, name: old.name, level: level);
    });
    widget.onSkillsChanged(_items);
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
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.start,
          children: ResumeSkillPresets.clinical.map((s) {
            final selected = _items.any((sk) => sk.id == s);
            return FilterChip(
              label: Text(
                s,
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
              onSelected: (_) => _toggleSkill(s, s),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        ResumeSkillCommentField(
          label: '코멘트',
          hint: _clinicalCommentHint,
          controller: _clinicalCommentCtrl,
          onChanged: (_) => _emitComments(),
          bottomPadding: 16,
        ),

        const SizedBox(height: 24),
        const Text(
          '소프트 스킬',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.start,
          children: ResumeSkillPresets.soft.map((s) {
            final selected = _items.any((sk) => sk.id == s);
            return FilterChip(
              label: Text(
                s,
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
              onSelected: (_) => _toggleSkill(s, s),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        ResumeSkillCommentField(
          label: '코멘트',
          hint: _softCommentHint,
          controller: _softCommentCtrl,
          onChanged: (_) => _emitComments(),
          bottomPadding: 16,
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
                        widget.onSkillsChanged(_items);
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
          ResumeInlineUnderlineField(
            label: '스킬',
            hint: '예: 틀니 보조, 치과CT 촬영 등',
            controller: _customCtrl,
            autofocus: true,
            bottomPadding: 6,
            onSubmitted: (_) => _addCustomSkill(),
            inputSuffix: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ElevatedButton(
                onPressed: _addCustomSkill,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.onAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  elevation: 0,
                ),
                child: const Text('추가', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
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
