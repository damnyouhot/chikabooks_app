import 'package:cloud_firestore/cloud_firestore.dart';

/// 1:1 대화 스레드.
///
/// Firestore 경로: `messageThreads/{threadId}`
///
/// `threadId` 는 두 참여자 uid 를 사전식으로 정렬한 뒤 `_` 로 잇는다.
/// 같은 페어가 thread 를 중복 생성하지 못하도록 클라이언트가 결정적으로 만든다.
///   예: A < B 이면 threadId = "A_B"
class MessageThread {
  /// `messageThreads/{id}` 의 문서 id.
  final String id;

  /// 정확히 2개의 uid (정렬됨).
  final List<String> participants;

  /// 채팅을 시작한 시점의 컨텍스트 (선택).
  /// 예: 치과가 인재풀에서 "메시지 보내기" 로 시작한 경우 jobId 가 들어감.
  final String? jobId;

  /// 빠른 미리보기 — 가장 최근 메시지의 메타데이터.
  final String lastText;
  final String lastSenderUid;
  final DateTime? lastSentAt;

  /// 각 참여자의 안 읽은 메시지 개수.
  /// key = uid, value = 정수.
  final Map<String, int> unread;

  /// 진입 시점 표시용.
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MessageThread({
    required this.id,
    required this.participants,
    this.jobId,
    this.lastText = '',
    this.lastSenderUid = '',
    this.lastSentAt,
    this.unread = const {},
    this.createdAt,
    this.updatedAt,
  });

  factory MessageThread.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return MessageThread(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? const []),
      jobId: data['jobId'] as String?,
      lastText: (data['lastText'] as String?) ?? '',
      lastSenderUid: (data['lastSenderUid'] as String?) ?? '',
      lastSentAt: (data['lastSentAt'] as Timestamp?)?.toDate(),
      unread: ((data['unread'] as Map<String, dynamic>?) ?? const {})
          .map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0)),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// 두 uid 에서 결정적인 threadId 를 만든다.
  /// 같은 페어는 항상 동일한 id 를 반환.
  static String makeId(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// 정렬된 참여자 배열.
  static List<String> makeParticipants(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return sorted;
  }

  /// 내 시점에서의 상대방 uid.
  String otherUidFor(String myUid) {
    return participants.firstWhere((u) => u != myUid, orElse: () => '');
  }

  /// 내 시점에서의 안 읽은 개수.
  int unreadFor(String myUid) => unread[myUid] ?? 0;
}
