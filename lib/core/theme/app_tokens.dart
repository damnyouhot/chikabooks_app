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
  static const double formSectionSpacing = 46.0;

  /// 섹션 제목(기본 정보·병원 정보…) — 본문 14pt 대비 1.5배
  static const double formSectionTitleSize = 21.0;

  /// 섹션 제목 아래 → 필드 블록
  static const double formSectionTitleGap = 26.0;

  /// 필드 블록 → 다음 파트 전 내부 하단 여백 (Divider 없음)
  static const double formSectionBottomGap = 38.0;

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

  /// 웹 공고 미리보기 [JobPostPreview] 블록 사이 [Divider] 높이(세로 여백)
  static const double previewSectionDividerHeight = 28.0;
}

/// 웹 일반계정(지원자) 플로우 — 공고 보드/상세, /me 사이드바 셸 공통 규격
///
/// 단일 소스 원칙: 헤더 높이·사이드바 폭·카드 라운드 등 일반계정 영역 전반에서
/// 사용하는 값은 모두 여기에서 정의한다. 같은 값을 위젯마다 하드코딩하지 않는다.
class AppApplicant {
  AppApplicant._();

  // ── 글로벌 셸 ─────────────────────────────────────────────────
  /// 상단 글로벌 헤더 높이 (로고/검색바/알림/프로필 버튼)
  static const double topBarHeight = 64.0;

  /// 좌측 사이드바 펼침 폭
  static const double sideNavWidth = 240.0;

  /// 좌측 사이드바 접힘 폭 (아이콘만)
  static const double sideNavCollapsedWidth = 72.0;

  /// 사이드바 / 본문 분기 브레이크포인트 (이 미만은 사이드바 숨김 + 햄버거 메뉴)
  static const double sideNavBreakpoint = 960.0;

  /// 본문 좌우 최대 너비 (가독성을 위한 컨텐츠 폭 제한)
  static const double contentMaxWidth = 1200.0;

  /// 본문 좌우 패딩 (브레이크포인트 이상에서)
  static const double contentHPadding = 32.0;

  /// 본문 좌우 패딩 (모바일/좁은 폭)
  static const double contentHPaddingNarrow = 16.0;

  // ── 카드 / 모듈 ────────────────────────────────────────────────
  /// 공고 카드 / 대시보드 카드 공통 라운드
  static const double cardRadius = 14.0;

  /// 공고 카드 그림자 blur
  static const double cardShadowBlur = 18.0;

  /// 등급별 섹션 사이 세로 간격
  static const double sectionSpacing = 40.0;

  /// 섹션 헤더 ↔ 본문(카드 그리드) 간격
  static const double sectionHeaderGap = 16.0;

  // ── 등급 배지 ─────────────────────────────────────────────────
  /// 프리미엄(레벨 1) 카드 강조 라운드
  static const double premiumCardRadius = 18.0;

  /// 추천(레벨 2) 그리드 카드 라운드
  static const double recommendedCardRadius = 14.0;

  /// 일반(레벨 3) 리스트 카드 라운드 — 행 형태라 작게
  static const double standardCardRadius = 10.0;

  // ── 공고 카드 그리드 ───────────────────────────────────────────
  /// 추천 카드 그리드 최소 카드 폭 (이 폭으로 칸 수 자동 계산)
  static const double recommendedMinCardWidth = 280.0;

  /// 추천 카드 그리드 카드 간 가로/세로 간격
  static const double recommendedCardGap = 16.0;

  /// 프리미엄(레벨 1) 카드 그리드 최소 카드 폭.
  ///
  /// 추천 카드보다 살짝 큰 폭을 두어 시각적 위계를 만든다.
  /// 본문 폭(`contentMaxWidth - sideNav`)에 따라 1~3열로 자동 분할된다.
  static const double premiumMinCardWidth = 320.0;

  /// 프리미엄 카드 그리드 카드 간 가로/세로 간격
  static const double premiumCardGap = 14.0;

  // ── 사이드바 항목 ─────────────────────────────────────────────
  /// 사이드바 메뉴 항목 높이
  static const double sideNavItemHeight = 44.0;

  /// 사이드바 섹션(공고/같이/성장/내정보) 사이 간격
  static const double sideNavSectionGap = 18.0;
}
