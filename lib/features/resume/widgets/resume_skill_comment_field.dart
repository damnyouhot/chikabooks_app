import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// 스킬 코멘트용 — 줄 수만큼만 높이를 쓰고 **밑줄이 텍스트 바로 아래**에 붙음
/// (Material [UnderlineInputBorder] + maxLines 조합으로 밑줄이 멀어지는 문제 회피)
class ResumeSkillCommentField extends StatefulWidget {
  const ResumeSkillCommentField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
    this.bottomPadding = 16,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final double bottomPadding;

  @override
  State<ResumeSkillCommentField> createState() =>
      _ResumeSkillCommentFieldState();
}

class _ResumeSkillCommentFieldState extends State<ResumeSkillCommentField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focusNode.hasFocus;
    final borderColor = focused ? AppColors.accent : AppColors.divider;
    final borderWidth = focused ? 2.0 : 1.0;

    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: AppPublisher.formInlineLabelWidth,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ),
          ),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: borderColor, width: borderWidth),
                ),
              ),
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                minLines: 1,
                maxLines: 8,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.45,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: widget.hint,
                  hintStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textDisabled,
                    height: 1.35,
                  ),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.only(top: 2, bottom: 4),
                ),
                onChanged: widget.onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
