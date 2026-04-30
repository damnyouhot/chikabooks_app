import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 캐릭터 먹이(퀴즈·공감투표·속닥속닥·오늘 단어 등) — `users/{uid}.caringTreatCount`
///
/// 중복 지급 방지: `users/{uid}/caringTreatGrants/{docId}` 문서 존재 여부
class CaringTreatService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static const int empathyAmount = 1;

  /// 퀴즈 문항을 **처음 제출**할 때(풀 때) 1개 — 하루 2문항이면 최대 2
  static const int quizFirstAnswerAmount = 1;
  static const int quizCorrectAmount = 1;

  /// 글·댓글·답글 작성 시 지급(일일 속닥 합산 상한 내)
  static const int whisperWriteTreatAmount = 2;

  /// 좋아요·힘내요 등 반응 1회당
  static const int whisperReactionTreatAmount = 1;

  /// 속닥속닥 관련 먹이(작성+반응) 하루 합산 상한
  static const int whisperDailyTreatCap = 10;
  static const int feedCost = 3;

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

  static String _dateKeyKst([DateTime? dt]) {
    final kst = (dt ?? DateTime.now().toUtc()).add(const Duration(hours: 9));
    return '${kst.year}-${kst.month.toString().padLeft(2, '0')}-'
        '${kst.day.toString().padLeft(2, '0')}';
  }

  static int _treatTotalFromDayData(Map<String, dynamic>? data) {
    if (data == null) return 0;
    final t = data['treatTotal'];
    if (t is int) return t;
    if (t is num) return t.toInt();
    // 레거시: 작성 이벤트 횟수만 있던 시절(회당 1먹이) → 상한 추정
    final legacy = data['count'];
    if (legacy is int) return legacy;
    if (legacy is num) return legacy.toInt();
    return 0;
  }

  static int _intFromGrantData(Map<String, dynamic>? data, String key) {
    final value = data?[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static Future<bool> _revokeWhisperGrant(String docId) async {
    final grants = _grantsRef;
    final userRef = _userRef;
    if (grants == null || userRef == null) return false;

    try {
      return await _db.runTransaction<bool>((txn) async {
        final grantRef = grants.doc(docId);
        final grantSnap = await txn.get(grantRef);
        final grantData = grantSnap.data();
        if (!grantSnap.exists || grantData == null) return false;

        final amount = _intFromGrantData(grantData, 'amount');
        final dateKey = grantData['dateKey'] as String?;
        if (amount <= 0 || dateKey == null || dateKey.isEmpty) {
          txn.delete(grantRef);
          return false;
        }

        final dayRef = grants.doc('whisperDay_$dateKey');
        final daySnap = await txn.get(dayRef);
        final dayTotal = _treatTotalFromDayData(daySnap.data());

        final userSnap = await txn.get(userRef);
        final currentTreat = _intFromGrantData(
          userSnap.data(),
          'caringTreatCount',
        );

        txn.delete(grantRef);
        txn.set(dayRef, {
          'type': 'whisperDay',
          'dateKey': dateKey,
          'treatTotal': (dayTotal - amount).clamp(0, whisperDailyTreatCap),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        txn.set(userRef, {
          'caringTreatCount': (currentTreat - amount).clamp(0, currentTreat),
        }, SetOptions(merge: true));
        return true;
      });
    } catch (e) {
      debugPrint('⚠️ CaringTreatService._revokeWhisperGrant: $e');
      return false;
    }
  }

  /// 밥주기 **성공 저장 후** 호출: 보유 먹이 [feedCost]개 소모
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
        if (c < feedCost) return;
        txn.set(userRef, {
          'caringTreatCount': c - feedCost,
        }, SetOptions(merge: true));
      });
    } catch (e) {
      debugPrint(
        '⚠️ CaringTreatService.consumeOneTreatAfterSuccessfulFeed: $e',
      );
    }
  }

  /// 서버에 저장된 현재 보유 먹이 개수 (미로그인·오류 시 0)
  static Future<int> getTreatCount() async {
    final userRef = _userRef;
    if (userRef == null) return 0;
    try {
      final snap = await userRef.get();
      final n = snap.data()?['caringTreatCount'];
      if (n is int) return n;
      if (n is num) return n.toInt();
      return 0;
    } catch (e) {
      debugPrint('⚠️ CaringTreatService.getTreatCount: $e');
      return 0;
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
        txn.set(ref, {
          'type': 'empathy',
          'pollId': pollId,
          'at': FieldValue.serverTimestamp(),
        });
        txn.set(userRef, {
          'caringTreatCount': FieldValue.increment(empathyAmount),
        }, SetOptions(merge: true));
        return true;
      });
      return granted;
    } catch (e) {
      debugPrint('⚠️ CaringTreatService.tryGrantEmpathyFirstVote: $e');
      return false;
    }
  }

  /// 오늘의 퀴즈 문항을 **처음 제출**했을 때 1개 (문항당 1회, 하루 최대 2문항 → 2개)
  static Future<bool> tryGrantQuizFirstAnswer(
    String dateKey,
    String quizId,
  ) async {
    final grants = _grantsRef;
    final userRef = _userRef;
    if (grants == null || userRef == null) return false;

    final docId = 'quizFirst_${dateKey}_$quizId';
    try {
      return await _db.runTransaction<bool>((txn) async {
        final ref = grants.doc(docId);
        final snap = await txn.get(ref);
        if (snap.exists) return false;
        txn.set(ref, {
          'type': 'quizFirst',
          'dateKey': dateKey,
          'quizId': quizId,
          'at': FieldValue.serverTimestamp(),
        });
        txn.set(userRef, {
          'caringTreatCount': FieldValue.increment(quizFirstAnswerAmount),
        }, SetOptions(merge: true));
        return true;
      });
    } catch (e) {
      debugPrint('⚠️ CaringTreatService.tryGrantQuizFirstAnswer: $e');
      return false;
    }
  }

  /// 문항별 정답 **1회** (같은 날·같은 quizId, 정답일 때만 별도 기록)
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
        txn.set(ref, {
          'type': 'quizCorrect',
          'dateKey': dateKey,
          'quizId': quizId,
          'at': FieldValue.serverTimestamp(),
        });
        txn.set(userRef, {
          'caringTreatCount': FieldValue.increment(quizCorrectAmount),
        }, SetOptions(merge: true));
        return true;
      });
    } catch (e) {
      debugPrint('⚠️ CaringTreatService.tryGrantQuizCorrect: $e');
      return false;
    }
  }

  /// 오늘 단어에서 **아는 단어** 또는 **다시 보기**를 처음 표시할 때 단어만 1개
  static Future<bool> tryGrantDailyWordPick({
    required String dateKey,
    required String wordId,
  }) async {
    final grants = _grantsRef;
    final userRef = _userRef;
    if (grants == null || userRef == null) return false;

    final docId = 'dailyWord_${dateKey}_$wordId';
    try {
      return await _db.runTransaction<bool>((txn) async {
        final ref = grants.doc(docId);
        final snap = await txn.get(ref);
        if (snap.exists) return false;
        txn.set(ref, {
          'type': 'dailyWord',
          'dateKey': dateKey,
          'wordId': wordId,
          'at': FieldValue.serverTimestamp(),
        });
        txn.set(userRef, {
          'caringTreatCount': FieldValue.increment(1),
        }, SetOptions(merge: true));
        return true;
      });
    } catch (e) {
      debugPrint('⚠️ CaringTreatService.tryGrantDailyWordPick: $e');
      return false;
    }
  }

  /// 속닥속닥 글·댓글·답글 — 작성당 [whisperWriteTreatAmount]개(남은 일일 상한만큼만).
  static Future<bool> tryGrantWhisperWrite({
    required String contentType,
    required String contentId,
  }) async {
    final uid = _auth.currentUser?.uid;
    final grants = _grantsRef;
    final userRef = _userRef;
    if (uid == null || grants == null || userRef == null) return false;

    final dateKey = _dateKeyKst();
    final safeType = contentType.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final grantRef = grants.doc('whisper_${safeType}_$contentId');
    final dayRef = grants.doc('whisperDay_$dateKey');

    try {
      return await _db.runTransaction<bool>((txn) async {
        final grantSnap = await txn.get(grantRef);
        if (grantSnap.exists) return false;

        final daySnap = await txn.get(dayRef);
        final total = _treatTotalFromDayData(daySnap.data());

        if (total >= whisperDailyTreatCap) return false;

        final room = whisperDailyTreatCap - total;
        final amount =
            room < whisperWriteTreatAmount ? room : whisperWriteTreatAmount;
        if (amount <= 0) return false;

        txn.set(grantRef, {
          'type': 'whisperWrite',
          'contentType': safeType,
          'contentId': contentId,
          'dateKey': dateKey,
          'amount': amount,
          'at': FieldValue.serverTimestamp(),
        });
        txn.set(dayRef, {
          'type': 'whisperDay',
          'dateKey': dateKey,
          'treatTotal': total + amount,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        txn.set(userRef, {
          'caringTreatCount': FieldValue.increment(amount),
        }, SetOptions(merge: true));
        return true;
      });
    } catch (e) {
      debugPrint('⚠️ CaringTreatService.tryGrantWhisperWrite: $e');
      return false;
    }
  }

  /// 속닥속닥 글·댓글·답글 삭제 시 지급했던 먹이를 회수하고 재지급 가능 상태로 되돌림.
  static Future<bool> revokeWhisperWrite({
    required String contentType,
    required String contentId,
  }) {
    final safeType = contentType.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return _revokeWhisperGrant('whisper_${safeType}_$contentId');
  }

  /// 속닥속닥 본문·댓글·답글의 좋아요·힘내요 — 반응당 1개(일일 속닥 합산 10개 상한)
  ///
  /// [grantKey]는 사용자·대상·반응 종류별로 유일해야 함
  static Future<bool> tryGrantWhisperReaction({
    required String grantKey,
  }) async {
    final uid = _auth.currentUser?.uid;
    final grants = _grantsRef;
    final userRef = _userRef;
    if (uid == null || grants == null || userRef == null) return false;

    final safeKey = grantKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    if (safeKey.isEmpty) return false;

    final dateKey = _dateKeyKst();
    final grantRef = grants.doc('whisperRe_$safeKey');
    final dayRef = grants.doc('whisperDay_$dateKey');

    try {
      return await _db.runTransaction<bool>((txn) async {
        final grantSnap = await txn.get(grantRef);
        if (grantSnap.exists) return false;

        final daySnap = await txn.get(dayRef);
        final total = _treatTotalFromDayData(daySnap.data());
        if (total >= whisperDailyTreatCap) return false;

        final room = whisperDailyTreatCap - total;
        final amount =
            room < whisperReactionTreatAmount
                ? room
                : whisperReactionTreatAmount;
        if (amount <= 0) return false;

        txn.set(grantRef, {
          'type': 'whisperReaction',
          'grantKey': safeKey,
          'dateKey': dateKey,
          'amount': amount,
          'at': FieldValue.serverTimestamp(),
        });
        txn.set(dayRef, {
          'type': 'whisperDay',
          'dateKey': dateKey,
          'treatTotal': total + amount,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        txn.set(userRef, {
          'caringTreatCount': FieldValue.increment(amount),
        }, SetOptions(merge: true));
        return true;
      });
    } catch (e) {
      debugPrint('⚠️ CaringTreatService.tryGrantWhisperReaction: $e');
      return false;
    }
  }

  /// 속닥속닥 좋아요·힘내요 취소 시 지급했던 먹이를 회수하고 재지급 가능 상태로 되돌림.
  static Future<bool> revokeWhisperReaction({required String grantKey}) {
    final safeKey = grantKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    if (safeKey.isEmpty) return Future.value(false);
    return _revokeWhisperGrant('whisperRe_$safeKey');
  }
}
