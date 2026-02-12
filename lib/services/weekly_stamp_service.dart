import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/weekly_stamp.dart';
import 'weekly_goal_service.dart';

/// ══════════════════════════════════════════════════
/// 이번 주 작은 기념 스탬프 서비스
/// ══════════════════════════════════════════════════
///
/// Firestore:
///   partnerGroups/{groupId}/weeklyStamps/{weekKey}
///   partnerGroups/{groupId}/weeklyStamps/{weekKey}/daily/{dateKey}
///
/// 읽기는 Flutter에서, 쓰기는 Cloud Function에서만.
class WeeklyStampService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ─── weekKey / dateKey 유틸 (기존 서비스 재사용) ───

  /// ISO 주차 키 (WeeklyGoalService와 동일)
  static String currentWeekKey() => WeeklyGoalService.currentWeekKey();

  /// KST 기준 오늘 dateKey "2026-02-13"
  static String todayDateKey() {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    return '${kst.year}-'
        '${kst.month.toString().padLeft(2, '0')}-'
        '${kst.day.toString().padLeft(2, '0')}';
  }

  /// KST 기준 오늘 요일 인덱스 (0=월 ~ 6=일)
  static int todayDayOfWeek() {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    return kst.weekday - 1; // DateTime.weekday: 1=월 ~ 7=일
  }

  // ─── 읽기 (Flutter → Firestore) ───

  /// 이번 주 스탬프 상태 1회 읽기
  static Future<WeeklyStampState> getThisWeek(String groupId) async {
    final weekKey = currentWeekKey();
    try {
      final doc = await _db
          .collection('partnerGroups')
          .doc(groupId)
          .collection('weeklyStamps')
          .doc(weekKey)
          .get();

      if (!doc.exists || doc.data() == null) {
        return WeeklyStampState.empty(weekKey);
      }
      return WeeklyStampState.fromMap(doc.data()!);
    } catch (e) {
      debugPrint('⚠️ WeeklyStampService.getThisWeek error: $e');
      return WeeklyStampState.empty(weekKey);
    }
  }

  /// 이번 주 스탬프 실시간 스트림
  static Stream<WeeklyStampState> watchThisWeek(String groupId) {
    final weekKey = currentWeekKey();
    try {
      return _db
          .collection('partnerGroups')
          .doc(groupId)
          .collection('weeklyStamps')
          .doc(weekKey)
          .snapshots()
          .map((snap) {
        if (!snap.exists || snap.data() == null) {
          return WeeklyStampState.empty(weekKey);
        }
        return WeeklyStampState.fromMap(snap.data()!);
      });
    } catch (e) {
      debugPrint('⚠️ WeeklyStampService.watchThisWeek error: $e');
      return Stream.value(WeeklyStampState.empty(weekKey));
    }
  }

  /// 오늘 일별 참여 로그 읽기 (UI에서 "내가 뭘 했는지" 확인용)
  static Future<DailyStampLog?> getTodayLog(String groupId) async {
    final weekKey = currentWeekKey();
    final dateKey = todayDateKey();
    try {
      final doc = await _db
          .collection('partnerGroups')
          .doc(groupId)
          .collection('weeklyStamps')
          .doc(weekKey)
          .collection('daily')
          .doc(dateKey)
          .get();

      if (!doc.exists || doc.data() == null) return null;
      return DailyStampLog.fromMap(doc.data()!);
    } catch (e) {
      debugPrint('⚠️ WeeklyStampService.getTodayLog error: $e');
      return null;
    }
  }

  // ─── 트리거 (Flutter → Cloud Function) ───

  /// 파트너 활동 보고 → Cloud Function이 스탬프 판정
  ///
  /// [activityType]: 'poll_vote' | 'sentence_reaction' | 'goal_check' | 'sentence_write'
  static Future<void> reportActivity({
    required String groupId,
    required String activityType,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-northeast3',
      ).httpsCallable('onPartnerActivityForStamp');

      await callable.call<Map<String, dynamic>>({
        'groupId': groupId,
        'activityType': activityType,
      });

      debugPrint('✅ stamp activity reported: $activityType');
    } catch (e) {
      // 스탬프는 보조 기능이므로 실패해도 UX 차단하지 않음
      debugPrint('⚠️ WeeklyStampService.reportActivity error: $e');
    }
  }
}

