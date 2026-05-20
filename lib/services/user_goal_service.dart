import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_goal.dart';
import '../models/routine_check.dart';

/// 사용자 목표 서비스
/// 
/// Firestore: users/{uid}/goals/current
/// 목표는 최대 3개, 기간(연/월/주)별 자동 리셋
class UserGoalService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ─── 기간 키 생성 ───

  /// 현재 주차 키 (ISO 8601)
  static String currentWeekKey() {
    return weekKeyFor(DateTime.now());
  }

  /// 특정 날짜의 주차 키
  static String weekKeyFor(DateTime dt) {
    final thursday = dt.add(Duration(days: DateTime.thursday - dt.weekday));
    final jan4 = DateTime(thursday.year, 1, 4);
    final weekNum = ((thursday.difference(jan4).inDays) / 7).ceil() + 1;
    return '${thursday.year}-W${weekNum.toString().padLeft(2, '0')}';
  }

  /// 현재 월 키
  static String currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  /// 현재 연 키
  static String currentYearKey() {
    return '${DateTime.now().year}';
  }

  /// 현재 일 키 (`YYYY-MM-DD`)
  static String currentDayKey() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  /// 기간 타입별 현재 periodKey 반환
  static String getCurrentPeriodKey(PeriodType type) {
    switch (type) {
      case PeriodType.day:
        return currentDayKey();
      case PeriodType.week:
        return currentWeekKey();
      case PeriodType.month:
        return currentMonthKey();
      case PeriodType.year:
        return currentYearKey();
    }
  }

  // ─── CRUD ───

  /// 목표 로드 + 자동 리셋
  static Future<UserGoals> loadGoals() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return UserGoals.empty();

      final doc = await _db
          .collection('users')
          .doc(uid)
          .collection('goals')
          .doc('current')
          .get();

      if (!doc.exists || doc.data() == null) {
        return UserGoals.empty();
      }

      var goals = UserGoals.fromMap(doc.data()!);

      // 자동 리셋 체크
      bool needsUpdate = false;
      final updatedItems = <UserGoal>[];

      for (var goal in goals.items) {
        final currentKey = getCurrentPeriodKey(goal.periodType);
        
        if (goal.periodKey != currentKey) {
          // 기간이 바뀜 → 리셋
          debugPrint('🔄 목표 리셋: ${goal.title} (${goal.periodKey} → $currentKey)');
          updatedItems.add(goal.copyWith(
            isDone: false,
            doneAt: null,
            periodKey: currentKey,
            updatedAt: DateTime.now(),
          ));
          needsUpdate = true;
        } else {
          updatedItems.add(goal);
        }
      }

      if (needsUpdate) {
        final updatedGoals = UserGoals(
          items: updatedItems,
          updatedAt: DateTime.now(),
        );
        await _saveGoals(updatedGoals);
        return updatedGoals;
      }

      return goals;
    } catch (e) {
      debugPrint('⚠️ UserGoalService.loadGoals error: $e');
      return UserGoals.empty();
    }
  }

  /// 목표 저장 — 상한 없음.
  static Future<bool> saveGoals(List<UserGoal> items) async {
    final goals = UserGoals(
      items: items,
      updatedAt: DateTime.now(),
    );

    return await _saveGoals(goals);
  }

  /// 내부 저장 메서드
  static Future<bool> _saveGoals(UserGoals goals) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return false;

      await _db
          .collection('users')
          .doc(uid)
          .collection('goals')
          .doc('current')
          .set(goals.toMap(), SetOptions(merge: true));

      debugPrint('✅ 목표 저장 완료: ${goals.items.length}개');
      return true;
    } catch (e) {
      debugPrint('⚠️ UserGoalService._saveGoals error: $e');
      return false;
    }
  }

  /// 목표 추가
  static Future<bool> addGoal({
    required String title,
    required GoalType type,
    required PeriodType periodType,
    int weeklyTarget = 7,
  }) async {
    try {
      if (title.trim().isEmpty) {
        debugPrint('⚠️ 목표 내용이 비어있음');
        return false;
      }

      final goals = await loadGoals();

      final newGoal = UserGoal.create(
        title: title.trim(),
        type: type,
        periodType: periodType,
        periodKey: getCurrentPeriodKey(periodType),
        weeklyTarget: weeklyTarget,
      );

      final updatedItems = [...goals.items, newGoal];
      return await saveGoals(updatedItems);
    } catch (e) {
      debugPrint('⚠️ UserGoalService.addGoal error: $e');
      return false;
    }
  }

  /// 목표 업데이트
  static Future<bool> updateGoal(UserGoal updatedGoal) async {
    try {
      final goals = await loadGoals();
      final index = goals.items.indexWhere((g) => g.id == updatedGoal.id);
      
      if (index == -1) {
        debugPrint('⚠️ 목표를 찾을 수 없음: ${updatedGoal.id}');
        return false;
      }

      final updatedItems = [...goals.items];
      updatedItems[index] = updatedGoal.copyWith(updatedAt: DateTime.now());

      return await saveGoals(updatedItems);
    } catch (e) {
      debugPrint('⚠️ UserGoalService.updateGoal error: $e');
      return false;
    }
  }

  /// 목표 삭제
  static Future<bool> deleteGoal(String goalId) async {
    try {
      final goals = await loadGoals();
      final updatedItems = goals.items.where((g) => g.id != goalId).toList();
      
      return await saveGoals(updatedItems);
    } catch (e) {
      debugPrint('⚠️ UserGoalService.deleteGoal error: $e');
      return false;
    }
  }

  /// 완료 토글
  static Future<bool> toggleDone(String goalId) async {
    try {
      final goals = await loadGoals();
      final goal = goals.items.firstWhere(
        (g) => g.id == goalId,
        orElse: () => throw Exception('목표를 찾을 수 없음'),
      );

      final updatedGoal = goal.copyWith(
        isDone: !goal.isDone,
        doneAt: !goal.isDone ? DateTime.now() : null,
        updatedAt: DateTime.now(),
      );

      return await updateGoal(updatedGoal);
    } catch (e) {
      debugPrint('⚠️ UserGoalService.toggleDone error: $e');
      return false;
    }
  }

  /// 목표 스트림 (실시간 업데이트)
  static Stream<UserGoals> watchGoals() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Stream.value(UserGoals.empty());
    }

    return _db
        .collection('users')
        .doc(uid)
        .collection('goals')
        .doc('current')
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) {
        return UserGoals.empty();
      }
      return UserGoals.fromMap(doc.data()!);
    });
  }

  // ─── 루틴 체크 관련 ───

  /// 오늘 날짜 키
  static String todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 오늘 루틴 체크 로드
  static Future<RoutineCheck> loadTodayCheck() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return RoutineCheck.empty(todayKey());

      final doc = await _db
          .collection('users')
          .doc(uid)
          .collection('routineChecks')
          .doc(todayKey())
          .get();

      if (!doc.exists || doc.data() == null) {
        return RoutineCheck.empty(todayKey());
      }

      return RoutineCheck.fromMap(doc.data()!);
    } catch (e) {
      debugPrint('⚠️ loadTodayCheck error: $e');
      return RoutineCheck.empty(todayKey());
    }
  }

  /// 루틴 체크 토글 (오늘)
  static Future<bool> toggleRoutineCheck(String goalId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return false;

      final today = todayKey();
      final check = await loadTodayCheck();
      final updated = check.toggleCheck(goalId);

      await _db
          .collection('users')
          .doc(uid)
          .collection('routineChecks')
          .doc(today)
          .set(updated.toMap(), SetOptions(merge: true));

      debugPrint('✅ 루틴 체크 토글: $goalId (${updated.isChecked(goalId) ? "ON" : "OFF"})');
      return true;
    } catch (e) {
      debugPrint('⚠️ toggleRoutineCheck error: $e');
      return false;
    }
  }

  /// 이번 주 특정 루틴의 체크 횟수
  static Future<int> getWeeklyCheckCount(String goalId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return 0;

      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      
      int count = 0;
      for (int i = 0; i < 7; i++) {
        final date = monday.add(Duration(days: i));
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        
        final doc = await _db
            .collection('users')
            .doc(uid)
            .collection('routineChecks')
            .doc(dateKey)
            .get();

        if (doc.exists && doc.data() != null) {
          final check = RoutineCheck.fromMap(doc.data()!);
          if (check.isChecked(goalId)) count++;
        }
      }

      return count;
    } catch (e) {
      debugPrint('⚠️ getWeeklyCheckCount error: $e');
      return 0;
    }
  }

  /// 이번 달 모든 루틴 체크 누적 합계.
  ///
  /// 매월 1일부터 오늘까지의 `routineChecks/{dateKey}` 를 순회하며 각 문서에서
  /// 체크된 항목 수를 합산한다. 호출 횟수: 최대 31회/월 (작음).
  static Future<int> getMonthlyTotalChecks() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return 0;

      final now = DateTime.now();
      int total = 0;
      for (int day = 1; day <= now.day; day++) {
        final dateKey =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-'
            '${day.toString().padLeft(2, '0')}';
        final doc = await _db
            .collection('users')
            .doc(uid)
            .collection('routineChecks')
            .doc(dateKey)
            .get();
        if (doc.exists && doc.data() != null) {
          final check = RoutineCheck.fromMap(doc.data()!);
          total += check.checkedGoalIds.length;
        }
      }
      return total;
    } catch (e) {
      debugPrint('⚠️ getMonthlyTotalChecks error: $e');
      return 0;
    }
  }

  /// 연속 체크 일수 (스트릭)
  static Future<int> getStreak(String goalId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return 0;

      int streak = 0;
      final now = DateTime.now();

      // 어제부터 역순으로 체크
      for (int i = 1; i <= 30; i++) {  // 최대 30일 검사
        final date = now.subtract(Duration(days: i));
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        
        final doc = await _db
            .collection('users')
            .doc(uid)
            .collection('routineChecks')
            .doc(dateKey)
            .get();

        if (doc.exists && doc.data() != null) {
          final check = RoutineCheck.fromMap(doc.data()!);
          if (check.isChecked(goalId)) {
            streak++;
          } else {
            break;  // 연속이 끊김
          }
        } else {
          break;
        }
      }

      return streak;
    } catch (e) {
      debugPrint('⚠️ getStreak error: $e');
      return 0;
    }
  }
}

