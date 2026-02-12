import 'package:cloud_firestore/cloud_firestore.dart';

/// 파트너 한마디 슬롯
/// docId 형식: "{groupId}_{dateKey}_{slotKey}" (예: abc123_2026-02-10_1230)
class DailySlot {
  final String id;
  final String groupId;
  final String dateKey;     // "2026-02-10"
  final String slotKey;     // "1230" | "1900"
  final String? claimedByUid;
  final DateTime? claimedAt;
  final String? text;       // 최대 60자
  final String? toneEmoji;
  final String status;      // "open" | "claimed" | "posted"

  const DailySlot({
    required this.id,
    required this.groupId,
    required this.dateKey,
    required this.slotKey,
    this.claimedByUid,
    this.claimedAt,
    this.text,
    this.toneEmoji,
    this.status = 'open',
  });

  bool get isOpen => status == 'open';
  bool get isClaimed => status == 'claimed';
  bool get isPosted => status == 'posted';

  /// 슬롯 시간 라벨
  String get slotTimeLabel {
    if (slotKey == '1230') return '12:30';
    if (slotKey == '1900') return '19:00';
    return slotKey;
  }

  factory DailySlot.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return DailySlot(
      id: doc.id,
      groupId: d['groupId'] ?? '',
      dateKey: d['dateKey'] ?? '',
      slotKey: d['slotKey'] ?? '',
      claimedByUid: d['claimedByUid'],
      claimedAt: _ts(d['claimedAt']),
      text: d['text'],
      toneEmoji: d['toneEmoji'],
      status: d['status'] ?? 'open',
    );
  }

  Map<String, dynamic> toMap() => {
        'groupId': groupId,
        'dateKey': dateKey,
        'slotKey': slotKey,
        'claimedByUid': claimedByUid,
        'claimedAt': claimedAt != null ? Timestamp.fromDate(claimedAt!) : null,
        'text': text,
        'toneEmoji': toneEmoji,
        'status': status,
      };

  static DateTime? _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}

/// 슬롯 리액션 (dailySlots/{docId}/reactions/{uid})
class SlotReaction {
  final String uid;
  final String reactionKey;
  final DateTime createdAt;

  const SlotReaction({
    required this.uid,
    required this.reactionKey,
    required this.createdAt,
  });

  factory SlotReaction.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return SlotReaction(
      uid: doc.id,
      reactionKey: d['reactionKey'] ?? '',
      createdAt: _ts(d['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'reactionKey': reactionKey,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  static DateTime _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.now();
  }
}



