import 'package:cloud_firestore/cloud_firestore.dart';

import 'quiz_content_config.dart';

/// quiz_pool 컬렉션 문서 모델
///
/// 날짜와 무관한 "원본 문제 은행".
/// Cloud Function이 매일 자정 quiz_schedule에 순서대로 배포.
///
/// [questionType]: `national_exam`(국시) | `clinical`(임상·책 발췌). 미설정은 임상으로 취급.
class QuizPoolItem {
  final String id;          // Firestore autoId
  final int order;          // 배포 순서 (1부터 시작, 연속 정수)
  final String question;
  final List<String> options;
  final int correctIndex;   // 0-based
  final String explanation;
  final String category;    // e.g. '임플란트', '보철', '예방치과'
  final String difficulty;  // 'basic' | 'intermediate' | 'advanced'
  /// `national_exam` | `clinical` — 스케줄 스냅샷에도 복사됨 (앱 배지용)
  final String questionType;
  final String sourceBook;  // 출처 책 이름
  final String sourceFileName; // PDF 원본 파일명
  final String sourcePage;  // 출처 페이지
  /// 국시 등 책 외 출처 한 줄 (예: 2024 국가고시 치과위생사)
  final String sourceName;
  /// 임상 세트 전환용 패크 ID (`config/quiz_content` 와 매칭). 비어 있으면 레거시 풀.
  final String packId;
  /// 패크 내 버전(정수). 스케줄 스냅샷에 복사됨.
  final int packVersion;
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
    this.questionType = 'clinical',
    required this.sourceBook,
    required this.sourceFileName,
    required this.sourcePage,
    this.sourceName = '',
    this.packId = '',
    this.packVersion = 0,
    required this.isActive,
    required this.lastCycleServed,
    required this.createdAt,
    required this.updatedAt,
  });

  static const String kNationalExam = 'national_exam';
  static const String kClinical = 'clinical';

  /// `quiz_schedule.items[]` 스냅샷용: 필드가 빠진 레거시 문서는 packId·config 로 국시 여부 복원
  /// (Cloud Function `quizQuestionType` + 국시 pack 휴리스틱과 맞춤)
  static String resolveQuestionTypeForScheduleSnapshot(
    Map<String, dynamic> map,
    QuizContentConfig contentConfig,
  ) {
    final raw = map['questionType'] as String?;
    if (raw == kNationalExam) return kNationalExam;
    if (raw == kClinical) return kClinical;
    final pid = (map['packId'] as String?)?.trim() ?? '';
    if (pid == 'national_default') return kNationalExam;
    final nid = contentConfig.currentNationalPackId;
    if (nid.isNotEmpty && pid == nid) return kNationalExam;
    return kClinical;
  }

  /// 앱·관리자 UI용 유형 표기
  static String badgeLabelForType(String questionType) =>
      questionType == kNationalExam ? '국시' : '임상';

  factory QuizPoolItem.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final rawType = d['questionType'] as String?;
    final qType = rawType == kNationalExam ? kNationalExam : kClinical;
    return QuizPoolItem(
      id:              doc.id,
      order:           (d['order'] as num?)?.toInt() ?? 0,
      question:        d['question'] as String? ?? '',
      options:         List<String>.from(d['options'] ?? []),
      correctIndex:    (d['correctIndex'] as num?)?.toInt() ?? 0,
      explanation:     d['explanation'] as String? ?? '',
      category:        d['category'] as String? ?? '일반',
      difficulty:      d['difficulty'] as String? ?? 'basic',
      questionType:    qType,
      sourceBook:      d['sourceBook'] as String? ?? '',
      sourceFileName:  d['sourceFileName'] as String? ?? '',
      sourcePage:      d['sourcePage'] as String? ?? '',
      sourceName:      d['sourceName'] as String? ?? '',
      packId:          d['packId'] as String? ?? '',
      packVersion:     (d['packVersion'] as num?)?.toInt() ?? 0,
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
    'questionType':    questionType,
    'sourceBook':      sourceBook,
    'sourceFileName':  sourceFileName,
    'sourcePage':      sourcePage,
    'sourceName':      sourceName,
    'packId':          packId,
    'packVersion':     packVersion,
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
      questionType:    questionType,
      sourceBook:      sourceBook,
      sourceFileName:  sourceFileName,
      sourcePage:      sourcePage,
      sourceName:      sourceName,
      packId:          packId,
      packVersion:     packVersion,
      isActive:        isActive ?? this.isActive,
      lastCycleServed: lastCycleServed ?? this.lastCycleServed,
      createdAt:       createdAt,
      updatedAt:       updatedAt ?? this.updatedAt,
    );
  }
}







