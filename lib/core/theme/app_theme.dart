import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 앱 테마 설정
class AppTheme {
  static ThemeData get light {
    return ThemeData(
      colorSchemeSeed: AppColors.accent,   // D1FF00 라임 → Material 위젯 포인트
      brightness: Brightness.dark,          // 블루 배경에 맞춰 다크 기반
      useMaterial3: true,
      fontFamily: 'NotoSansKR',
      fontFamilyFallback: const ['Apple SD Gothic Neo', 'Roboto'],
      scaffoldBackgroundColor: AppColors.bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.cardBg,  // AppBar 아이콘/텍스트 흰색
      ),
      // 텍스트 기본색 흰색 계열 (블루 배경 위)
      textTheme: const TextTheme(
        bodyLarge:   TextStyle(color: AppColors.cardBg),
        bodyMedium:  TextStyle(color: AppColors.cardBg),
        bodySmall:   TextStyle(color: AppColors.cardBg),
        titleLarge:  TextStyle(color: AppColors.cardBg),
        titleMedium: TextStyle(color: AppColors.cardBg),
        titleSmall:  TextStyle(color: AppColors.cardBg),
      ),
    );
  }
}
