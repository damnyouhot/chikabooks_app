import 'package:cloud_firestore/cloud_firestore.dart';

/// analytics_daily/{dateKey} 문서의 Dart 모델
///
/// Cloud Function이 매일 새벽 생성하는 일별 집계 데이터.
/// 클라이언트에서는 읽기 전용.
///
/// ── 스키마 호환 ────────────────────────────────────────────────
/// v2 문서(기존)와 v3 문서(2026-05+) 가 같은 컬렉션에 공존한다.
/// [fromFirestore] 는 누락 필드를 모두 안전한 기본값(0 / 빈 맵)으로 채우므로,
/// 백필이 끝나지 않은 과거 날짜라도 차트가 끊기지 않는다.
/// ───────────────────────────────────────────────────────────────
class DailySummary {
  final String dateKey;
  final DateTime generatedAt;

  /// 스키마 버전 (1차: 1, 2차: 2, 3차: 3 v3+에서 신규 필드 채워짐)
  final int schemaVersion;

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

  // ── v3 신규 필드 (이전 문서에선 0/빈값 기본) ─────────────────
  /// 해당 일에 가입한 일반 사용자 수
  final int signups;

  /// 해당 일에 새로 등록된 공고자(clinic_profile) 수
  final int publisherSignups;

  /// 해당 일 결제·환불 집계
  final RevenueDaily revenueDaily;

  /// 해당 일 발생 오류 수
  final int errorCount;

  /// 서버 집계 중 일부 쿼리가 실패하면 문제 필드 키 목록을 남긴다.
  /// 빈 배열이면 모든 필드가 정상 집계된 것.
  final List<String> partialFailures;

  const DailySummary({
    required this.dateKey,
    required this.generatedAt,
    required this.schemaVersion,
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
    required this.signups,
    required this.publisherSignups,
    required this.revenueDaily,
    required this.errorCount,
    required this.partialFailures,
  });

  factory DailySummary.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return DailySummary(
      dateKey: d['dateKey'] as String? ?? doc.id,
      generatedAt: (d['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      schemaVersion: (d['schemaVersion'] as num?)?.toInt() ?? 1,
      totalValidUsers: (d['totalValidUsers'] as num?)?.toInt() ?? 0,
      activeUsers: (d['activeUsers'] as num?)?.toInt() ?? 0,
      featureUsage: _intMap(d['featureUsage']),
      tabViews: _intMap(d['tabViews']),
      tabConversions: _intMap(d['tabConversions']),
      depthBuckets: _intMap(d['depthBuckets']),
      segments: _intMap(d['segments']),
      retentionD3: (d['retention'] as Map?)?['d3'] as int? ?? 0,
      retentionD7: (d['retention'] as Map?)?['d7'] as int? ?? 0,
      eventCounts: _intMap(d['eventCounts']),
      signups: (d['signups'] as num?)?.toInt() ?? 0,
      publisherSignups: (d['publisherSignups'] as num?)?.toInt() ?? 0,
      revenueDaily: RevenueDaily.fromMap(d['revenueDaily']),
      errorCount: (d['errorCount'] as num?)?.toInt() ?? 0,
      partialFailures: _stringList(d['partialFailures']),
    );
  }

  static Map<String, int> _intMap(dynamic raw) {
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0));
    }
    return {};
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).toList(growable: false);
    }
    return const [];
  }
}

/// `analytics_daily.revenueDaily` 서브 객체
class RevenueDaily {
  final int paidCount;
  final int paidAmountKrw;
  final int refundCount;
  final int refundAmountKrw;
  final Map<String, int> byProductTier;

  const RevenueDaily({
    required this.paidCount,
    required this.paidAmountKrw,
    required this.refundCount,
    required this.refundAmountKrw,
    required this.byProductTier,
  });

  static const RevenueDaily empty = RevenueDaily(
    paidCount: 0,
    paidAmountKrw: 0,
    refundCount: 0,
    refundAmountKrw: 0,
    byProductTier: {},
  );

  factory RevenueDaily.fromMap(dynamic raw) {
    if (raw is! Map) return empty;
    final m = Map<String, dynamic>.from(raw);
    final tierRaw = m['byProductTier'];
    final tier = <String, int>{};
    if (tierRaw is Map) {
      tierRaw.forEach((k, v) {
        tier[k.toString()] = (v as num?)?.toInt() ?? 0;
      });
    }
    return RevenueDaily(
      paidCount: (m['paidCount'] as num?)?.toInt() ?? 0,
      paidAmountKrw: (m['paidAmountKrw'] as num?)?.toInt() ?? 0,
      refundCount: (m['refundCount'] as num?)?.toInt() ?? 0,
      refundAmountKrw: (m['refundAmountKrw'] as num?)?.toInt() ?? 0,
      byProductTier: tier,
    );
  }
}
