import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 광고 캠페인 알림 인박스.
///
/// Firestore: `users/{uid}/clinicInbox/{noticeId}`
///   - 만료 임박, 자동연장 성공·실패, 환불 등 자동화 알림이 적재된다 (서버만 추가).
///   - 클라이언트는 read 토글만 가능 (firestore.rules 에 강제).
///
/// 사용 예:
///   - 캠페인 대시보드 상단 종 아이콘에 미읽음 카운트 노출.
///   - 알림 드롭다운/페이지에서 deepLink 따라가도록.
class ClinicInboxNotice {
  const ClinicInboxNotice({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.severity,
    required this.read,
    required this.createdAt,
    this.campaignId,
    this.jobId,
    this.orderId,
    this.deepLink,
    this.dedupeKey,
    this.meta,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String severity;
  final bool read;
  final DateTime createdAt;
  final String? campaignId;
  final String? jobId;
  final String? orderId;
  final String? deepLink;
  final String? dedupeKey;
  final Map<String, dynamic>? meta;

  factory ClinicInboxNotice.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final d = snap.data() ?? <String, dynamic>{};
    final ts = d['createdAt'];
    return ClinicInboxNotice(
      id: snap.id,
      type: (d['type'] ?? '').toString(),
      title: (d['title'] ?? '').toString(),
      body: (d['body'] ?? '').toString(),
      severity: (d['severity'] ?? 'info').toString(),
      read: d['read'] == true,
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      campaignId: d['campaignId'] as String?,
      jobId: d['jobId'] as String?,
      orderId: d['orderId'] as String?,
      deepLink: d['deepLink'] as String?,
      dedupeKey: d['dedupeKey'] as String?,
      meta: d['meta'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(d['meta'] as Map)
          : null,
    );
  }
}

class ClinicInboxService {
  ClinicInboxService._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('clinicInbox');

  /// 최신순 N건 스트림.
  static Stream<List<ClinicInboxNotice>> watchRecent({int limit = 30}) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _col(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map(ClinicInboxNotice.fromDoc).toList(growable: false),
        );
  }

  /// 미읽음 개수 스트림 (배지용).
  static Stream<int> watchUnreadCount() {
    final uid = _uid;
    if (uid == null) return Stream.value(0);
    return _col(uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  /// 특정 알림 읽음 처리.
  static Future<bool> markRead(String noticeId) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await _col(uid).doc(noticeId).update({
        'read': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('⚠️ ClinicInboxService.markRead: $e');
      return false;
    }
  }

  /// 미읽음 일괄 읽음 처리 (최대 200건).
  static Future<int> markAllRead({int limit = 200}) async {
    final uid = _uid;
    if (uid == null) return 0;
    try {
      final q = await _col(uid)
          .where('read', isEqualTo: false)
          .limit(limit)
          .get();
      if (q.docs.isEmpty) return 0;
      final batch = _db.batch();
      final now = FieldValue.serverTimestamp();
      for (final d in q.docs) {
        batch.update(d.reference, {'read': true, 'updatedAt': now});
      }
      await batch.commit();
      return q.docs.length;
    } catch (e) {
      debugPrint('⚠️ ClinicInboxService.markAllRead: $e');
      return 0;
    }
  }
}
