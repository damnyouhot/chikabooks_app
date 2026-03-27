import 'package:flutter/material.dart';
import '../../../models/resume.dart';
import '../../../core/theme/app_colors.dart';
import 'resume_ocr_prompt.dart';

/// A. 기본정보 섹션
class SectionProfile extends StatefulWidget {
  final ResumeProfile? profile;
  final ValueChanged<ResumeProfile> onChanged;

  const SectionProfile({super.key, this.profile, required this.onChanged});

  @override
  State<SectionProfile> createState() => _SectionProfileState();
}

class _SectionProfileState extends State<SectionProfile> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _regionCtrl;
  late final TextEditingController _headlineCtrl;
  List<String> _workTypes = [];

  static const _workTypeOptions = [
    '정규직',
    '파트타임',
    '주말',
    '야간',
    '단기',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.profile ?? const ResumeProfile();
    _nameCtrl = TextEditingController(text: p.name);
    _phoneCtrl = TextEditingController(text: p.phone);
    _emailCtrl = TextEditingController(text: p.email);
    _regionCtrl = TextEditingController(text: p.region);
    _headlineCtrl = TextEditingController(text: p.headline);
    _workTypes = List<String>.from(p.workTypes);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _regionCtrl.dispose();
    _headlineCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(ResumeProfile(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      region: _regionCtrl.text.trim(),
      workTypes: _workTypes,
      headline: _headlineCtrl.text.trim(),
      summary: widget.profile?.summary ?? '',
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        _sectionTitle('기본정보', '이름과 연락처는 지원 시 익명 처리돼요.'),
        const SizedBox(height: 12),
        const ResumeOcrPrompt(),

        _field('이름 *', _nameCtrl, '홍길동'),
        _field('휴대폰 *', _phoneCtrl, '010-0000-0000',
            keyboard: TextInputType.phone),
        _field('이메일 *', _emailCtrl, 'example@email.com',
            keyboard: TextInputType.emailAddress),
        _field('거주지 (시/구)', _regionCtrl, '서울시 강남구'),
        _field('한줄소개', _headlineCtrl, '밝고 성실한 3년차 치과위생사입니다.'),

        const SizedBox(height: 20),
        _sectionTitle('희망 근무형태', '복수 선택 가능'),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, c) {
            const gap = 8.0;
            final w = (c.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: _workTypeOptions.map((type) {
                final selected = _workTypes.contains(type);
                return SizedBox(
                  width: w,
                  child: FilterChip(
                    label: Text(
                      type,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    selected: selected,
                    selectedColor: AppColors.accent.withOpacity(0.15),
                    checkmarkColor: AppColors.accent,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: BorderSide(
                      color: selected
                          ? AppColors.accent.withOpacity(0.5)
                          : AppColors.divider,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _workTypes.add(type);
                        } else {
                          _workTypes.remove(type);
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
      ],
    );
  }

  Widget _sectionTitle(String title, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          sub,
          style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
        ),
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    String hint, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
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
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}

