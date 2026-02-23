import 'package:cloud_firestore/cloud_firestore.dart';

/// 일일 퀴즈 모델
class DailyQuiz {
  final String dateKey; // 문서 ID (예: '2026-02-23')
  final String question;
  final List<String> options;
  final int correctAnswer; // 정답 인덱스 (0-based)
  final String explanation;
  final String category; // periodontics, orthodontics, etc
  final String difficulty; // basic, intermediate, advanced
  final String? sourceBookId; // 출처 책 ID
  final String? sourcePage; // 출처 페이지
  final DateTime createdAt;

  DailyQuiz({
    required this.dateKey,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    required this.category,
    required this.difficulty,
    this.sourceBookId,
    this.sourcePage,
    required this.createdAt,
  });

  /// Firestore 문서에서 객체 생성
  factory DailyQuiz.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DailyQuiz(
      dateKey: doc.id,
      question: data['question'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      correctAnswer: data['correctAnswer'] ?? 0,
      explanation: data['explanation'] ?? '',
      category: data['category'] ?? 'general',
      difficulty: data['difficulty'] ?? 'basic',
      sourceBookId: data['sourceBookId'],
      sourcePage: data['sourcePage'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  /// Firestore 문서로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
      'category': category,
      'difficulty': difficulty,
      'sourceBookId': sourceBookId,
      'sourcePage': sourcePage,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// 출처 문자열 생성
  String? get sourceText {
    if (sourceBookId == null) return null;
    if (sourcePage != null) {
      return '출처: $sourceBookId (p.$sourcePage)';
    }
    return '출처: $sourceBookId';
  }

  /// 오늘 날짜 키 생성 (YYYY-MM-DD)
  static String getTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
