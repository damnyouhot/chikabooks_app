import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 영문 브랜드 타이틀 `HygieneLab` — Zalando Sans SemiExpanded (w900)
/// 기본 색은 한글 타이틀(하이진랩)과 동일한 [AppColors.textPrimary].
/// 웹 로그인 등 보조 톤이 필요하면 [color]로 [AppColors.textSecondary] 등 지정.
class HygieneLabEnglishTitle extends StatelessWidget {
  const HygieneLabEnglishTitle({
    super.key,
    this.fontSize = 29,
    this.letterSpacing = 0.35,
    this.color,
  });

  final double fontSize;
  final double letterSpacing;

  /// null이면 [AppColors.textPrimary] (앱 로그인 한글 타이틀과 동일)
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      'HygieneLab',
      style: TextStyle(
        fontFamily: 'ZalandoSansSemiExpanded',
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        letterSpacing: letterSpacing,
        color: color ?? AppColors.textPrimary,
      ),
    );
  }
}
