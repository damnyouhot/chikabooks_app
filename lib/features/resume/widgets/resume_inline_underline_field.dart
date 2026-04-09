import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// 이력서 작성: 웹 공고 편집기와 동일한 **좌측 라벨 + 우측 입력 + 밑줄** 레이아웃.
class ResumeInlineUnderlineField extends StatelessWidget {
  const ResumeInlineUnderlineField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.maxLength,
    this.textInputAction,
    this.labelWidth = AppPublisher.formInlineLabelWidth,
    this.bottomPadding = 14,
    this.inputSuffix,
    this.autofocus = false,
    this.hideCounter = false,
    this.expandHeightWithContent = false,
    this.minLines,
    this.scrollPhysics,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType keyboardType;
  final int maxLines;
  final int? maxLength;
  final TextInputAction? textInputAction;
  final double labelWidth;
  final double bottomPadding;

  /// 입력칸 오른쪽 (같은 행) — 예: 추가 버튼
  final Widget? inputSuffix;
  final bool autofocus;

  /// `maxLength` 사용 시 기본 카운터 숨김 (상단에 커스텀 카운터·버튼 둘 때)
  final bool hideCounter;

  /// `true`이면 [maxLines]는 무시되고 높이가 본문 길이에 맞게 늘어나며,
  /// 스크롤은 조상(예: [SingleChildScrollView])에 위임합니다.
  final bool expandHeightWithContent;

  /// [expandHeightWithContent]일 때 최소 줄 수 (미지정 시 6)
  final int? minLines;

  /// [expandHeightWithContent]일 때 기본은 내부 스크롤 비활성
  final ScrollPhysics? scrollPhysics;

  static const TextStyle labelStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    height: 1.35,
  );

  static const TextStyle valueStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// 라벨 없이 힌트만 있는 밑줄 입력 (다이얼로그 등)
  static InputDecoration underlineDecoration({
    String? hint,
    bool hideCounter = false,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textDisabled,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      isDense: true,
      counterText: hideCounter ? '' : null,
      border: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.divider),
      ),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.divider),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.accent, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMultiline = expandHeightWithContent || maxLines > 1;
    final labelTop = isMultiline ? 12.0 : 10.0;
    final effectiveKeyboard =
        expandHeightWithContent ? TextInputType.multiline : keyboardType;
    final effectiveMaxLines = expandHeightWithContent ? null : maxLines;
    final effectiveMinLines = expandHeightWithContent ? (minLines ?? 6) : null;
    final effectiveScrollPhysics =
        expandHeightWithContent
            ? (scrollPhysics ?? const NeverScrollableScrollPhysics())
            : null;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Padding(
              padding: EdgeInsets.only(top: labelTop),
              child: _LabelText(label: label),
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    autofocus: autofocus,
                    keyboardType: effectiveKeyboard,
                    maxLines: effectiveMaxLines,
                    minLines: effectiveMinLines,
                    maxLength: maxLength,
                    textInputAction: textInputAction,
                    scrollPhysics: effectiveScrollPhysics,
                    style: valueStyle,
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                    decoration: underlineDecoration(
                      hint: hint,
                      hideCounter: hideCounter,
                    ),
                  ),
                ),
                if (inputSuffix != null) ...[
                  const SizedBox(width: 8),
                  inputSuffix!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelText extends StatelessWidget {
  const _LabelText({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final idx = label.lastIndexOf(' *');
    if (idx < 0) {
      return Text(
        label,
        style: ResumeInlineUnderlineField.labelStyle,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Text.rich(
      TextSpan(
        style: ResumeInlineUnderlineField.labelStyle,
        children: [
          TextSpan(text: label.substring(0, idx)),
          const TextSpan(
            text: ' *',
            style: TextStyle(
              color: AppColors.cardEmphasis,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}
