import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 공고자 알림 아이템 모델
class PublisherNotification {
  final String id;
  final String type; // job_expiring | draft_reminder | voucher_expiring
  final String title;
  final String body;
  final bool read;
  final DateTime? createdAt;
  final String? jobId;
  final String? draftId;
  final String? voucherId;

  const PublisherNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    this.createdAt,
    this.jobId,
    this.draftId,
    this.voucherId,
  });

  factory PublisherNotification.fromMap(String id, Map<String, dynamic> data) {
    return PublisherNotification(
      id: id,
      type: data['type'] as String? ?? '',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      read: data['read'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      jobId: data['jobId'] as String?,
      draftId: data['draftId'] as String?,
      voucherId: data['voucherId'] as String?,
    );
  }
}

/// 공고자 알림 서비스
///
/// `notifications/{uid}/items` 서브컬렉션에서 알림을 조회하고
/// 읽음 처리를 합니다. 알림 생성은 서버(Cloud Functions)에서만 수행합니다.
class PublisherNotificationService {
  static final _db = FirebaseFirestore.instance;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>>? get _itemsRef {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('notifications').doc(uid).collection('items');
  }

  /// 전체 알림 실시간 스트림 (최신순)
  static Stream<List<PublisherNotification>> watchAll({int limit = 50}) {
    final ref = _itemsRef;
    if (ref == null) return Stream.value([]);

    return ref
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PublisherNotification.fromMap(d.id, d.data()))
            .toList());
  }

  /// 읽지 않은 알림 수 실시간 스트림
  static Stream<int> watchUnreadCount() {
    final ref = _itemsRef;
    if (ref == null) return Stream.value(0);

    return ref
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// 단건 읽음 처리
  static Future<void> markAsRead(String notificationId) async {
    final ref = _itemsRef;
    if (ref == null) return;

    await ref.doc(notificationId).update({'read': true});
  }

  /// 전체 읽음 처리
  static Future<void> markAllAsRead() async {
    final ref = _itemsRef;
    if (ref == null) return;

    final snap = await ref.where('read', isEqualTo: false).get();
    if (snap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
