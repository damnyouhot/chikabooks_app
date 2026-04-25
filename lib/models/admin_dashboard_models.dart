/// 관리자 대시보드에서 사용하는 데이터 모델 모음
library;

import '../core/analytics/event_catalog.dart';

// ─── 표본 한계 메타 ─────────────────────────────────────────
/// activityLogs / appErrors 최근 N건만 읽어 클라이언트 집계할 때
/// "표본이 limit에 닿았는지" 알리기 위한 메타 정보.
///
/// Firestore는 group-by · distinct count를 지원하지 않아 클라이언트가
/// 최근 N건을 읽어 집계한다. 사용자/이벤트가 늘어나면 선택한 기간
/// 전체가 아니라 **최근 일부만 반영된 숫자**가 표시될 수 있어, UI에
/// 안내 배너로 명확히 표시한다.
class SampleMeta {
  /// 실제로 읽어들인 문서 수
  final int sampleSize;

  /// Firestore에 요청한 limit
  final int limit;

  /// sampleSize == limit 이면 true (= 더 오래된 데이터가 잘렸을 가능성)
  bool get truncated => sampleSize >= limit;

  const SampleMeta({required this.sampleSize, required this.limit});

  static const empty = SampleMeta(sampleSize: 0, limit: 0);
}

// ─── KPI 카드 ───────────────────────────────────────────────
class DashboardKpi {
  final String label;
  final String value;
  final String? sublabel; // 예: "최근 7일"

  const DashboardKpi({
    required this.label,
    required this.value,
    this.sublabel,
  });
}

// ─── 퍼널 단계 ───────────────────────────────────────────────
class FunnelStep {
  final String label;
  final int count;
  final double? conversionRate; // 이전 단계 대비 전환율 (0.0~1.0)

  const FunnelStep({
    required this.label,
    required this.count,
    this.conversionRate,
  });
}

// ─── 기능 반응 집계용 가상 타입 (Firestore type 문자열과 다를 수 있음) ───
///
/// [getTopFeatures]에서 `같이` 탭 투표 이벤트를 의미 단위로 합칠 때 사용합니다.
abstract final class FeatureReactionAggregates {
  FeatureReactionAggregates._();

  /// [poll_empathize] + [poll_change_empathy] 클릭·유저 합산
  static const bondPollVote = '__feat_bond_poll_vote__';

  /// [poll_add_option] 단독 (보기 추가)
  static const bondPollAdd = '__feat_bond_poll_add__';
}

// ─── 기능 반응 항목 ──────────────────────────────────────────
class FeatureReactionItem {
  /// [activityLogs.type] 또는 [FeatureReactionAggregates] 키
  final String eventType;
  final String label; // 화면에 표시할 한국어 이름
  /// [EventCatalog.tabForType] 또는 탭 고정(집계 행) — 기능 반응 그룹(탭)
  final String tab;
  final int clickCount;
  final int userCount;

  const FeatureReactionItem({
    required this.eventType,
    required this.label,
    required this.tab,
    required this.clickCount,
    required this.userCount,
  });

  /// activityLogs.type 또는 집계 키 → 한글 라벨
  static String labelFor(String type) {
    if (type == FeatureReactionAggregates.bondPollVote) {
      return '공감투표 참여';
    }
    if (type == FeatureReactionAggregates.bondPollAdd) {
      return '투표 보기 추가';
    }
    return EventCatalog.labelForType(type);
  }
}

// ─── 표본 메타를 함께 반환하는 결과 래퍼들 ─────────────────
class FeatureReactionResult {
  final List<FeatureReactionItem> items;
  final SampleMeta sample;
  const FeatureReactionResult({required this.items, required this.sample});
}

class RecentErrorsResult {
  final List<AppErrorItem> items;
  final SampleMeta sample;
  const RecentErrorsResult({required this.items, required this.sample});
}

class TopErrorPagesResult {
  final List<MapEntry<String, int>> entries;
  final SampleMeta sample;
  const TopErrorPagesResult({required this.entries, required this.sample});
}

// ─── 오류 항목 ───────────────────────────────────────────────
class AppErrorItem {
  final String id;
  final DateTime timestamp;
  final String errorMessage;
  final String? page;
  final String? feature;
  final String? appVersion;
  final String? uid;
  final bool isFatal;

  const AppErrorItem({
    required this.id,
    required this.timestamp,
    required this.errorMessage,
    this.page,
    this.feature,
    this.appVersion,
    this.uid,
    this.isFatal = false,
  });

  factory AppErrorItem.fromMap(String id, Map<String, dynamic> m) {
    return AppErrorItem(
      id: id,
      timestamp: (m['timestamp'] as dynamic)?.toDate() ?? DateTime.now(),
      errorMessage: m['errorMessage'] as String? ?? '(메시지 없음)',
      page: m['page'] as String?,
      feature: m['feature'] as String?,
      appVersion: m['appVersion'] as String?,
      uid: m['userId'] as String?,   // ← AppErrorLogger가 'userId'로 저장
      isFatal: m['isFatal'] as bool? ?? false,
    );
  }
}

// ─── 연차 분포 항목 ──────────────────────────────────────────
class CareerGroupCount {
  final String group; // careerBucket: '0-2', '3-5', '6+'
  final int count;

  const CareerGroupCount({required this.group, required this.count});

  String get label {
    const map = {
      '0-2': '0~2년차',
      '3-5': '3~5년차',
      '6+':  '6년차+',
    };
    return map[group] ?? group;
  }
}

