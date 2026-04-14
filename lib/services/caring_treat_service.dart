import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 캐릭터 먹이(퀴즈·공감투표 보상) — `users/{uid}.caringTreatCount`
///
/// 중복 지급 방지: `users/{uid}/caringTreatGrants/{docId}` 문서 존재 여부
class CaringTreatService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static const int empathyAmount = 2;
  static const int quizOpenAmount = 2;
  static const int quizCorrectAmount = 3;

  static DocumentReference<Map<String, dynamic>>? get _userRef {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  static CollectionReference<Map<String, dynamic>>? get _grantsRef {
    final u = _userRef;
    if (u == null) return null;
    return u.collection('caringTreatGrants');
  }

  /// 밥주기 **성공 저장 후** 호출: 보유 먹이 1 소모 (0 미만으로 내려가지 않음)
  static Future<void> consumeOneTreatAfterSuccessfulFeed() async {
    final userRef = _userRef;
    if (userRef == null) return;
    try {
      await _db.runTransaction<void>((txn) async {
        final snap = await txn.get(userRef);
        final raw = snap.data()?['caringTreatCount'];
        var c = 0;
        if (raw is int) {
          c = raw;
        } else if (raw is num) {
          c = raw.toInt();
        }
        if (c <= 0) return;
        txn.set(
          userRef,
          {'caringTreatCount': c - 1},
          SetOptions(merge: true),
        );
      });
    } catch (e) {
      debugPrint('⚠️ CaringTreatService.consumeOneTreatAfterSuccessfulFeed: $e');
    }
  }

  /// 먹이 개수 스트림 (로그아웃 시 0)
  static Stream<int> watchTreatCount() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(0);
    return _db.collection('users').doc(uid).snapshots().map((d) {
      final n = d.data()?['caringTreatCount'];
      if (n is int) return n;
      if (n is num) return n.toInt();
      return 0;
    });
  }

  /// 공감투표 **첫** 선택 시만 (같은 poll 재선택·변경 시 지급 없음)
  static Future<bool> tryGrantEmpathyFirstVote(String pollId) async {
    final uid = _auth.currentUser?.uid;
    final grants = _grantsRef;
    final userRef = _userRef;
    if (uid == null || grants == null || userRef == null) return false;

    final docId = 'empathy_$pollId';
    try {
      final granted = await _db.runTransaction<bool>((txn) async {
        final ref = grants.doc(docId);
        final snap = await txn.get(ref);
        if (snap.exists) return false;
        txn.set(ref, {'type': 'empathy', 'pollId': pollId, 'at': FieldValue.serverTimestamp()});
        txn.set(
          userRef,
          {'caringTreatCount': FieldValue.increment(empathyAmount)},
          SetOptions(merge: true),
        );
        return true;
      });
      return granted;
    } catch (e) {
      debugPrint('⚠️ CaringTreatService.tryGrantEmpathyFirstVote: $e');
      return false;
    }
  }

  /// 오늘의 퀴즈 화면에서 **하루 1회** (날짜 키당 1회)
  static Future<bool> tryGrantQuizDayOpened(String dateKey) async {
    final grants = _grantsRef;
    final userRef = _userRef;
    if (grants == null || userRef == null) return false;

    final docId = 'quizOpen_$dateKey';
    try {
      return await _db.runTransaction<bool>((txn) async {
        final ref = grants.doc(docId);
        final snap = await txn.get(ref);
        if (snap.exists) return false;
        txn.set(ref, {'type': 'quizOpen', 'dateKey': dateKey, 'at': FieldValue.serverTimestamp()});
        txn.set(
          userRef,
          {'caringTreatCount': FieldValue.increment(quizOpenAmount)},
          SetOptions(merge: true),
        );
        return true;
      });
    } catch (e) {
      debugPrint('⚠️ CaringTreatService.tryGrantQuizDayOpened: $e');
      return false;
    }
  }

  /// 문항별 정답 **1회** (같은 날·같은 quizId 재응시 시 중복 없음)
  static Future<bool> tryGrantQuizCorrect(String dateKey, String quizId) async {
    final grants = _grantsRef;
    final userRef = _userRef;
    if (grants == null || userRef == null) return false;

    final docId = 'quizCorrect_${dateKey}_$quizId';
    try {
      return await _db.runTransaction<bool>((txn) async {
        final ref = grants.doc(docId);
        final snap = await txn.get(ref);
        if (snap.exists) return false;
        txn.set(
          ref,
          {
            'type': 'quizCorrect',
            'dateKey': dateKey,
            'quizId': quizId,
            'at': FieldValue.serverTimestamp(),
          },
        );
        txn.set(
          userRef,
          {'caringTreatCount': FieldValue.increment(quizCorrectAmount)},
          SetOptions(merge: true),
        );
        return true;
      });
    } catch (e) {
      debugPrint('⚠️ CaringTreatService.tryGrantQuizCorrect: $e');
      return false;
    }
  }
}
