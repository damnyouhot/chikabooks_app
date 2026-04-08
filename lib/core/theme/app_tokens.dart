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
  static const double xs = 6.0;

  /// 작은 radius (버튼 내부 요소, 소형 뱃지)
  static const double sm = 8.0;

  /// 기본 radius (버튼, 선택지 옵션, 탭바 인디케이터)
  static const double md = 10.0;

  /// 카드 radius (대부분의 리스트 타일 카드)
  static const double lg = 14.0;

  /// 큰 카드 radius (퀴즈 카드, 성적 카드 등 섹션 카드)
  static const double xl = 16.0;

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
  static const double xs = 4.0;

  /// 8px — 카드 내 항목 간격
  static const double sm = 8.0;

  /// 12px — 카드 내 섹션 간격, 리스트 아이템 간격
  static const double md = 12.0;

  /// 16px — 카드 기본 패딩, 리스트 패딩
  static const double lg = 16.0;

  /// 20px — 페이지 좌우 패딩
  static const double xl = 20.0;

  /// 24px — 섹션 간격
  static const double xxl = 24.0;
}

/// 웹 공고자(게시자) 플로우 — 로그인 카드·공고 폼 공통 규격
class AppPublisher {
  AppPublisher._();

  /// 로그인 파트 주요 CTA와 동일 높이 (`web_login_page` ElevatedButton 48)
  static const double ctaHeight = 48.0;

  /// 칩·체크박스·썸네일·스낵 등 — 거의 직각에 가까운 약한 라운드
  static const double softRadius = 3.0;

  /// 주요 Outlined/Elevated CTA — `softRadius` 보다 한 단계 더 라운드
  static const double buttonRadius = 8.0;

  /// `JobPostForm(publisherWebStyle)` 파트 ↔ 파트 세로 간격 (구분선 없이 여백만)
  static const double formSectionSpacing = 40.0;

  /// 섹션 제목(기본 정보·병원 정보…) — 본문 14pt 대비 1.5배
  static const double formSectionTitleSize = 21.0;

  /// 섹션 제목 아래 → 필드 블록
  static const double formSectionTitleGap = 22.0;

  /// 필드 블록 → 다음 파트 전 내부 하단 여백 (Divider 없음)
  static const double formSectionBottomGap = 32.0;

  /// 복리·근무요일·지원방법 등 Wrap 칩 가로/세로 간격
  static const double formChipSpacing = 12.0;
  static const double formChipRunSpacing = 10.0;

  /// 병원 정보 등 나란히 두 필드 사이
  static const double formFieldRowGap = 20.0;

  /// 웹 편집기 step3: 라벨 열 고정 폭 (한 줄 라벨 + 입력)
  static const double formInlineLabelWidth = 108.0;

  /// 이미지 행·보조 버튼 줄 사이 가로 간격
  static const double formButtonRowGap = 14.0;

  /// 웹 공고 자료 입력(`/post-job/input`) 흰 패널·임시저장 카드 모서리 — [AppRadius.md]와 동일 스케일
  static const double inputPanelRadius = 10.0;
}
