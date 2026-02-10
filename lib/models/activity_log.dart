import 'package:cloud_firestore/cloud_firestore.dart';

/// 파트너 활동 로그 (요약 카드용)
/// 컬렉션: partnerGroups/{groupId}/activityLogs/{logId}
class ActivityLog {
  final String id;
  final DateTime createdAt;
  final String actorUid;
  final ActivityType type;
  final Map<String, dynamic> meta; // 타입별 추가 정보

  const ActivityLog({
    required this.id,
    required this.createdAt,
    required this.actorUid,
    required this.type,
    this.meta = const {},
  });

  factory ActivityLog.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ActivityLog(
      id: doc.id,
      createdAt: _ts(d['createdAt']),
      actorUid: d['actorUid'] ?? '',
      type: ActivityType.fromString(d['type'] ?? ''),
      meta: Map<String, dynamic>.from(d['meta'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() => {
        'createdAt': Timestamp.fromDate(createdAt),
        'actorUid': actorUid,
        'type': type.value,
        'meta': meta,
      };

  /// 요약 카드용 아이콘
  String get summaryIcon {
    switch (type) {
      case ActivityType.slotPost:
        return '✍️';
      case ActivityType.slotReaction:
        return '💛';
      case ActivityType.cheerReaction:
        return '✨';
      case ActivityType.ebookRead:
        return '📖';
      case ActivityType.quizComplete:
        return '🧠';
      case ActivityType.wallPost:
        return '🫧';
      case ActivityType.pollVote:
        return '🗳️';
      default:
        return '·';
    }
  }

  static DateTime _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.now();
  }
}

enum ActivityType {
  slotClaim('SLOT_CLAIM'),
  slotPost('SLOT_POST'),
  slotReaction('SLOT_REACTION'),
  cheerReaction('CHEER_REACTION'),
  ebookRead('EBOOK_3MIN'),
  quizComplete('QUIZ_1'),
  wallPost('WALL_POST'),
  pollVote('POLL_VOTE'),
  unknown('UNKNOWN');

  final String value;
  const ActivityType(this.value);

  static ActivityType fromString(String s) {
    return ActivityType.values.firstWhere(
      (e) => e.value == s,
      orElse: () => ActivityType.unknown,
    );
  }
}

