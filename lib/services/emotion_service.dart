// lib/services/emotion_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'growth_service.dart';

class EmotionService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// 하루에 한 번만 기록 가능 여부 검사 (기존과 동일)
  static Future<bool> canRecordToday() async {
    final uid = _auth.currentUser!.uid;
    final start =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final q = await _db
        .collection('emotionLogs')
        .where('userId', isEqualTo: uid)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .limit(1)
        .get();
    return q.docs.isEmpty;
  }

  /// 감정 점수 저장
  /// 이제 stats 업데이트 없이 로그 기록만 담당합니다.
  static Future<void> recordEmotion(int score) async {
    final uid = _auth.currentUser!.uid;
    final points = score * 10; // 가중치 예시

    // 1) 감정 자체에 대한 로그를 기록
    await _db.collection('emotionLogs').add({
      'userId': uid,
      'score': score,
      'points': points,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2) 이 활동을 '성장 이벤트'로도 기록 (Cloud Function이 이 이벤트를 감지)
    await GrowthService.recordEvent(
      uid: uid,
      type: 'emotion', // "emotion" 타입으로 이벤트 전달
      value: points.toDouble(),
    );
  }

  /// 누적 emotionPoints 스트림
  /// 이제 users.stats.emotionPoints를 직접 읽어옵니다.
  static Stream<int> emotionPointStream(String uid) {
    return _db.doc('users/$uid').snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return 0;
      final data = doc.data()!;
      // stats 맵이 없거나, emotionPoints 필드가 없을 경우를 안전하게 처리
      if (data.containsKey('stats') && data['stats'] is Map) {
        return (data['stats']['emotionPoints'] ?? 0) as int;
      }
      return 0;
    });
  }
}
