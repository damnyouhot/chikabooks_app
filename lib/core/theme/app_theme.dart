import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 앱 테마 설정
class AppTheme {
  static ThemeData get light {
    return ThemeData(
      colorSchemeSeed: AppColors.blue,       // blue → Material 위젯 포인트
      brightness: Brightness.light,          // 흰 배경 기반 → 라이트 모드
      useMaterial3: true,
      fontFamily: 'NotoSansKR',
      fontFamilyFallback: const ['Apple SD Gothic Neo', 'Roboto'],
      scaffoldBackgroundColor: AppColors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.black,    // AppBar 아이콘/텍스트 검정
      ),
      // 텍스트 기본색 검정 (흰 배경 위 최대 대비)
      textTheme: const TextTheme(
        bodyLarge:   TextStyle(color: AppColors.black),
        bodyMedium:  TextStyle(color: AppColors.black),
        bodySmall:   TextStyle(color: AppColors.black),
        titleLarge:  TextStyle(color: AppColors.black),
        titleMedium: TextStyle(color: AppColors.black),
        titleSmall:  TextStyle(color: AppColors.black),
      ),
    );
  }
}
