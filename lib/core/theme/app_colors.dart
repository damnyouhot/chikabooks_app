import 'package:flutter/material.dart';

/// ══════════════════════════════════════════════════════════════
/// AppColors — 앱 전체 컬러 단일 소스
///
/// 🎨 색상 변경 방법:
///   Primitive 4개(white/lime/black/blue)만 수정하면
///   Semantic Token → 전체 앱 UI에 자동 반영됩니다.
///
/// 디자인 원칙:
///   - 앱 배경: soft gray (#F7F8FA)
///   - 일반 카드: Blue 배경 + White 텍스트
///   - 강조 카드: Neon Lime 배경 + Black 텍스트
///   - 그림자 없음 / 테두리 없음 / 탭별 컬러 차이 없음
///
/// 반전 법칙:
///   Blue / Black 채운 요소 → White 텍스트/아이콘
///   Neon / White 채운 요소 → Black 텍스트/아이콘
/// ══════════════════════════════════════════════════════════════
class AppColors {
  AppColors._();

  // ══════════════════════════════════════════════════════════════
  // 🎨 Primitive — 여기 4개만 바꾸면 전체 앱 색상이 바뀝니다
  // ══════════════════════════════════════════════════════════════
  static const white = Color(0xFFFFFFFF);
  static const lime  = Color(0xFFD1FF00);
  static const black = Color(0xFF000000);
  static const blue  = Color(0xFF2E5BFF);

  // ══════════════════════════════════════════════════════════════
  // 🏗️ Semantic Token — 역할 기반 색상 (Primitive 참조)
  // ══════════════════════════════════════════════════════════════

  // ── 앱 전체 배경 ──────────────────────────────────────────────
  /// 앱 Scaffold 배경: 매우 연한 회색 (카드와 대비)
  static const appBg = Color(0xFFF7F8FA);

  // ── 텍스트 ──────────────────────────────────────────────────
  /// 주요 텍스트: Pure Black (최대 대비)
  static const textPrimary = black;
  /// 보조 텍스트: 진한 회색
  static const textSecondary = Color(0xFF555555);
  /// 비활성 텍스트
  static const textDisabled = Color(0xFF999999);

  // ── 카드 시스템 (2종) ────────────────────────────────────────
  /// 일반 카드 배경: Blue
  static const cardPrimary   = blue;
  /// 일반 카드 위 텍스트/아이콘: White
  static const onCardPrimary = white;

  /// 강조 카드 배경: Neon Lime
  static const cardEmphasis   = lime;
  /// 강조 카드 위 텍스트/아이콘: Black
  static const onCardEmphasis = black;

  // ── 서피스 / 비활성 영역 ──────────────────────────────────────
  /// Muted surface: 연한 회색 (세그먼트 컨테이너, 비활성 배경)
  static const surfaceMuted  = Color(0xFFEEF0F5);
  /// Muted surface 위 텍스트
  static const onSurfaceMuted = textSecondary;

  /// Disabled 배경
  static const disabledBg   = Color(0xFFDDDEE2);
  /// Disabled 텍스트
  static const disabledText = Color(0xFFAAADB5);

  // ── 세그먼트/필터/탭 버튼 ─────────────────────────────────────
  /// 세그먼트 선택: Blue fill
  static const segmentSelected   = blue;
  /// 세그먼트 선택 텍스트: White
  static const onSegmentSelected = white;
  /// 세그먼트 미선택: 투명 (surfaceMuted 컨테이너 위)
  static const segmentUnselected   = Color(0x00000000); // transparent
  /// 세그먼트 미선택 텍스트: textSecondary
  static const onSegmentUnselected = textSecondary;

  // ── 내비게이션 바 ────────────────────────────────────────────
  /// BottomNavBar 배경: White
  static const navBg         = white;
  /// BottomNavBar 선택 아이콘/텍스트: Blue
  static const navSelected   = blue;
  /// BottomNavBar 비선택 아이콘/텍스트
  static const navUnselected = textSecondary;

  // ── 포인트 / 강조 ─────────────────────────────────────────────
  /// 주 포인트 색상 (버튼, 하이라이트): Blue
  static const accent   = blue;
  /// Accent 위 텍스트/아이콘: White
  static const onAccent = white;

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
