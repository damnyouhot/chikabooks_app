// lib/services/growth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GrowthService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// 범용 이벤트 기록 API
  /// 이제 이 함수는 growthEvents 컬렉션에 로그를 남기는 역할만 합니다.
  /// 통계(stats) 업데이트는 위에서 작성한 Cloud Function이 담당합니다.
  static Future<void> recordEvent({
    String? uid,
    required String type,
    required double value,
  }) async {
    final userId = uid ?? _auth.currentUser!.uid;

    // (1) growthEvents 컬렉션에 raw 이벤트 저장만 수행
    await _db.collection('growthEvents').add({
      'userId': userId,
      'type': type,
      'value': value,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
