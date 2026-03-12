import 'package:flutter/material.dart';

/// ══════════════════════════════════════════════════════════════
/// AppColors — 앱 전체 컬러 토큰 (단일 소스)
///
/// 🎨 모드 전환 방법:
///   아래 [ACTIVE MODE] 섹션에서 원하는 모드 3줄을 주석 해제하고
///   나머지 3줄을 주석 처리하면 전체 앱 컬러가 즉시 변경됩니다.
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

  // ── Primitive (원시값 팔레트 — 직접 사용 금지) ─────────────────
  static const _white = Color(0xFFFFFFFF);
  static const _lime  = Color(0xFFD1FF00);
  // ignore: unused_field
  static const _black = Color(0xFF000000);  // White/Neon Mode에서 사용
  static const _blue  = Color(0xFF2E5BFF);

  // ════════════════════════════════════════════════════════════
  // 🎨 [ACTIVE MODE] — 원하는 모드만 주석 해제
  // ════════════════════════════════════════════════════════════

  // ── White Mode (bg=흰, text=검, accent=파랑) ──────────────────
  // static const bg      = _white;
  // static const text    = _black;
  // static const accent  = _blue;

  // ── Neon Mode (bg=라임, text=검, accent=흰) ───────────────────
  // ⚠️ Inversion Rule: 라임 배경 → 흰 글씨 절대 금지, 검정만 사용
  // static const bg      = _lime;
  // static const text    = _black;
  // static const accent  = _white;

  // ── Black Mode (bg=검, text=흰, accent=라임) ──────────────────
  // static const bg      = _black;
  // static const text    = _white;
  // static const accent  = _lime;

  // ── Blue Mode (bg=파랑, text=흰, accent=라임) — 현재 활성 ──────
  static const bg      = _blue;
  static const text    = _white;
  static const accent  = _lime;

  // ════════════════════════════════════════════════════════════

  /// 카드 배경 — 항상 흰색 고정 (모드에 무관)
  static const cardBg = _white;

  // ── 모드별 파생 토큰 ────────────────────────────────────────────
  // (현재 Blue Mode 기준. 모드 변경 시 함께 수동 교체 필요)

  /// 배경보다 약간 밝은 서브 배경
  static const bgSub = Color(0xFF4A6FFF);       // Blue: 밝은 파랑

  /// 테두리/구분선
  static const shadow = Color(0xFF8AAEFF);      // Blue: 연파랑

  /// 비활성 요소 (칩, 비선택)
  static const muted = Color(0xFFCCD6FF);       // Blue: 매우 연한 파랑

  /// 카드 내부 서브 표면
  static const surfaceCard  = Color(0xFFF0F3FF);
  static const surfaceInput = Color(0xFFE8EDFF);
  static const surfaceChip  = Color(0xFFDDE4FF);

  // ── 의미 컬러 (모드 무관 고정) ────────────────────────────────
  static const quizCorrect       = Color(0xFF00E676);
  static const quizCorrectBg     = Color(0xFFE8FFF0);
  static const quizCorrectBorder = Color(0xFF69F0AE);
  static const quizWrong         = Color(0xFFFF1744);
  static const quizWrongBg       = Color(0xFFFFE8EC);
  static const quizWrongBorder   = Color(0xFFFF5252);
  static const success           = Color(0xFF00E676);
  static const warning           = Color(0xFFFF9100);

  /// 커리어 탭 전용 포인트 블루
  static const careerBlue      = Color(0xFF2E5BFF);
  static const careerBlueMuted = Color(0xFFE8EDFF);

  // ── 편의 메서드 ─────────────────────────────────────────────────
  static Color accentWith(double opacity)  => accent.withOpacity(opacity);
  static Color textWith(double opacity)    => text.withOpacity(opacity);
  static Color bgWith(double opacity)      => bg.withOpacity(opacity);
  static Color shadowWith(double opacity)  => shadow.withOpacity(opacity);
  static Color cardBgWith(double opacity)  => cardBg.withOpacity(opacity);

  // ── 공통 카드 데코레이션 ─────────────────────────────────────────
  static BoxDecoration cardDecoration({double radius = 16}) {
    return BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: shadow.withOpacity(0.35), width: 0.8),
      boxShadow: [
        BoxShadow(
          color: bg.withOpacity(0.18),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  // 📋 모드 전환 가이드 (파생 토큰 세트)
  //
  // White Mode로 바꿀 때 bgSub/shadow/muted/surface* 도 아래로 교체:
  //   bgSub        = Color(0xFFF5F7FF)
  //   shadow       = Color(0xFFD0D8FF)
  //   muted        = Color(0xFFEEF1FF)
  //   surfaceCard  = Color(0xFFF8F9FF)
  //   surfaceInput = Color(0xFFF3F5FF)
  //   surfaceChip  = Color(0xFFECEFFF)
  //
  // Neon Mode로 바꿀 때:
  //   bgSub        = Color(0xFFE8FF4D)   ← 라임보다 약간 어두운 노랑
  //   shadow       = Color(0xFFB8E600)   ← 라임보다 진한 경계선
  //   muted        = Color(0xFF000000)   ← 검정 계열 비활성
  //   surfaceCard  = Color(0xFFF5FFB3)
  //   surfaceInput = Color(0xFFEEFF99)
  //   surfaceChip  = Color(0xFFE5FF66)
  //
  // Black Mode로 바꿀 때:
  //   bgSub        = Color(0xFF1A1A1A)   ← 카드 구분용 미세 어두운 검정
  //   shadow       = Color(0xFF333333)   ← 경계선
  //   muted        = Color(0xFF555555)   ← 비활성
  //   surfaceCard  = Color(0xFF111111)
  //   surfaceInput = Color(0xFF1A1A1A)
  //   surfaceChip  = Color(0xFF222222)
  // ════════════════════════════════════════════════════════════
}
