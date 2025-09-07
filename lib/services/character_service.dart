import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/character.dart';

class CharacterService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// 내부: 사용자 문서 없으면 기본 캐릭터 생성
  static Future<void> _ensureUserDoc(String uid) async {
    final ref = _db.collection('users').doc(uid);
    final snap = await ref.get();
    if (!snap.exists) {
      final defaultChar = Character(id: uid);
      await ref.set(defaultChar.toJson(), SetOptions(merge: true));
    }
  }

  /// 캐릭터 한 번 가져오기 (없으면 생성)
  static Future<Character> fetchCharacter(String uid) async {
    final ref = _db.collection('users').doc(uid);
    final snap = await ref.get();
    if (!snap.exists) {
      final defaultChar = Character(id: uid);
      await ref.set(defaultChar.toJson());
      return defaultChar;
    }
    return Character.fromDoc(snap);
  }

  /// 캐릭터 실시간 구독
  static Stream<Character> watchCharacter(String uid) async* {
    await _ensureUserDoc(uid);
    yield* _db.collection('users').doc(uid).snapshots().map((doc) {
      return Character.fromDoc(doc);
    });
  }

  /// 간식/돌보기: affection/exp 증가
  static Future<void> feedCharacter() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final ref = _db.collection('users').doc(uid);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      Character ch = snap.exists ? Character.fromDoc(snap) : Character(id: uid);

      ch.affection = (ch.affection ?? 0) + 2;
      ch.gainExperience(5);

      final data = ch.toJson();
      final stats = Map<String, dynamic>.from(data['stats'] ?? {});
      stats['emotionPoints'] = (stats['emotionPoints'] ?? 0) + 1;
      data['stats'] = stats;

      tx.set(ref, data, SetOptions(merge: true));
    });
  }

  /// 아이템 장착/해제 (null이면 해제)
  static Future<void> equipItem(String? itemId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final ref = _db.collection('users').doc(uid);

    await ref.set({'equippedItemId': itemId}, SetOptions(merge: true));

    if (itemId != null) {
      await ref.set({
        'inventory': FieldValue.arrayUnion([itemId]),
      }, SetOptions(merge: true));
    }
  }

  /// 하루 1회 출석 체크
  static Future<String> dailyCheckIn() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return '로그인이 필요합니다.';

    final now = DateTime.now();
    final ymd =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    final checkRef = _db
        .collection('users')
        .doc(uid)
        .collection('daily')
        .doc(ymd);
    final exists = (await checkRef.get()).exists;

    if (exists) {
      return '오늘은 이미 체크인 했어요!';
    }

    await _db.runTransaction((tx) async {
      tx.set(checkRef, {'createdAt': FieldValue.serverTimestamp()});

      final userRef = _db.collection('users').doc(uid);
      final snap = await tx.get(userRef);
      Character ch = snap.exists ? Character.fromDoc(snap) : Character(id: uid);

      ch.affection = (ch.affection ?? 0) + 1;
      ch.gainExperience(3);

      final data = ch.toJson();
      final stats = Map<String, dynamic>.from(data['stats'] ?? {});
      stats['emotionPoints'] = (stats['emotionPoints'] ?? 0) + 10;
      data['stats'] = stats;

      tx.set(userRef, data, SetOptions(merge: true));
    });

    return '체크인 완료! 보상을 받았어요 😊';
  }

  /// 경험치 추가
  static Future<void> addExperience(double amount) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final ref = _db.collection('users').doc(uid);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      Character ch = snap.exists ? Character.fromDoc(snap) : Character(id: uid);
      ch.gainExperience(amount);
      tx.set(ref, ch.toJson(), SetOptions(merge: true));
    });
  }

  /// 통계/스탯 적립
  static Future<void> incrementStats({
    int emotionPoints = 0,
    int studyMinutes = 0,
    int stepCount = 0,
    int quizCount = 0,
    double affection = 0.0,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final ref = _db.collection('users').doc(uid);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      Map<String, dynamic> base = {};
      if (snap.exists && snap.data() != null) {
        base = Map<String, dynamic>.from(snap.data()!);
      }

      base['emotionPoints'] = (base['emotionPoints'] ?? 0) + emotionPoints;
      base['studyMinutes'] = (base['studyMinutes'] ?? 0) + studyMinutes;
      base['stepCount'] = (base['stepCount'] ?? 0) + stepCount;
      base['quizCount'] = (base['quizCount'] ?? 0) + quizCount;
      base['affection'] = ((base['affection'] ?? 0).toDouble()) + affection;

      final stats = Map<String, dynamic>.from(base['stats'] ?? {});
      stats['emotionPoints'] = (stats['emotionPoints'] ?? 0) + emotionPoints;
      stats['studyMinutes'] = (stats['studyMinutes'] ?? 0) + studyMinutes;
      stats['stepCount'] = (stats['stepCount'] ?? 0) + stepCount;
      stats['quizCount'] = (stats['quizCount'] ?? 0) + quizCount;

      base['stats'] = stats;
      tx.set(ref, base, SetOptions(merge: true));
    });
  }
}
