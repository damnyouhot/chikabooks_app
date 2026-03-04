import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/application.dart';

/// 연락처 요청/승인 서비스
///
/// 설계서 §2.3 익명 프로필 정책:
/// Step 0: 지원 초기 — 병원은 익명 프로필만 열람 가능
/// Step 1: 병원이 '연락처 요청' → 지원자에게 알림 → 승인 시 공개
///
/// 현재 MVP에서는 앱 내 알림(Firestore notifications 컬렉션) 기반
/// 푸시 알림(FCM)은 추후 연동 예정
class ContactRequestService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  // ══════════════════════════════════════════════
  // 병원 → 지원자 연락처 요청
  // ══════════════════════════════════════════════

  /// 병원이 연락처 공개를 요청
  ///
  /// 1. application 상태를 contactRequested로 변경
  /// 2. 지원자에게 앱 내 알림 생성
  static Future<void> requestContact({
    required String applicationId,
    required String applicantUid,
    required String jobTitle,
    required String clinicName,
  }) async {
    final clinicUid = _uid;
    if (clinicUid == null) throw Exception('로그인이 필요합니다.');

    final batch = _db.batch();

    // 1. application 상태 변경
    batch.update(
      _db.collection('applications').doc(applicationId),
      {
        'status': ApplicationStatus.contactRequested.name,
        'contactRequestedAt': FieldValue.serverTimestamp(),
        'contactRequestedBy': clinicUid,
      },
    );

    // 2. 지원자에게 앱 내 알림 생성
    final notifRef = _db
        .collection('users')
        .doc(applicantUid)
        .collection('notifications')
        .doc();

    batch.set(notifRef, {
      'type': 'contact_request',
      'title': '연락처 요청이 왔어요!',
      'body': '$clinicName 에서 "$jobTitle" 공고 지원에 대해 연락처를 요청했어요.',
      'data': {
        'applicationId': applicationId,
        'clinicUid': clinicUid,
        'clinicName': clinicName,
        'jobTitle': jobTitle,
      },
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    debugPrint('✅ 연락처 요청 전송: $applicationId');
  }

  // ══════════════════════════════════════════════
  // 지원자 → 연락처 공개 승인
  // ══════════════════════════════════════════════

  /// 지원자가 연락처 공개를 승인
  ///
  /// 1. application의 visibilityGranted.contactShared = true
  /// 2. 병원에게 앱 내 알림 생성
  static Future<void> approveContact({
    required String applicationId,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('로그인이 필요합니다.');

    // application 조회
    final appDoc =
        await _db.collection('applications').doc(applicationId).get();
    if (!appDoc.exists) throw Exception('존재하지 않는 지원서입니다.');

    final app = Application.fromDoc(appDoc);
    if (app.applicantUid != uid) {
      throw Exception('본인의 지원서만 승인할 수 있습니다.');
    }

    final batch = _db.batch();

    // 1. 연락처 공개 + 상태 변경
    batch.update(
      _db.collection('applications').doc(applicationId),
      {
        'visibilityGranted.contactShared': true,
        'visibilityGranted.sharedAt': FieldValue.serverTimestamp(),
        'status': ApplicationStatus.contactShared.name,
      },
    );

    // 2. 병원에게 알림
    final clinicUid = appDoc.data()?['contactRequestedBy'] as String?;
    if (clinicUid != null) {
      final notifRef = _db
          .collection('users')
          .doc(clinicUid)
          .collection('notifications')
          .doc();

      batch.set(notifRef, {
        'type': 'contact_approved',
        'title': '연락처가 공개되었어요!',
        'body': '지원자가 연락처 공개를 승인했습니다.',
        'data': {
          'applicationId': applicationId,
          'applicantUid': uid,
        },
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    debugPrint('✅ 연락처 공개 승인: $applicationId');
  }

  /// 지원자가 연락처 공개를 거절
  static Future<void> rejectContact({
    required String applicationId,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('로그인이 필요합니다.');

    await _db.collection('applications').doc(applicationId).update({
      'status': ApplicationStatus.submitted.name, // 원래 상태로 복귀
      'contactRequestedAt': FieldValue.delete(),
      'contactRequestedBy': FieldValue.delete(),
    });
    debugPrint('✅ 연락처 요청 거절: $applicationId');
  }

  // ══════════════════════════════════════════════
  // 앱 내 알림 스트림
  // ══════════════════════════════════════════════

  /// 내 알림 목록 실시간 스트림
  static Stream<List<Map<String, dynamic>>> watchMyNotifications() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);

    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            }).toList());
  }

  /// 읽지 않은 알림 수
  static Stream<int> watchUnreadCount() {
    final uid = _uid;
    if (uid == null) return Stream.value(0);

    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// 알림 읽음 처리
  static Future<void> markAsRead(String notificationId) async {
    final uid = _uid;
    if (uid == null) return;

    await _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }
}

