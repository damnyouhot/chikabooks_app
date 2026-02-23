import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/furniture.dart';

class FurnitureService {
  static final _db = FirebaseFirestore.instance;

  /// 현재 유저의 배치된 가구 목록 스트림
  static Stream<List<PlacedFurniture>> watchPlacedFurniture() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _db
        .collection('users')
        .doc(uid)
        .collection('placedFurniture')
        .snapshots()
        .map((snap) => snap.docs.map(PlacedFurniture.fromDoc).toList());
  }

  /// 현재 유저의 보유 가구 목록 스트림
  static Stream<List<OwnedFurniture>> watchOwnedFurniture() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _db
        .collection('users')
        .doc(uid)
        .collection('ownedFurniture')
        .orderBy('purchasedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(OwnedFurniture.fromDoc).toList());
  }

  /// 가구 구매
  static Future<String> purchaseFurniture(String furnitureId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return '로그인이 필요합니다.';

    final definition = FurnitureDefinition.getById(furnitureId);
    if (definition == null) return '가구를 찾을 수 없습니다.';

    // 포인트 확인
    final userDoc = await _db.collection('users').doc(uid).get();
    final currentPoints = (userDoc.data()?['emotionPoints'] ?? 0) as int;

    if (currentPoints < definition.price) {
      return '포인트가 부족합니다. (필요: ${definition.price}P, 보유: ${currentPoints}P)';
    }

    // 트랜잭션으로 포인트 차감 + 가구 추가
    await _db.runTransaction((tx) async {
      tx.update(_db.collection('users').doc(uid), {
        'emotionPoints': FieldValue.increment(-definition.price),
      });

      tx.set(
        _db.collection('users').doc(uid).collection('ownedFurniture').doc(),
        {
          'furnitureId': furnitureId,
          'isPlaced': false,
          'purchasedAt': FieldValue.serverTimestamp(),
        },
      );
    });

    return '${definition.name}을(를) 구매했습니다! 🎉';
  }

  /// 가구 배치
  static Future<String> placeFurniture({
    required String ownedFurnitureId,
    required int gridX,
    required int gridY,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return '로그인이 필요합니다.';

    // 보유 가구 확인
    final ownedDoc =
        await _db
            .collection('users')
            .doc(uid)
            .collection('ownedFurniture')
            .doc(ownedFurnitureId)
            .get();

    if (!ownedDoc.exists) return '가구를 찾을 수 없습니다.';

    final furnitureId = ownedDoc.data()?['furnitureId'] as String?;
    if (furnitureId == null) return '가구 정보가 올바르지 않습니다.';

    // 트랜잭션으로 배치
    await _db.runTransaction((tx) async {
      // 보유 가구 상태 업데이트
      tx.update(ownedDoc.reference, {'isPlaced': true});

      // 배치된 가구에 추가
      tx.set(
        _db
            .collection('users')
            .doc(uid)
            .collection('placedFurniture')
            .doc(ownedFurnitureId),
        {'furnitureId': furnitureId, 'gridX': gridX, 'gridY': gridY},
      );
    });

    return '가구를 배치했습니다! 🏠';
  }

  /// 가구 배치 해제
  static Future<String> removeFurniture(String placedFurnitureId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return '로그인이 필요합니다.';

    await _db.runTransaction((tx) async {
      // 보유 가구 상태 업데이트
      tx.update(
        _db
            .collection('users')
            .doc(uid)
            .collection('ownedFurniture')
            .doc(placedFurnitureId),
        {'isPlaced': false},
      );

      // 배치된 가구에서 제거
      tx.delete(
        _db
            .collection('users')
            .doc(uid)
            .collection('placedFurniture')
            .doc(placedFurnitureId),
      );
    });

    return '가구를 수납했습니다.';
  }

  /// 가구 위치 이동
  static Future<void> moveFurniture({
    required String placedFurnitureId,
    required int newGridX,
    required int newGridY,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await _db
        .collection('users')
        .doc(uid)
        .collection('placedFurniture')
        .doc(placedFurnitureId)
        .update({'gridX': newGridX, 'gridY': newGridY});
  }
}























































