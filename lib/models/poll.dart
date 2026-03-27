import 'package:cloud_firestore/cloud_firestore.dart';

/// 공감투표 주제 모델
///
/// Firestore: polls/{pollId}
class Poll {
  final String id;
  final String question;
  /// Firestore: `active` | `closed` | `scheduled` (일정만 반영, 앱은 시간으로 판별)
  final String status;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime? closedAt;
  final int totalEmpathyCount;
  final String category;

  /// 프로그램·운영 허브 정렬용 (낮을수록 앞). 미백필 문서는 [fromDoc]에서 dayIndex·문서 ID 등으로 유추.
  final int displayOrder;

  const Poll({
    required this.id,
    required this.question,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    this.closedAt,
    this.totalEmpathyCount = 0,
    this.category = '',
    this.displayOrder = 1000000,
  });

  bool get isActive => status == 'active';
  bool get isClosed => status == 'closed';
  bool get isScheduled => status == 'scheduled';

  /// 현재 시각 기준 투표 진행 중 (startsAt ≤ now < endsAt)
  bool get isVotingOpen {
    final n = DateTime.now();
    return !startsAt.isAfter(n) && endsAt.isAfter(n);
  }

  /// 마감 시각 경과 (한마디·지난 투표 피드)
  bool get hasEnded {
    final n = DateTime.now();
    return !endsAt.isAfter(n);
  }

  /// 마감까지 남은 시간 (종료됐으면 Duration.zero)
  Duration get remaining {
    final diff = endsAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  static int _displayOrderFromMap(Map<String, dynamic> m, String docId) {
    final raw = m['displayOrder'];
    if (raw is int) return raw;
    if (raw is num) return raw.round();
    final di = m['dayIndex'];
    if (di is int) return di;
    if (di is num) return di.round();
    final match = RegExp(r'^empathy_(\d+)$').firstMatch(docId);
    if (match != null) return int.parse(match.group(1)!);
    return 1000000;
  }

  factory Poll.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>? ?? {};
    return Poll(
      id: doc.id,
      question: m['question'] as String? ?? '',
      status: m['status'] as String? ?? 'active',
      startsAt: (m['startsAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endsAt: (m['endsAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      closedAt: (m['closedAt'] as Timestamp?)?.toDate(),
      totalEmpathyCount: (m['totalEmpathyCount'] as int?) ?? 0,
      category: m['category'] as String? ?? '',
      displayOrder: _displayOrderFromMap(m, doc.id),
    );
  }

  Map<String, dynamic> toMap() => {
        'question': question,
        'status': status,
        'startsAt': Timestamp.fromDate(startsAt),
        'endsAt': Timestamp.fromDate(endsAt),
        if (closedAt != null) 'closedAt': Timestamp.fromDate(closedAt!),
        'totalEmpathyCount': totalEmpathyCount,
        'category': category,
        'displayOrder': displayOrder,
      };
}
