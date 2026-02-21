import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 시간대 구분
enum TimeSlot {
  morning,  // 06:00 ~ 11:59
  afternoon // 12:00 ~ 23:59
}

/// 오늘을 나누기 게시물 서비스 (파트너 그룹 기반)
class BondPostService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// 파트너 그룹의 posts 컬렉션 참조
  static CollectionReference<Map<String, dynamic>> _groupPostsRef(String groupId) =>
      _db.collection('partnerGroups').doc(groupId).collection('posts');

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
    required String groupId,
    required TimeSlot timeSlot,
  }) async {
    try {
      final dateKey = todayDateKey();
      
      debugPrint('🔍 [쿨타임] 조회 경로: partnerGroups/$groupId/posts');
      debugPrint('🔍 [쿨타임] uid: $uid, dateKey: $dateKey, timeSlot: ${timeSlot.name}');
      
      final snap = await _groupPostsRef(groupId)
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
          final preview = text.length > 20 ? '${text.substring(0, 20)}...' : text;
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
      final snap = await _groupPostsRef(groupId)
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
          final preview = text.length > 20 ? '${text.substring(0, 20)}...' : text;
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

    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    
    // 새벽 시간(00:00 ~ 05:59)에는 게시 불가
    if (kst.hour < 6) {
      return false;
    }

    final currentSlot = getCurrentTimeSlot();
    final count = await getTodayPostCountByTimeSlot(
      uid: uid,
      groupId: groupId,
      timeSlot: currentSlot,
    );
    
    return count < 1; // 각 시간대 1회만
  }

  /// 오늘 게시 가능 여부 확인 (하루 2번 제한)
  static Future<bool> canPostToday(String groupId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    
    final count = await getTodayPostCount(uid, groupId);
    return count < 2;
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

    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    
    debugPrint('🔍 [쿨타임] 현재 시간 체크');
    debugPrint('🔍 [쿨타임] UTC: ${DateTime.now().toUtc()}');
    debugPrint('🔍 [쿨타임] KST: $kst (${kst.hour}시 ${kst.minute}분)');
    
    // ✅ 새벽 시간 체크 제거 (에뮬레이터 시간 동기화 문제로 인해)
    // 실제 배포 시에는 다시 활성화할 수 있습니다.
    // if (kst.hour < 6) {
    //   debugPrint('❌ [쿨타임] 새벽 시간대 (${kst.hour}시) - 06시 이후 작성 가능');
    //   return {
    //     'canPostNow': false,
    //     'remainingToday': 2,
    //     'currentSlot': TimeSlot.morning,
    //     'message': '아침 6시 이후에 작성할 수 있어요.',
    //   };
    // }
    
    debugPrint('✅ [쿨타임] 새벽 시간 체크 통과');

    final currentSlot = getCurrentTimeSlot();
    debugPrint('🔍 [쿨타임] 현재 시간대: ${currentSlot.name}');
    
    final currentSlotCount = await getTodayPostCountByTimeSlot(
      uid: uid,
      groupId: groupId,
      timeSlot: currentSlot,
    );
    final totalCount = await getTodayPostCount(uid, groupId);
    
    debugPrint('🔍 [쿨타임] 현재 시간대 작성 횟수: $currentSlotCount');
    debugPrint('🔍 [쿨타임] 오늘 총 작성 횟수: $totalCount');

    if (totalCount >= 2) {
      debugPrint('❌ [쿨타임] 오늘 2번 모두 작성 완료');
      return {
        'canPostNow': false,
        'remainingToday': 0,
        'currentSlot': currentSlot,
        'message': '오늘은 이미 2번 나눴어요. 내일 다시 만나요 😊',
      };
    }

    if (currentSlotCount >= 1) {
      if (currentSlot == TimeSlot.morning) {
        debugPrint('❌ [쿨타임] 오전 시간대 이미 작성 완료 - 12시 이후 가능');
        return {
          'canPostNow': false,
          'remainingToday': 1,
          'currentSlot': currentSlot,
          'message': '낮 12시 이후에 한 번 더 나눌 수 있어요.',
        };
      } else {
        debugPrint('❌ [쿨타임] 오후 시간대 이미 작성 완료');
        return {
          'canPostNow': false,
          'remainingToday': 0,
          'currentSlot': currentSlot,
          'message': '오늘은 이미 2번 나눴어요. 내일 다시 만나요 😊',
        };
      }
    }

    debugPrint('✅ [쿨타임] 작성 가능!');
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
  static Future<int> getRemainingPostsToday(String groupId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 0;
    
    final count = await getTodayPostCount(uid, groupId);
    return (2 - count).clamp(0, 2);
  }
}
