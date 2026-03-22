import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/analytics/event_catalog.dart';

/// 행동 분석 대시보드 데이터 서비스
///
/// ── 핵심 원칙 ─────────────────────────────────────────────────
/// 1. users 컬렉션에서 excludeFromStats == false인 유효 UID 집합(validUserIds)을
///    먼저 확보한 뒤, 모든 지표를 이 집합 기준으로만 계산한다.
/// 2. activityLogs를 1회 bulk read하여 7개 지표를 동시에 계산한다.
/// 3. 새로운 Firestore write는 절대 추가하지 않는다.
/// 4. 탭 전환·기능 실행률·세그먼트 타입 집합은 [EventCatalog] 단일 출처 (C파트).
/// ──────────────────────────────────────────────────────────────
class AdminBehaviorService {
  static final _db = FirebaseFirestore.instance;

  /// activityLogs bulk read → 지표 동시 계산
  static Future<BehaviorAnalysis> analyze({
    required DateTime since,
    int readLimit = 3000,
  }) async {
    try {
      // ── Step 1: 유효 UID 집합 확보 ──
      final usersSnap = await _db
          .collection('users')
          .where('excludeFromStats', isEqualTo: false)
          .get();
      final validUserIds = <String>{};
      for (final doc in usersSnap.docs) {
        validUserIds.add(doc.id);
      }
      final total = validUserIds.length;
      debugPrint('📊 [Behavior] validUserIds: $total명');

      // ── Step 2: activityLogs bulk read ──
      final snap = await _db
          .collection('activityLogs')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
          .orderBy('timestamp', descending: true)
          .limit(readLimit)
          .get();

      debugPrint('📊 [Behavior] activityLogs 원본: ${snap.docs.length}건');

      // ── Step 3: validUserIds 기준 필터링 + 그룹화 ──
      final userEvents = <String, List<_EventEntry>>{};
      int skippedFunnel = 0;
      int skippedInvalidUid = 0;
      int skippedPublisher = 0;
      int skippedEmpty = 0;

      for (final doc in snap.docs) {
        final data = doc.data();

        if (data['isFunnel'] == true) {
          skippedFunnel++;
          continue;
        }
        if (data['accountType'] == 'publisher') {
          skippedPublisher++;
          continue;
        }

        final uid = data['userId'] as String? ?? '';
        final type = data['type'] as String? ?? '';
        final ts = (data['timestamp'] as Timestamp?)?.toDate();

        if (uid.isEmpty || type.isEmpty || ts == null) {
          skippedEmpty++;
          continue;
        }
        if (!validUserIds.contains(uid)) {
          skippedInvalidUid++;
          continue;
        }

        userEvents.putIfAbsent(uid, () => []).add(_EventEntry(type, ts));
      }

      debugPrint('📊 [Behavior] 필터 후 distinct uid: ${userEvents.length}명');
      debugPrint('📊 [Behavior] 제외 — '
          'funnel=$skippedFunnel, '
          'invalidUid=$skippedInvalidUid, '
          'publisher=$skippedPublisher, '
          'empty=$skippedEmpty');

      // ── Step 4: 지표 계산 (모두 validUserIds 기준) ──
      final featureUsage = _calcFeatureUsage(userEvents, total);
      final conversions = _calcConversions(userEvents);
      final depth = _calcEngagementDepth(userEvents, validUserIds, total);
      final repeat = _calcRepeatUsage(userEvents);
      final segments = _calcUserSegments(userEvents, validUserIds, total);
      final firstActions = _calcFirstAction(userEvents, total);
      final retention = _calcRetention(userEvents, total);

      return BehaviorAnalysis(
        totalLoginUsers: total,
        featureUsage: featureUsage,
        conversions: conversions,
        depth: depth,
        repeat: repeat,
        segments: segments,
        firstActions: firstActions,
        retention: retention,
      );
    } catch (e, st) {
      debugPrint('❌ [Behavior] analyze 실패: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  // ── 1. 기능 실행률 ──
  static List<MetricCard> _calcFeatureUsage(
    Map<String, List<_EventEntry>> userEvents,
    int total,
  ) {
    return EventCatalog.behaviorFeatureUsageRows.map((f) {
      final count = userEvents.entries
          .where((e) => e.value.any((ev) => f.$2.contains(ev.type)))
          .length;
      debugPrint('📊 [기능실행률] ${f.$1}: $count / $total');
      return MetricCard.safe(
        label: f.$1,
        count: count,
        total: total,
        basis: '전체 로그인 사용자',
      );
    }).toList();
  }

  // ── 2. 탭→행동 전환율 ──
  static List<MetricCard> _calcConversions(
    Map<String, List<_EventEntry>> userEvents,
  ) {
    return EventCatalog.behaviorConversionRows.map((p) {
      final tabUsers = userEvents.entries
          .where((e) => e.value.any((ev) => ev.type == p.$2))
          .length;
      final actionUsers = userEvents.entries
          .where(
            (e) =>
                e.value.any((ev) => ev.type == p.$2) &&
                e.value.any((ev) => ev.type == p.$3),
          )
          .length;
      debugPrint('📊 [전환율] ${p.$1}: $actionUsers / $tabUsers');
      return MetricCard.safe(
        label: p.$1,
        count: actionUsers,
        total: tabUsers,
        basis: '${_tabLabel(p.$2)} 진입 사용자',
      );
    }).toList();
  }

  static String _tabLabel(String event) {
    return switch (event) {
      'view_home' => '나 탭',
      'view_job' => '구직 탭',
      'view_growth' => '성장 탭',
      'view_bond' => '같이 탭',
      _ => event,
    };
  }

  // ── 3. 행동 깊이 ──
  static List<MetricCard> _calcEngagementDepth(
    Map<String, List<_EventEntry>> userEvents,
    Set<String> validUserIds,
    int total,
  ) {
    int loginOnly = 0;
    int oneAction = 0;
    int twoToFour = 0;
    int fivePlus = 0;

    for (final entry in userEvents.entries) {
      final meaningful =
          entry.value
              .where((e) => EventCatalog.meaningfulTypes.contains(e.type))
              .length;
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

    // validUserIds 중 activityLogs에 이벤트가 없는 유저 → 로그인만
    final noEventUsers = validUserIds
        .where((uid) => !userEvents.containsKey(uid))
        .length;
    loginOnly += noEventUsers;

    debugPrint('📊 [행동깊이] 로그인만=$loginOnly(이벤트없음=$noEventUsers), '
        '1회=$oneAction, 2~4회=$twoToFour, 5회+=$fivePlus, total=$total');

    return [
      MetricCard.safe(
          label: '로그인만 (0회)', count: loginOnly, total: total,
          basis: '전체 로그인 사용자'),
      MetricCard.safe(
          label: '1회 행동', count: oneAction, total: total,
          basis: '전체 로그인 사용자'),
      MetricCard.safe(
          label: '2~4회 행동', count: twoToFour, total: total,
          basis: '전체 로그인 사용자'),
      MetricCard.safe(
          label: '5회 이상 행동', count: fivePlus, total: total,
          basis: '전체 로그인 사용자'),
    ];
  }

  // ── 4. 반복 사용 ──
  static List<MetricCard> _calcRepeatUsage(
    Map<String, List<_EventEntry>> userEvents,
  ) {
    return EventCatalog.behaviorRepeatRows.map((f) {
      final oneOrMore = userEvents.entries
          .where((e) => e.value.any((ev) => ev.type == f.$2))
          .length;
      final repeatUsers = userEvents.entries
          .where(
            (e) => e.value.where((ev) => ev.type == f.$2).length >= f.$3,
          )
          .length;
      debugPrint('📊 [반복사용] ${f.$1}: $repeatUsers / $oneOrMore');
      return MetricCard.safe(
        label: f.$1,
        count: repeatUsers,
        total: oneOrMore,
        basis: f.$4,
      );
    }).toList();
  }

  // ── 5. 유저 타입 분포 ──
  static List<MetricCard> _calcUserSegments(
    Map<String, List<_EventEntry>> userEvents,
    Set<String> validUserIds,
    int total,
  ) {
    int growth = 0;
    int emotion = 0;
    int career = 0;
    int bond = 0;
    int ghost = 0;

    for (final entry in userEvents.entries) {
      final types = entry.value.map((e) => e.type).toSet();
      final isGrowth =
          types.any((t) => EventCatalog.segmentGrowthTypes.contains(t));
      final isEmotion =
          types.any((t) => EventCatalog.segmentEmotionTypes.contains(t));
      final isCareer =
          types.any((t) => EventCatalog.segmentCareerTypes.contains(t));
      final isBond =
          types.any((t) => EventCatalog.segmentBondTypes.contains(t));
      if (isGrowth) growth++;
      if (isEmotion) emotion++;
      if (isCareer) career++;
      if (isBond) bond++;
      if (!isGrowth &&
          !isEmotion &&
          !isCareer &&
          !isBond &&
          !types.any((t) => EventCatalog.meaningfulTypes.contains(t))) {
        ghost++;
      }
    }

    // validUserIds 중 이벤트가 없는 유저 → 유령
    final noEventUsers = validUserIds
        .where((uid) => !userEvents.containsKey(uid))
        .length;
    ghost += noEventUsers;

    debugPrint('📊 [유저타입] 성장관심=$growth, 감정=$emotion, '
        '커리어=$career, 교감=$bond, 유령=$ghost(이벤트없음=$noEventUsers), total=$total');

    final segDetails = EventCatalog.behaviorSegmentCardDetails;
    return [
      MetricCard.safe(
        label: '성장 관심형',
        count: growth,
        total: total,
        basis: '전체 로그인 사용자',
        detail: segDetails[0],
      ),
      MetricCard.safe(
        label: '감정형',
        count: emotion,
        total: total,
        basis: '전체 로그인 사용자',
        detail: segDetails[1],
      ),
      MetricCard.safe(
        label: '커리어형',
        count: career,
        total: total,
        basis: '전체 로그인 사용자',
        detail: segDetails[2],
      ),
      MetricCard.safe(
        label: '교감형',
        count: bond,
        total: total,
        basis: '전체 로그인 사용자',
        detail: segDetails[3],
      ),
      MetricCard.safe(
        label: '유령 유저',
        count: ghost,
        total: total,
        basis: '전체 로그인 사용자',
        detail: segDetails[4],
      ),
    ];
  }

  // ── 6. 첫 클릭 위치 ──
  static List<MetricCard> _calcFirstAction(
    Map<String, List<_EventEntry>> userEvents,
    int total,
  ) {
    final firstActionMap = <String, int>{};

    for (final entry in userEvents.entries) {
      final sorted = [...entry.value]..sort((a, b) => a.ts.compareTo(b.ts));
      final loginIdx =
          sorted.indexWhere((e) => e.type == 'login_success');
      final startIdx = loginIdx >= 0 ? loginIdx + 1 : 0;
      for (var i = startIdx; i < sorted.length; i++) {
        final t = sorted[i].type;
        if (t == 'login_success' || t == 'app_open') continue;
        final category = _categorizeAction(t);
        firstActionMap[category] = (firstActionMap[category] ?? 0) + 1;
        break;
      }
    }

    debugPrint('📊 [첫클릭] $firstActionMap, total=$total');

    const order = [
      '나 탭',
      '교감 탭',
      '성장 탭',
      '구직 탭',
      '커리어 탭',
      '기타',
    ];
    return order.map((cat) {
      return MetricCard.safe(
        label: '$cat 첫 클릭',
        count: firstActionMap[cat] ?? 0,
        total: total,
        basis: '전체 로그인 사용자',
      );
    }).toList();
  }

  static String _categorizeAction(String type) {
    if (type.startsWith('view_home') ||
        type == 'tap_character' ||
        type == 'tap_emotion_start' ||
        type == 'emotion_save_success' ||
        type == 'caring_feed_success') {
      return '나 탭';
    }
    if (type.startsWith('view_bond') ||
        type == 'poll_empathize' ||
        type == 'poll_change_empathy' ||
        type == 'poll_add_option') {
      return '교감 탭';
    }
    if (type.startsWith('view_growth') || type == 'quiz_completed') {
      return '성장 탭';
    }
    if (type.startsWith('view_job') ||
        type == 'tap_job_save' ||
        type == 'tap_job_apply') {
      return '구직 탭';
    }
    if (type.startsWith('view_career') || type == 'tap_career_edit') {
      return '커리어 탭';
    }
    return '기타';
  }

  // ── 7. 재방문 (D3/D7 Retention Lite) ──
  static RetentionData _calcRetention(
    Map<String, List<_EventEntry>> userEvents,
    int total,
  ) {
    int d3 = 0;
    int d7 = 0;

    for (final entry in userEvents.entries) {
      final distinctDays = entry.value
          .map((e) => DateTime(e.ts.year, e.ts.month, e.ts.day))
          .toSet()
          .length;
      if (distinctDays >= 2) d3++;
      if (distinctDays >= 3) d7++;
    }

    debugPrint('📊 [재방문] D3=$d3, D7=$d7, total=$total');

    return RetentionData(d3Count: d3, d7Count: d7, total: total);
  }
}

// ── 내부 이벤트 엔트리 ──
class _EventEntry {
  final String type;
  final DateTime ts;
  const _EventEntry(this.type, this.ts);
}

// ═══════════════════════════════════════════════════════════════
// 결과 모델
// ═══════════════════════════════════════════════════════════════

class BehaviorAnalysis {
  final int totalLoginUsers;
  final List<MetricCard> featureUsage;
  final List<MetricCard> conversions;
  final List<MetricCard> depth;
  final List<MetricCard> repeat;
  final List<MetricCard> segments;
  final List<MetricCard> firstActions;
  final RetentionData retention;

  const BehaviorAnalysis({
    required this.totalLoginUsers,
    required this.featureUsage,
    required this.conversions,
    required this.depth,
    required this.repeat,
    required this.segments,
    required this.firstActions,
    required this.retention,
  });
}

class MetricCard {
  final String label;
  final int count;
  final int total;
  final String basis;

  /// 집계 규칙 등 추가 설명 (유저 타입 등)
  final String? detail;

  const MetricCard({
    required this.label,
    required this.count,
    required this.total,
    required this.basis,
    this.detail,
  });

  /// 안전한 생성자: 음수 clamp + 분자>분모 warning
  factory MetricCard.safe({
    required String label,
    required int count,
    required int total,
    required String basis,
    String? detail,
  }) {
    var safeCount = count < 0 ? 0 : count;
    final safeTotal = total < 0 ? 0 : total;

    if (safeCount > safeTotal && safeTotal > 0) {
      debugPrint('⚠️ [MetricCard] "$label" 분자($count) > 분모($total) → clamp');
      safeCount = safeTotal;
    }

    return MetricCard(
      label: label,
      count: safeCount,
      total: safeTotal,
      basis: basis,
      detail: detail,
    );
  }

  double get rate => total > 0 ? (count / total).clamp(0.0, 1.0) : 0;
  String get percent => '${(rate * 100).toStringAsFixed(0)}%';
}

class RetentionData {
  final int d3Count;
  final int d7Count;
  final int total;

  const RetentionData({
    required this.d3Count,
    required this.d7Count,
    required this.total,
  });
}
