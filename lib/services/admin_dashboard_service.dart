import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/admin_dashboard_models.dart';

/// 관리자 대시보드 데이터를 Firestore에서 읽어오는 서비스
///
/// ── 기간 필터 ─────────────────────────────────────────────────
/// [since] 파라미터로 기간을 제한합니다.
/// null이면 전체 기간 데이터를 대상으로 합니다.
/// ──────────────────────────────────────────────────────────────
class AdminDashboardService {
  static final _db = FirebaseFirestore.instance;

  // ─── Overview ─────────────────────────────────────────────────

  /// 전체 사용자 수 (excludeFromStats 제외, 기간 무관)
  static Future<int> getTotalUserCount() async {
    try {
      final snap = await _db
          .collection('users')
          .where('excludeFromStats', isNotEqualTo: true)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      debugPrint('⚠️ getTotalUserCount: $e');
      return 0;
    }
  }

  /// 신규 가입자 수 ([since] 이후 createdAt)
  static Future<int> getRecentSignups({required DateTime since}) async {
    try {
      final snap = await _db
          .collection('users')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(since))
          .where('excludeFromStats', isNotEqualTo: true)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      debugPrint('⚠️ getRecentSignups: $e');
      return 0;
    }
  }

  /// 활성 유저 수 ([since] 이후 lastActiveAt)
  static Future<int> getActiveUserCount({required DateTime since}) async {
    try {
      final snap = await _db
          .collection('users')
          .where('lastActiveAt', isGreaterThan: Timestamp.fromDate(since))
          .where('excludeFromStats', isNotEqualTo: true)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      debugPrint('⚠️ getActiveUserCount: $e');
      return 0;
    }
  }

  /// 장기 미접속 유저 수 (lastActiveAt이 14일 이전, 기간 무관)
  static Future<int> getLongAbsentCount({int days = 14}) async {
    try {
      final before = DateTime.now().subtract(Duration(days: days));
      final snap = await _db
          .collection('users')
          .where('lastActiveAt', isLessThan: Timestamp.fromDate(before))
          .where('excludeFromStats', isNotEqualTo: true)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      debugPrint('⚠️ getLongAbsentCount: $e');
      return 0;
    }
  }

  /// 연차별 사용자 분포 (careerBucket 기준, 기간 무관)
  static Future<List<CareerGroupCount>> getCareerGroupDistribution() async {
    const buckets = <(String, String)>[
      ('0-2', '0~2년차'),
      ('3-5', '3~5년차'),
      ('6+', '6년차+'),
    ];
    final result = <CareerGroupCount>[];
    for (final (bucket, _) in buckets) {
      try {
        final snap = await _db
            .collection('users')
            .where('careerBucket', isEqualTo: bucket)
            .where('excludeFromStats', isNotEqualTo: true)
            .count()
            .get();
        result.add(CareerGroupCount(group: bucket, count: snap.count ?? 0));
      } catch (_) {
        result.add(CareerGroupCount(group: bucket, count: 0));
      }
    }
    return result;
  }

  /// [since] 이후 오류 수
  static Future<int> getRecentErrorCount({required DateTime since}) async {
    try {
      final snap = await _db
          .collection('appErrors')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      debugPrint('⚠️ getRecentErrorCount: $e');
      return 0;
    }
  }

  // ─── Emotion KPI ──────────────────────────────────────────────

  /// [since] 이후 감정기록 수
  static Future<int> getEmotionCount({required DateTime since}) async {
    try {
      final snap = await _db
          .collection('emotionLogs')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      debugPrint('⚠️ getEmotionCount: $e');
      return 0;
    }
  }

  /// [since] 이후 감정 평균 점수
  ///
  /// Firestore는 평균 집계를 지원하지 않으므로
  /// 최근 200건을 읽어 클라이언트에서 계산합니다.
  static Future<double?> getAverageEmotionScore({required DateTime since}) async {
    try {
      final snap = await _db
          .collection('emotionLogs')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
          .orderBy('timestamp', descending: true)
          .limit(200)
          .get();
      if (snap.docs.isEmpty) return null;
      final scores = snap.docs
          .map((d) => (d.data()['score'] as num?)?.toDouble())
          .whereType<double>()
          .toList();
      if (scores.isEmpty) return null;
      return scores.reduce((a, b) => a + b) / scores.length;
    } catch (e) {
      debugPrint('⚠️ getAverageEmotionScore: $e');
      return null;
    }
  }

  // ─── User Flow (퍼널) ─────────────────────────────────────────

  /// 퍼널 단계별 도달자 수
  ///
  /// 4단계:
  ///   1. view_sign_in_page           — 로그인 화면 진입
  ///   2. login_success               — 로그인 성공
  ///   3. tap_profile_save            — 프로필 저장 완료
  ///   4. funnel_first_emotion_complete — 첫 감정기록 완료
  ///
  /// [since] 로 기간 제한 가능 (null이면 전체 기간)
  static Future<List<FunnelStep>> getFunnelSteps({DateTime? since}) async {
    const steps = <(String, String)>[
      ('view_sign_in_page', '① 로그인 화면 진입'),
      ('login_success', '② 로그인 성공'),
      ('tap_profile_save', '③ 프로필 저장'),
      ('funnel_first_emotion_complete', '④ 첫 감정기록 완료'),
    ];

    final result = <FunnelStep>[];
    int? prevCount;

    for (final (key, label) in steps) {
      try {
        Query<Map<String, dynamic>> q =
            _db.collection('activityLogs').where('type', isEqualTo: key);
        if (since != null) {
          q = q.where('timestamp', isGreaterThan: Timestamp.fromDate(since));
        }
        final snap = await q.count().get();
        final count = snap.count ?? 0;
        final rate = (prevCount != null && prevCount > 0)
            ? count / prevCount
            : null;
        result.add(FunnelStep(label: label, count: count, conversionRate: rate));
        prevCount = count;
      } catch (_) {
        result.add(FunnelStep(label: label, count: 0));
        prevCount = 0;
      }
    }

    return result;
  }

  // ─── Feature Reaction ─────────────────────────────────────────

  /// 기능 반응 TOP N
  ///
  /// Firestore group-by 미지원 → 최근 N건 읽어 클라이언트 집계
  /// [since] 로 기간 제한 가능
  static Future<List<FeatureReactionItem>> getTopFeatures({
    int limit = 12,
    DateTime? since,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _db
          .collection('activityLogs')
          .where('isFunnel', isNotEqualTo: true)
          .orderBy('timestamp', descending: true)
          .limit(2000);
      if (since != null) {
        q = _db
            .collection('activityLogs')
            .where('isFunnel', isNotEqualTo: true)
            .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
            .orderBy('timestamp', descending: true)
            .limit(2000);
      }
      final snap = await q.get();

      final typeMap = <String, ({int clicks, Set<String> users})>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final type = data['type'] as String? ?? '';
        final uid = data['userId'] as String? ?? '';
        if (type.isEmpty) continue;
        final prev = typeMap[type];
        if (prev == null) {
          typeMap[type] = (clicks: 1, users: {uid});
        } else {
          typeMap[type] = (
            clicks: prev.clicks + 1,
            users: {...prev.users, uid},
          );
        }
      }

      final items = typeMap.entries
          .map((e) => FeatureReactionItem(
                eventType: e.key,
                label: FeatureReactionItem.labelFor(e.key),
                clickCount: e.value.clicks,
                userCount: e.value.users.length,
              ))
          .toList()
        ..sort((a, b) => b.clickCount.compareTo(a.clickCount));

      return items.take(limit).toList();
    } catch (e) {
      debugPrint('⚠️ getTopFeatures: $e');
      return [];
    }
  }

  // ─── Emotion Feed ─────────────────────────────────────────────

  /// 최근 감정 기록 리스트
  ///
  /// emotionLogs 최신순 [limit]건
  /// [since] 로 기간 제한 가능
  static Future<List<EmotionLogItem>> getRecentEmotionLogs({
    int limit = 50,
    DateTime? since,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _db
          .collection('emotionLogs')
          .orderBy('timestamp', descending: true)
          .limit(limit);
      if (since != null) {
        q = _db
            .collection('emotionLogs')
            .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
            .orderBy('timestamp', descending: true)
            .limit(limit);
      }
      final snap = await q.get();
      return snap.docs
          .map((d) => EmotionLogItem.fromMap(d.id, d.data()))
          .toList();
    } catch (e) {
      debugPrint('⚠️ getRecentEmotionLogs: $e');
      return [];
    }
  }

  // ─── Error Monitor ────────────────────────────────────────────

  /// 최근 오류 리스트 ([since] 필터 포함)
  static Future<List<AppErrorItem>> getRecentErrors({
    int limit = 50,
    DateTime? since,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _db
          .collection('appErrors')
          .orderBy('timestamp', descending: true)
          .limit(limit);
      if (since != null) {
        q = _db
            .collection('appErrors')
            .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
            .orderBy('timestamp', descending: true)
            .limit(limit);
      }
      final snap = await q.get();
      return snap.docs
          .map((d) => AppErrorItem.fromMap(d.id, d.data()))
          .toList();
    } catch (e) {
      debugPrint('⚠️ getRecentErrors: $e');
      return [];
    }
  }

  /// 페이지별 오류 빈도 TOP N ([since] 필터 포함)
  static Future<List<MapEntry<String, int>>> getTopErrorPages({
    int limit = 5,
    DateTime? since,
  }) async {
    try {
      Query<Map<String, dynamic>> q =
          _db.collection('appErrors').limit(500);
      if (since != null) {
        q = _db
            .collection('appErrors')
            .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
            .limit(500);
      }
      final snap = await q.get();
      final pageMap = <String, int>{};
      for (final doc in snap.docs) {
        final page = doc.data()['page'] as String? ?? '(알 수 없음)';
        pageMap[page] = (pageMap[page] ?? 0) + 1;
      }
      final sorted = pageMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return sorted.take(limit).toList();
    } catch (e) {
      debugPrint('⚠️ getTopErrorPages: $e');
      return [];
    }
  }
}


