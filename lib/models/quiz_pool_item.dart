import 'package:cloud_firestore/cloud_firestore.dart';

/// quiz_pool 컬렉션 문서 모델
///
/// 날짜와 무관한 "원본 문제 은행".
/// Cloud Function이 매일 자정 quiz_schedule에 순서대로 배포.
class QuizPoolItem {
  final String id;          // Firestore autoId
  final int order;          // 배포 순서 (1부터 시작, 연속 정수)
  final String question;
  final List<String> options;
  final int correctIndex;   // 0-based
  final String explanation;
  final String category;    // e.g. '임플란트', '보철', '예방치과'
  final String difficulty;  // 'basic' | 'intermediate' | 'advanced'
  final String sourceBook;  // 출처 책 이름
  final String sourceFileName; // PDF 원본 파일명
  final String sourcePage;  // 출처 페이지
  final bool isActive;      // false면 스케줄에서 제외
  final int lastCycleServed; // 마지막으로 배포된 사이클 번호 (0 = 아직 미배포)
  final DateTime createdAt;
  final DateTime updatedAt;

  const QuizPoolItem({
    required this.id,
    required this.order,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.category,
    required this.difficulty,
    required this.sourceBook,
    required this.sourceFileName,
    required this.sourcePage,
    required this.isActive,
    required this.lastCycleServed,
    required this.createdAt,
    required this.updatedAt,
  });

  factory QuizPoolItem.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return QuizPoolItem(
      id:              doc.id,
      order:           (d['order'] as num?)?.toInt() ?? 0,
      question:        d['question'] as String? ?? '',
      options:         List<String>.from(d['options'] ?? []),
      correctIndex:    (d['correctIndex'] as num?)?.toInt() ?? 0,
      explanation:     d['explanation'] as String? ?? '',
      category:        d['category'] as String? ?? '일반',
      difficulty:      d['difficulty'] as String? ?? 'basic',
      sourceBook:      d['sourceBook'] as String? ?? '',
      sourceFileName:  d['sourceFileName'] as String? ?? '',
      sourcePage:      d['sourcePage'] as String? ?? '',
      isActive:        d['isActive'] as bool? ?? true,
      lastCycleServed: (d['lastCycleServed'] as num?)?.toInt() ?? 0,
      createdAt:       (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:       (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'order':           order,
    'question':        question,
    'options':         options,
    'correctIndex':    correctIndex,
    'explanation':     explanation,
    'category':        category,
    'difficulty':      difficulty,
    'sourceBook':      sourceBook,
    'sourceFileName':  sourceFileName,
    'sourcePage':      sourcePage,
    'isActive':        isActive,
    'lastCycleServed': lastCycleServed,
    'createdAt':       Timestamp.fromDate(createdAt),
    'updatedAt':       Timestamp.fromDate(updatedAt),
  };

  QuizPoolItem copyWith({
    bool? isActive,
    int? lastCycleServed,
    DateTime? updatedAt,
  }) {
    return QuizPoolItem(
      id:              id,
      order:           order,
      question:        question,
      options:         options,
      correctIndex:    correctIndex,
      explanation:     explanation,
      category:        category,
      difficulty:      difficulty,
      sourceBook:      sourceBook,
      sourceFileName:  sourceFileName,
      sourcePage:      sourcePage,
      isActive:        isActive ?? this.isActive,
      lastCycleServed: lastCycleServed ?? this.lastCycleServed,
      createdAt:       createdAt,
      updatedAt:       updatedAt ?? this.updatedAt,
    );
  }
}







