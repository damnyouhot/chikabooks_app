import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 앱 오류 기록 서비스
///
/// 컬렉션: `appErrors`
///   - timestamp    : 서버 타임스탬프
///   - page         : 오류 발생 페이지
///   - feature      : 오류 발생 기능/액션
///   - errorMessage : 오류 메시지 (stack trace 앞 200자)
///   - appVersion   : 앱 버전 (예: "1.0.3")
///   - userId       : 오류 발생 유저 UID (선택, 익명 식별용)
///   - isFatal      : 치명적 오류 여부
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
///   rethrow; // 또는 UI에 에러 표시
/// }
/// ──────────────────────────────────────────────────────────────
class AppErrorLogger {
  static final _db = FirebaseFirestore.instance;

  // 앱 버전 캐시 (매번 조회 방지)
  static String? _appVersionCache;

  /// 오류 기록
  ///
  /// [page]       : 오류 발생 페이지명 (예: 'emotion_record', 'job_list')
  /// [feature]    : 오류 발생 기능 (예: 'save_emotion', 'load_jobs')
  /// [error]      : catch 블록의 error 객체
  /// [stackTrace] : catch 블록의 stackTrace (선택)
  /// [isFatal]    : 앱 크래시 수준 오류 여부 (기본값: false)
  /// [extra]      : 추가 컨텍스트 (선택)
  static Future<void> log({
    required String page,
    required String feature,
    required Object error,
    StackTrace? stackTrace,
    bool isFatal = false,
    Map<String, dynamic>? extra,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final version = await _getAppVersion();

      // 오류 메시지: 앞 300자만 저장 (Firestore 용량 절약)
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
      };

      if (uid != null) data['userId'] = uid;
      if (stackMsg != null) data['stackTrace'] = stackMsg;
      if (extra != null) data.addAll(extra);

      await _db.collection('appErrors').add(data);
    } catch (e) {
      // 오류 기록 자체가 실패해도 앱에 영향 없어야 함
      debugPrint('⚠️ AppErrorLogger.log 실패: $e');
    }
  }

  /// 앱 버전 가져오기 (캐시)
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

  /// 캐시 초기화
  static void clearCache() => _appVersionCache = null;
}

