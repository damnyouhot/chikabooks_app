// lib/models/emotion_log.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class EmotionLog {
  final String id;
  final String userId;
  final int score; // 1~5
  final int points; // 변환된 포인트
  final DateTime timestamp;

  EmotionLog({
    required this.id,
    required this.userId,
    required this.score,
    required this.points,
    required this.timestamp,
  });

  factory EmotionLog.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return EmotionLog(
      id: doc.id,
      userId: d['userId'] as String,
      score: d['score'] as int,
      points: d['points'] as int,
      timestamp: (d['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'score': score,
      'points': points,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
