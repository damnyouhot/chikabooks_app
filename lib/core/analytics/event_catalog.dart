// ignore_for_file: constant_identifier_names
//
// ═══════════════════════════════════════════════════════════════════════════
// 분석 이벤트 단일 카탈로그 (A파트)
//
// - activityLogs.type 문자열의 유일한 메타데이터 출처
// - Feature(탭 그룹), Behavior(meaningful), 온보딩 퍼널 단계 정의에 공통 사용
// - 새 이벤트 추가 시: 이 파일만 수정하고 enum value 문자열과 일치시킬 것
// ═══════════════════════════════════════════════════════════════════════════

/// 탭(기능 반응 그룹) 구분 — UI 섹션 헤더와 동일한 문자열
abstract final class EventTab {
  static const String na = '나';
  static const String bond = '같이';
  static const String growth = '성장';
  static const String career = '커리어';
  static const String job = '구직';
  static const String auth = '인증·설정';
  static const String publisher = '공고자';
  static const String other = '기타';
}

/// 단일 이벤트 메타
class EventMeta {
  const EventMeta({
    required this.type,
    required this.labelKo,
    required this.tab,
    this.funnelStep,
    this.meaningfulBehavior = false,
  });

  /// activityLogs.type (snake_case)
  final String type;

  /// 관리자 UI 등 표시용 한글
  final String labelKo;

  /// [EventTab] 상수
  final String tab;

  /// 온보딩 순차 퍼널 단계 (1~5). 해당 없으면 null
  final int? funnelStep;

  /// Behavior 탭 «의미 있는 행동» 집계에 포함
  final bool meaningfulBehavior;
}

/// 전체 카탈로그 (알파벳 순이 아님 — 읽기 쉬운 그룹 순)
const Map<String, EventMeta> kEventCatalog = {
  // ── 온보딩 퍼널 전용 (isFunnel: true 로 기록) ─────────────────
  'funnel_step_2_feed': EventMeta(
    type: 'funnel_step_2_feed',
    labelKo: '캐릭터 밥주기 (온보딩)',
    tab: EventTab.na,
    funnelStep: 2,
    meaningfulBehavior: false,
  ),
  'funnel_step_3_poll': EventMeta(
    type: 'funnel_step_3_poll',
    labelKo: '공감투표 선택 (온보딩)',
    tab: EventTab.bond,
    funnelStep: 3,
    meaningfulBehavior: false,
  ),
  'funnel_step_4_quiz': EventMeta(
    type: 'funnel_step_4_quiz',
    labelKo: '퀴즈 첫 풀이 (온보딩)',
    tab: EventTab.growth,
    funnelStep: 4,
    meaningfulBehavior: false,
  ),
  'funnel_step_5_career_specialty': EventMeta(
    type: 'funnel_step_5_career_specialty',
    labelKo: '전문분야 등록 (온보딩)',
    tab: EventTab.career,
    funnelStep: 5,
    meaningfulBehavior: false,
  ),

  // ── 레거시 퍼널 (기존 로그 호환, 집계에서는 신규 퍼널과 별도) ──
  'funnel_signup_complete': EventMeta(
    type: 'funnel_signup_complete',
    labelKo: '회원가입 완료 (레거시)',
    tab: EventTab.auth,
    meaningfulBehavior: false,
  ),
  'funnel_profile_basic': EventMeta(
    type: 'funnel_profile_basic',
    labelKo: '기본 프로필 완료 (레거시)',
    tab: EventTab.auth,
    meaningfulBehavior: false,
  ),
  'funnel_first_emotion_start': EventMeta(
    type: 'funnel_first_emotion_start',
    labelKo: '첫 감정기록 시작 (레거시)',
    tab: EventTab.na,
    meaningfulBehavior: false,
  ),
  'funnel_first_emotion_complete': EventMeta(
    type: 'funnel_first_emotion_complete',
    labelKo: '첫 감정기록 완료 (레거시)',
    tab: EventTab.na,
    meaningfulBehavior: false,
  ),

  // ── 화면 진입 ───────────────────────────────────────────────
  'view_sign_in_page': EventMeta(
    type: 'view_sign_in_page',
    labelKo: '로그인 화면 진입',
    tab: EventTab.auth,
    funnelStep: 1,
    meaningfulBehavior: false,
  ),
  'view_home': EventMeta(
    type: 'view_home',
    labelKo: '홈 탭',
    tab: EventTab.na,
    meaningfulBehavior: false,
  ),
  'view_career': EventMeta(
    type: 'view_career',
    labelKo: '커리어 탭',
    tab: EventTab.career,
    meaningfulBehavior: false,
  ),
  'view_job': EventMeta(
    type: 'view_job',
    labelKo: '구직 탭',
    tab: EventTab.job,
    meaningfulBehavior: false,
  ),
  'view_growth': EventMeta(
    type: 'view_growth',
    labelKo: '성장 탭',
    tab: EventTab.growth,
    meaningfulBehavior: false,
  ),
  'view_bond': EventMeta(
    type: 'view_bond',
    labelKo: '교감 탭',
    tab: EventTab.bond,
    meaningfulBehavior: false,
  ),
  'view_settings': EventMeta(
    type: 'view_settings',
    labelKo: '설정 진입',
    tab: EventTab.auth,
    meaningfulBehavior: false,
  ),
  'view_emotion_record': EventMeta(
    type: 'view_emotion_record',
    labelKo: '감정기록 화면',
    tab: EventTab.na,
    meaningfulBehavior: false,
  ),
  'view_job_detail': EventMeta(
    type: 'view_job_detail',
    labelKo: '공고 상세',
    tab: EventTab.job,
    meaningfulBehavior: true,
  ),
  'view_onboarding_profile': EventMeta(
    type: 'view_onboarding_profile',
    labelKo: '온보딩 프로필',
    tab: EventTab.auth,
    meaningfulBehavior: false,
  ),

  // ── 로그인 버튼 ──────────────────────────────────────────────
  'tap_login_google': EventMeta(
    type: 'tap_login_google',
    labelKo: 'Google 로그인',
    tab: EventTab.auth,
    meaningfulBehavior: false,
  ),
  'tap_login_apple': EventMeta(
    type: 'tap_login_apple',
    labelKo: 'Apple 로그인',
    tab: EventTab.auth,
    meaningfulBehavior: false,
  ),
  'tap_login_kakao': EventMeta(
    type: 'tap_login_kakao',
    labelKo: '카카오 로그인',
    tab: EventTab.auth,
    meaningfulBehavior: false,
  ),
  'tap_login_naver': EventMeta(
    type: 'tap_login_naver',
    labelKo: '네이버 로그인',
    tab: EventTab.auth,
    meaningfulBehavior: false,
  ),
  'tap_login_email': EventMeta(
    type: 'tap_login_email',
    labelKo: '이메일 로그인',
    tab: EventTab.auth,
    meaningfulBehavior: false,
  ),
  'login_success': EventMeta(
    type: 'login_success',
    labelKo: '로그인 성공',
    tab: EventTab.auth,
    meaningfulBehavior: false,
  ),

  // ── 나 탭 행동 ───────────────────────────────────────────────
  'tap_character': EventMeta(
    type: 'tap_character',
    labelKo: '캐릭터 클릭',
    tab: EventTab.na,
    meaningfulBehavior: true,
  ),
  'caring_feed_success': EventMeta(
    type: 'caring_feed_success',
    labelKo: '캐릭터 밥주기 성공',
    tab: EventTab.na,
    meaningfulBehavior: true,
  ),
  'tap_emotion_start': EventMeta(
    type: 'tap_emotion_start',
    labelKo: '감정기록 시작',
    tab: EventTab.na,
    meaningfulBehavior: true,
  ),
  'tap_emotion_save': EventMeta(
    type: 'tap_emotion_save',
    labelKo: '감정기록 저장 시도',
    tab: EventTab.na,
    meaningfulBehavior: true,
  ),
  'emotion_save_success': EventMeta(
    type: 'emotion_save_success',
    labelKo: '감정기록 저장 성공',
    tab: EventTab.na,
    meaningfulBehavior: true,
  ),
  'emotion_save_fail': EventMeta(
    type: 'emotion_save_fail',
    labelKo: '감정기록 저장 실패',
    tab: EventTab.na,
    meaningfulBehavior: false,
  ),

  // ── 프로필·커리어·구직 ───────────────────────────────────────
  'tap_profile_save': EventMeta(
    type: 'tap_profile_save',
    labelKo: '프로필 저장',
    tab: EventTab.auth,
    meaningfulBehavior: true,
  ),
  'tap_job_save': EventMeta(
    type: 'tap_job_save',
    labelKo: '공고 관심 저장',
    tab: EventTab.job,
    meaningfulBehavior: true,
  ),
  'tap_job_apply': EventMeta(
    type: 'tap_job_apply',
    labelKo: '공고 지원',
    tab: EventTab.job,
    meaningfulBehavior: true,
  ),
  'tap_career_edit': EventMeta(
    type: 'tap_career_edit',
    labelKo: '커리어 카드 수정',
    tab: EventTab.career,
    meaningfulBehavior: true,
  ),
  'tap_notification_allow': EventMeta(
    type: 'tap_notification_allow',
    labelKo: '알림 허용',
    tab: EventTab.auth,
    meaningfulBehavior: false,
  ),

  // ── 성장·퀴즈 ────────────────────────────────────────────────
  'quiz_completed': EventMeta(
    type: 'quiz_completed',
    labelKo: '퀴즈 풀이 완료',
    tab: EventTab.growth,
    meaningfulBehavior: true,
  ),

  // ── 공감투표 ─────────────────────────────────────────────────
  'poll_empathize': EventMeta(
    type: 'poll_empathize',
    labelKo: '공감투표 공감',
    tab: EventTab.bond,
    meaningfulBehavior: true,
  ),
  'poll_change_empathy': EventMeta(
    type: 'poll_change_empathy',
    labelKo: '공감투표 공감 변경',
    tab: EventTab.bond,
    meaningfulBehavior: true,
  ),
  'poll_add_option': EventMeta(
    type: 'poll_add_option',
    labelKo: '공감투표 보기 추가',
    tab: EventTab.bond,
    meaningfulBehavior: true,
  ),

  'app_open': EventMeta(
    type: 'app_open',
    labelKo: '앱 실행',
    tab: EventTab.other,
    meaningfulBehavior: false,
  ),

  // ── 공고자 ───────────────────────────────────────────────────
  'publisher_signup_submitted': EventMeta(
    type: 'publisher_signup_submitted',
    labelKo: '공고자 가입 신청',
    tab: EventTab.publisher,
    meaningfulBehavior: false,
  ),
  'publisher_login': EventMeta(
    type: 'publisher_login',
    labelKo: '공고자 로그인',
    tab: EventTab.publisher,
    meaningfulBehavior: false,
  ),
  'publisher_phone_verified': EventMeta(
    type: 'publisher_phone_verified',
    labelKo: '공고자 휴대폰 인증',
    tab: EventTab.publisher,
    meaningfulBehavior: false,
  ),
  'publisher_profile_saved': EventMeta(
    type: 'publisher_profile_saved',
    labelKo: '공고자 프로필 저장',
    tab: EventTab.publisher,
    meaningfulBehavior: false,
  ),
  'publisher_biz_submitted': EventMeta(
    type: 'publisher_biz_submitted',
    labelKo: '공고자 사업자 인증 제출',
    tab: EventTab.publisher,
    meaningfulBehavior: false,
  ),
  'publisher_approved': EventMeta(
    type: 'publisher_approved',
    labelKo: '공고자 승인 완료',
    tab: EventTab.publisher,
    meaningfulBehavior: false,
  ),
  'publisher_job_created': EventMeta(
    type: 'publisher_job_created',
    labelKo: '공고 작성 완료',
    tab: EventTab.publisher,
    meaningfulBehavior: false,
  ),
};

/// 온보딩 순차 퍼널: 집계 시 **교집합** 적용 순서 (type, 화면 라벨)
const List<(String type, String label)> kOnboardingFunnelOrderedSteps = [
  ('view_sign_in_page', '① 로그인 화면 진입'),
  ('funnel_step_2_feed', '② 캐릭터 밥주기'),
  ('funnel_step_3_poll', '③ 공감투표 선택'),
  ('funnel_step_4_quiz', '④ 퀴즈 첫 풀이'),
  ('funnel_step_5_career_specialty', '⑤ 전문분야 등록'),
];

/// 탭 → 핵심 행동 전환 (제목 + `activityLogs.type` 쌍)
///
/// [AdminAnalyticsDailyService] `tabConversions`와 [AdminBehaviorService] 전환율이 동일 출처.
/// 일별 문서 키는 `tabViewType__actionType` (예: `view_home__caring_feed_success`).
///
/// **Breaking (정의 변경 시):** 첫 행을 `emotion_save_success` → `caring_feed_success`로 바꾼 경우,
/// 과거 일별 `tabConversions`의 `view_home__emotion_save_success`와 **동일 지표가 아님**.
/// 시계열 비교·백필 시 날짜·키 정의를 문서에 남길 것.
const List<(String title, String tabViewType, String actionType)>
    kTabConversionRows = [
  ('나 탭 → 캐릭터 밥주기', 'view_home', 'caring_feed_success'),
  ('구직 탭 → 공고 상세', 'view_job', 'view_job_detail'),
  ('성장 탭 → 퀴즈 풀이', 'view_growth', 'quiz_completed'),
  ('같이 탭 → 공감투표', 'view_bond', 'poll_empathize'),
];

// ── C파트: Behavior 탭 집계 행 (AdminBehaviorService) ─────────────

/// «기능 실행률» 카드 — (표시 라벨, 해당 타입 중 하나라도 있으면 카운트)
const List<(String label, Set<String> types)> kBehaviorFeatureUsageRows = [
  ('감정 기록', {'emotion_save_success'}),
  ('캐릭터 인터랙션', {'tap_character'}),
  ('캐릭터 밥주기', {'caring_feed_success'}),
  ('채용 공고 클릭', {'view_job_detail'}),
  ('퀴즈 풀이', {'quiz_completed'}),
  ('공감투표 참여', {'poll_empathize'}),
];

/// «반복 사용» — (라벨, 이벤트 타입, 최소 횟수, 분모 설명)
///
/// 분모: 해당 [eventType]이 **1회 이상**인 사용자 수. 분자: 같은 타입이 [minCount]회 이상.
const List<(String label, String eventType, int minCount, String repeatBasis)>
    kBehaviorRepeatRows = [
  (
    '공감투표 3회+',
    'poll_empathize',
    3,
    '공감투표(공감) 이벤트 1회 이상 발생한 사용자',
  ),
  (
    '캐릭터 상호작용 3회+',
    'tap_character',
    3,
    '캐릭터 탭(상호작용) 이벤트 1회 이상 발생한 사용자',
  ),
  (
    '퀴즈 풀이 3회+',
    'quiz_completed',
    3,
    '퀴즈 완료 이벤트 1회 이상 발생한 사용자',
  ),
  (
    '밥주기 3회+',
    'caring_feed_success',
    3,
    '밥주기 성공 이벤트 1회 이상 발생한 사용자',
  ),
];

/// «유저 타입 분포» 카드 부가 설명 (집계 규칙과 동일 순서: 성장·감정·커리어·교감·유령)
const List<String> kBehaviorSegmentCardDetails = [
  '분석 기간 내 성장 탭(view_growth)을 한 번이라도 연 사용자. 다른 유형과 중복 집계됩니다.',
  '캐릭터 탭(tap_character) 또는 감정 기록 저장(emotion_save_success)을 한 번이라도 한 사용자. 다른 유형과 중복 집계됩니다.',
  '채용 공고 상세·관심 저장·지원(view_job_detail / tap_job_save / tap_job_apply) 중 하나라도 한 사용자. 다른 유형과 중복 집계됩니다.',
  '교감 탭(view_bond) 또는 공감투표 관련(poll_empathize 등) 행동을 한 번이라도 한 사용자. 다른 유형과 중복 집계됩니다.',
  '기간 내 활동 로그가 없거나, 위 네 유형에 해당하지 않으며 의미 있는 행동(meaningful)도 없는 사용자(단일 집계).',
];

/// 유저 세그먼트(중복 가능): 해당 타입을 **한 번이라도** 하면 포함
const Set<String> kSegmentGrowthTypes = {'view_growth'};
const Set<String> kSegmentEmotionTypes = {
  'tap_character',
  'emotion_save_success',
};
const Set<String> kSegmentCareerTypes = {
  'view_job_detail',
  'tap_job_save',
  'tap_job_apply',
};
const Set<String> kSegmentBondTypes = {
  'view_bond',
  'poll_empathize',
  'poll_change_empathy',
  'poll_add_option',
};

/// 카탈로그 조회 API (서비스·UI에서 import)
abstract final class EventCatalog {
  EventCatalog._();

  static final Set<String> meaningfulTypes = kEventCatalog.entries
      .where((e) => e.value.meaningfulBehavior)
      .map((e) => e.key)
      .toSet();

  static const List<(String type, String label)> onboardingFunnelOrderedSteps =
      kOnboardingFunnelOrderedSteps;

  // ── B파트: analytics_daily 백필용 (AdminAnalyticsDailyService) ──

  /// `featureUsage`: 일별 **대표 행동**별 1회 이상 수행한 고유 유저 수
  static const Set<String> dailyFeatureUsageTypes = {
    'emotion_save_success',
    'tap_character',
    'caring_feed_success',
    'view_job_detail',
    'quiz_completed',
  };

  /// `tabConversions`: 탭 진입 + 핵심 행동 **동시** 만족 유저 수 (키: `tab__action`)
  static List<(String tabViewType, String actionType)>
      get dailyTabConversionPairs => [
            for (final r in kTabConversionRows) (r.$2, r.$3),
          ];

  /// Behavior «탭 → 행동 전환율» (제목 + 타입)
  static const List<(String title, String tabViewType, String actionType)>
      behaviorConversionRows = kTabConversionRows;

  /// Behavior «기능 실행률»
  static const List<(String label, Set<String> types)>
      behaviorFeatureUsageRows = kBehaviorFeatureUsageRows;

  /// Behavior «반복 사용»
  static const List<(String label, String eventType, int minCount, String repeatBasis)>
      behaviorRepeatRows = kBehaviorRepeatRows;

  /// Behavior «유저 타입» 카드 하단 설명 (순서 고정)
  static const List<String> behaviorSegmentCardDetails = kBehaviorSegmentCardDetails;

  static const Set<String> segmentGrowthTypes = kSegmentGrowthTypes;
  static const Set<String> segmentEmotionTypes = kSegmentEmotionTypes;
  static const Set<String> segmentCareerTypes = kSegmentCareerTypes;
  static const Set<String> segmentBondTypes = kSegmentBondTypes;

  /// 표시용 라벨 (미등록 타입은 원문 반환)
  static String labelForType(String type) =>
      kEventCatalog[type]?.labelKo ?? type;

  /// 표시용 탭 (미등록은 기타)
  static String tabForType(String type) =>
      kEventCatalog[type]?.tab ?? EventTab.other;
}
