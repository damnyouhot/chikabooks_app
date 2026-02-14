import 'package:cloud_firestore/cloud_firestore.dart';

/// 루틴 체크 기록 (날짜별)
/// 
/// Firestore 경로: users/{uid}/routineChecks/{dateKey}
/// 예: users/abc123/routineChecks/2026-02-14
class RoutineCheck {
  final String dateKey;            // "2026-02-14"
  final List<String> checkedGoalIds;  // 오늘 체크한 목표 ID 목록
  final DateTime updatedAt;

  const RoutineCheck({
    required this.dateKey,
    required this.checkedGoalIds,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'dateKey': dateKey,
      'checkedGoalIds': checkedGoalIds,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory RoutineCheck.fromMap(Map<String, dynamic> map) {
    return RoutineCheck(
      dateKey: map['dateKey'] as String,
      checkedGoalIds: List<String>.from(map['checkedGoalIds'] ?? []),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  factory RoutineCheck.empty(String dateKey) {
    return RoutineCheck(
      dateKey: dateKey,
      checkedGoalIds: [],
      updatedAt: DateTime.now(),
    );
  }

  /// 특정 목표가 체크되었는지
  bool isChecked(String goalId) => checkedGoalIds.contains(goalId);

  /// 체크 토글
  RoutineCheck toggleCheck(String goalId) {
    final updated = List<String>.from(checkedGoalIds);
    if (updated.contains(goalId)) {
      updated.remove(goalId);
    } else {
      updated.add(goalId);
    }
    return RoutineCheck(
      dateKey: dateKey,
      checkedGoalIds: updated,
      updatedAt: DateTime.now(),
    );
  }
}




