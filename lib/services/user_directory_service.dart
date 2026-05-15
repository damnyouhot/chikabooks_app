import 'package:cloud_firestore/cloud_firestore.dart';

/// uid → 표시명 변환 헬퍼.
///
/// 우선순위:
///   1. `users/{uid}.displayName`  (지원자 / 일반 가입자)
///   2. `clinics_accounts/{uid}.displayName | clinicName | branchName`  (치과 계정)
///   3. `users/{uid}.email` 의 앞부분
///   4. fallback: '사용자'
///
/// 결과는 메모리에 캐싱한다. 페이지 단위 인스턴스로 사용해도 되고,
/// 앱 전역 싱글턴으로 사용해도 된다.
class UserDirectoryService {
  UserDirectoryService();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  final Map<String, String> _cache = {};
  final Map<String, Future<String>> _inflight = {};

  /// 캐시된 이름이 있으면 즉시 반환, 없으면 'unknown' 빈 문자열을 반환한다.
  /// (스트리밍 UI 에서 한 번 fetch 후 setState 시 사용)
  String? cachedName(String uid) => _cache[uid];

  /// uid 의 표시명을 비동기로 가져온다. (캐시 우선)
  Future<String> displayName(String uid) {
    if (uid.isEmpty) return Future.value('사용자');
    final cached = _cache[uid];
    if (cached != null) return Future.value(cached);
    final inflight = _inflight[uid];
    if (inflight != null) return inflight;
    final fut = _resolve(uid).then((name) {
      _cache[uid] = name;
      _inflight.remove(uid);
      return name;
    });
    _inflight[uid] = fut;
    return fut;
  }

  Future<String> _resolve(String uid) async {
    try {
      final userSnap = await _db.collection('users').doc(uid).get();
      final user = userSnap.data();
      if (user != null) {
        final dn = (user['displayName'] as String?)?.trim();
        if (dn != null && dn.isNotEmpty) return dn;
      }

      final clinicSnap = await _db.collection('clinics_accounts').doc(uid).get();
      final clinic = clinicSnap.data();
      if (clinic != null) {
        for (final key in const ['displayName', 'clinicName', 'branchName']) {
          final v = (clinic[key] as String?)?.trim();
          if (v != null && v.isNotEmpty) return v;
        }
      }

      // email prefix fallback
      final email = (user?['email'] as String?)?.trim();
      if (email != null && email.contains('@')) {
        return email.split('@').first;
      }
    } catch (_) {
      // 보안 규칙으로 막힌 경우 등은 조용히 fallback.
    }
    return '사용자';
  }
}
