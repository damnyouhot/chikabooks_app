import 'package:flutter/material.dart';

/// 결 탭 디자인 팔레트
/// White(#FFFFFF) bg + Blue(#2E5BFF) accent
/// Inversion Rule: White bg → Black text/icon
class BondColors {
  BondColors._();

  static const kBg      = Color(0xFFFFFFFF);  // 배경: 흰색
  static const kAccent  = Color(0xFF2E5BFF);  // 포인트: 블루
  static const kText    = Color(0xFF000000);  // 텍스트: 블랙 (Inversion)
  static const kCardBg  = Color(0xFFF5F7FF);  // 카드 배경: 연블루틴트
  static const kShadow1 = Color(0xFFD0D8FF);  // 그림자/구분선
  static const kShadow2 = Color(0xFFEEF1FF);  // 연한 구분선
  static const kMuted   = Color(0xFF888888);  // 비활성 텍스트 (Grey→Black계열)
  static const kSurface = Color(0xFFF0F3FF);  // 서브 표면

  /// 공통 카드 데코레이션
  static BoxDecoration cardDecoration({double radius = 16}) {
    return BoxDecoration(
      color: kCardBg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: kShadow1.withOpacity(0.5), width: 0.8),
      boxShadow: [
        BoxShadow(
          color: kAccent.withOpacity(0.08),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }
}
