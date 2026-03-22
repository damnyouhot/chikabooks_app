import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 관리자 대시보드용 사용자 행동 기록 서비스
///
/// 컬렉션: `activityLogs`
///   - userId                 : 행동한 유저 UID
///   - type                   : 이벤트 타입 (ActivityEventType.value)
///   - page                   : 이벤트 발생 페이지
///   - timestamp              : 서버 타임스탬프
///   - careerGroupSnapshot    : 기록 시점 연차 (분석용)
///   - careerBucketSnapshot   : 기록 시점 연차 버킷 (분석용)
///   - regionSnapshot         : 기록 시점 지역 (분석용)
///   - workplaceTypeSnapshot  : 기록 시점 근무지 유형 (분석용)
///
/// ── 설계 원칙 ─────────────────────────────────────────────────
/// 1. UI 코드에서 직접 Firestore를 쓰지 않고 이 서비스만 호출
/// 2. 실패해도 앱 동작에 영향 없도록 try-catch 내부 처리
/// 3. excludeFromStats == true 유저는 기록하지 않음
/// 4. 프로필 스냅샷은 세션 캐시로 관리 — Firestore 읽기 최소화
/// ──────────────────────────────────────────────────────────────
class AdminActivityService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ── 세션 캐시 ────────────────────────────────────────────────
  /// 통계 제외 계정 여부 캐시
  static bool? _excludedCache;

  /// 유저 스냅샷 캐시 (Firestore 읽기 최소화)
  static _UserSnapshot? _snapshotCache;

  /// 캐시 초기화 (로그아웃 / 계정 전환 시 반드시 호출)
  static void clearCache() {
    _excludedCache = null;
    _snapshotCache = null;
  }

  // ── 공개 메서드 ───────────────────────────────────────────────

  /// 행동 이벤트 기록 — fire-and-forget (UI 블로킹 없음)
  ///
  /// [type]     : [ActivityEventType] 열거형
  /// [page]     : 이벤트 발생 페이지명 (예: 'home', 'career', 'job_list')
  /// [targetId] : 관련 리소스 ID (선택, 예: jobId)
  /// [extra]    : 추가 메타데이터 (선택)
  static void log(
    ActivityEventType type, {
    required String page,
    String? targetId,
    Map<String, dynamic>? extra,
  }) {
    // 다음 이벤트 루프로 넘겨 UI 렌더링을 블로킹하지 않음
    Future.delayed(Duration.zero, () async {
      try {
        final uid = _auth.currentUser?.uid;
        if (uid == null) return;

        if (await _isExcluded(uid)) return;

        final snapshot = await _getSnapshot(uid);
        final data = <String, dynamic>{
          'userId': uid,
          'type': type.value,
          'page': page,
          'timestamp': FieldValue.serverTimestamp(),
          'isFunnel': false, // Feature 탭 쿼리에서 퍼널 이벤트 제외용
          ...snapshot.toMap(),
        };

        if (targetId != null) data['targetId'] = targetId;
        if (extra != null) data.addAll(extra);

        await _db.collection('activityLogs').add(data);
      } catch (e) {
        debugPrint('⚠️ AdminActivityService.log 실패: $e');
      }
    });
  }

  /// 퍼널 이벤트 기록 — fire-and-forget (UI 블로킹 없음)
  static void logFunnel(
    FunnelEventType type, {
    Map<String, dynamic>? extra,
  }) {
    Future.delayed(Duration.zero, () async {
      try {
        final uid = _auth.currentUser?.uid;
        if (uid == null) return;

        if (await _isExcluded(uid)) return;

        final snapshot = await _getSnapshot(uid);
        final data = <String, dynamic>{
          'userId': uid,
          'type': type.value,
          'page': type.page,
          'timestamp': FieldValue.serverTimestamp(),
          'isFunnel': true,
          ...snapshot.toMap(),
        };

        if (extra != null) data.addAll(extra);

        await _db.collection('activityLogs').add(data);
      } catch (e) {
        debugPrint('⚠️ AdminActivityService.logFunnel 실패: $e');
      }
    });
  }

  /// 세션 시작 시 유저 스냅샷 캐시를 미리 채워둠 — 이후 로그 기록 시 Firestore 읽기 생략
  static void warmupCache() {
    Future.delayed(Duration.zero, () async {
      final uid = _auth.currentUser?.uid;
      if (uid != null) await _getSnapshot(uid);
    });
  }

  /// 스냅샷 캐시 수동 갱신 (프로필 수정 후 호출)
  static void refreshSnapshot() {
    _snapshotCache = null;
    Future.delayed(Duration.zero, () async {
      final uid = _auth.currentUser?.uid;
      if (uid != null) await _getSnapshot(uid);
    });
  }

  /// Publisher(공고자) 이벤트 기록 — fire-and-forget
  ///
  /// 위생사 이벤트와 달리 `clinics_accounts`에서 스냅샷을 수집합니다.
  static void logPublisher(
    ActivityEventType type, {
    required String page,
    String? targetId,
    Map<String, dynamic>? extra,
  }) {
    Future.delayed(Duration.zero, () async {
      try {
        final uid = _auth.currentUser?.uid;
        if (uid == null) return;

        final doc = await _db.collection('clinics_accounts').doc(uid).get();
        final clinicData = doc.data() ?? {};

        final data = <String, dynamic>{
          'userId': uid,
          'type': type.value,
          'page': page,
          'timestamp': FieldValue.serverTimestamp(),
          'isFunnel': false,
          'accountType': 'publisher',
          if (clinicData['approvalStatus'] != null)
            'approvalStatusSnapshot': clinicData['approvalStatus'],
          if (clinicData['clinic'] is Map)
            'clinicNameSnapshot': (clinicData['clinic'] as Map)['name'],
        };

        if (targetId != null) data['targetId'] = targetId;
        if (extra != null) data.addAll(extra);

        await _db.collection('activityLogs').add(data);
      } catch (e) {
        debugPrint('⚠️ AdminActivityService.logPublisher 실패: $e');
      }
    });
  }

  // ── 내부 메서드 ───────────────────────────────────────────────

  /// 통계 제외 계정 여부 (세션 캐시)
  static Future<bool> _isExcluded(String uid) async {
    if (_excludedCache != null) return _excludedCache!;
    try {
      final doc = await _db.collection('users').doc(uid).get();
      _excludedCache = doc.data()?['excludeFromStats'] == true;
      // 첫 로드 시 스냅샷도 함께 캐시
      if (_snapshotCache == null) {
        _snapshotCache = _UserSnapshot.fromMap(doc.data() ?? {});
      }
      return _excludedCache!;
    } catch (_) {
      return false;
    }
  }

  /// 유저 스냅샷 가져오기 (세션 캐시 우선)
  static Future<_UserSnapshot> _getSnapshot(String uid) async {
    if (_snapshotCache != null) return _snapshotCache!;
    try {
      final doc = await _db.collection('users').doc(uid).get();
      _excludedCache ??= doc.data()?['excludeFromStats'] == true;
      _snapshotCache = _UserSnapshot.fromMap(doc.data() ?? {});
      return _snapshotCache!;
    } catch (_) {
      return const _UserSnapshot();
    }
  }
}

// ── 유저 스냅샷 내부 모델 ──────────────────────────────────────
/// 이벤트 로그에 첨부되는 유저 특성 스냅샷
class _UserSnapshot {
  final String careerGroup;
  final String careerBucket;
  final String region;
  final String workplaceType;

  const _UserSnapshot({
    this.careerGroup = '',
    this.careerBucket = '',
    this.region = '',
    this.workplaceType = '',
  });

  factory _UserSnapshot.fromMap(Map<String, dynamic> m) => _UserSnapshot(
    careerGroup:    m['careerGroup']    as String? ?? '',
    careerBucket:   m['careerBucket']   as String? ?? '',
    region:         m['region']         as String? ?? '',
    workplaceType:  m['workplaceType']  as String? ?? '',
  );

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (careerGroup.isNotEmpty)   map['careerGroupSnapshot']   = careerGroup;
    if (careerBucket.isNotEmpty)  map['careerBucketSnapshot']  = careerBucket;
    if (region.isNotEmpty)        map['regionSnapshot']        = region;
    if (workplaceType.isNotEmpty) map['workplaceTypeSnapshot'] = workplaceType;
    return map;
  }
}

// ═══════════════════════════════════════════════════════════════
// 이벤트 타입 정의
// ═══════════════════════════════════════════════════════════════

/// 행동 이벤트 타입
enum ActivityEventType {
  // ── 화면 진입 ──────────────────────────────────────────────
  viewSignInPage('view_sign_in_page', '로그인 화면 진입'),
  viewHome('view_home', '홈 진입'),
  viewCareer('view_career', '커리어 탭 진입'),
  viewJob('view_job', '구직 탭 진입'),
  viewGrowth('view_growth', '성장 탭 진입'),
  viewBond('view_bond', '교감 탭 진입'),
  viewSettings('view_settings', '설정 진입'),
  viewEmotionRecord('view_emotion_record', '감정기록 화면 진입'),
  viewJobDetail('view_job_detail', '공고 상세 진입'),
  viewOnboardingProfile('view_onboarding_profile', '온보딩 프로필 화면 진입'),

  // ── 소셜 로그인 버튼 ────────────────────────────────────────
  tapLoginGoogle('tap_login_google', 'Google 로그인 버튼'),
  tapLoginApple('tap_login_apple', 'Apple 로그인 버튼'),
  tapLoginKakao('tap_login_kakao', 'Kakao 로그인 버튼'),
  tapLoginNaver('tap_login_naver', 'Naver 로그인 버튼'),
  tapLoginEmail('tap_login_email', '이메일 로그인 버튼'),
  loginSuccess('login_success', '로그인 성공'),

  // ── 버튼/기능 클릭 ─────────────────────────────────────────
  tapCharacter('tap_character', '캐릭터 클릭'),
  caringFeedSuccess('caring_feed_success', '캐릭터 밥주기 성공'),
  tapEmotionStart('tap_emotion_start', '감정기록 시작'),
  tapEmotionSave('tap_emotion_save', '감정기록 저장 시도'),
  emotionSaveSuccess('emotion_save_success', '감정기록 저장 성공'),
  emotionSaveFail('emotion_save_fail', '감정기록 저장 실패'),
  tapProfileSave('tap_profile_save', '프로필 저장'),
  tapJobSave('tap_job_save', '공고 관심 저장'),
  tapJobApply('tap_job_apply', '공고 지원'),
  tapCareerEdit('tap_career_edit', '커리어 카드 수정'),
  tapNotificationAllow('tap_notification_allow', '알림 허용'),

  // ── 퀴즈 ──────────────────────────────────────────────────
  quizCompleted('quiz_completed', '퀴즈 풀이 완료'),

  // ── 공감투표 ──────────────────────────────────────────────
  pollEmpathize('poll_empathize', '공감투표 공감'),
  pollChangeEmpathy('poll_change_empathy', '공감투표 공감 변경'),
  pollAddOption('poll_add_option', '공감투표 보기 추가'),

  // ── 기타 ──────────────────────────────────────────────────
  appOpen('app_open', '앱 실행'),

  // ── 공고자(Publisher) 이벤트 ─────────────────────────────
  publisherSignupSubmitted('publisher_signup_submitted', '공고자 가입 신청'),
  publisherLogin('publisher_login', '공고자 로그인'),
  publisherPhoneVerified('publisher_phone_verified', '공고자 휴대폰 인증'),
  publisherProfileSaved('publisher_profile_saved', '공고자 프로필 저장'),
  publisherBizSubmitted('publisher_biz_submitted', '공고자 사업자 인증 제출'),
  publisherApproved('publisher_approved', '공고자 승인 완료'),
  publisherJobCreated('publisher_job_created', '공고 작성 완료');

  final String value;
  final String label;
  const ActivityEventType(this.value, this.label);

  static ActivityEventType? fromString(String s) {
    return ActivityEventType.values.cast<ActivityEventType?>().firstWhere(
      (e) => e?.value == s,
      orElse: () => null,
    );
  }
}

/// 퍼널 단계 이벤트 타입
enum FunnelEventType {
  signupComplete('funnel_signup_complete', 'auth', '회원가입 완료', 1),
  profileBasicComplete('funnel_profile_basic', 'onboarding', '기본 프로필 완료', 2),
  firstEmotionStart('funnel_first_emotion_start', 'emotion', '첫 감정기록 시작', 3),
  firstEmotionComplete('funnel_first_emotion_complete', 'emotion', '첫 감정기록 완료', 4),

  /// v3 온보딩 순차 퍼널 (대시보드 교집합 집계용, [order]는 레거시와 구분용)
  onboardingFeed('funnel_step_2_feed', 'home', '캐릭터 밥주기 (온보딩)', 10),
  onboardingPoll('funnel_step_3_poll', 'bond', '공감투표 선택 (온보딩)', 11),
  onboardingQuiz('funnel_step_4_quiz', 'growth', '퀴즈 첫 풀이 (온보딩)', 12),
  onboardingCareerSpecialty(
    'funnel_step_5_career_specialty',
    'career',
    '전문분야 등록 (온보딩)',
    13,
  );

  final String value;
  final String page;
  final String label;
  final int order;
  const FunnelEventType(this.value, this.page, this.label, this.order);
}
