import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// 행동 분석 대시보드 데이터 서비스
///
/// ── 핵심 원칙 ─────────────────────────────────────────────────
/// 1. users 컬렉션에서 excludeFromStats == false인 유효 UID 집합(validUserIds)을
///    먼저 확보한 뒤, 모든 지표를 이 집합 기준으로만 계산한다.
/// 2. activityLogs를 1회 bulk read하여 7개 지표를 동시에 계산한다.
/// 3. 새로운 Firestore write는 절대 추가하지 않는다.
/// ──────────────────────────────────────────────────────────────
class AdminBehaviorService {
  static final _db = FirebaseFirestore.instance;

  // ── 의미 있는 행동 이벤트 (단순 화면 진입 제외) ──
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

  // ── 유저 타입 분류용 이벤트 그룹 ──
  static const _growthEvents = {'view_growth'};
  static const _emotionEvents = {'tap_character', 'emotion_save_success'};
  static const _careerEvents = {
    'view_job_detail',
    'tap_job_save',
    'tap_job_apply',
  };

  /// activityLogs bulk read → 7개 지표 동시 계산
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

      // ── Step 4: 7개 지표 계산 (모두 validUserIds 기준) ──
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
    const features = <(String, Set<String>)>[
      ('감정 기록', {'emotion_save_success'}),
      ('캐릭터 인터랙션', {'tap_character'}),
      ('채용 공고 클릭', {'view_job_detail'}),
      ('퀴즈 풀이', {'quiz_completed'}),
    ];

    return features.map((f) {
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
    const pairs = <(String, String, String)>[
      ('나 탭 → 감정 기록', 'view_home', 'emotion_save_success'),
      ('구직 탭 → 공고 상세', 'view_job', 'view_job_detail'),
      ('성장 탭 → 퀴즈 풀이', 'view_growth', 'quiz_completed'),
    ];

    return pairs.map((p) {
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
      'view_bond' => '교감 탭',
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
          entry.value.where((e) => _meaningfulActions.contains(e.type)).length;
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
    const features = <(String, String, int)>[
      ('감정 기록 2회+', 'emotion_save_success', 2),
      ('캐릭터 상호작용 3회+', 'tap_character', 3),
      ('퀴즈 풀이 2회+', 'quiz_completed', 2),
    ];

    return features.map((f) {
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
        basis: '${f.$1.split(' ').first} 1회 이상 사용자',
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
    int ghost = 0;

    for (final entry in userEvents.entries) {
      final types = entry.value.map((e) => e.type).toSet();
      final isGrowth = types.any((t) => _growthEvents.contains(t));
      final isEmotion = types.any((t) => _emotionEvents.contains(t));
      final isCareer = types.any((t) => _careerEvents.contains(t));
      if (isGrowth) growth++;
      if (isEmotion) emotion++;
      if (isCareer) career++;
      if (!isGrowth && !isEmotion && !isCareer) {
        final hasMeaningful =
            types.any((t) => _meaningfulActions.contains(t));
        if (!hasMeaningful) ghost++;
      }
    }

    // validUserIds 중 이벤트가 없는 유저 → 유령
    final noEventUsers = validUserIds
        .where((uid) => !userEvents.containsKey(uid))
        .length;
    ghost += noEventUsers;

    debugPrint('📊 [유저타입] 성장관심=$growth, 감정=$emotion, '
        '커리어=$career, 유령=$ghost(이벤트없음=$noEventUsers), total=$total');

    return [
      MetricCard.safe(
          label: '성장 관심형', count: growth, total: total,
          basis: '전체 로그인 사용자'),
      MetricCard.safe(
          label: '감정형', count: emotion, total: total,
          basis: '전체 로그인 사용자'),
      MetricCard.safe(
          label: '커리어형', count: career, total: total,
          basis: '전체 로그인 사용자'),
      MetricCard.safe(
          label: '유령 유저', count: ghost, total: total,
          basis: '전체 로그인 사용자'),
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

    const order = ['나 탭', '교감 탭', '성장 탭', '구직 탭', '기타'];
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
        type == 'emotion_save_success') return '나 탭';
    if (type.startsWith('view_bond')) return '교감 탭';
    if (type.startsWith('view_growth') || type == 'quiz_completed') {
      return '성장 탭';
    }
    if (type.startsWith('view_job') ||
        type == 'tap_job_save' ||
        type == 'tap_job_apply') return '구직 탭';
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

  const MetricCard({
    required this.label,
    required this.count,
    required this.total,
    required this.basis,
  });

  /// 안전한 생성자: 음수 clamp + 분자>분모 warning
  factory MetricCard.safe({
    required String label,
    required int count,
    required int total,
    required String basis,
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
