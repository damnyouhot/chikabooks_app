import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // debugPrint를 위해 추가
import '../models/character.dart';
import '../models/store_item.dart';

class StoreService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<List<StoreItem>> fetchStoreItems() async {
    final snapshot = await _db.collection('storeItems').orderBy('price').get();
    return snapshot.docs.map((doc) => StoreItem.fromDoc(doc)).toList();
  }

  Future<List<StoreItem>> fetchMyItems() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final userDoc = await _db.collection('users').doc(uid).get();
    if (!userDoc.exists) return [];

    final character = Character.fromDoc(userDoc);
    final myItemIds = character.inventory;

    if (myItemIds.isEmpty) return [];

    final snapshot = await _db
        .collection('storeItems')
        .where(FieldPath.documentId, whereIn: myItemIds)
        .get();
    return snapshot.docs.map((doc) => StoreItem.fromDoc(doc)).toList();
  }

  Future<StoreItem?> fetchItemById(String itemId) async {
    try {
      final doc = await _db.collection('storeItems').doc(itemId).get();
      if (!doc.exists) return null;
      return StoreItem.fromDoc(doc);
    } catch (e) {
      debugPrint('Error fetching item by ID: $e');
      return null;
    }
  }

  Future<String> purchaseItem(StoreItem item) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return "로그인이 필요합니다.";

    final userRef = _db.collection('users').doc(uid);

    return _db.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);
      if (!userDoc.exists) throw "사용자 정보를 찾을 수 없습니다.";

      final character = Character.fromDoc(userDoc);

      if (item.type == StoreItemType.coupon) {
        // 쿠폰 구매 로직 (이번 단계에서는 일단 통과)
      } else {
        if (character.inventory.contains(item.id)) {
          return "이미 보유하고 있는 아이템입니다.";
        }
      }

      if (character.emotionPoints < item.price) {
        return "포인트가 부족합니다!";
      }

      transaction.update(
          userRef, {'emotionPoints': FieldValue.increment(-item.price)});

      if (item.type == StoreItemType.coupon) {
        final couponRef = userRef.collection('coupons').doc();
        transaction.set(couponRef, {
          'itemId': item.id,
          'name': item.name,
          'value': item.value,
          'isUsed': false,
          'purchasedAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.update(userRef, {
          'inventory': FieldValue.arrayUnion([item.id])
        });
      }

      return "${item.name} 구매 완료!";
    }).catchError((error) {
      debugPrint("구매 중 오류 발생: $error");
      return "구매 중 오류가 발생했습니다.";
    });
  }
}
