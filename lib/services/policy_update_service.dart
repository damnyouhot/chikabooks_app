import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/policy_update.dart';

/// 제도 변경 정보 관리 서비스
class PolicyUpdateService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'policyUpdates';

  /// 임박한 제도 변경 3건 가져오기 (카드용)
  /// 조건: isActive == true AND effectiveDate >= now
  /// 정렬: effectiveDate asc, priority asc
  static Future<List<PolicyUpdate>> getUpcomingUpdates({int limit = 3}) async {
    try {
      final now = DateTime.now();
      final snapshot =
          await _firestore
              .collection(_collection)
              .where('isActive', isEqualTo: true)
              .where(
                'effectiveDate',
                isGreaterThanOrEqualTo: Timestamp.fromDate(now),
              )
              .orderBy('effectiveDate', descending: false)
              .orderBy('priority', descending: false)
              .limit(limit)
              .get();

      return snapshot.docs
          .map((doc) => PolicyUpdate.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('⚠️ PolicyUpdateService.getUpcomingUpdates 에러: $e');
      return [];
    }
  }

  /// 모든 활성 제도 변경 가져오기
  static Future<List<PolicyUpdate>> getAllActive() async {
    try {
      final snapshot =
          await _firestore
              .collection(_collection)
              .where('isActive', isEqualTo: true)
              .orderBy('effectiveDate', descending: false)
              .get();

      return snapshot.docs
          .map((doc) => PolicyUpdate.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('⚠️ PolicyUpdateService.getAllActive 에러: $e');
      return [];
    }
  }

  /// 특정 카테고리 제도 변경 가져오기
  static Future<List<PolicyUpdate>> getByCategory(String category) async {
    try {
      final snapshot =
          await _firestore
              .collection(_collection)
              .where('category', isEqualTo: category)
              .where('isActive', isEqualTo: true)
              .orderBy('effectiveDate', descending: false)
              .get();

      return snapshot.docs
          .map((doc) => PolicyUpdate.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('⚠️ PolicyUpdateService.getByCategory 에러: $e');
      return [];
    }
  }

  /// 제도 변경 추가 (Admin용)
  static Future<String?> add(PolicyUpdate update) async {
    try {
      final docRef = await _firestore
          .collection(_collection)
          .add(update.toFirestore());
      return docRef.id;
    } catch (e) {
      print('⚠️ PolicyUpdateService.add 에러: $e');
      return null;
    }
  }

  /// 제도 변경 수정 (Admin용)
  static Future<bool> update(String id, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(_collection).doc(id).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('⚠️ PolicyUpdateService.update 에러: $e');
      return false;
    }
  }

  /// 제도 변경 삭제 (Admin용)
  static Future<bool> delete(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
      return true;
    } catch (e) {
      print('⚠️ PolicyUpdateService.delete 에러: $e');
      return false;
    }
  }
}
