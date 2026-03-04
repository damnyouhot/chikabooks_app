import 'package:flutter/material.dart';
import '../../../models/resume.dart';

const _kText = Color(0xFF3D4A5C);
const _kBlue = Color(0xFF4A90D9);

/// C. 면허/자격 섹션
class SectionLicenses extends StatefulWidget {
  final List<ResumeLicense> licenses;
  final ValueChanged<List<ResumeLicense>> onChanged;

  const SectionLicenses({super.key, required this.licenses, required this.onChanged});

  @override
  State<SectionLicenses> createState() => _SectionLicensesState();
}

class _SectionLicensesState extends State<SectionLicenses> {
  late List<ResumeLicense> _items;

  static const _presets = [
    '치과위생사 면허',
    'CPR/BLS',
    '방사선 관련 교육/이수',
    '감염관리 교육',
    '보험청구 교육',
    'CS 교육',
  ];

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.licenses);
    // 프리셋 중 없는 항목은 has=false로 추가
    for (final preset in _presets) {
      if (!_items.any((l) => l.type == preset)) {
        _items.add(ResumeLicense(type: preset, has: false));
      }
    }
  }

  void _toggle(int index) {
    setState(() {
      final old = _items[index];
      _items[index] = ResumeLicense(
        type: old.type,
        has: !old.has,
        numberMasked: old.numberMasked,
        issuedYear: old.issuedYear,
      );
    });
    widget.onChanged(_items.where((l) => l.has).toList());
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        const Text(
          '면허 / 자격',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _kText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '보유 여부만 체크하세요. 면허 번호 등 민감정보는 기본 비공개예요.',
          style: TextStyle(fontSize: 12, color: _kText.withOpacity(0.4)),
        ),
        const SizedBox(height: 16),
        ...List.generate(_items.length, (i) {
          final l = _items[i];
          return CheckboxListTile(
            title: Text(
              l.type,
              style: TextStyle(
                fontSize: 14,
                color: _kText,
                fontWeight: l.has ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            value: l.has,
            activeColor: _kBlue,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (_) => _toggle(i),
            contentPadding: EdgeInsets.zero,
          );
        }),
      ],
    );
  }
}

