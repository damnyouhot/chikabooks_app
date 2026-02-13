import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_goal.dart';

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

  /// 기간 타입별 현재 periodKey 반환
  static String getCurrentPeriodKey(PeriodType type) {
    switch (type) {
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

  /// 목표 저장 (최대 3개 검증)
  static Future<bool> saveGoals(List<UserGoal> items) async {
    if (items.length > 3) {
      debugPrint('⚠️ 목표는 최대 3개까지만 저장 가능');
      return false;
    }

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
    required PeriodType periodType,
  }) async {
    try {
      if (title.trim().isEmpty) {
        debugPrint('⚠️ 목표 내용이 비어있음');
        return false;
      }

      final goals = await loadGoals();
      
      if (!goals.canAdd) {
        debugPrint('⚠️ 목표는 최대 3개까지만 추가 가능');
        return false;
      }

      final newGoal = UserGoal.create(
        title: title.trim(),
        periodType: periodType,
        periodKey: getCurrentPeriodKey(periodType),
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
}

