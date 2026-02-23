import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// 주간 활동 데이터 집계 서비스
/// - 파트너의 주간 게시물 수
/// - 파트너의 주간 리액션 수
class WeeklyActivityService {
  static final _db = FirebaseFirestore.instance;

  /// 이번 주 시작 시간 계산 (월요일 00:00 KST)
  static DateTime _getThisWeekStartTime() {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    final weekday = kst.weekday; // 1=월, 7=일
    final monday = kst.subtract(Duration(days: weekday - 1));
    final mondayStart = DateTime(monday.year, monday.month, monday.day);
    return mondayStart.subtract(const Duration(hours: 9)); // UTC로 변환
  }

  /// 특정 그룹의 멤버별 주간 게시물 수 조회
  /// Returns: {uid: postCount}
  static Future<Map<String, int>> getWeeklyPostCounts(String groupId) async {
    try {
      final weekStart = _getThisWeekStartTime();
      final weekStartTimestamp = Timestamp.fromDate(weekStart);

      // partnerGroups/{groupId}/posts 컬렉션에서 이번 주 게시물 조회
      final postsSnapshot = await _db
          .collection('partnerGroups')
          .doc(groupId)
          .collection('posts')
          .where('createdAt', isGreaterThanOrEqualTo: weekStartTimestamp)
          .where('isDeleted', isEqualTo: false)
          .get();

      // UID별로 카운트
      final counts = <String, int>{};
      for (final doc in postsSnapshot.docs) {
        final uid = doc.data()['uid'] as String?;
        if (uid != null) {
          counts[uid] = (counts[uid] ?? 0) + 1;
        }
      }

      return counts;
    } catch (e) {
      debugPrint('⚠️ getWeeklyPostCounts error: $e');
      return {};
    }
  }

  /// 특정 그룹의 멤버별 주간 리액션 수 조회
  /// Returns: {uid: reactionCount}
  static Future<Map<String, int>> getWeeklyReactionCounts(String groupId) async {
    try {
      final weekStart = _getThisWeekStartTime();
      final weekStartTimestamp = Timestamp.fromDate(weekStart);

      // 모든 게시물의 리액션 서브컬렉션 조회
      final postsSnapshot = await _db
          .collection('partnerGroups')
          .doc(groupId)
          .collection('posts')
          .where('createdAt', isGreaterThanOrEqualTo: weekStartTimestamp)
          .where('isDeleted', isEqualTo: false)
          .get();

      final counts = <String, int>{};

      // 각 게시물의 리액션 조회
      for (final postDoc in postsSnapshot.docs) {
        try {
          final reactionsSnapshot = await postDoc.reference
              .collection('reactions')
              .get();

          for (final reactionDoc in reactionsSnapshot.docs) {
            final uid = reactionDoc.id; // 리액션 문서 ID = UID
            final updatedAt = reactionDoc.data()['updatedAt'] as Timestamp?;
            
            // 이번 주에 생성/수정된 리액션만 카운트
            if (updatedAt != null && updatedAt.toDate().isAfter(weekStart)) {
              counts[uid] = (counts[uid] ?? 0) + 1;
            }
          }
        } catch (e) {
          debugPrint('⚠️ 리액션 조회 실패 (${postDoc.id}): $e');
        }
      }

      return counts;
    } catch (e) {
      debugPrint('⚠️ getWeeklyReactionCounts error: $e');
      return {};
    }
  }

  /// 특정 그룹의 멤버별 주간 활동 데이터 한 번에 조회
  /// Returns: {
  ///   'posts': {uid: count},
  ///   'reactions': {uid: count}
  /// }
  static Future<Map<String, Map<String, int>>> getWeeklyActivityData(
    String groupId,
  ) async {
    try {
      final postCounts = await getWeeklyPostCounts(groupId);
      final reactionCounts = await getWeeklyReactionCounts(groupId);

      return {
        'posts': postCounts,
        'reactions': reactionCounts,
      };
    } catch (e) {
      debugPrint('⚠️ getWeeklyActivityData error: $e');
      return {
        'posts': {},
        'reactions': {},
      };
    }
  }
}

