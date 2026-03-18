import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/analytics_daily_model.dart';

/// analytics_daily 읽기 + 백필 서비스
///
/// ── 역할 ─────────────────────────────────────────────────────
/// 1. fetchRange: 기간 내 일별 집계 문서 읽기 (차트용)
/// 2. backfill: 누락된 날짜의 집계를 activityLogs에서 생성
/// ──────────────────────────────────────────────────────────────
class AdminAnalyticsDailyService {
  static final _db = FirebaseFirestore.instance;

  // ── 의미 있는 행동 이벤트 (AdminBehaviorService와 동일) ──
  static const _meaningfulActions = {
    'tap_character',
    'tap_emotion_start',
    'tap_emotion_save',
    'emotion_save_success',
    'tap_profile_save',
    'tap_job_save',
    'tap_job_apply',
    'tap_career_edit',
    'view_job_detail',
    'quiz_completed',
  };

  static const _growthEvents = {'view_growth'};
  static const _emotionEvents = {'tap_character', 'emotion_save_success'};
  static const _careerEvents = {'view_job_detail', 'tap_job_save', 'tap_job_apply'};

  static const _featureKeys = {
    'emotion_save_success',
    'tap_character',
    'view_job_detail',
    'quiz_completed',
  };

  static const _tabKeys = {
    'view_home',
    'view_job',
    'view_growth',
    'view_bond',
  };

  static const _conversionPairs = [
    ('view_home', 'emotion_save_success'),
    ('view_job', 'view_job_detail'),
    ('view_growth', 'quiz_completed'),
  ];

  /// 기간 내 일별 집계 문서 읽기
  static Future<List<DailySummary>> fetchRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final startKey = _dateKey(start);
    final endKey = _dateKey(end);

    debugPrint('📊 [AnalyticsDaily] fetchRange: $startKey ~ $endKey');

    final snap = await _db
        .collection('analytics_daily')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startKey)
        .where(FieldPath.documentId, isLessThanOrEqualTo: endKey)
        .orderBy(FieldPath.documentId)
        .get();

    debugPrint('📊 [AnalyticsDaily] ${snap.docs.length}건 로드');

    return snap.docs.map((d) => DailySummary.fromFirestore(d)).toList();
  }

  /// 누락된 날짜만 백필
  ///
  /// 관리자 화면에서 "백필" 버튼을 누를 때 호출.
  /// 이미 존재하는 날짜는 건너뛴다.
  static Future<int> backfill({
    required DateTime start,
    required DateTime end,
  }) async {
    final existing = await fetchRange(start: start, end: end);
    final existingKeys = existing.map((e) => e.dateKey).toSet();

    final allDates = <DateTime>[];
    var cursor = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    while (!cursor.isAfter(endDate)) {
      if (!existingKeys.contains(_dateKey(cursor))) {
        allDates.add(cursor);
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    if (allDates.isEmpty) {
      debugPrint('📊 [Backfill] 누락 없음');
      return 0;
    }

    debugPrint('📊 [Backfill] 누락 ${allDates.length}일 생성 시작');

    // validUserIds 1회 확보
    final usersSnap = await _db
        .collection('users')
        .where('excludeFromStats', isEqualTo: false)
        .get();
    final validUserIds = <String>{};
    for (final doc in usersSnap.docs) {
      validUserIds.add(doc.id);
    }

    int created = 0;
    for (final date in allDates) {
      try {
        await _generateForDate(date, validUserIds);
        created++;
        debugPrint('📊 [Backfill] ${_dateKey(date)} 완료 ($created/${allDates.length})');
      } catch (e) {
        debugPrint('⚠️ [Backfill] ${_dateKey(date)} 실패: $e');
      }
    }

    debugPrint('📊 [Backfill] 총 $created일 생성 완료');
    return created;
  }

  /// 특정 날짜의 집계를 activityLogs에서 계산하여 Firestore에 저장
  static Future<void> _generateForDate(
    DateTime date,
    Set<String> validUserIds,
  ) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final dateKey = _dateKey(date);

    final snap = await _db
        .collection('activityLogs')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('timestamp', isLessThan: Timestamp.fromDate(dayEnd))
        .orderBy('timestamp')
        .limit(5000)
        .get();

    // uid → 이벤트 타입 목록
    final userEvents = <String, List<String>>{};
    final eventCounts = <String, int>{};
    final activeUserIds = <String>{};

    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['isFunnel'] == true) continue;
      if (data['accountType'] == 'publisher') continue;

      final uid = data['userId'] as String? ?? '';
      final type = data['type'] as String? ?? '';
      if (uid.isEmpty || type.isEmpty) continue;
      if (!validUserIds.contains(uid)) continue;

      activeUserIds.add(uid);
      userEvents.putIfAbsent(uid, () => []).add(type);
      eventCounts[type] = (eventCounts[type] ?? 0) + 1;
    }

    final total = validUserIds.length;

    // featureUsage: 각 기능을 1회 이상 사용한 고유 유저 수
    final featureUsage = <String, int>{};
    for (final key in _featureKeys) {
      featureUsage[key] = userEvents.entries
          .where((e) => e.value.contains(key))
          .length;
    }

    // tabViews
    final tabViews = <String, int>{};
    for (final key in _tabKeys) {
      tabViews[key] = userEvents.entries
          .where((e) => e.value.contains(key))
          .length;
    }

    // tabConversions
    final tabConversions = <String, int>{};
    for (final (tab, action) in _conversionPairs) {
      final convKey = '${tab}__$action';
      tabConversions[convKey] = userEvents.entries
          .where((e) => e.value.contains(tab) && e.value.contains(action))
          .length;
    }

    // depthBuckets
    int loginOnly = 0, oneAction = 0, twoToFour = 0, fivePlus = 0;
    for (final entry in userEvents.entries) {
      final meaningful = entry.value.where((t) => _meaningfulActions.contains(t)).length;
      if (meaningful == 0) {
        loginOnly++;
      } else if (meaningful == 1) {
        oneAction++;
      } else if (meaningful <= 4) {
        twoToFour++;
      } else {
        fivePlus++;
      }
    }
    final noEventUsers = validUserIds.where((uid) => !userEvents.containsKey(uid)).length;
    loginOnly += noEventUsers;

    // segments
    int growth = 0, emotion = 0, career = 0, ghost = 0;
    for (final entry in userEvents.entries) {
      final types = entry.value.toSet();
      final isGrowth = types.any((t) => _growthEvents.contains(t));
      final isEmotion = types.any((t) => _emotionEvents.contains(t));
      final isCareer = types.any((t) => _careerEvents.contains(t));
      if (isGrowth) growth++;
      if (isEmotion) emotion++;
      if (isCareer) career++;
      if (!isGrowth && !isEmotion && !isCareer) {
        if (!types.any((t) => _meaningfulActions.contains(t))) ghost++;
      }
    }
    ghost += noEventUsers;

    // retention은 단일 날짜에서는 의미가 제한적이므로 0으로 기본 저장
    // (7일 범위 재방문은 fetchRange 이후 클라이언트에서 계산)

    await _db.collection('analytics_daily').doc(dateKey).set({
      'dateKey': dateKey,
      'generatedAt': FieldValue.serverTimestamp(),
      'totalValidUsers': total,
      'activeUsers': activeUserIds.length,
      'featureUsage': featureUsage,
      'tabViews': tabViews,
      'tabConversions': tabConversions,
      'depthBuckets': {
        'loginOnly': loginOnly,
        'oneAction': oneAction,
        'twoToFour': twoToFour,
        'fivePlus': fivePlus,
      },
      'segments': {
        'growth': growth,
        'emotion': emotion,
        'career': career,
        'ghost': ghost,
      },
      'retention': {'d3': 0, 'd7': 0},
      'eventCounts': eventCounts,
    });
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
