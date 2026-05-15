import 'package:cloud_firestore/cloud_firestore.dart';

/// 종료된 투표에 달리는 한마디 댓글
class PollComment {
  PollComment({
    required this.id,
    required this.text,
    required this.uid,
    required this.createdAt,
    this.likeCount = 0,
    this.replyCount = 0,
    this.stickerIds = const [],
  });

  final String id;
  final String text;
  final String uid;
  final DateTime createdAt;
  final int likeCount;
  final int replyCount;
  final List<String> stickerIds;

  factory PollComment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return PollComment(
      id: doc.id,
      text: (d['text'] as String?) ?? '',
      uid: (d['uid'] as String?) ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likeCount: (d['likeCount'] as int?) ?? 0,
      replyCount: (d['replyCount'] as int?) ?? 0,
      stickerIds: List<String>.from(d['stickerIds'] as List? ?? []),
    );
  }
}
