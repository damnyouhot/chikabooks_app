import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'tab_theme.dart';

/// 앱 테마 설정
class AppTheme {
  static ThemeData get light {
    return ThemeData(
      colorSchemeSeed: AppColors.blue,       // blue → Material 위젯 포인트
      brightness: Brightness.dark,           // 블루 배경에 맞춰 다크 기반
      useMaterial3: true,
      fontFamily: 'NotoSansKR',
      fontFamilyFallback: const ['Apple SD Gothic Neo', 'Roboto'],
      scaffoldBackgroundColor: TabTheme.caring.bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.white,    // AppBar 아이콘/텍스트 흰색
      ),
      // 텍스트 기본색 흰색 계열 (블루 배경 위)
      textTheme: const TextTheme(
        bodyLarge:   TextStyle(color: AppColors.white),
        bodyMedium:  TextStyle(color: AppColors.white),
        bodySmall:   TextStyle(color: AppColors.white),
        titleLarge:  TextStyle(color: AppColors.white),
        titleMedium: TextStyle(color: AppColors.white),
        titleSmall:  TextStyle(color: AppColors.white),
      ),
    );
  }
}
