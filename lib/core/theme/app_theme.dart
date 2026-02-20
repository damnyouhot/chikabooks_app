import 'package:flutter/material.dart';

/// 앱 테마 설정
class AppTheme {
  static ThemeData get light {
    return ThemeData(
      // 미니멀 컬러: 시안/블루 계열 포인트
      colorSchemeSeed: const Color(0xFF1E88E5),
      brightness: Brightness.light,
      useMaterial3: true,
      fontFamily: 'NotoSansKR',
      fontFamilyFallback: const ['Apple SD Gothic Neo', 'Roboto'],
      scaffoldBackgroundColor: const Color(0xFFFCFCFF),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
    );
  }
}







