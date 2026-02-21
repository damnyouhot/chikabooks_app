import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/enthrone.dart';

/// 추대 및 전광판 서비스
class EnthroneService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// 게시물에 추대하기
  /// 
  /// [bondGroupId]: 결 그룹 ID
  /// [postId]: 게시물 ID
  static Future<bool> enthronePost({
    required String bondGroupId,
    required String postId,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      debugPrint('⚠️ enthronePost: User not logged in');
      return false;
    }

    try {
      // 중복 추대 방지: 이미 추대했는지 확인
      final existingEnthrone = await _db
          .collection('partnerGroups')
          .doc(bondGroupId)
          .collection('posts')
          .doc(postId)
          .collection('enthrones')
          .doc(uid)
          .get();

      if (existingEnthrone.exists) {
        debugPrint('⚠️ enthronePost: Already enthroned');
        return false; // 이미 추대함
      }

      // 추대 기록 저장
      final enthrone = Enthrone(
        uid: uid,
        createdAt: DateTime.now(),
      );

      await _db
          .collection('partnerGroups')
          .doc(bondGroupId)
          .collection('posts')
          .doc(postId)
          .collection('enthrones')
          .doc(uid)
          .set(enthrone.toMap());

      debugPrint('✅ enthronePost: Success');
      return true;
    } catch (e) {
      debugPrint('⚠️ enthronePost error: $e');
      return false;
    }
  }

  /// 추대 취소하기
  static Future<bool> unenthronePost({
    required String bondGroupId,
    required String postId,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    try {
      await _db
          .collection('partnerGroups')
          .doc(bondGroupId)
          .collection('posts')
          .doc(postId)
          .collection('enthrones')
          .doc(uid)
          .delete();

      debugPrint('✅ unenthronePost: Success');
      return true;
    } catch (e) {
      debugPrint('⚠️ unenthronePost error: $e');
      return false;
    }
  }

  /// 내가 이 게시물을 추대했는지 확인
  static Future<bool> hasEnthroned({
    required String bondGroupId,
    required String postId,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    try {
      final doc = await _db
          .collection('partnerGroups')
          .doc(bondGroupId)
          .collection('posts')
          .doc(postId)
          .collection('enthrones')
          .doc(uid)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('⚠️ hasEnthroned error: $e');
      return false;
    }
  }

  /// 게시물의 추대 수 가져오기
  static Future<int> getEnthroneCount({
    required String bondGroupId,
    required String postId,
  }) async {
    try {
      final snapshot = await _db
          .collection('partnerGroups')
          .doc(bondGroupId)
          .collection('posts')
          .doc(postId)
          .collection('enthrones')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('⚠️ getEnthroneCount error: $e');
      return 0;
    }
  }

  /// 전광판 게시물 스트림 (최근 48시간 내)
  static Stream<List<BillboardPost>> watchActiveBillboard({int limit = 3}) {
    try {
      final cutoff = DateTime.now().subtract(const Duration(hours: 48));
      
      return _db
          .collection('billboardPosts')
          .where('status', isEqualTo: EnthroneStatus.confirmed.name)
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(cutoff))
          .orderBy('expiresAt', descending: false)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snap) {
        return snap.docs
            .map((doc) => BillboardPost.fromDoc(doc))
            .where((post) => post.isActive)
            .toList();
      });
    } catch (e) {
      debugPrint('⚠️ watchActiveBillboard error: $e');
      return Stream.value([]);
    }
  }

  /// 전광판 게시물 가져오기 (1회)
  static Future<List<BillboardPost>> getActiveBillboard({int limit = 3}) async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(hours: 48));
      
      final snapshot = await _db
          .collection('billboardPosts')
          .where('status', isEqualTo: EnthroneStatus.confirmed.name)
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(cutoff))
          .orderBy('expiresAt', descending: false)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => BillboardPost.fromDoc(doc))
          .where((post) => post.isActive)
          .toList();
    } catch (e) {
      debugPrint('⚠️ getActiveBillboard error: $e');
      return [];
    }
  }
}










