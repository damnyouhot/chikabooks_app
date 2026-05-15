import 'package:cloud_firestore/cloud_firestore.dart';

/// 종료된 투표 댓글에 달리는 대댓글
class PollCommentReply {
  PollCommentReply({
    required this.id,
    required this.text,
    required this.uid,
    required this.createdAt,
    this.nickname = '',
    this.likeCount = 0,
    this.stickerIds = const [],
  });

  final String id;
  final String text;
  final String uid;
  final DateTime createdAt;
  /// 빈 문자열이면 익명 작성
  final String nickname;
  final int likeCount;
  final List<String> stickerIds;

  factory PollCommentReply.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return PollCommentReply(
      id: doc.id,
      text: (d['text'] as String?) ?? '',
      uid: (d['uid'] as String?) ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      nickname: (d['nickname'] as String?) ?? '',
      likeCount: (d['likeCount'] as int?) ?? 0,
      stickerIds: List<String>.from(d['stickerIds'] as List? ?? []),
    );
  }
}
