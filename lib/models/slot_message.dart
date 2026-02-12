import 'package:cloud_firestore/cloud_firestore.dart';

/// 슬롯 한마디 메시지
class SlotMessage {
  final String id; // slotId
  final String slotKey; // "1230" | "1900"
  final String date; // "YYYY-MM-DD"
  final String groupId;
  final String message;
  final String authorUid;
  final DateTime createdAt;
  final Map<String, SlotReaction> reactions;

  const SlotMessage({
    required this.id,
    required this.slotKey,
    required this.date,
    required this.groupId,
    required this.message,
    required this.authorUid,
    required this.createdAt,
    this.reactions = const {},
  });

  factory SlotMessage.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final reactionsMap = d['reactions'] as Map<String, dynamic>? ?? {};
    final reactions = <String, SlotReaction>{};
    reactionsMap.forEach((uid, data) {
      if (data is Map<String, dynamic>) {
        reactions[uid] = SlotReaction.fromMap(data);
      }
    });

    return SlotMessage(
      id: doc.id,
      slotKey: d['slotKey'] ?? '',
      date: d['date'] ?? '',
      groupId: d['groupId'] ?? '',
      message: d['message'] ?? '',
      authorUid: d['authorUid'] ?? '',
      createdAt: _toDateTime(d['createdAt']),
      reactions: reactions,
    );
  }

  static DateTime _toDateTime(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.now();
  }
}

/// 슬롯 리액션
class SlotReaction {
  final String emoji;
  final String phraseId;
  final String phraseText;
  final DateTime reactedAt;

  const SlotReaction({
    required this.emoji,
    required this.phraseId,
    required this.phraseText,
    required this.reactedAt,
  });

  factory SlotReaction.fromMap(Map<String, dynamic> m) => SlotReaction(
        emoji: m['emoji'] ?? '',
        phraseId: m['phraseId'] ?? '',
        phraseText: m['phraseText'] ?? '',
        reactedAt: _toDateTime(m['reactedAt']),
      );

  static DateTime _toDateTime(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.now();
  }
}



