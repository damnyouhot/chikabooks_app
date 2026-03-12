import 'package:flutter/material.dart';
import 'app_colors.dart';

/// ══════════════════════════════════════════════════════════════
/// AppStyle — 앱 전체 공용 스타일 헬퍼
///
/// 사용법:
///   Container(decoration: AppStyle.primaryCardDecoration())
///   Container(decoration: AppStyle.emphasisCardDecoration())
///   Container(decoration: AppStyle.mutedSurfaceDecoration())
///   Container(decoration: AppStyle.segmentContainerDecoration())
///
/// 원칙:
///   - 그림자(BoxShadow) 없음
///   - 테두리(Border/BorderSide) 없음
///   - 색상은 반드시 AppColors 토큰만 참조
///   - radius 기본값은 각 역할에 맞게 설정, 필요 시 오버라이드
/// ══════════════════════════════════════════════════════════════
class AppStyle {
  AppStyle._();

  // ══════════════════════════════════════════════════════════════
  // 📦 카드 Decoration
  // ══════════════════════════════════════════════════════════════

  /// 일반 카드: Blue 배경, 그림자/테두리 없음
  /// 위 텍스트/아이콘은 AppColors.onCardPrimary (White) 사용
  static BoxDecoration primaryCardDecoration({double radius = 16}) {
    return BoxDecoration(
      color: AppColors.cardPrimary,
      borderRadius: BorderRadius.circular(radius),
    );
  }

  /// 강조 카드: Neon Lime 배경, 그림자/테두리 없음
  /// 위 텍스트/아이콘은 AppColors.onCardEmphasis (Black) 사용
  static BoxDecoration emphasisCardDecoration({double radius = 16}) {
    return BoxDecoration(
      color: AppColors.cardEmphasis,
      borderRadius: BorderRadius.circular(radius),
    );
  }

  /// Muted surface: 연한 회색 배경 (세그먼트 컨테이너, 비활성 섹션)
  /// 위 텍스트는 AppColors.onSurfaceMuted 사용
  static BoxDecoration mutedSurfaceDecoration({double radius = 12}) {
    return BoxDecoration(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(radius),
    );
  }

  /// Disabled 영역: 더 연한 회색 배경
  static BoxDecoration disabledDecoration({double radius = 12}) {
    return BoxDecoration(
      color: AppColors.disabledBg,
      borderRadius: BorderRadius.circular(radius),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // 🔘 세그먼트 / 필터 / 탭 버튼 Decoration
  // ══════════════════════════════════════════════════════════════

  /// 세그먼트 외부 컨테이너: surfaceMuted 배경
  static BoxDecoration segmentContainerDecoration({double radius = 10}) {
    return BoxDecoration(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(radius),
    );
  }

  /// 세그먼트 선택 아이템: Blue 배경
  static BoxDecoration segmentSelectedDecoration({double radius = 8}) {
    return BoxDecoration(
      color: AppColors.segmentSelected,
      borderRadius: BorderRadius.circular(radius),
    );
  }

  /// 세그먼트 미선택 아이템: 투명 배경
  static BoxDecoration segmentUnselectedDecoration({double radius = 8}) {
    return BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // 🅰️ 텍스트 스타일 (공용)
  // ══════════════════════════════════════════════════════════════

  /// 일반 카드 위 본문 텍스트 (White)
  static const TextStyle cardPrimaryBody = TextStyle(
    color: AppColors.onCardPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  /// 일반 카드 위 제목 텍스트 (White, Bold)
  static const TextStyle cardPrimaryTitle = TextStyle(
    color: AppColors.onCardPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );

  /// 강조 카드 위 본문 텍스트 (Black)
  static const TextStyle cardEmphasisBody = TextStyle(
    color: AppColors.onCardEmphasis,
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  /// 강조 카드 위 제목 텍스트 (Black, Bold)
  static const TextStyle cardEmphasisTitle = TextStyle(
    color: AppColors.onCardEmphasis,
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );

  /// 앱 배경 위 주요 텍스트 (Black)
  static const TextStyle bodyPrimary = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  /// 앱 배경 위 보조 텍스트 (진한 회색)
  static const TextStyle bodySecondary = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );

  /// 섹션 타이틀 텍스트 (Black, Bold)
  static const TextStyle sectionTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );

  // ══════════════════════════════════════════════════════════════
  // 🔲 버튼 스타일
  // ══════════════════════════════════════════════════════════════

  /// 주 버튼: Blue 배경, White 텍스트
  static ButtonStyle primaryButtonStyle({double radius = 12}) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.onAccent,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  /// 강조 버튼: Neon 배경, Black 텍스트
  static ButtonStyle emphasisButtonStyle({double radius = 12}) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.cardEmphasis,
      foregroundColor: AppColors.onCardEmphasis,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  /// 보조 버튼: surfaceMuted 배경, textSecondary 텍스트
  static ButtonStyle mutedButtonStyle({double radius = 12}) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.surfaceMuted,
      foregroundColor: AppColors.textSecondary,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}



