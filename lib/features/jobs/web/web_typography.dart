import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 웹 페이지 전용 타이포그래피
/// Noto Sans KR + 좁은 자간 + 전반적으로 볼드한 웨이트
class WebTypo {
  WebTypo._();

  // ── 헤딩 ─────────────────────────────────────────────
  /// 페이지 대제목 (예: "구인공고 등록")
  static TextStyle heading({Color? color}) => GoogleFonts.notoSansKr(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    color: color,
  );

  /// 섹션 타이틀 (예: "기본 정보")
  static TextStyle sectionTitle({Color? color}) => GoogleFonts.notoSansKr(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: color,
  );

  // ── 본문 ─────────────────────────────────────────────
  /// 일반 본문
  static TextStyle body({Color? color, double size = 14}) =>
      GoogleFonts.notoSansKr(
        fontSize: size,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.3,
        color: color,
      );

  /// 보조 설명 텍스트
  static TextStyle caption({Color? color, double size = 12}) =>
      GoogleFonts.notoSansKr(
        fontSize: size,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.2,
        color: color,
      );

  // ── 버튼 ─────────────────────────────────────────────
  static TextStyle button({Color? color, double size = 14}) =>
      GoogleFonts.notoSansKr(
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: color,
      );

  // ── 라벨 / 뱃지 ──────────────────────────────────────
  static TextStyle label({Color? color, double size = 11}) =>
      GoogleFonts.notoSansKr(
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: color,
      );

  // ── 숫자 강조 ─────────────────────────────────────────
  static TextStyle number({Color? color, double size = 22}) =>
      GoogleFonts.notoSansKr(
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: color,
      );

  // ── Theme 래퍼 ───────────────────────────────────────
  /// 웹 전용 페이지를 이 Theme으로 감싸면 내부 모든 TextTheme에 자동 적용됨
  static ThemeData themeData(ThemeData base) {
    final notoTextTheme = GoogleFonts.notoSansKrTextTheme(
      base.textTheme,
    ).copyWith(
      bodyMedium: GoogleFonts.notoSansKr(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.3,
      ),
      bodySmall: GoogleFonts.notoSansKr(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.2,
      ),
      titleMedium: GoogleFonts.notoSansKr(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: GoogleFonts.notoSansKr(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
      ),
      labelMedium: GoogleFonts.notoSansKr(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.0,
      ),
    );

    return base.copyWith(textTheme: notoTextTheme);
  }
}


