/// ══════════════════════════════════════════════════════════════
/// AppRadius — 앱 전체 radius 단일 소스
///
/// 사용법:
///   borderRadius: BorderRadius.circular(AppRadius.lg)
///   borderRadius: BorderRadius.circular(AppRadius.full) // 원형
/// ══════════════════════════════════════════════════════════════
class AppRadius {
  AppRadius._();

  /// 아주 작은 radius (선택지 뱃지 등)
  static const double xs   = 6.0;
  /// 작은 radius (버튼 내부 요소, 소형 뱃지)
  static const double sm   = 8.0;
  /// 기본 radius (버튼, 선택지 옵션, 탭바 인디케이터)
  static const double md   = 10.0;
  /// 카드 radius (대부분의 리스트 타일 카드)
  static const double lg   = 14.0;
  /// 큰 카드 radius (퀴즈 카드, 성적 카드 등 섹션 카드)
  static const double xl   = 16.0;
  /// 원형 (뱃지, pill 버튼)
  static const double full = 999.0;
}

/// ══════════════════════════════════════════════════════════════
/// AppSpacing — 앱 전체 spacing/padding 단일 소스
///
/// 사용법:
///   padding: EdgeInsets.all(AppSpacing.md)
///   SizedBox(height: AppSpacing.sm)
/// ══════════════════════════════════════════════════════════════
class AppSpacing {
  AppSpacing._();

  /// 4px — 아이콘-텍스트 간격, 최소 여백
  static const double xs  = 4.0;
  /// 8px — 카드 내 항목 간격
  static const double sm  = 8.0;
  /// 12px — 카드 내 섹션 간격, 리스트 아이템 간격
  static const double md  = 12.0;
  /// 16px — 카드 기본 패딩, 리스트 패딩
  static const double lg  = 16.0;
  /// 20px — 페이지 좌우 패딩
  static const double xl  = 20.0;
  /// 24px — 섹션 간격
  static const double xxl = 24.0;
}

