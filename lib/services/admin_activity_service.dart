import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 관리자 대시보드용 사용자 행동 기록 서비스
///
/// 컬렉션: `activityLogs`
///   - userId       : 행동한 유저 UID
///   - type         : 이벤트 타입 (ActivityEventType.value)
///   - page         : 이벤트 발생 페이지
///   - action       : 세부 액션 설명 (선택)
///   - targetId     : 관련 리소스 ID (선택, 예: jobId, emotionLogId)
///   - timestamp    : 서버 타임스탬프
///
/// ── 설계 원칙 ─────────────────────────────────────────────────
/// 1. UI 코드에서 직접 Firestore를 쓰지 않고 이 서비스만 호출
/// 2. 실패해도 앱 동작에 영향 없도록 try-catch 내부 처리
/// 3. excludeFromStats == true 유저는 기록하지 않음
/// ──────────────────────────────────────────────────────────────
class AdminActivityService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // 세션 내 제외 계정 캐시 (매번 Firestore 조회 방지)
  static bool? _excludedCache;

  /// 캐시 초기화 (로그아웃 시 호출)
  static void clearCache() => _excludedCache = null;

  /// 행동 이벤트 기록
  ///
  /// [type]     : [ActivityEventType] 열거형
  /// [page]     : 이벤트 발생 페이지명 (예: 'home', 'career', 'job_list')
  /// [action]   : 세부 액션 (선택, 예: 'tap_save_button')
  /// [targetId] : 관련 리소스 ID (선택)
  /// [extra]    : 추가 메타데이터 (선택)
  static Future<void> log(
    ActivityEventType type, {
    required String page,
    String? action,
    String? targetId,
    Map<String, dynamic>? extra,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      // 제외 계정 확인 (세션 캐시 활용)
      if (await _isExcluded(uid)) return;

      final data = <String, dynamic>{
        'userId': uid,
        'type': type.value,
        'page': page,
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (action != null) data['action'] = action;
      if (targetId != null) data['targetId'] = targetId;
      if (extra != null) data.addAll(extra);

      await _db.collection('activityLogs').add(data);
    } catch (e) {
      // 기록 실패는 무시 (앱 동작에 영향 없어야 함)
      debugPrint('⚠️ AdminActivityService.log 실패: $e');
    }
  }

  /// 퍼널 이벤트 기록 (특정 단계 도달)
  ///
  /// 가입 퍼널, 감정기록 퍼널 등 단계별 전환율 측정에 사용
  static Future<void> logFunnel(
    FunnelEventType type, {
    Map<String, dynamic>? extra,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      if (await _isExcluded(uid)) return;

      final data = <String, dynamic>{
        'userId': uid,
        'type': type.value,
        'page': type.page,
        'timestamp': FieldValue.serverTimestamp(),
        'isFunnel': true,
      };

      if (extra != null) data.addAll(extra);

      await _db.collection('activityLogs').add(data);
    } catch (e) {
      debugPrint('⚠️ AdminActivityService.logFunnel 실패: $e');
    }
  }

  /// 제외 계정 여부 확인 (세션 캐시 적용)
  static Future<bool> _isExcluded(String uid) async {
    if (_excludedCache != null) return _excludedCache!;

    try {
      final doc = await _db.collection('users').doc(uid).get();
      _excludedCache = doc.data()?['excludeFromStats'] == true;
      return _excludedCache!;
    } catch (_) {
      return false;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// 이벤트 타입 정의
// ═══════════════════════════════════════════════════════════════

/// 행동 이벤트 타입
///
/// [value]  : Firestore에 저장되는 문자열 키
/// [label]  : 대시보드 표시용 한글 라벨
enum ActivityEventType {
  // ── 화면 진입 ──────────────────────────────────────────────
  viewHome('view_home', '홈 진입'),
  viewCareer('view_career', '커리어 탭 진입'),
  viewJob('view_job', '구직 탭 진입'),
  viewGrowth('view_growth', '성장 탭 진입'),
  viewBond('view_bond', '교감 탭 진입'),
  viewSettings('view_settings', '설정 진입'),
  viewEmotionRecord('view_emotion_record', '감정기록 화면 진입'),
  viewJobDetail('view_job_detail', '공고 상세 진입'),

  // ── 버튼/기능 클릭 ─────────────────────────────────────────
  tapCharacter('tap_character', '캐릭터 클릭'),
  tapEmotionStart('tap_emotion_start', '감정기록 시작'),
  tapEmotionSave('tap_emotion_save', '감정기록 저장'),
  tapJobSave('tap_job_save', '공고 관심 저장'),
  tapJobApply('tap_job_apply', '공고 지원'),
  tapCareerEdit('tap_career_edit', '커리어 카드 수정'),
  tapNotificationAllow('tap_notification_allow', '알림 허용'),

  // ── 기타 ──────────────────────────────────────────────────
  appOpen('app_open', '앱 실행');

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
///
/// [value]  : Firestore 저장 키
/// [page]   : 발생 페이지
/// [label]  : 대시보드 표시용 라벨
/// [order]  : 퍼널 순서 (낮을수록 앞 단계)
enum FunnelEventType {
  signupComplete('funnel_signup_complete', 'auth', '회원가입 완료', 1),
  profileBasicComplete('funnel_profile_basic', 'onboarding', '기본 프로필 완료', 2),
  profilePartnerComplete('funnel_profile_partner', 'onboarding', '파트너 프로필 완료', 3),
  firstEmotionStart('funnel_first_emotion_start', 'emotion', '첫 감정기록 시작', 4),
  firstEmotionComplete('funnel_first_emotion_complete', 'emotion', '첫 감정기록 완료', 5);

  final String value;
  final String page;
  final String label;
  final int order;
  const FunnelEventType(this.value, this.page, this.label, this.order);
}

