import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// 결 탭 디자인 팔레트
/// TabTheme.bond: White(#FFFFFF) bg + Blue(#2E5BFF) + Neon(#D1FF00) 포인트
/// 색상 변경 → app_colors.dart Primitive만 수정하면 자동 반영
/// Inversion Rule: Blue/Dark bg → White text | Neon bg → Black text
class BondColors {
  BondColors._();

  // ── 기본 팔레트 (AppColors Primitive 참조) ────────────────
  static const kBg      = AppColors.white;   // 배경: 흰색
  static const kAccent  = AppColors.blue;    // 포인트: 블루
  static const kNeon    = AppColors.lime;    // 형광: 라임
  static const kText    = AppColors.black;   // 기본 텍스트: 블랙
  static const kCardBg  = Color(0xFFF5F7FF); // 일반 카드 배경 (파생값)
  static const kShadow1 = Color(0xFFD0D8FF); // 그림자/구분선 (파생값)
  static const kShadow2 = Color(0xFFEEF1FF); // 연한 구분선 (파생값)
  static const kMuted   = Color(0xFF888888); // 비활성 텍스트

  // ── Inversion: 채워진 카드 위 글씨 ────────────────────────
  static const kOnAccent = AppColors.white;  // Blue 배경 → White
  static const kOnNeon   = AppColors.black;  // Neon 배경 → Black
  static const kOnDark   = AppColors.white;  // Dark 배경 → White
  static const kDarkCard = Color(0xFF111111);// Dark 카드 배경

  // ── 카드 데코레이션 ────────────────────────────────────────

  /// 기본 흰 카드
  static BoxDecoration cardDecoration({double radius = 16}) {
    return BoxDecoration(
      color: kCardBg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: kShadow1.withOpacity(0.5), width: 0.8),
      boxShadow: [
        BoxShadow(
          color: kAccent.withOpacity(0.07),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  /// Blue 채운 카드 (파트너 요약 등)
  static BoxDecoration blueCardDecoration({double radius = 16}) {
    return BoxDecoration(
      color: kAccent,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: kAccent.withOpacity(0.35),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  /// Neon 채운 카드 (스탬프 등)
  static BoxDecoration neonCardDecoration({double radius = 16}) {
    return BoxDecoration(
      color: kNeon,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: kNeon.withOpacity(0.45),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  /// Dark 채운 카드 (투표 등)
  static BoxDecoration darkCardDecoration({double radius = 16}) {
    return BoxDecoration(
      color: kDarkCard,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.25),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
