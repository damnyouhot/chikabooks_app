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
      final existingEnthrone =
          await _db
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
      final enthrone = Enthrone(uid: uid, createdAt: DateTime.now());

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
      final doc =
          await _db
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
      final snapshot =
          await _db
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
      final cutoff = DateTime.now().subtract(const Duration(hours: 12));

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
      final cutoff = DateTime.now().subtract(const Duration(hours: 12));

      final snapshot =
          await _db
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

  /// 전국구 게시판(전광판) 이모지 반응 토글/변경
  ///
  /// 요구사항:
  /// - 한 글당 내 반응은 1개만 가능
  /// - 동일 이모지 다시 누르면 취소
  /// - 취소 후 다른 이모지 가능 (여기서는 바로 변경도 허용: 이전 취소 + 새 반응을 한 번에 처리)
  /// - 본인 글에도 가능
  ///
  /// 데이터:
  /// - billboardPosts/{postId}.reactions.{emoji}: 집계 카운트
  /// - billboardPosts/{postId}/userReactions/{uid}: { emoji: '👏', updatedAt }
  static Future<bool> toggleBillboardReaction({
    required String billboardPostId,
    required String emoji,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      debugPrint('⚠️ toggleBillboardReaction: User not logged in');
      return false;
    }

    try {
      final postRef = _db.collection('billboardPosts').doc(billboardPostId);
      final reactionRef = postRef.collection('userReactions').doc(uid);

      await _db.runTransaction((tx) async {
        final reactionSnap = await tx.get(reactionRef);
        final prevEmoji = reactionSnap.data()?['emoji'] as String?;

        if (prevEmoji != null && prevEmoji.isNotEmpty) {
          // 이전 반응 집계 감소
          tx.update(postRef, {
            'reactions.$prevEmoji': FieldValue.increment(-1),
          });
        }

        if (prevEmoji == emoji) {
          // 동일 이모지 재탭 → 취소
          tx.delete(reactionRef);
          return;
        }

        // 새 반응 설정 + 집계 증가
        tx.set(reactionRef, {
          'uid': uid,
          'emoji': emoji,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.update(postRef, {'reactions.$emoji': FieldValue.increment(1)});
      });

      return true;
    } catch (e) {
      debugPrint('⚠️ toggleBillboardReaction error: $e');
      return false;
    }
  }
}
