import 'package:cloud_firestore/cloud_firestore.dart';
import 'quiz_content_config.dart';
import 'quiz_pool_item.dart';

/// quiz_schedule/{dateKey} 문서 모델
///
/// Cloud Function이 매일 자정에 생성.
/// items: 배포 시점의 문제 스냅샷 (quiz_pool 수정에 독립적)
class QuizSchedule {
  final String dateKey;        // 문서 ID e.g. '2026-03-16'
  final List<String> quizIds;  // quiz_pool 문서 ID 목록
  final List<QuizPoolItem> items; // 배포 시점 스냅샷
  final int cycleCount;        // 몇 번째 사이클인지
  final int startOrder;        // 이 날의 첫 번째 문제 order
  final int endOrder;          // 이 날의 마지막 문제 order
  final DateTime createdAt;

  const QuizSchedule({
    required this.dateKey,
    required this.quizIds,
    required this.items,
    required this.cycleCount,
    required this.startOrder,
    required this.endOrder,
    required this.createdAt,
  });

  factory QuizSchedule.fromFirestore(
    DocumentSnapshot doc, {
    QuizContentConfig? contentConfig,
  }) {
    final d = doc.data() as Map<String, dynamic>;
    final cfg = contentConfig ?? QuizContentConfig.defaultLegacy();

    // items: 스냅샷 리스트 역직렬화
    final rawItems = d['items'] as List<dynamic>? ?? [];
    final items = rawItems.map((e) {
      // items는 자동ID 없이 저장되므로 임시 id=''로 처리
      final map = Map<String, dynamic>.from(e as Map);
      final qType = QuizPoolItem.resolveQuestionTypeForScheduleSnapshot(map, cfg);
      return QuizPoolItem(
        id:              map['id'] as String? ?? '',
        order:           (map['order'] as num?)?.toInt() ?? 0,
        question:        map['question'] as String? ?? '',
        options:         List<String>.from(map['options'] ?? []),
        correctIndex:    (map['correctIndex'] as num?)?.toInt() ?? 0,
        explanation:     map['explanation'] as String? ?? '',
        category:        map['category'] as String? ?? '',
        difficulty:      map['difficulty'] as String? ?? 'basic',
        questionType:    qType,
        sourceBook:      map['sourceBook'] as String? ?? '',
        sourceFileName:  map['sourceFileName'] as String? ?? '',
        sourcePage:      map['sourcePage'] as String? ?? '',
        sourceName:      map['sourceName'] as String? ?? '',
        packId:          map['packId'] as String? ?? '',
        packVersion:     (map['packVersion'] as num?)?.toInt() ?? 0,
        isActive:        map['isActive'] as bool? ?? true,
        lastCycleServed: (map['lastCycleServed'] as num?)?.toInt() ?? 0,
        createdAt:       DateTime.now(),
        updatedAt:       DateTime.now(),
      );
    }).toList();

    return QuizSchedule(
      dateKey:    doc.id,
      quizIds:    List<String>.from(d['quizIds'] ?? []),
      items:      items,
      cycleCount: (d['cycleCount'] as num?)?.toInt() ?? 1,
      startOrder: (d['startOrder'] as num?)?.toInt() ?? 0,
      endOrder:   (d['endOrder'] as num?)?.toInt() ?? 0,
      createdAt:  (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// quiz_meta/state 문서 모델
///
/// 전체 배포 진행 상태를 추적.
/// 대시보드에서 "전체 N개 중 M번째 진행 중" 표시에 사용.
///
/// [usedCount]: usedQuizIds 배열의 길이.
///   - 이번 사이클에서 배포된 문제 수를 나타냄.
///   - 풀 소진(사이클 리셋) 시 0으로 초기화되므로 "이번 사이클 배포 수"임.
///   - Firestore에 직접 저장되는 필드가 아닌, usedQuizIds.length 파생값.
class QuizMetaState {
  final int cycleCount;        // 현재 사이클 번호 (1부터)
  /// `config/quiz_content` 패크 필터를 적용한 스케줄 후보 수 (국시+임상 합)
  final int totalActiveCount;
  /// 후보 중 국시 문항 수 (CF `computeQuizMetaAnalytics` 동기화)
  final int totalNationalActiveCount;
  /// 후보 중 임상 문항 수
  final int totalClinicalActiveCount;
  /// 이번 사이클 배포된 고유 국시 id 수
  final int usedNationalCount;
  /// 이번 사이클 배포된 고유 임상 id 수
  final int usedClinicalCount;
  final String lastScheduledDate; // 마지막 스케줄 생성일 e.g. '2026-03-16'
  final int dailyCount;        // 하루 배포 수 (기본 2)
  final int usedCount;         // 이번 사이클에서 배포된 문제 수 (usedQuizIds.length)

  const QuizMetaState({
    required this.cycleCount,
    required this.totalActiveCount,
    this.totalNationalActiveCount = 0,
    this.totalClinicalActiveCount = 0,
    this.usedNationalCount = 0,
    this.usedClinicalCount = 0,
    required this.lastScheduledDate,
    required this.dailyCount,
    this.usedCount = 0,
  });

  factory QuizMetaState.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    // usedQuizIds: 이번 사이클에서 배포된 문제 ID 누적 배열
    // 풀 소진 시 CF가 []로 초기화하므로 "이번 사이클 배포 수"를 나타냄
    final usedQuizIds = d['usedQuizIds'] as List<dynamic>? ?? [];
    return QuizMetaState(
      cycleCount:         (d['cycleCount'] as num?)?.toInt() ?? 1,
      totalActiveCount:   (d['totalActiveCount'] as num?)?.toInt() ?? 0,
      totalNationalActiveCount:
          (d['totalNationalActiveCount'] as num?)?.toInt() ?? 0,
      totalClinicalActiveCount:
          (d['totalClinicalActiveCount'] as num?)?.toInt() ?? 0,
      usedNationalCount: (d['usedNationalCount'] as num?)?.toInt() ?? 0,
      usedClinicalCount: (d['usedClinicalCount'] as num?)?.toInt() ?? 0,
      lastScheduledDate:  d['lastScheduledDate'] as String? ?? '',
      dailyCount:         (d['dailyCount'] as num?)?.toInt() ?? 2,
      usedCount:          usedQuizIds.length,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'cycleCount':         cycleCount,
    'totalActiveCount':   totalActiveCount,
    'lastScheduledDate':  lastScheduledDate,
    'dailyCount':         dailyCount,
  };

  /// 대시보드 표시용: "전체 N개 중 M문제 진행 중 (K사이클)"
  String get progressLabel {
    if (totalActiveCount == 0) return '퀴즈 풀 없음';
    return '전체 ${totalActiveCount}문제 중 ${usedCount}문제 진행 ($cycleCount사이클)';
  }
}

/// users/{uid}/quiz_history/{dateKey} 문서 모델
///
/// 유저별 날짜별 풀이 기록.
/// "다시보기 모드", 지난 퀴즈 정답/오답 표시에 사용.
class UserQuizHistory {
  final String dateKey;
  final List<String> quizIds;
  final Map<String, int> answers;    // quizId → 선택한 옵션 인덱스
  final int correctCount;
  final bool rewardGranted;
  final DateTime? submittedAt;

  const UserQuizHistory({
    required this.dateKey,
    required this.quizIds,
    required this.answers,
    required this.correctCount,
    required this.rewardGranted,
    this.submittedAt,
  });

  factory UserQuizHistory.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserQuizHistory(
      dateKey:       doc.id,
      quizIds:       List<String>.from(d['quizIds'] ?? []),
      answers:       Map<String, int>.from(
        (d['answers'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toInt())),
      ),
      correctCount:  (d['correctCount'] as num?)?.toInt() ?? 0,
      rewardGranted: d['rewardGranted'] as bool? ?? false,
      submittedAt:   (d['submittedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'quizIds':       quizIds,
    'answers':       answers,
    'correctCount':  correctCount,
    'rewardGranted': rewardGranted,
    'submittedAt':   submittedAt != null
        ? Timestamp.fromDate(submittedAt!)
        : FieldValue.serverTimestamp(),
  };

  bool get isCompleted => answers.length == quizIds.length;
}


