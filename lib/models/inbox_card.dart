import 'package:cloud_firestore/cloud_firestore.dart';

/// 파트너 인박스 요약 카드
class InboxCard {
  final String id; // inboxId: ${groupId}_${YYYY-MM-DD}
  final String groupId;
  final String date; // "YYYY-MM-DD"
  final DateTime createdAt;
  final List<InboxItem> items;
  final bool unread;
  final DateTime? readAt;

  const InboxCard({
    required this.id,
    required this.groupId,
    required this.date,
    required this.createdAt,
    this.items = const [],
    this.unread = true,
    this.readAt,
  });

  factory InboxCard.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final itemsList = d['items'] as List<dynamic>? ?? [];
    final items = itemsList
        .map((e) => InboxItem.fromMap(e as Map<String, dynamic>))
        .toList();

    return InboxCard(
      id: doc.id,
      groupId: d['groupId'] ?? '',
      date: d['date'] ?? '',
      createdAt: _toDateTime(d['createdAt']),
      items: items,
      unread: d['unread'] ?? true,
      readAt: d['readAt'] != null ? _toDateTime(d['readAt']) : null,
    );
  }

  static DateTime _toDateTime(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.now();
  }
}

/// 인박스 항목 (사람별 묶음)
class InboxItem {
  final String actorUid;
  final String actorRegion;
  final String actorCareerBucket;
  final List<String> lines; // ["한마디 1개", "리액션 2개"]
  final DateTime lastAt;

  const InboxItem({
    required this.actorUid,
    required this.actorRegion,
    required this.actorCareerBucket,
    this.lines = const [],
    required this.lastAt,
  });

  factory InboxItem.fromMap(Map<String, dynamic> m) => InboxItem(
        actorUid: m['actorUid'] ?? '',
        actorRegion: m['actorRegion'] ?? '',
        actorCareerBucket: m['actorCareerBucket'] ?? '',
        lines: List<String>.from(m['lines'] ?? []),
        lastAt: _toDateTime(m['lastAt']),
      );

  static DateTime _toDateTime(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.now();
  }

  /// 지역 + 경력 라벨 (예: "서울 · 3-5")
  String get locationLabel {
    final parts = <String>[];
    if (actorRegion.isNotEmpty) parts.add(actorRegion);
    if (actorCareerBucket.isNotEmpty) parts.add(actorCareerBucket);
    return parts.join(' · ');
  }
}



