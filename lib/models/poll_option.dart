import 'package:cloud_firestore/cloud_firestore.dart';

/// 공감투표 보기(선택지) 모델
///
/// Firestore: polls/{pollId}/options/{optionId}
class PollOption {
  final String id;
  final String content;
  final String? authorUid;
  /// 사용자 추가 보기 작성 시점 닉네임(비정규화). 구문서는 null.
  final String? authorNickname;
  final bool isSystem;
  final DateTime createdAt;
  final int empathyCount;
  final int reportCount;
  final bool isHidden;

  const PollOption({
    required this.id,
    required this.content,
    this.authorUid,
    this.authorNickname,
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
      authorNickname: m['authorNickname'] as String?,
      isSystem: m['isSystem'] as bool? ?? true,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      empathyCount: (m['empathyCount'] as int?) ?? 0,
      reportCount: (m['reportCount'] as int?) ?? 0,
      isHidden: m['isHidden'] as bool? ?? false,
    );
  }

  /// 사용자 추가 보기 하단에 표시할 이름(구문서·빈 닉네임은 '익명')
  String get displayAuthorLabel {
    if (isSystem) return '';
    final n = authorNickname?.trim();
    if (n != null && n.isNotEmpty) return n;
    return '익명';
  }

  Map<String, dynamic> toMap() => {
        'content': content,
        'authorUid': authorUid,
        if (authorNickname != null) 'authorNickname': authorNickname,
        'isSystem': isSystem,
        'createdAt': Timestamp.fromDate(createdAt),
        'empathyCount': empathyCount,
        'reportCount': reportCount,
        'isHidden': isHidden,
      };
}
