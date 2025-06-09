// 파일 경로: lib/services/store_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/store_item.dart';

class StoreService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Firestore의 'storeItems' 컬렉션에서 아이템 목록을 불러옵니다.
  Future<List<StoreItem>> fetchStoreItems() async {
    final snapshot = await _db.collection('storeItems').orderBy('price').get();
    return snapshot.docs.map((doc) => StoreItem.fromDoc(doc)).toList();
  }

  // 사용자가 보유한 아이템 목록을 가져옵니다. (CaringPage에서 사용)
  Future<List<StoreItem>> fetchMyItems(List<String> myItemIds) async {
    if (myItemIds.isEmpty) return [];

    final snapshot = await _db
        .collection('storeItems')
        .where(FieldPath.documentId, whereIn: myItemIds)
        .get();
    return snapshot.docs.map((doc) => StoreItem.fromDoc(doc)).toList();
  }

  // 아이템을 구매하는 트랜잭션 함수
  Future<String> purchaseItem(StoreItem item) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return "로그인이 필요합니다.";

    final userRef = _db.collection('users').doc(uid);

    // 데이터의 일관성을 보장하기 위해 트랜잭션을 사용합니다.
    return _db.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);
      if (!userDoc.exists) {
        throw "사용자 정보를 찾을 수 없습니다.";
      }

      final characterData = userDoc.data() as Map<String, dynamic>;
      final currentPoints = (characterData['emotionPoints'] ?? 0) as int;
      final inventory = List<String>.from(characterData['inventory'] ?? []);

      // 이미 보유한 아이템인지 확인
      if (inventory.contains(item.id)) {
        return "이미 보유하고 있는 아이템입니다.";
      }

      // 포인트가 부족한지 확인
      if (currentPoints < item.price) {
        return "포인트가 부족합니다!";
      }

      // 트랜잭션 내에서 사용자 데이터 업데이트
      transaction.update(userRef, {
        'emotionPoints': FieldValue.increment(-item.price), // 포인트 차감
        'inventory': FieldValue.arrayUnion([item.id]), // 인벤토리에 아이템 ID 추가
      });

      return "${item.name} 구매 완료!";
    }).catchError((error) {
      print("구매 중 오류 발생: $error");
      return "구매 중 오류가 발생했습니다.";
    });
  }
}
