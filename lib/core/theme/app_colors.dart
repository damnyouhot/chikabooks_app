import 'package:flutter/material.dart';

/// ══════════════════════════════════════════════════════════════
/// AppColors — 앱 전체 컬러 단일 소스
///
/// 🎨 색상 변경 방법:
///   Primitive 4개(white/lime/black/blue)만 수정하면
///   Semantic Token → 전체 앱 UI에 자동 반영됩니다.
///
/// 디자인 원칙:
///   - 앱 배경: 크림 화이트 (#FDFAF5) — 따뜻하고 부드러운 느낌
///   - 일반 카드: Green 배경 + White 텍스트
///   - 강조 카드: Orange 배경 + Black 텍스트
///   - 그림자 없음 / 테두리 없음 / 탭별 컬러 차이 없음
///
/// 반전 법칙:
///   Green / Black 채운 요소 → White 텍스트/아이콘
///   Orange / White 채운 요소 → Black 텍스트/아이콘
/// ══════════════════════════════════════════════════════════════
class AppColors {
  AppColors._();

  // ══════════════════════════════════════════════════════════════
  // 🎨 Primitive — 여기 4개만 바꾸면 전체 앱 색상이 바뀝니다
  // ══════════════════════════════════════════════════════════════
  static const white = Color(0xFFFFFFFF);
  static const lime  = Color(0xFFFF7A00); // 주황색 (기존 Neon Lime 대체)
  static const black = Color(0xFF000000);
  static const blue  = Color(0xFF2AAB6C); // 녹색 (기존 Blue 대체)

  // ══════════════════════════════════════════════════════════════
  // 🏗️ Semantic Token — 역할 기반 색상 (Primitive 참조)
  // ══════════════════════════════════════════════════════════════

  // ── 앱 전체 배경 ──────────────────────────────────────────────
  /// 앱 Scaffold 배경: 크림 화이트 (따뜻하고 부드러운 배경)
  static const appBg = Color(0xFFFDFAF5);

  // ── 텍스트 ──────────────────────────────────────────────────
  /// 주요 텍스트: Pure Black (최대 대비)
  static const textPrimary = black;
  /// 보조 텍스트: 진한 회색
  static const textSecondary = Color(0xFF555555);
  /// 비활성 텍스트
  static const textDisabled = Color(0xFF999999);

  // ── 카드 시스템 (2종) ────────────────────────────────────────
  /// 일반 카드 배경: Green
  static const cardPrimary   = blue;
  /// 일반 카드 위 텍스트/아이콘: White
  static const onCardPrimary = white;

  /// 강조 카드 배경: Orange
  static const cardEmphasis   = lime;
  /// 강조 카드 위 텍스트/아이콘: Black
  static const onCardEmphasis = black;

  // ── 서피스 / 비활성 영역 ──────────────────────────────────────
  /// Muted surface: 크림 배경 위 부드러운 베이지 (세그먼트 컨테이너, 비활성 배경)
  static const surfaceMuted  = Color(0xFFF0EDE6);
  /// Muted surface 위 텍스트
  static const onSurfaceMuted = textSecondary;

  /// Disabled 배경
  static const disabledBg   = Color(0xFFE2DDD6);
  /// Disabled 텍스트
  static const disabledText = Color(0xFFB5B0A8);

  // ── 세그먼트/필터/탭 버튼 ─────────────────────────────────────
  /// 세그먼트 선택: Green fill
  static const segmentSelected   = blue;
  /// 세그먼트 선택 텍스트: White
  static const onSegmentSelected = white;
  /// 세그먼트 미선택: 투명 (surfaceMuted 컨테이너 위)
  static const segmentUnselected   = Color(0x00000000); // transparent
  /// 세그먼트 미선택 텍스트: textSecondary
  static const onSegmentUnselected = textSecondary;

  // ── 내비게이션 바 ────────────────────────────────────────────
  /// BottomNavBar 배경: 크림 화이트 (앱 배경과 통일감)
  static const navBg         = Color(0xFFFDFAF5);
  /// BottomNavBar 선택 아이콘/텍스트: Green
  static const navSelected   = blue;
  /// BottomNavBar 비선택 아이콘/텍스트
  static const navUnselected = textSecondary;

  // ── 포인트 / 강조 ─────────────────────────────────────────────
  /// 주 포인트 색상 (버튼, 하이라이트): Green
  static const accent   = blue;
  /// Accent 위 텍스트/아이콘: White
  static const onAccent = white;

  // ── 구분선 ───────────────────────────────────────────────────
  /// 카드 내부 VerticalDivider / Divider 색상
  static const divider = Color(0xFFE2DDD6);

  // ── 크림 화이트 (진한 배경 위 부드러운 강조 텍스트) ──────────────
  /// Green/Orange 카드 등 진한 배경 위 부드러운 화이트 텍스트
  /// 나중에 색상 변경 시 이 토큰 한 곳만 수정하면 전체 반영됨
  static const creamWhite = Color(0xFFFDFAF5);

  // ── 퀴즈 배지 (공감투표 '이번 주'와 동일 법칙) ───────────────────
  /// 퀴즈 Q1/Q2 배지 배경 = cardEmphasis (주황)
  /// → 2번탭 공감투표 '이번 주' 배지와 동일 토큰 참조
  /// 나중에 cardEmphasis 색 바꾸면 두 곳 모두 자동 반영
  static const quizBadgeBg   = cardEmphasis;   // 주황
  /// 퀴즈 Q1/Q2 배지 텍스트 = onCardEmphasis (검정)
  static const quizBadgeText = onCardEmphasis; // 검정

  // ── 의미 컬러 (퀴즈, 상태) — 고정값 ──────────────────────────
  static const quizCorrect       = Color(0xFF00E676);
  static const quizCorrectBg     = Color(0xFFE8FFF0);
  static const quizCorrectBorder = Color(0xFF69F0AE);
  static const quizWrong         = Color(0xFFFF1744);
  static const quizWrongBg       = Color(0xFFFFE8EC);
  static const quizWrongBorder   = Color(0xFFFF5252);
  static const success           = Color(0xFF00E676);
  static const warning           = Color(0xFFFF9100);
  static const error             = Color(0xFFFF1744);
}
