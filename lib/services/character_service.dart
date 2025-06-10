import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/character.dart';

class CharacterService {
  static final _db = FirebaseFirestore.instance;

  static Future<Character?> fetchCharacter() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final docRef = _db.collection('users').doc(uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      final defaultChar = Character(id: uid);
      await docRef.set(defaultChar.toJson());
      return defaultChar;
    }
    return Character.fromDoc(doc);
  }

  // ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼ 이 함수들이 누락되었습니다 ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
  static Stream<Character?> watchCharacter(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Character.fromDoc(doc);
    });
  }

  static Future<void> equipItem(String? itemId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({'equippedItemId': itemId});
  }
  // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲ 이 함수들이 누락되었습니다 ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲

  static Future<void> feedCharacter() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final docRef = _db.collection('users').doc(uid);
    await docRef.update({'affection': FieldValue.increment(0.1)});
  }

  static Future<String> dailyCheckIn() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return "로그인이 필요합니다.";

    final docRef = _db.collection('users').doc(uid);
    final doc = await docRef.get();

    final lastCheckIn = (doc.data()?['lastCheckIn'] as Timestamp?)?.toDate();
    final now = DateTime.now();

    if (lastCheckIn != null &&
        lastCheckIn.year == now.year &&
        lastCheckIn.month == now.month &&
        lastCheckIn.day == now.day) {
      return "오늘은 이미 출석했습니다!";
    }

    await docRef.update({
      'experience': FieldValue.increment(10.0),
      'emotionPoints': FieldValue.increment(5),
      'lastCheckIn': Timestamp.fromDate(now),
    });

    return "출석 완료! 경험치 +10, 포인트 +5";
  }
}
