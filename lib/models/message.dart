import 'package:cloud_firestore/cloud_firestore.dart';

/// 단일 메시지.
///
/// Firestore 경로: `messageThreads/{threadId}/messages/{messageId}`
class Message {
  final String id;
  final String senderUid;
  final String text;
  final DateTime? sentAt;

  const Message({
    required this.id,
    required this.senderUid,
    required this.text,
    this.sentAt,
  });

  factory Message.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Message(
      id: doc.id,
      senderUid: (data['senderUid'] as String?) ?? '',
      text: (data['text'] as String?) ?? '',
      sentAt: (data['sentAt'] as Timestamp?)?.toDate(),
    );
  }
}
