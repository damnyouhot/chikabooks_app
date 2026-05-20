import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

/// 목표 타입
enum GoalType {
  routine,   // 루틴형 (매일/반복)
  project,   // 프로젝트형 (한 번 달성)
}

/// 목표 기간 타입
enum PeriodType {
  day,    // 일간 (오늘 안에 끝낼 일)
  week,   // 주간
  month,  // 월간
  year,   // 연간
}

/// 프로젝트 체크포인트(마일스톤). 1~5개. 자유로운 단계 표현.
class GoalCheckpoint {
  final String id;
  final String title;
  final bool done;

  const GoalCheckpoint({
    required this.id,
    required this.title,
    this.done = false,
  });

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'done': done};

  factory GoalCheckpoint.fromMap(Map<String, dynamic> m) => GoalCheckpoint(
        id: m['id'] as String,
        title: m['title'] as String,
        done: m['done'] as bool? ?? false,
      );

  GoalCheckpoint copyWith({String? title, bool? done}) => GoalCheckpoint(
        id: id,
        title: title ?? this.title,
        done: done ?? this.done,
      );
}

/// 사용자 목표
class UserGoal {
  final String id;
  final String title;
  final GoalType type;
  final PeriodType periodType;
  final String periodKey;  // "2026-W07", "2026-02", "2026"

  // 프로젝트형 필드
  final bool isDone;
  final DateTime? doneAt;
  /// 사용자가 캘린더로 직접 고른 마감일. 없으면 periodType 기반(주말/월말 등).
  final DateTime? deadline;
  /// 1~5개의 마일스톤. 진행률 = 완료 수 / 전체.
  final List<GoalCheckpoint> checkpoints;
  /// 「오늘 5분이라도 했어요」 일일 터치 날짜 키(yyyy-MM-dd) 누적.
  final List<String> dailyTouchDates;

  // 루틴형 필드
  final int weeklyTarget;

  final DateTime createdAt;
  final DateTime updatedAt;

  const UserGoal({
    required this.id,
    required this.title,
    required this.type,
    required this.periodType,
    required this.periodKey,
    this.isDone = false,
    this.doneAt,
    this.deadline,
    this.checkpoints = const [],
    this.dailyTouchDates = const [],
    this.weeklyTarget = 7,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type.name,
      'periodType': periodType.name,
      'periodKey': periodKey,
      'isDone': isDone,
      'doneAt': doneAt != null ? Timestamp.fromDate(doneAt!) : null,
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'checkpoints': checkpoints.map((c) => c.toMap()).toList(),
      'dailyTouchDates': dailyTouchDates,
      'weeklyTarget': weeklyTarget,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory UserGoal.fromMap(Map<String, dynamic> map) {
    return UserGoal(
      id: map['id'] as String,
      title: map['title'] as String,
      type: GoalType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'project'),
        orElse: () => GoalType.project,
      ),
      periodType: PeriodType.values.firstWhere(
        (e) => e.name == map['periodType'],
        orElse: () => PeriodType.week,
      ),
      periodKey: map['periodKey'] as String,
      isDone: map['isDone'] as bool? ?? false,
      doneAt: map['doneAt'] != null
          ? (map['doneAt'] as Timestamp).toDate()
          : null,
      deadline: map['deadline'] != null
          ? (map['deadline'] as Timestamp).toDate()
          : null,
      checkpoints: ((map['checkpoints'] as List?) ?? const [])
          .map((e) => GoalCheckpoint.fromMap(e as Map<String, dynamic>))
          .toList(),
      dailyTouchDates: ((map['dailyTouchDates'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      weeklyTarget: map['weeklyTarget'] as int? ?? 7,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// 새 목표 생성
  factory UserGoal.create({
    required String title,
    required GoalType type,
    required PeriodType periodType,
    required String periodKey,
    int weeklyTarget = 7,
    DateTime? deadline,
    List<GoalCheckpoint> checkpoints = const [],
  }) {
    final now = DateTime.now();
    return UserGoal(
      id: const Uuid().v4(),
      title: title,
      type: type,
      periodType: periodType,
      periodKey: periodKey,
      weeklyTarget: weeklyTarget,
      isDone: false,
      doneAt: null,
      deadline: deadline,
      checkpoints: checkpoints,
      dailyTouchDates: const [],
      createdAt: now,
      updatedAt: now,
    );
  }

  UserGoal copyWith({
    String? title,
    GoalType? type,
    PeriodType? periodType,
    String? periodKey,
    bool? isDone,
    DateTime? doneAt,
    DateTime? deadline,
    bool clearDeadline = false,
    List<GoalCheckpoint>? checkpoints,
    List<String>? dailyTouchDates,
    int? weeklyTarget,
    DateTime? updatedAt,
  }) {
    return UserGoal(
      id: id,
      title: title ?? this.title,
      type: type ?? this.type,
      periodType: periodType ?? this.periodType,
      periodKey: periodKey ?? this.periodKey,
      isDone: isDone ?? this.isDone,
      doneAt: doneAt ?? this.doneAt,
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
      checkpoints: checkpoints ?? this.checkpoints,
      dailyTouchDates: dailyTouchDates ?? this.dailyTouchDates,
      weeklyTarget: weeklyTarget ?? this.weeklyTarget,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// 타입 라벨
  String get typeLabel {
    switch (type) {
      case GoalType.routine:
        return '루틴';
      case GoalType.project:
        return '프로젝트';
    }
  }

  /// 기간 라벨
  String get periodLabel {
    switch (periodType) {
      case PeriodType.day:
        return '오늘';
      case PeriodType.week:
        return '주간';
      case PeriodType.month:
        return '월간';
      case PeriodType.year:
        return '연간';
    }
  }

  /// 마감 안내 문구 (프로젝트용)
  /// 사용자가 캘린더로 직접 고른 [deadline] 이 있으면 그걸 우선.
  String get deadlineText {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dl = effectiveDeadline;
    if (dl != null) {
      final dlDay = DateTime(dl.year, dl.month, dl.day);
      final diff = dlDay.difference(today).inDays;
      if (diff == 0) return '오늘 마감';
      if (diff < 0) return '${-diff}일 지남';
      return '$diff일 남음 (${dl.month}/${dl.day})';
    }
    switch (periodType) {
      case PeriodType.day:
        return '오늘까지';

      case PeriodType.week:
        final sunday = now.add(Duration(days: DateTime.sunday - now.weekday));
        final diff = sunday.difference(now).inDays;
        if (diff == 0) return '오늘까지';
        return '$diff일 남음 (${sunday.month}/${sunday.day})';

      case PeriodType.month:
        final lastDay = DateTime(now.year, now.month + 1, 0);
        final diff = lastDay.difference(now).inDays;
        if (diff == 0) return '오늘까지';
        return '$diff일 남음 (${lastDay.month}/${lastDay.day})';

      case PeriodType.year:
        final lastDay = DateTime(now.year, 12, 31);
        final diff = lastDay.difference(now).inDays;
        if (diff < 30) return '$diff일 남음';
        return '12/31까지';
    }
  }

  /// periodType 기본 마감 OR 사용자가 직접 지정한 deadline 중 후자 우선.
  DateTime? get effectiveDeadline {
    if (deadline != null) return deadline;
    final now = DateTime.now();
    switch (periodType) {
      case PeriodType.day:
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
      case PeriodType.week:
        return now.add(Duration(days: DateTime.sunday - now.weekday));
      case PeriodType.month:
        return DateTime(now.year, now.month + 1, 0);
      case PeriodType.year:
        return DateTime(now.year, 12, 31);
    }
  }

  /// 마감까지 남은 일수(과거면 음수). null = 마감 정보 없음.
  int? get daysUntilDeadline {
    final dl = effectiveDeadline;
    if (dl == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dlDay = DateTime(dl.year, dl.month, dl.day);
    return dlDay.difference(today).inDays;
  }

  /// D-N 짧은 칩 라벨 ("D-7", "D-DAY", "D+2"). 없으면 null.
  String? get dDayLabel {
    final n = daysUntilDeadline;
    if (n == null) return null;
    if (n == 0) return 'D-DAY';
    if (n > 0) return 'D-$n';
    return 'D+${-n}';
  }

  /// 체크포인트 진행률 (0.0 ~ 1.0). 체크포인트 없으면 null.
  double? get checkpointProgress {
    if (checkpoints.isEmpty) return null;
    final done = checkpoints.where((c) => c.done).length;
    return done / checkpoints.length;
  }

  /// 오늘 일일 터치 했는지.
  bool get touchedToday {
    final now = DateTime.now();
    final key =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return dailyTouchDates.contains(key);
  }

  /// 루틴 빈도 문구
  String get frequencyText {
    if (weeklyTarget == 7) return '매일';
    if (weeklyTarget == 5) return '주 5회 (평일)';
    return '주 $weeklyTarget회';
  }
}

/// 사용자 목표 컨테이너
class UserGoals {
  final List<UserGoal> items;
  final DateTime updatedAt;

  const UserGoals({
    required this.items,
    required this.updatedAt,
  });

  factory UserGoals.empty() {
    return UserGoals(
      items: [],
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'items': items.map((g) => g.toMap()).toList(),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory UserGoals.fromMap(Map<String, dynamic> map) {
    final itemsList = map['items'] as List<dynamic>? ?? [];
    return UserGoals(
      items: itemsList.map((item) => UserGoal.fromMap(item as Map<String, dynamic>)).toList(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// 목표 개수
  int get count => items.length;

  /// 추가 가능 여부 — 상한 없음(필요 시 클라이언트 UX 측면에서만 제한).
  bool get canAdd => true;

  /// 루틴형 목표만
  List<UserGoal> get routines => items.where((g) => g.type == GoalType.routine).toList();

  /// 프로젝트형 목표만
  List<UserGoal> get projects => items.where((g) => g.type == GoalType.project).toList();
}

