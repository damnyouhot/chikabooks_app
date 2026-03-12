import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// 결 탭 디자인 팔레트 (AppColors 위임)
class BondColors {
  static const kAccent  = AppColors.accent;   // #D1FF00
  static const kText    = AppColors.text;      // #000000
  static const kBg      = AppColors.bg;        // #2E5BFF
  static const kShadow1 = AppColors.shadow;    // #8AAEFF
  static const kShadow2 = AppColors.muted;     // #CCD6FF
  static const kCardBg  = AppColors.cardBg;    // #FFFFFF

  /// 공통 카드 데코레이션
  static BoxDecoration cardDecoration() => AppColors.cardDecoration();
}
