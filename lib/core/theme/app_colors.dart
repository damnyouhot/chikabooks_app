import 'package:flutter/material.dart';

/// ══════════════════════════════════════════════════════════
/// AppColors — 앱 전체 컬러 토큰
/// 여기서만 수치를 바꾸면 전체 앱 컬러가 변경됩니다.
/// ══════════════════════════════════════════════════════════
class AppColors {
  AppColors._();

  // ── Level 1: Primitive (원시값 — 직접 사용 금지) ──────────
  static const _white    = Color(0xFFFFFFFF);
  static const _lime     = Color(0xFFD1FF00);
  static const _black    = Color(0xFF000000);
  static const _blue     = Color(0xFF2E5BFF);

  // ── Level 2: Semantic (의미 토큰) ─────────────────────────

  /// 포인트 컬러: 버튼, 배지, 하이라이트, 선택 상태
  static const accent   = _lime;          // #D1FF00 라임

  /// 기본 텍스트 컬러
  static const text     = _black;         // #000000 블랙

  /// 앱 배경 컬러
  static const bg       = _blue;          // #2E5BFF 블루

  /// 카드 배경 (흰색)
  static const cardBg   = _white;         // #FFFFFF 흰색

  // ── Level 3: Derived (파생 토큰) ───────────────────────────

  /// 서브 배경: bg보다 살짝 밝은 블루 (카드 내부 구분용)
  static const bgSub    = Color(0xFF4A6FFF);  // 밝은 블루

  /// 비활성/경계선: bg 기반 연한 블루
  static const shadow   = Color(0xFF8AAEFF);  // 연블루 (테두리, 구분선)

  /// 비활성 요소 (칩, 비선택 상태)
  static const muted    = Color(0xFFCCD6FF);  // 매우 연한 블루

  /// 카드 내부 서브 배경
  static const surfaceCard  = Color(0xFFF0F3FF);  // 블루 틴트 화이트
  static const surfaceInput = Color(0xFFE8EDFF);  // 입력 필드 배경
  static const surfaceChip  = Color(0xFFDDE4FF);  // 칩/태그 배경

  // ── Level 4: Component Override (의도적 예외) ─────────────

  /// 퀴즈 정답 (의미 컬러 — accent와 무관하게 유지)
  static const quizCorrect        = Color(0xFF00E676);  // 라임 계열 초록
  static const quizCorrectBg      = Color(0xFFE8FFF0);
  static const quizCorrectBorder  = Color(0xFF69F0AE);

  /// 퀴즈 오답 (의미 컬러)
  static const quizWrong          = Color(0xFFFF1744);
  static const quizWrongBg        = Color(0xFFFFE8EC);
  static const quizWrongBorder    = Color(0xFFFF5252);

  /// 성공 상태 (커리어 최고 단계 등)
  static const success = Color(0xFF00E676);

  /// 경고 상태
  static const warning = Color(0xFFFF9100);

  /// 커리어 탭 전용 블루 (탭 내부 독립 포인트)
  static const careerBlue       = Color(0xFF2E5BFF);  // bg와 동일, 명시적 분리
  static const careerBlueMuted  = Color(0xFFE8EDFF);

  // ── 편의 메서드 ────────────────────────────────────────────
  static Color accentWith(double opacity)  => accent.withOpacity(opacity);
  static Color textWith(double opacity)    => text.withOpacity(opacity);
  static Color bgWith(double opacity)      => bg.withOpacity(opacity);
  static Color shadowWith(double opacity)  => shadow.withOpacity(opacity);
  static Color cardBgWith(double opacity)  => cardBg.withOpacity(opacity);

  // ── 공통 카드 데코레이션 ────────────────────────────────────
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
}

