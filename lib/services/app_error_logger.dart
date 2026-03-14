import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 앱 오류 기록 서비스
///
/// 컬렉션: `appErrors`
///   - timestamp              : 서버 타임스탬프
///   - page                   : 오류 발생 페이지
///   - feature                : 오류 발생 기능/액션
///   - errorMessage           : 오류 메시지 (앞 300자)
///   - stackTrace             : 스택 트레이스 (앞 500자, 선택)
///   - appVersion             : 앱 버전 (예: "1.0.3")
///   - userId                 : 오류 발생 유저 UID
///   - isFatal                : 치명적 오류 여부
///   - actionType             : 오류 직전 행동 (선택)
///   - errorCode              : 오류 코드 (선택)
///   - careerGroupSnapshot    : 오류 발생 시점 연차 (분석용)
///   - regionSnapshot         : 오류 발생 시점 지역 (분석용)
///
/// ── 사용 방법 ─────────────────────────────────────────────────
/// try {
///   await someOperation();
/// } catch (e, stack) {
///   await AppErrorLogger.log(
///     page: 'emotion_record',
///     feature: 'save_emotion',
///     error: e,
///     stackTrace: stack,
///   );
///   rethrow;
/// }
/// ──────────────────────────────────────────────────────────────
class AppErrorLogger {
  static final _db = FirebaseFirestore.instance;

  // ── 세션 캐시 ─────────────────────────────────────────────────
  static String? _appVersionCache;
  static _ErrorUserSnapshot? _snapshotCache;

  /// 캐시 초기화 (로그아웃 시 호출)
  static void clearCache() {
    _appVersionCache = null;
    _snapshotCache = null;
  }

  // ── 공개 메서드 ───────────────────────────────────────────────

  /// 오류 기록
  ///
  /// [page]       : 오류 발생 페이지명 (예: 'emotion_record', 'job_list')
  /// [feature]    : 오류 발생 기능 (예: 'save_emotion', 'load_jobs')
  /// [error]      : catch 블록의 error 객체
  /// [stackTrace] : catch 블록의 stackTrace (선택)
  /// [isFatal]    : 앱 크래시 수준 오류 여부 (기본값: false)
  /// [actionType] : 오류 직전 행동 (선택, 예: 'tap_save_button')
  /// [errorCode]  : 오류 코드 (선택, 예: 'permission-denied')
  /// [extra]      : 추가 컨텍스트 (선택)
  static Future<void> log({
    required String page,
    required String feature,
    required Object error,
    StackTrace? stackTrace,
    bool isFatal = false,
    String? actionType,
    String? errorCode,
    Map<String, dynamic>? extra,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final version = await _getAppVersion();
      final snapshot = await _getSnapshot(uid);

      // 오류 메시지: 앞 300자만 저장
      final errorMsg = error.toString().length > 300
          ? '${error.toString().substring(0, 300)}...'
          : error.toString();

      // 스택 트레이스: 앞 500자만 저장
      String? stackMsg;
      if (stackTrace != null) {
        final full = stackTrace.toString();
        stackMsg = full.length > 500 ? '${full.substring(0, 500)}...' : full;
      }

      final data = <String, dynamic>{
        'timestamp': FieldValue.serverTimestamp(),
        'page': page,
        'feature': feature,
        'errorMessage': errorMsg,
        'appVersion': version,
        'isFatal': isFatal,
        ...snapshot.toMap(),
      };

      if (uid != null) data['userId'] = uid;
      if (stackMsg != null) data['stackTrace'] = stackMsg;
      if (actionType != null) data['actionType'] = actionType;
      if (errorCode != null) data['errorCode'] = errorCode;
      if (extra != null) data.addAll(extra);

      await _db.collection('appErrors').add(data);
    } catch (e) {
      debugPrint('⚠️ AppErrorLogger.log 실패: $e');
    }
  }

  // ── 내부 메서드 ───────────────────────────────────────────────

  static Future<String> _getAppVersion() async {
    if (_appVersionCache != null) return _appVersionCache!;
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersionCache = info.version;
      return _appVersionCache!;
    } catch (_) {
      return 'unknown';
    }
  }

  static Future<_ErrorUserSnapshot> _getSnapshot(String? uid) async {
    if (_snapshotCache != null) return _snapshotCache!;
    if (uid == null) return const _ErrorUserSnapshot();
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      _snapshotCache = _ErrorUserSnapshot.fromMap(doc.data() ?? {});
      return _snapshotCache!;
    } catch (_) {
      return const _ErrorUserSnapshot();
    }
  }
}

// ── 오류 기록용 유저 스냅샷 ───────────────────────────────────
class _ErrorUserSnapshot {
  final String careerGroup;
  final String region;

  const _ErrorUserSnapshot({
    this.careerGroup = '',
    this.region = '',
  });

  factory _ErrorUserSnapshot.fromMap(Map<String, dynamic> m) =>
      _ErrorUserSnapshot(
        careerGroup: m['careerGroup'] as String? ?? '',
        region:      m['region']      as String? ?? '',
      );

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (careerGroup.isNotEmpty) map['careerGroupSnapshot'] = careerGroup;
    if (region.isNotEmpty)      map['regionSnapshot']      = region;
    return map;
  }
}
