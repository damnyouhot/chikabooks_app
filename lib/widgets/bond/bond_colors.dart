import 'package:flutter/material.dart';

/// 결 탭 디자인 팔레트 (1탭과 통일)
class BondColors {
  static const kAccent = Color(0xFFF7CBCA);
  static const kText = Color(0xFF5D6B6B);
  static const kBg = Color(0xFFF1F7F7);
  static const kShadow1 = Color(0xFFDDD3D8);
  static const kShadow2 = Color(0xFFD5E5E5);
  static const kCardBg = Colors.white;

  /// 공통 카드 데코레이션
  static BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: kCardBg,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: kShadow2.withOpacity(0.3),
        width: 0.5,
      ),
      boxShadow: [
        BoxShadow(
          color: kShadow1.withOpacity(0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}



