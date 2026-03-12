import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 앱 테마 설정
class AppTheme {
  static ThemeData get light {
    return ThemeData(
      colorSchemeSeed: AppColors.blue,
      brightness: Brightness.light,
      useMaterial3: true,
      fontFamily: 'NotoSansKR',
      fontFamilyFallback: const ['Apple SD Gothic Neo', 'Roboto'],
      // Scaffold 배경: soft gray (카드와 시각적 분리)
      scaffoldBackgroundColor: AppColors.appBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      // 텍스트 기본색: Black (soft gray 배경 위 최대 대비)
      textTheme: const TextTheme(
        bodyLarge:   TextStyle(color: AppColors.textPrimary),
        bodyMedium:  TextStyle(color: AppColors.textPrimary),
        bodySmall:   TextStyle(color: AppColors.textSecondary),
        titleLarge:  TextStyle(color: AppColors.textPrimary),
        titleMedium: TextStyle(color: AppColors.textPrimary),
        titleSmall:  TextStyle(color: AppColors.textPrimary),
      ),
      // BottomNavigationBar 전역 테마 (Consumer 없이 고정)
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.navBg,
        selectedItemColor: AppColors.navSelected,
        unselectedItemColor: AppColors.navUnselected,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      // ElevatedButton: 기본값 Blue + White, shadow 없음
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      // Card: shadow 없음, 배경 Blue (AppStyle.primaryCardDecoration 권장)
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        color: AppColors.cardPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
