import 'package:flutter/material.dart';

/// ══════════════════════════════════════════════════════════════
/// AppColors — 앱 전체 컬러 토큰 (단일 소스)
///
/// 🎨 모드 전환 방법:
///   아래 4가지 Primitive 중 원하는 색상값만 변경하면
///   tab_theme.dart → 각 탭 → 전체 UI가 자동 반영됩니다.
///
/// ┌─────────────┬───────────┬───────────┬───────────┬──────────┐
/// │   Mode      │    bg     │   text    │  accent   │ 가독성비  │
/// ├─────────────┼───────────┼───────────┼───────────┼──────────┤
/// │ White Mode  │ #FFFFFF   │ #000000   │ #2E5BFF   │  21:1    │
/// │ Neon Mode   │ #D1FF00   │ #000000   │ #FFFFFF   │ 14.2:1   │
/// │ Black Mode  │ #000000   │ #FFFFFF   │ #D1FF00   │  21:1    │
/// │ Blue Mode   │ #2E5BFF   │ #FFFFFF   │ #D1FF00   │  5.4:1   │
/// └─────────────┴───────────┴───────────┴───────────┴──────────┘
/// ══════════════════════════════════════════════════════════════
class AppColors {
  AppColors._();

  // ══════════════════════════════════════════════════════════════
  // 🎨 Primitive — 여기 4개만 바꾸면 tab_theme → 전체 앱 반영
  // ══════════════════════════════════════════════════════════════
  static const white = Color(0xFFFFFFFF);
  static const lime  = Color(0xFFD1FF00);
  static const black = Color(0xFF000000);
  static const blue  = Color(0xFF2E5BFF);

  // ── 카드 배경 — 항상 흰색 고정 ──────────────────────────────
  static const cardBg = white;

  // ── 의미 컬러 (모드 무관 고정) ────────────────────────────────
  static const quizCorrect       = Color(0xFF00E676);
  static const quizCorrectBg     = Color(0xFFE8FFF0);
  static const quizCorrectBorder = Color(0xFF69F0AE);
  static const quizWrong         = Color(0xFFFF1744);
  static const quizWrongBg       = Color(0xFFFFE8EC);
  static const quizWrongBorder   = Color(0xFFFF5252);
  static const success           = Color(0xFF00E676);
  static const warning           = Color(0xFFFF9100);

  // ── 공통 카드 데코레이션 ─────────────────────────────────────────
  static BoxDecoration cardDecoration({double radius = 16}) {
    return BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: blue.withOpacity(0.2), width: 0.8),
      boxShadow: [
        BoxShadow(
          color: blue.withOpacity(0.10),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
