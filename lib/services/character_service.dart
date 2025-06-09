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

  static Future<void> feedCharacter() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final docRef = _db.collection('users').doc(uid);
    await docRef.update({'affection': FieldValue.increment(0.1)});
  }

  // ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼ 출석 체크 함수 추가 ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
  static Future<String> dailyCheckIn() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return "로그인이 필요합니다.";

    final docRef = _db.collection('users').doc(uid);
    final doc = await docRef.get();

    final lastCheckIn = (doc.data()?['lastCheckIn'] as Timestamp?)?.toDate();
    final now = DateTime.now();

    // 마지막 출석일이 오늘과 같은지 확인
    if (lastCheckIn != null &&
        lastCheckIn.year == now.year &&
        lastCheckIn.month == now.month &&
        lastCheckIn.day == now.day) {
      return "오늘은 이미 출석했습니다!";
    }

    // 출석 보상 (경험치 +10) 및 마지막 출석일 업데이트
    await docRef.update({
      'experience': FieldValue.increment(10.0),
      'lastCheckIn': Timestamp.fromDate(now),
    });

    return "출석 완료! 경험치 +10";
  }
  // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲ 출석 체크 함수 추가 ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲
}
