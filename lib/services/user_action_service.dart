import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/reward_constants.dart';

/// 유저 행동 서비스 (캐릭터 삭제 후 대체)
///
/// 포인트 적립, 출석 체크, 스킨/오라 장착 등
/// Character 모델 없이 users/{uid} 문서에 직접 읽기/쓰기
class UserActionService {
  static final _db = FirebaseFirestore.instance;

  // ─── 포인트 적립 ───

  /// 밥주기 → 포인트만 적립 (게이지 제거됨)
  static Future<String> feed() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return '로그인이 필요합니다.';
    await _db.collection('users').doc(uid).update({
      'emotionPoints': FieldValue.increment(RewardPolicy.feed),
    });
    return '기록했어요. +${RewardPolicy.feed}P';
  }

  /// 쓰다듬기(응원) → 포인트 적립
  static Future<String> pet() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return '로그인이 필요합니다.';
    await _db.collection('users').doc(uid).update({
      'emotionPoints': FieldValue.increment(RewardPolicy.petCharacter),
    });
    return '따뜻한 마음. +${RewardPolicy.petCharacter}P';
  }

  // ─── 출석 체크 ───

  /// 일일 출석 체크 (하루 1회)
  static Future<String> dailyCheckIn() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return '로그인이 필요합니다.';

    final docRef = _db.collection('users').doc(uid);
    final doc = await docRef.get();

    final lastCheckIn = (doc.data()?['lastCheckIn'] as Timestamp?)?.toDate();
    final now = DateTime.now();

    if (lastCheckIn != null &&
        lastCheckIn.year == now.year &&
        lastCheckIn.month == now.month &&
        lastCheckIn.day == now.day) {
      return '오늘은 이미 출석했어요.';
    }

    await docRef.set({
      'emotionPoints': FieldValue.increment(RewardPolicy.attendance),
      'lastCheckIn': Timestamp.fromDate(now),
    }, SetOptions(merge: true));

    return '출석 완료! +${RewardPolicy.attendance}P';
  }

  // ─── 스킨/오라 장착 ───

  /// 원 스킨 장착 (null이면 해제)
  static Future<void> equipSkin(String? skinId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set(
      {'equippedSkinId': skinId},
      SetOptions(merge: true),
    );
  }

  /// 오라 스킨 장착 (null이면 해제)
  static Future<void> equipAura(String? auraId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set(
      {'equippedAuraId': auraId},
      SetOptions(merge: true),
    );
  }

  // ─── 유저 데이터 읽기 ───

  /// 인벤토리 목록 가져오기 (users/{uid} 문서에서 직접)
  static Future<List<String>> getInventory() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return [];
    return List<String>.from(doc.data()?['inventory'] ?? []);
  }

  /// 현재 장착된 스킨 ID
  static Future<String?> getEquippedSkinId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['equippedSkinId'];
  }

  /// 현재 장착된 오라 ID
  static Future<String?> getEquippedAuraId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['equippedAuraId'];
  }
}

