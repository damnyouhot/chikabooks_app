import 'package:flutter/material.dart';

const _kText = Color(0xFF3D4A5C);

/// B. Professional Summary 섹션
class SectionSummary extends StatefulWidget {
  final String summary;
  final ValueChanged<String> onChanged;

  const SectionSummary({super.key, required this.summary, required this.onChanged});

  @override
  State<SectionSummary> createState() => _SectionSummaryState();
}

class _SectionSummaryState extends State<SectionSummary> {
  late final TextEditingController _ctrl;

  static const _templates = [
    '치과 임상 경험 O년차, 스케일링/예방처치/환자 상담을 주 업무로 수행했습니다.',
    '교정과 중심의 경력을 바탕으로 정확한 진료 보조와 환자 케어에 강점이 있습니다.',
    '종합병원 구강외과에서 수술 보조 및 감염관리 전담 업무를 담당했습니다.',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.summary);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        const Text(
          '요약 (Professional Summary)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _kText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '3~5줄로 자신을 소개해주세요.',
          style: TextStyle(fontSize: 12, color: _kText.withOpacity(0.4)),
        ),
        const SizedBox(height: 16),

        // 템플릿 버튼
        Text(
          '템플릿 활용하기',
          style: TextStyle(fontSize: 12, color: _kText.withOpacity(0.5)),
        ),
        const SizedBox(height: 8),
        ..._templates.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () {
                  _ctrl.text = t;
                  widget.onChanged(t);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: _kText.withOpacity(0.08)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    t,
                    style: TextStyle(
                      fontSize: 12,
                      color: _kText.withOpacity(0.5),
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            )),
        const SizedBox(height: 16),

        TextField(
          controller: _ctrl,
          maxLines: 6,
          maxLength: 500,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            hintText: '자유롭게 작성하거나 위 템플릿을 수정해주세요.',
            hintStyle: TextStyle(color: _kText.withOpacity(0.2)),
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ],
    );
  }
}

