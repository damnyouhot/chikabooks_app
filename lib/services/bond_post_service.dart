import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 시간대 구분
enum TimeSlot {
  morning,  // 06:00 ~ 11:59
  afternoon // 12:00 ~ 23:59
}

/// 오늘을 나누기 게시물 서비스
class BondPostService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static CollectionReference<Map<String, dynamic>> get _postsRef =>
      _db.collection('bondPosts');

  /// KST 기준 오늘 dateKey (YYYY-MM-DD)
  static String todayDateKey() {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    return '${kst.year}-${kst.month.toString().padLeft(2, '0')}-${kst.day.toString().padLeft(2, '0')}';
  }

  /// 현재 시간대 확인 (KST 기준)
  static TimeSlot getCurrentTimeSlot() {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    return kst.hour < 12 ? TimeSlot.morning : TimeSlot.afternoon;
  }

  /// 오늘 특정 시간대의 게시물 수 확인
  static Future<int> getTodayPostCountByTimeSlot({
    required String uid,
    required TimeSlot timeSlot,
  }) async {
    try {
      final dateKey = todayDateKey();
      
      final snap = await _postsRef
          .where('uid', isEqualTo: uid)
          .where('dateKey', isEqualTo: dateKey)
          .where('timeSlot', isEqualTo: timeSlot.name)
          .get();
      
      return snap.docs.length;
    } catch (e) {
      debugPrint('⚠️ getTodayPostCountByTimeSlot error: $e');
      return 0;
    }
  }

  /// 오늘 전체 게시물 수 확인
  static Future<int> getTodayPostCount(String uid) async {
    try {
      final dateKey = todayDateKey();
      
      // dateKey를 기준으로 조회 (서버 타임스탬프 문제 회피)
      final snap = await _postsRef
          .where('uid', isEqualTo: uid)
          .where('dateKey', isEqualTo: dateKey)
          .get();
      
      return snap.docs.length;
    } catch (e) {
      debugPrint('⚠️ getTodayPostCount error: $e');
      return 0;
    }
  }

  /// 현재 시간대에 게시 가능 여부 확인
  static Future<bool> canPostNow() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    
    // 새벽 시간(00:00 ~ 05:59)에는 게시 불가
    if (kst.hour < 6) {
      return false;
    }

    final currentSlot = getCurrentTimeSlot();
    final count = await getTodayPostCountByTimeSlot(
      uid: uid,
      timeSlot: currentSlot,
    );
    
    return count < 1; // 각 시간대 1회만
  }

  /// 오늘 게시 가능 여부 확인 (하루 2번 제한)
  static Future<bool> canPostToday() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    
    final count = await getTodayPostCount(uid);
    return count < 2;
  }

  /// 현재 시간대의 남은 게시 횟수와 다음 시간대 정보
  static Future<Map<String, dynamic>> getPostingStatus() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return {
        'canPostNow': false,
        'remainingToday': 0,
        'currentSlot': TimeSlot.morning,
        'message': '로그인이 필요합니다.',
      };
    }

    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    
    // 새벽 시간 체크
    if (kst.hour < 6) {
      return {
        'canPostNow': false,
        'remainingToday': 2,
        'currentSlot': TimeSlot.morning,
        'message': '아침 6시 이후에 작성할 수 있어요.',
      };
    }

    final currentSlot = getCurrentTimeSlot();
    final currentSlotCount = await getTodayPostCountByTimeSlot(
      uid: uid,
      timeSlot: currentSlot,
    );
    final totalCount = await getTodayPostCount(uid);

    if (totalCount >= 2) {
      return {
        'canPostNow': false,
        'remainingToday': 0,
        'currentSlot': currentSlot,
        'message': '오늘은 이미 2번 나눴어요. 내일 다시 만나요 😊',
      };
    }

    if (currentSlotCount >= 1) {
      if (currentSlot == TimeSlot.morning) {
        return {
          'canPostNow': false,
          'remainingToday': 1,
          'currentSlot': currentSlot,
          'message': '낮 12시 이후에 한 번 더 나눌 수 있어요.',
        };
      } else {
        return {
          'canPostNow': false,
          'remainingToday': 0,
          'currentSlot': currentSlot,
          'message': '오늘은 이미 2번 나눴어요. 내일 다시 만나요 😊',
        };
      }
    }

    return {
      'canPostNow': true,
      'remainingToday': 2 - totalCount,
      'currentSlot': currentSlot,
      'message': currentSlot == TimeSlot.morning 
          ? '오늘 첫 번째 나누기예요 ☀️'
          : '오늘 두 번째 나누기예요 🌙',
    };
  }

  /// 오늘 남은 게시 횟수
  static Future<int> getRemainingPostsToday() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 0;
    
    final count = await getTodayPostCount(uid);
    return (2 - count).clamp(0, 2);
  }
}
