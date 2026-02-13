import 'package:cloud_firestore/cloud_firestore.dart';

/// 주간 목표 모델
/// Firestore: weeklyGoals/{uid_YYYYWW}
class WeeklyGoals {
  final String uid;
  final String weekKey; // "2026-W07"
  final List<GoalItem> goals; // 최대 2개
  final DateTime? updatedAt;

  const WeeklyGoals({
    required this.uid,
    required this.weekKey,
    this.goals = const [],
    this.updatedAt,
  });

  factory WeeklyGoals.fromMap(Map<String, dynamic> m) {
    final rawGoals = m['goals'] as List<dynamic>? ?? [];
    return WeeklyGoals(
      uid: m['uid'] ?? '',
      weekKey: m['weekKey'] ?? '',
      goals: rawGoals.map((g) => GoalItem.fromMap(g as Map<String, dynamic>)).toList(),
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'weekKey': weekKey,
        'goals': goals.map((g) => g.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// 목표 추가 가능 여부 (최대 2개)
  bool get canAddGoal => goals.length < 2;
}

/// 개별 목표 아이템
class GoalItem {
  final String id;
  final String title;
  final DateTime createdAt;
  final int progress; // 체크인 횟수
  final int target; // 목표 횟수 (기본 7 = 일주일)

  const GoalItem({
    required this.id,
    required this.title,
    required this.createdAt,
    this.progress = 0,
    this.target = 7,
  });

  factory GoalItem.fromMap(Map<String, dynamic> m) {
    return GoalItem(
      id: m['id'] ?? '',
      title: m['title'] ?? '',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      progress: m['progress'] ?? 0,
      target: m['target'] ?? 7,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'createdAt': Timestamp.fromDate(createdAt),
        'progress': progress,
        'target': target,
      };

  GoalItem copyWith({int? progress}) => GoalItem(
        id: id,
        title: title,
        createdAt: createdAt,
        progress: progress ?? this.progress,
        target: target,
      );
}




