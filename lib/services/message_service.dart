import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/message.dart';
import '../models/message_thread.dart';

/// 1:1 메시지 스레드/메시지 운영 서비스.
///
/// 데이터 모델
///   `messageThreads/{threadId}`
///     - participants: `List<String>` (size 2, 사전식 정렬)
///     - jobId?: `String`             (시작 컨텍스트)
///     - lastText, lastSenderUid, lastSentAt
///     - unread: `Map<String,int>`
///     - createdAt, updatedAt
///   `messageThreads/{threadId}/messages/{messageId}`
///     - senderUid, text, sentAt
///
/// MVP 범위: 텍스트만. 첨부/푸시는 후속 단계에서 확장.
class MessageService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static CollectionReference<Map<String, dynamic>> get _threadsRef =>
      _db.collection('messageThreads');

  static DocumentReference<Map<String, dynamic>> _threadDoc(String id) =>
      _threadsRef.doc(id);

  static CollectionReference<Map<String, dynamic>> _messagesRef(String tid) =>
      _threadDoc(tid).collection('messages');

  /// 내 thread 목록 (최근 업데이트 순).
  static Stream<List<MessageThread>> watchMyThreads() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const <MessageThread>[]);
    return _threadsRef
        .where('participants', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map(MessageThread.fromDoc).toList());
  }

  /// 단일 thread 변경 구독 (대화창에서 안 읽은 카운트/타이틀 등 동기화).
  static Stream<MessageThread?> watchThread(String threadId) {
    return _threadDoc(threadId).snapshots().map(
          (snap) => snap.exists ? MessageThread.fromDoc(snap) : null,
        );
  }

  /// thread 내 메시지 목록 (오래된 → 최신).
  static Stream<List<Message>> watchMessages(String threadId, {int limit = 200}) {
    return _messagesRef(threadId)
        .orderBy('sentAt')
        .limitToLast(limit)
        .snapshots()
        .map((s) => s.docs.map(Message.fromDoc).toList());
  }

  /// 해당 페어의 thread 를 만들거나 가져온다 (id 결정적).
  ///
  /// - 이미 존재하면 그대로 반환
  /// - 없으면 메타데이터(participants, unread=0, createdAt 등) 채워서 생성
  /// 반환: threadId
  static Future<String> ensureThread({
    required String otherUid,
    String? jobId,
  }) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) {
      throw StateError('로그인이 필요해요.');
    }
    if (otherUid.isEmpty || otherUid == myUid) {
      throw ArgumentError('상대방 uid 가 유효하지 않아요.');
    }

    final tid = MessageThread.makeId(myUid, otherUid);
    final doc = _threadDoc(tid);
    final snap = await doc.get();
    if (snap.exists) {
      // 컨텍스트(jobId) 가 새로 전달됐고 기존 값이 비어 있으면 채워준다.
      if (jobId != null &&
          (jobId.isNotEmpty) &&
          (snap.data()?['jobId'] == null)) {
        await doc.update({'jobId': jobId, 'updatedAt': FieldValue.serverTimestamp()});
      }
      return tid;
    }

    final participants = MessageThread.makeParticipants(myUid, otherUid);
    final now = FieldValue.serverTimestamp();
    await doc.set({
      'participants': participants,
      if (jobId != null && jobId.isNotEmpty) 'jobId': jobId,
      'lastText': '',
      'lastSenderUid': '',
      'unread': {for (final u in participants) u: 0},
      'createdAt': now,
      'updatedAt': now,
    });
    return tid;
  }

  /// 메시지 전송. thread 의 lastMessage / unread / updatedAt 까지 갱신.
  ///
  /// 모든 작업은 batch 로 atomic 처리해 lastMessage 와 메시지가 어긋나지 않게 한다.
  static Future<void> sendMessage({
    required String threadId,
    required String text,
  }) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) {
      throw StateError('로그인이 필요해요.');
    }
    final t = text.trim();
    if (t.isEmpty) return;

    final threadDoc = _threadDoc(threadId);
    final threadSnap = await threadDoc.get();
    if (!threadSnap.exists) {
      throw StateError('대화방을 찾을 수 없어요.');
    }
    final participants =
        List<String>.from(threadSnap.data()?['participants'] ?? const []);
    if (!participants.contains(myUid)) {
      throw StateError('이 대화방에 참여하고 있지 않아요.');
    }

    final newMsgRef = _messagesRef(threadId).doc();
    final batch = _db.batch();
    batch.set(newMsgRef, {
      'senderUid': myUid,
      'text': t,
      'sentAt': FieldValue.serverTimestamp(),
    });

    // 상대방 unread +1, 본인 unread 는 0 으로 유지(보낸 사람은 이미 본 것).
    final unreadUpdates = <String, dynamic>{};
    for (final uid in participants) {
      if (uid == myUid) {
        unreadUpdates['unread.$uid'] = 0;
      } else {
        unreadUpdates['unread.$uid'] = FieldValue.increment(1);
      }
    }
    batch.update(threadDoc, {
      'lastText': t,
      'lastSenderUid': myUid,
      'lastSentAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      ...unreadUpdates,
    });

    await batch.commit();
  }

  /// 내가 이 thread 를 본 것으로 표시(unread.myUid = 0).
  static Future<void> markRead(String threadId) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;
    try {
      await _threadDoc(threadId).update({'unread.$myUid': 0});
    } catch (e) {
      // 권한/네트워크 일시 오류는 무시 (다음 진입 시 다시 시도).
      debugPrint('⚠️ MessageService.markRead error: $e');
    }
  }
}
