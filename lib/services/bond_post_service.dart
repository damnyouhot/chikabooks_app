import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 오늘을 나누기 게시물 서비스
class BondPostService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static CollectionReference<Map<String, dynamic>> get _postsRef =>
      _db.collection('bondPosts');

  /// KST 기준 오늘 dateKey
  static String todayDateKey() {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    return '${kst.year}-${kst.month.toString().padLeft(2, '0')}-${kst.day.toString().padLeft(2, '0')}';
  }

  /// 오늘 게시물 수 확인
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

  /// 오늘 게시 가능 여부 확인 (하루 2번 제한)
  static Future<bool> canPostToday() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    
    final count = await getTodayPostCount(uid);
    return count < 2;
  }

  /// 오늘 남은 게시 횟수
  static Future<int> getRemainingPostsToday() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 0;
    
    final count = await getTodayPostCount(uid);
    return (2 - count).clamp(0, 2);
  }
}

