import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

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
  final PeriodType periodType;
  final String periodKey;  // "2026-W07", "2026-02", "2026"
  final bool isDone;
  final DateTime? doneAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserGoal({
    required this.id,
    required this.title,
    required this.periodType,
    required this.periodKey,
    this.isDone = false,
    this.doneAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'periodType': periodType.name,
      'periodKey': periodKey,
      'isDone': isDone,
      'doneAt': doneAt != null ? Timestamp.fromDate(doneAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory UserGoal.fromMap(Map<String, dynamic> map) {
    return UserGoal(
      id: map['id'] as String,
      title: map['title'] as String,
      periodType: PeriodType.values.firstWhere(
        (e) => e.name == map['periodType'],
        orElse: () => PeriodType.week,
      ),
      periodKey: map['periodKey'] as String,
      isDone: map['isDone'] as bool? ?? false,
      doneAt: map['doneAt'] != null 
          ? (map['doneAt'] as Timestamp).toDate() 
          : null,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// 새 목표 생성
  factory UserGoal.create({
    required String title,
    required PeriodType periodType,
    required String periodKey,
  }) {
    final now = DateTime.now();
    return UserGoal(
      id: const Uuid().v4(),
      title: title,
      periodType: periodType,
      periodKey: periodKey,
      isDone: false,
      doneAt: null,
      createdAt: now,
      updatedAt: now,
    );
  }

  UserGoal copyWith({
    String? title,
    PeriodType? periodType,
    String? periodKey,
    bool? isDone,
    DateTime? doneAt,
    DateTime? updatedAt,
  }) {
    return UserGoal(
      id: id,
      title: title ?? this.title,
      periodType: periodType ?? this.periodType,
      periodKey: periodKey ?? this.periodKey,
      isDone: isDone ?? this.isDone,
      doneAt: doneAt ?? this.doneAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
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
}

