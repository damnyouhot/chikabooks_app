import 'package:cloud_firestore/cloud_firestore.dart';

/// 공감투표 보기(선택지) 모델
///
/// Firestore: polls/{pollId}/options/{optionId}
class PollOption {
  final String id;
  final String content;
  final String? authorUid;
  final bool isSystem;
  final DateTime createdAt;
  final int empathyCount;
  final int reportCount;
  final bool isHidden;

  const PollOption({
    required this.id,
    required this.content,
    this.authorUid,
    required this.isSystem,
    required this.createdAt,
    this.empathyCount = 0,
    this.reportCount = 0,
    this.isHidden = false,
  });

  factory PollOption.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>? ?? {};
    return PollOption(
      id: doc.id,
      content: m['content'] as String? ?? '',
      authorUid: m['authorUid'] as String?,
      isSystem: m['isSystem'] as bool? ?? true,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      empathyCount: (m['empathyCount'] as int?) ?? 0,
      reportCount: (m['reportCount'] as int?) ?? 0,
      isHidden: m['isHidden'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'content': content,
        'authorUid': authorUid,
        'isSystem': isSystem,
        'createdAt': Timestamp.fromDate(createdAt),
        'empathyCount': empathyCount,
        'reportCount': reportCount,
        'isHidden': isHidden,
      };
}
