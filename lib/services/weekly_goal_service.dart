import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/weekly_goal.dart';
import 'user_profile_service.dart';
import 'weekly_stamp_service.dart';

/// 주간 목표 서비스
///
/// Firestore: weeklyGoals/{uid_YYYYWW}
/// 사용자당 주 1문서, 목표 최대 2개.
class WeeklyGoalService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ─── 주차 키 계산 ───

  /// ISO 주차 키 반환: "2026-W07"
  static String currentWeekKey() {
    final now = DateTime.now();
    return weekKeyFor(now);
  }

  /// 특정 날짜의 주차 키
  static String weekKeyFor(DateTime dt) {
    // ISO 8601 주차 계산
    final thursday = dt.add(Duration(days: DateTime.thursday - dt.weekday));
    final jan4 = DateTime(thursday.year, 1, 4);
    final weekNum =
        ((thursday.difference(jan4).inDays) / 7).ceil() + 1;
    return '${thursday.year}-W${weekNum.toString().padLeft(2, '0')}';
  }

  /// 현재 주차 문서 ID
  static String _docId() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다.');
    return '${uid}_${currentWeekKey()}';
  }

  // ─── CRUD ───

  /// 이번 주 목표 읽기
  static Future<WeeklyGoals?> getThisWeek() async {
    try {
      final doc = await _db.collection('weeklyGoals').doc(_docId()).get();
      if (!doc.exists || doc.data() == null) return null;
      return WeeklyGoals.fromMap(doc.data()!);
    } catch (e) {
      debugPrint('⚠️ WeeklyGoalService.getThisWeek error: $e');
      return null;
    }
  }

  /// 이번 주 목표 스트림
  static Stream<WeeklyGoals?> watchThisWeek() {
    try {
      return _db
          .collection('weeklyGoals')
          .doc(_docId())
          .snapshots()
          .map((snap) {
        if (!snap.exists || snap.data() == null) return null;
        return WeeklyGoals.fromMap(snap.data()!);
      });
    } catch (e) {
      debugPrint('⚠️ WeeklyGoalService.watchThisWeek error: $e');
      return Stream.value(null);
    }
  }

  /// 목표 추가 (최대 2개 제한)
  static Future<String> addGoal(String title) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return '로그인이 필요합니다.';

      final docRef = _db.collection('weeklyGoals').doc(_docId());
      final doc = await docRef.get();

      List<GoalItem> goals = [];
      if (doc.exists && doc.data() != null) {
        final existing = WeeklyGoals.fromMap(doc.data()!);
        goals = List.from(existing.goals);
      }

      if (goals.length >= 2) return '목표는 최대 2개까지 설정할 수 있어요.';

      final newGoal = GoalItem(
        id: 'g${DateTime.now().millisecondsSinceEpoch}',
        title: title.trim(),
        createdAt: DateTime.now(),
      );
      goals.add(newGoal);

      final data = WeeklyGoals(
        uid: uid,
        weekKey: currentWeekKey(),
        goals: goals,
      );

      await docRef.set(data.toMap(), SetOptions(merge: true));
      return '목표가 추가되었어요.';
    } catch (e) {
      debugPrint('⚠️ WeeklyGoalService.addGoal error: $e');
      return '오류가 발생했어요.';
    }
  }

  /// 목표 삭제
  static Future<void> removeGoal(String goalId) async {
    try {
      final docRef = _db.collection('weeklyGoals').doc(_docId());
      final doc = await docRef.get();
      if (!doc.exists || doc.data() == null) return;

      final existing = WeeklyGoals.fromMap(doc.data()!);
      final updated = existing.goals.where((g) => g.id != goalId).toList();

      await docRef.update({
        'goals': updated.map((g) => g.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('⚠️ WeeklyGoalService.removeGoal error: $e');
    }
  }

  /// 목표 체크인 (progress +1)
  static Future<void> checkIn(String goalId) async {
    try {
      final docRef = _db.collection('weeklyGoals').doc(_docId());
      final doc = await docRef.get();
      if (!doc.exists || doc.data() == null) return;

      final existing = WeeklyGoals.fromMap(doc.data()!);
      final updated = existing.goals.map((g) {
        if (g.id == goalId && g.progress < g.target) {
          return g.copyWith(progress: g.progress + 1);
        }
        return g;
      }).toList();

      await docRef.update({
        'goals': updated.map((g) => g.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 스탬프 트리거 (fire-and-forget)
      _reportStampActivity('goal_check');
    } catch (e) {
      debugPrint('⚠️ WeeklyGoalService.checkIn error: $e');
    }
  }

  // ─── 스탬프 보조 ───

  /// 파트너 그룹이 있으면 스탬프 활동 보고 (실패해도 무시)
  static Future<void> _reportStampActivity(String activityType) async {
    try {
      final groupId = await UserProfileService.getPartnerGroupId();
      if (groupId == null || groupId.isEmpty) return;
      await WeeklyStampService.reportActivity(
        groupId: groupId,
        activityType: activityType,
      );
    } catch (_) {
      // 스탬프는 보조 기능 — 실패해도 UX 차단 안 함
    }
  }
}


