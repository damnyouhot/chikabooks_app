import 'package:cloud_firestore/cloud_firestore.dart';

/// analytics_daily/{dateKey} 문서의 Dart 모델
///
/// Cloud Function이 매일 새벽 생성하는 일별 집계 데이터.
/// 클라이언트에서는 읽기 전용.
class DailySummary {
  final String dateKey;
  final DateTime generatedAt;
  final int totalValidUsers;
  final int activeUsers;

  /// 기능별 고유 유저 수 (해당 이벤트 1회 이상 발생시킨 유저)
  final Map<String, int> featureUsage;

  /// 탭 진입 고유 유저 수
  final Map<String, int> tabViews;

  /// 탭→행동 전환 유저 수 (키: `tabViewType__actionType`, 예: `view_home__caring_feed_success`)
  ///
  /// 키는 [EventCatalog.kTabConversionRows] 정의가 바뀌면 달라질 수 있음. 과거 문서와 시계열 비교 시
  /// 동일 키가 동일 비즈니스 의미인지 확인할 것.
  final Map<String, int> tabConversions;

  /// 행동 깊이 분포
  final Map<String, int> depthBuckets;

  /// 유저 타입 분포
  final Map<String, int> segments;

  /// 재방문
  final int retentionD3;
  final int retentionD7;

  /// 이벤트별 총 발생 횟수 (차트 "일별 클릭 수" 용)
  final Map<String, int> eventCounts;

  const DailySummary({
    required this.dateKey,
    required this.generatedAt,
    required this.totalValidUsers,
    required this.activeUsers,
    required this.featureUsage,
    required this.tabViews,
    required this.tabConversions,
    required this.depthBuckets,
    required this.segments,
    required this.retentionD3,
    required this.retentionD7,
    required this.eventCounts,
  });

  factory DailySummary.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return DailySummary(
      dateKey: d['dateKey'] as String? ?? doc.id,
      generatedAt: (d['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalValidUsers: d['totalValidUsers'] as int? ?? 0,
      activeUsers: d['activeUsers'] as int? ?? 0,
      featureUsage: _intMap(d['featureUsage']),
      tabViews: _intMap(d['tabViews']),
      tabConversions: _intMap(d['tabConversions']),
      depthBuckets: _intMap(d['depthBuckets']),
      segments: _intMap(d['segments']),
      retentionD3: (d['retention'] as Map?)?['d3'] as int? ?? 0,
      retentionD7: (d['retention'] as Map?)?['d7'] as int? ?? 0,
      eventCounts: _intMap(d['eventCounts']),
    );
  }

  static Map<String, int> _intMap(dynamic raw) {
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0));
    }
    return {};
  }
}
