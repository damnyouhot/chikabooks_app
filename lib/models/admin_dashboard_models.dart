/// 관리자 대시보드에서 사용하는 데이터 모델 모음
library;

import '../core/analytics/event_catalog.dart';

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

// ─── 기능 반응 항목 ──────────────────────────────────────────
class FeatureReactionItem {
  final String eventType; // activityLogs.type
  final String label; // 화면에 표시할 한국어 이름
  /// [EventCatalog.tabForType] — 기능 반응 그룹(탭)
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

  /// activityLogs.type → 한국어 라벨 ([EventCatalog] 단일 출처)
  static String labelFor(String type) => EventCatalog.labelForType(type);
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

// ─── 기록하기 항목 — 대시보드 피드용 ──────────────────────────────
class NoteFeedItem {
  final String id;
  final String userId;
  final String text;
  final DateTime createdAt;
  final List<String> imageUrls;

  const NoteFeedItem({
    required this.id,
    required this.userId,
    required this.text,
    required this.createdAt,
    this.imageUrls = const [],
  });
}

// ─── 감정 기록 항목 (EmotionLog — emotionLogs 컬렉션용, 레거시) ─
class EmotionLogItem {
  final String id;
  final String userId;
  final DateTime timestamp;
  final int? score;
  final String? text;
  final List<String> tags;
  final String? careerGroupSnapshot;

  const EmotionLogItem({
    required this.id,
    required this.userId,
    required this.timestamp,
    this.score,
    this.text,
    this.tags = const [],
    this.careerGroupSnapshot,
  });

  factory EmotionLogItem.fromMap(String id, Map<String, dynamic> m) {
    List<String> parsedTags = [];
    final rawTags = m['tags'];
    if (rawTags is List) {
      parsedTags = rawTags.map((e) => e.toString()).toList();
    }
    return EmotionLogItem(
      id: id,
      userId: m['userId'] as String? ?? '',
      timestamp: (m['timestamp'] as dynamic)?.toDate() ?? DateTime.now(),
      score: (m['score'] as num?)?.toInt(),
      text: m['text'] as String?,
      tags: parsedTags,
      careerGroupSnapshot: m['careerGroupSnapshot'] as String?,
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

