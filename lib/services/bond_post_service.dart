import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 시간대 구분
enum TimeSlot {
  dawn, // 00:00 ~ 05:59
  morning, // 06:00 ~ 11:59
  afternoon, // 12:00 ~ 17:59
  evening, // 18:00 ~ 23:59
}

/// 오늘을 나누기 게시물 서비스 (파트너 그룹 기반)
class BondPostService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// 파트너 그룹의 posts 컬렉션 참조
  static CollectionReference<Map<String, dynamic>> _groupPostsRef(
    String groupId,
  ) => _db.collection('partnerGroups').doc(groupId).collection('posts');

  /// KST 기준 오늘 dateKey (YYYY-MM-DD)
  static String todayDateKey() {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    return '${kst.year}-${kst.month.toString().padLeft(2, '0')}-${kst.day.toString().padLeft(2, '0')}';
  }

  /// 현재 시간대 확인 (KST 기준)
  static TimeSlot getCurrentTimeSlot() {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    final h = kst.hour;
    if (h < 6) return TimeSlot.dawn;
    if (h < 12) return TimeSlot.morning;
    if (h < 18) return TimeSlot.afternoon;
    return TimeSlot.evening;
  }

  /// 오늘 특정 시간대의 게시물 수 확인
  static Future<int> getTodayPostCountByTimeSlot({
    required String uid,
    required String groupId,
    required TimeSlot timeSlot,
  }) async {
    try {
      final dateKey = todayDateKey();

      debugPrint('🔍 [쿨타임] 조회 경로: partnerGroups/$groupId/posts');
      debugPrint(
        '🔍 [쿨타임] uid: $uid, dateKey: $dateKey, timeSlot: ${timeSlot.name}',
      );

      final snap =
          await _groupPostsRef(groupId)
              .where('uid', isEqualTo: uid)
              .where('dateKey', isEqualTo: dateKey)
              .where('timeSlot', isEqualTo: timeSlot.name)
              .where('isDeleted', isEqualTo: false)
              .get();

      debugPrint('🔍 [쿨타임] 조회 결과: ${snap.docs.length}건');

      // ✅ 실제 데이터 출력
      if (snap.docs.isNotEmpty) {
        for (var doc in snap.docs) {
          final data = doc.data();
          final text = data['text'] as String? ?? '';
          final preview =
              text.length > 20 ? '${text.substring(0, 20)}...' : text;
          debugPrint('  - 문서ID: ${doc.id}');
          debugPrint('    내용: $preview');
          debugPrint('    작성시간: ${data['createdAt']}');
        }
      }

      return snap.docs.length;
    } catch (e) {
      debugPrint('⚠️ getTodayPostCountByTimeSlot error: $e');
      return 0;
    }
  }

  /// 오늘 전체 게시물 수 확인
  static Future<int> getTodayPostCount(String uid, String groupId) async {
    try {
      final dateKey = todayDateKey();

      debugPrint('🔍 [쿨타임] 조회 경로: partnerGroups/$groupId/posts');
      debugPrint('🔍 [쿨타임] uid: $uid, dateKey: $dateKey');

      // dateKey를 기준으로 조회 (서버 타임스탬프 문제 회피)
      final snap =
          await _groupPostsRef(groupId)
              .where('uid', isEqualTo: uid)
              .where('dateKey', isEqualTo: dateKey)
              .where('isDeleted', isEqualTo: false)
              .get();

      debugPrint('🔍 [쿨타임] 조회 결과: ${snap.docs.length}건');

      // ✅ 실제 데이터 출력
      if (snap.docs.isNotEmpty) {
        for (var doc in snap.docs) {
          final data = doc.data();
          final text = data['text'] as String? ?? '';
          final preview =
              text.length > 20 ? '${text.substring(0, 20)}...' : text;
          debugPrint('  - 문서ID: ${doc.id}');
          debugPrint('    내용: $preview');
          debugPrint('    시간대: ${data['timeSlot']}');
        }
      }

      return snap.docs.length;
    } catch (e) {
      debugPrint('⚠️ getTodayPostCount error: $e');
      return 0;
    }
  }

  /// 현재 시간대에 게시 가능 여부 확인
  static Future<bool> canPostNow(String groupId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    // 6시간 슬롯 제한 제거: 하루 4회 제한만 적용
    return canPostToday(groupId);
  }

  /// 오늘 게시 가능 여부 확인 (하루 4번 제한)
  static Future<bool> canPostToday(String groupId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    final count = await getTodayPostCount(uid, groupId);
    return count < 4;
  }

  /// 현재 시간대의 남은 게시 횟수와 다음 시간대 정보
  static Future<Map<String, dynamic>> getPostingStatus(String groupId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return {
        'canPostNow': false,
        'remainingToday': 0,
        'currentSlot': TimeSlot.morning,
        'message': '로그인이 필요합니다.',
      };
    }

    final totalCount = await getTodayPostCount(uid, groupId);

    if (totalCount >= 4) {
      debugPrint('❌ [쿨타임] 오늘 4번 모두 작성 완료');
      return {
        'canPostNow': false,
        'remainingToday': 0,
        'currentSlot': getCurrentTimeSlot(),
        'message': '오늘은 이미 4번 나눴어요. 내일 다시 만나요 😊',
      };
    }

    debugPrint('✅ [쿨타임] 작성 가능!');
    return {
      'canPostNow': true,
      'remainingToday': 4 - totalCount,
      'currentSlot': getCurrentTimeSlot(),
      'message': '오늘 ${totalCount + 1}번째 나누기예요 ✨',
    };
  }

  /// 오늘 남은 게시 횟수
  static Future<int> getRemainingPostsToday(String groupId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 0;

    final count = await getTodayPostCount(uid, groupId);
    return (4 - count).clamp(0, 4);
  }
}
