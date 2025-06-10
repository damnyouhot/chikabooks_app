import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GrowthService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static Future<void> recordEvent({
    String? uid,
    required String type,
    required double value,
  }) async {
    final userId = uid ?? _auth.currentUser!.uid;
    await _db.collection('growthEvents').add({
      'userId': userId,
      'type': type,
      'value': value,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼ 주간 활동 데이터를 가져오는 함수 추가 ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
  static Future<Map<int, double>> fetchWeeklyStudyData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {};

    final now = DateTime.now();
    // 이번 주 월요일 0시 0분 계산
    final startOfWeek =
        DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    final snapshot = await _db
        .collection('growthEvents')
        .where('userId', isEqualTo: uid)
        .where('type', isEqualTo: 'study') // 학습 이벤트만 필터링
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
        .where('timestamp', isLessThan: Timestamp.fromDate(endOfWeek))
        .get();

    // 월(1) ~ 일(7)까지의 데이터를 0으로 초기화
    final Map<int, double> weeklyData = {for (var i = 1; i <= 7; i++) i: 0};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final timestamp = (data['timestamp'] as Timestamp).toDate();
      final value = (data['value'] as num).toDouble();
      weeklyData[timestamp.weekday] =
          (weeklyData[timestamp.weekday] ?? 0) + value;
    }
    return weeklyData;
  }
  // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲ 주간 활동 데이터를 가져오는 함수 추가 ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲
}
