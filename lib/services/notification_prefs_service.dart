import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/notification_prefs.dart';

/// `clinics_accounts/{uid}/notificationPrefs/default` 문서 한 개로 관리.
///
/// 클라이언트가 직접 read/write 하며, 서버 발송 시 이 문서를 참조한다.
/// (값에 외부 시스템 자격증명 등 민감 정보는 들어가지 않으므로 client 쓰기 허용)
class NotificationPrefsService {
  NotificationPrefsService._();

  static final _db = FirebaseFirestore.instance;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static DocumentReference<Map<String, dynamic>> _docFor(String uid) =>
      _db
          .collection('clinics_accounts')
          .doc(uid)
          .collection('notificationPrefs')
          .doc('default');

  /// 실시간 구독.
  ///
  /// [uid] 를 주입하면 그 사용자에 대한 stream 을 만든다 (계정 격리).
  static Stream<NotificationPrefs> watchPrefs({String? uid}) {
    final effectiveUid = uid ?? _uid;
    if (effectiveUid == null) {
      return Stream.value(NotificationPrefs.defaults());
    }
    return _docFor(effectiveUid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) {
        return NotificationPrefs.defaults();
      }
      return NotificationPrefs.fromMap(snap.data()!);
    });
  }

  /// 한 번 읽기.
  static Future<NotificationPrefs> getPrefs() async {
    final uid = _uid;
    if (uid == null) return NotificationPrefs.defaults();
    final snap = await _docFor(uid).get();
    if (!snap.exists || snap.data() == null) {
      return NotificationPrefs.defaults();
    }
    return NotificationPrefs.fromMap(snap.data()!);
  }

  /// 전체 저장 (덮어쓰기).
  static Future<void> savePrefs(NotificationPrefs prefs) async {
    final uid = _uid;
    if (uid == null) {
      throw StateError('로그인이 필요합니다.');
    }
    await _docFor(uid).set(prefs.toMap(), SetOptions(merge: true));
  }

  /// 채널만 부분 업데이트.
  static Future<void> updateChannels(
      NotificationChannels channels) async {
    final uid = _uid;
    if (uid == null) {
      throw StateError('로그인이 필요합니다.');
    }
    await _docFor(uid).set({
      'channels': channels.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 이벤트만 부분 업데이트.
  static Future<void> updateEvents(NotificationEvents events) async {
    final uid = _uid;
    if (uid == null) {
      throw StateError('로그인이 필요합니다.');
    }
    await _docFor(uid).set({
      'events': events.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 수신자 추가.
  static Future<void> addRecipient(NotificationRecipient r) async {
    final cur = await getPrefs();
    final next = [...cur.recipients, r];
    await savePrefs(cur.copyWith(recipients: next));
  }

  /// 수신자 갱신.
  static Future<void> updateRecipient(
      NotificationRecipient r) async {
    final cur = await getPrefs();
    final next = cur.recipients
        .map((e) => e.id == r.id ? r : e)
        .toList(growable: false);
    await savePrefs(cur.copyWith(recipients: next));
  }

  /// 수신자 삭제.
  static Future<void> removeRecipient(String id) async {
    final cur = await getPrefs();
    final next =
        cur.recipients.where((e) => e.id != id).toList(growable: false);
    await savePrefs(cur.copyWith(recipients: next));
  }

  /// 야간 무음 토글.
  static Future<void> setQuietHours(bool on) async {
    final uid = _uid;
    if (uid == null) {
      throw StateError('로그인이 필요합니다.');
    }
    await _docFor(uid).set({
      'quietHours': on,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
