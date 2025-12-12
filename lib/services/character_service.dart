import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/reward_constants.dart';
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

  /// 밥주기 - 배고픔 해소 + 애정도 증가 + 포인트 획득
  static Future<String> feedCharacter() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return "로그인이 필요합니다.";
    final docRef = _db.collection('users').doc(uid);
    await docRef.update({
      'hunger': FieldValue.increment(RewardPolicy.feedHungerIncrease),
      'affection': FieldValue.increment(RewardPolicy.feedAffectionIncrease),
      'emotionPoints': FieldValue.increment(RewardPolicy.feed),
    });
    return "냠냠~ 맛있게 먹었어요! +${RewardPolicy.feed}P 🍽️";
  }

  /// 캐릭터 쓰다듬기 - 애정도 소량 증가 + 포인트 획득
  static Future<String> petCharacter() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return "로그인이 필요합니다.";
    final docRef = _db.collection('users').doc(uid);
    await docRef.update({
      'affection': FieldValue.increment(RewardPolicy.petAffectionIncrease),
      'emotionPoints': FieldValue.increment(RewardPolicy.petCharacter),
    });
    return "+${RewardPolicy.petCharacter}P ❤️";
  }

  /// 휴식하기 - 피로도 감소 + 포인트 획득
  static Future<String> rest() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return "로그인이 필요합니다.";
    final docRef = _db.collection('users').doc(uid);
    await docRef.update({
      'fatigue': FieldValue.increment(-RewardPolicy.restFatigueDecrease),
      'sleepHours': FieldValue.increment(RewardPolicy.restSleepIncrease),
      'emotionPoints': FieldValue.increment(RewardPolicy.rest),
    });
    return "푹 쉬었어요! +${RewardPolicy.rest}P 😴";
  }

  /// 일일 출석 체크
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
      'emotionPoints': FieldValue.increment(RewardPolicy.attendance),
      'lastCheckIn': Timestamp.fromDate(now),
    });

    return "출석 완료! +${RewardPolicy.attendance}P 🎉";
  }
}
