import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/admin_dashboard_models.dart';

/// 관리자 대시보드 데이터를 Firestore에서 읽어오는 서비스
class AdminDashboardService {
  static final _db = FirebaseFirestore.instance;

  // ─── Overview ─────────────────────────────────────────────────

  /// 전체 사용자 수 (excludeFromStats 제외)
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

  /// 최근 N일 신규 가입자 수
  static Future<int> getRecentSignups(int days) async {
    try {
      final since = DateTime.now().subtract(Duration(days: days));
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

  /// 최근 N일 활성 유저 수 (lastActiveAt 기준)
  static Future<int> getActiveUserCount(int days) async {
    try {
      final since = DateTime.now().subtract(Duration(days: days));
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

  /// 장기 미접속 유저 수 (lastActiveAt이 N일 이상 없거나 없는 유저)
  static Future<int> getLongAbsentCount(int days) async {
    try {
      final since = DateTime.now().subtract(Duration(days: days));
      final snap = await _db
          .collection('users')
          .where('lastActiveAt', isLessThan: Timestamp.fromDate(since))
          .where('excludeFromStats', isNotEqualTo: true)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      debugPrint('⚠️ getLongAbsentCount: $e');
      return 0;
    }
  }

  /// 연차별 사용자 분포
  static Future<List<CareerGroupCount>> getCareerGroupDistribution() async {
    const groups = ['student', '1y', '2_3y', '4_7y', '8y_plus'];
    final result = <CareerGroupCount>[];
    for (final g in groups) {
      try {
        final snap = await _db
            .collection('users')
            .where('careerYearGroup', isEqualTo: g)
            .where('excludeFromStats', isNotEqualTo: true)
            .count()
            .get();
        result.add(CareerGroupCount(group: g, count: snap.count ?? 0));
      } catch (_) {
        result.add(CareerGroupCount(group: g, count: 0));
      }
    }
    return result;
  }

  /// 최근 24시간 오류 수
  static Future<int> getRecentErrorCount() async {
    try {
      final since = DateTime.now().subtract(const Duration(hours: 24));
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

  // ─── User Flow (퍼널) ─────────────────────────────────────────

  /// 퍼널 단계별 도달자 수
  ///
  /// activityLogs에서 isFunnel == true인 레코드를 type별로 집계
  static Future<List<FunnelStep>> getFunnelSteps() async {
    // 퍼널 단계 정의 (순서, key, 표시 라벨)
    const steps = [
      ('funnel_signup_complete', '회원가입 완료'),
      ('funnel_profile_basic', '프로필 입력'),
      ('funnel_profile_partner', '파트너 설정'),
      ('funnel_first_emotion_start', '첫 감정기록 시작'),
      ('funnel_first_emotion_complete', '첫 감정기록 완료'),
    ];

    final result = <FunnelStep>[];
    int? prevCount;

    for (final (key, label) in steps) {
      try {
        final snap = await _db
            .collection('activityLogs')
            .where('type', isEqualTo: key)
            .count()
            .get();
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

  /// 기능 클릭 TOP N (activityLogs 기반)
  static Future<List<FeatureReactionItem>> getTopFeatures({int limit = 10}) async {
    try {
      // Firestore는 group-by를 직접 지원하지 않으므로 최근 1000건을 읽어 클라이언트에서 집계
      final snap = await _db
          .collection('activityLogs')
          .where('isFunnel', isNotEqualTo: true)
          .orderBy('timestamp', descending: true)
          .limit(2000)
          .get();

      // type → (clickCount, Set<uid>) 집계
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

      final items = typeMap.entries.map((e) => FeatureReactionItem(
        eventType: e.key,
        label: FeatureReactionItem.labelFor(e.key),
        clickCount: e.value.clicks,
        userCount: e.value.users.length,
      )).toList()
        ..sort((a, b) => b.clickCount.compareTo(a.clickCount));

      return items.take(limit).toList();
    } catch (e) {
      debugPrint('⚠️ getTopFeatures: $e');
      return [];
    }
  }

  /// 최근 오류 리스트
  static Future<List<AppErrorItem>> getRecentErrors({int limit = 20}) async {
    try {
      final snap = await _db
          .collection('appErrors')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((d) => AppErrorItem.fromMap(d.id, d.data()))
          .toList();
    } catch (e) {
      debugPrint('⚠️ getRecentErrors: $e');
      return [];
    }
  }

  /// 페이지별 오류 발생 빈도 TOP N
  static Future<List<MapEntry<String, int>>> getTopErrorPages({int limit = 5}) async {
    try {
      final snap = await _db
          .collection('appErrors')
          .limit(500)
          .get();
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

