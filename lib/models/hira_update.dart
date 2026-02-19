import 'package:cloud_firestore/cloud_firestore.dart';

/// HIRA 수가/급여 변경 업데이트
class HiraUpdate {
  final String id;
  final String title;
  final String link;
  final DateTime publishedAt;
  final String topic; // 'act' or 'notice'
  final int impactScore;
  final String impactLevel; // 'HIGH', 'MID', 'LOW'
  final List<String> keywords;
  final List<String> actionHints;
  final DateTime fetchedAt;

  HiraUpdate({
    required this.id,
    required this.title,
    required this.link,
    required this.publishedAt,
    required this.topic,
    required this.impactScore,
    required this.impactLevel,
    required this.keywords,
    required this.actionHints,
    required this.fetchedAt,
  });

  factory HiraUpdate.fromMap(String id, Map<String, dynamic> map) {
    return HiraUpdate(
      id: id,
      title: map['title'] as String? ?? '',
      link: map['link'] as String? ?? '',
      publishedAt: (map['publishedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      topic: map['topic'] as String? ?? 'notice',
      impactScore: map['impactScore'] as int? ?? 0,
      impactLevel: map['impactLevel'] as String? ?? 'LOW',
      keywords: List<String>.from(map['keywords'] ?? []),
      actionHints: List<String>.from(map['actionHints'] ?? []),
      fetchedAt: (map['fetchedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'link': link,
      'publishedAt': Timestamp.fromDate(publishedAt),
      'topic': topic,
      'impactScore': impactScore,
      'impactLevel': impactLevel,
      'keywords': keywords,
      'actionHints': actionHints,
      'fetchedAt': Timestamp.fromDate(fetchedAt),
    };
  }
}

/// HIRA Digest (오늘의 상위 3건)
class HiraDigest {
  final String dateKey; // YYYY-MM-DD
  final List<String> topIds;
  final DateTime generatedAt;

  HiraDigest({
    required this.dateKey,
    required this.topIds,
    required this.generatedAt,
  });

  factory HiraDigest.fromMap(String dateKey, Map<String, dynamic> map) {
    return HiraDigest(
      dateKey: dateKey,
      topIds: List<String>.from(map['topIds'] ?? []),
      generatedAt: (map['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'topIds': topIds,
      'generatedAt': Timestamp.fromDate(generatedAt),
    };
  }
}

