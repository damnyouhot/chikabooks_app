import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

/// 목표 타입
enum GoalType {
  routine,   // 루틴형 (매일/반복)
  project,   // 프로젝트형 (한 번 달성)
}

/// 목표 기간 타입
enum PeriodType {
  week,   // 주간
  month,  // 월간
  year,   // 연간
}

/// 사용자 목표 (최대 3개)
class UserGoal {
  final String id;
  final String title;
  final GoalType type;              // ✨ 추가: 루틴/프로젝트
  final PeriodType periodType;
  final String periodKey;  // "2026-W07", "2026-02", "2026"
  
  // 프로젝트형 필드
  final bool isDone;
  final DateTime? doneAt;
  
  // 루틴형 필드
  final int weeklyTarget;           // ✨ 추가: 주 n회 목표 (1~7, 기본 7)
  
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
    this.weeklyTarget = 7,          // 기본값: 매일
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
      case PeriodType.week:
        return '주간';
      case PeriodType.month:
        return '월간';
      case PeriodType.year:
        return '연간';
    }
  }

  /// 마감 안내 문구 (프로젝트용)
  String get deadlineText {
    final now = DateTime.now();
    switch (periodType) {
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

  /// 추가 가능 여부 (최대 3개)
  bool get canAdd => items.length < 3;

  /// 루틴형 목표만
  List<UserGoal> get routines => items.where((g) => g.type == GoalType.routine).toList();

  /// 프로젝트형 목표만
  List<UserGoal> get projects => items.where((g) => g.type == GoalType.project).toList();
}

