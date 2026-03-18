/// 관리자 대시보드에서 사용하는 데이터 모델 모음
library;

// ─── KPI 카드 ───────────────────────────────────────────────
class DashboardKpi {
  final String label;
  final String value;
  final String? sublabel; // 예: "최근 7일"

  const DashboardKpi({
    required this.label,
    required this.value,
    this.sublabel,
  });
}

// ─── 퍼널 단계 ───────────────────────────────────────────────
class FunnelStep {
  final String label;
  final int count;
  final double? conversionRate; // 이전 단계 대비 전환율 (0.0~1.0)

  const FunnelStep({
    required this.label,
    required this.count,
    this.conversionRate,
  });
}

// ─── 기능 반응 항목 ──────────────────────────────────────────
class FeatureReactionItem {
  final String eventType; // activityLogs.type
  final String label;     // 화면에 표시할 한국어 이름
  final int clickCount;
  final int userCount;

  const FeatureReactionItem({
    required this.eventType,
    required this.label,
    required this.clickCount,
    required this.userCount,
  });

  /// activityLogs.type → 한국어 라벨 매핑
  /// ※ Firestore에 저장되는 값은 ActivityEventType.value (snake_case)
  static String labelFor(String type) {
    const map = {
      // ── 화면 진입 ──────────────────────────────────────────
      'view_sign_in_page':        '로그인 화면 진입',
      'view_home':                '홈 탭',
      'view_bond':                '교감 탭',
      'view_growth':              '성장 탭',
      'view_career':              '커리어 탭',
      'view_job':                 '구직 탭',
      'view_settings':            '설정 진입',
      'view_emotion_record':      '감정기록 화면',
      'view_job_detail':          '공고 상세',
      'view_onboarding_profile':  '온보딩 프로필',
      // ── 소셜 로그인 ────────────────────────────────────────
      'tap_login_google':  'Google 로그인',
      'tap_login_apple':   'Apple 로그인',
      'tap_login_kakao':   '카카오 로그인',
      'tap_login_naver':   '네이버 로그인',
      'tap_login_email':   '이메일 로그인',
      'login_success':     '로그인 성공',
      // ── 기능 클릭 ──────────────────────────────────────────
      'quiz_completed':     '퀴즈 풀이 완료',
      'tap_character':      '캐릭터 클릭',
      'tap_emotion_start':  '감정기록 시작',
      'tap_emotion_save':   '감정기록 저장 시도',
      'emotion_save_success': '감정기록 저장 성공',
      'emotion_save_fail':  '감정기록 저장 실패',
      'tap_profile_save':   '프로필 저장',
      'tap_job_save':       '공고 관심 저장',
      'tap_job_apply':      '공고 지원',
      'tap_career_edit':    '커리어 카드 수정',
      'tap_notification_allow': '알림 허용',
      // ── 기타 ──────────────────────────────────────────────
      'app_open': '앱 실행',
      // ── 공고자(Publisher) 이벤트 ─────────────────────────
      'publisher_signup_submitted': '공고자 가입 신청',
      'publisher_login':            '공고자 로그인',
      'publisher_phone_verified':   '공고자 휴대폰 인증',
      'publisher_profile_saved':    '공고자 프로필 저장',
      'publisher_biz_submitted':    '공고자 사업자 인증 제출',
      'publisher_approved':         '공고자 승인 완료',
      'publisher_job_created':      '공고 작성 완료',
    };
    return map[type] ?? type;
  }
}

// ─── 오류 항목 ───────────────────────────────────────────────
class AppErrorItem {
  final String id;
  final DateTime timestamp;
  final String errorMessage;
  final String? page;
  final String? feature;
  final String? appVersion;
  final String? uid;
  final bool isFatal;

  const AppErrorItem({
    required this.id,
    required this.timestamp,
    required this.errorMessage,
    this.page,
    this.feature,
    this.appVersion,
    this.uid,
    this.isFatal = false,
  });

  factory AppErrorItem.fromMap(String id, Map<String, dynamic> m) {
    return AppErrorItem(
      id: id,
      timestamp: (m['timestamp'] as dynamic)?.toDate() ?? DateTime.now(),
      errorMessage: m['errorMessage'] as String? ?? '(메시지 없음)',
      page: m['page'] as String?,
      feature: m['feature'] as String?,
      appVersion: m['appVersion'] as String?,
      uid: m['userId'] as String?,   // ← AppErrorLogger가 'userId'로 저장
      isFatal: m['isFatal'] as bool? ?? false,
    );
  }
}

// ─── 기록하기 항목 — 대시보드 피드용 ──────────────────────────────
class NoteFeedItem {
  final String id;
  final String userId;
  final String text;
  final DateTime createdAt;
  final List<String> imageUrls;

  const NoteFeedItem({
    required this.id,
    required this.userId,
    required this.text,
    required this.createdAt,
    this.imageUrls = const [],
  });
}

// ─── 감정 기록 항목 (EmotionLog — emotionLogs 컬렉션용, 레거시) ─
class EmotionLogItem {
  final String id;
  final String userId;
  final DateTime timestamp;
  final int? score;
  final String? text;
  final List<String> tags;
  final String? careerGroupSnapshot;

  const EmotionLogItem({
    required this.id,
    required this.userId,
    required this.timestamp,
    this.score,
    this.text,
    this.tags = const [],
    this.careerGroupSnapshot,
  });

  factory EmotionLogItem.fromMap(String id, Map<String, dynamic> m) {
    List<String> parsedTags = [];
    final rawTags = m['tags'];
    if (rawTags is List) {
      parsedTags = rawTags.map((e) => e.toString()).toList();
    }
    return EmotionLogItem(
      id: id,
      userId: m['userId'] as String? ?? '',
      timestamp: (m['timestamp'] as dynamic)?.toDate() ?? DateTime.now(),
      score: (m['score'] as num?)?.toInt(),
      text: m['text'] as String?,
      tags: parsedTags,
      careerGroupSnapshot: m['careerGroupSnapshot'] as String?,
    );
  }
}

// ─── 연차 분포 항목 ──────────────────────────────────────────
class CareerGroupCount {
  final String group; // careerBucket: '0-2', '3-5', '6+'
  final int count;

  const CareerGroupCount({required this.group, required this.count});

  String get label {
    const map = {
      '0-2': '0~2년차',
      '3-5': '3~5년차',
      '6+':  '6년차+',
    };
    return map[group] ?? group;
  }
}

