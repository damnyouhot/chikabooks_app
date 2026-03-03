import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/hira_update.dart';

/// HIRA 댓글 서비스
class HiraCommentService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// 댓글 추가
  static Future<bool> addComment(String updateId, String text) async {
    try {
      debugPrint('🔍 addComment 시작: updateId=$updateId, text=$text');
      
      final uid = _auth.currentUser?.uid;
      debugPrint('🔍 현재 유저 UID: $uid');
      
      if (uid == null || text.trim().isEmpty) {
        debugPrint('⚠️ UID가 없거나 텍스트가 비어있음');
        return false;
      }

      final commentRef = _db
          .collection('content_hira_updates')
          .doc(updateId)
          .collection('comments')
          .doc();

      debugPrint('🔍 Firestore에 댓글 저장 중...');
      await commentRef.set({
        'uid': uid,
        'userName': '치과인', // 익명 처리
        'text': text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'isDeleted': false,
      });

      debugPrint('🔍 댓글 수 증가 중...');
      // 댓글 수 증가
      await _db
          .collection('content_hira_updates')
          .doc(updateId)
          .update({'commentCount': FieldValue.increment(1)});

      debugPrint('✅ 댓글 추가 완료: ${commentRef.id}');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ HiraCommentService.addComment error: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// 댓글 목록 스트림
  static Stream<List<HiraComment>> watchComments(String updateId) {
    return _db
        .collection('content_hira_updates')
        .doc(updateId)
        .collection('comments')
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => HiraComment.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// 댓글 삭제 (본인만 가능)
  static Future<bool> deleteComment(
      String updateId, String commentId, String commentUid) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null || uid != commentUid) return false;

      await _db
          .collection('content_hira_updates')
          .doc(updateId)
          .collection('comments')
          .doc(commentId)
          .update({'isDeleted': true});

      // 댓글 수 감소
      await _db
          .collection('content_hira_updates')
          .doc(updateId)
          .update({'commentCount': FieldValue.increment(-1)});

      debugPrint('✅ 댓글 삭제 완료: $commentId');
      return true;
    } catch (e) {
      debugPrint('⚠️ HiraCommentService.deleteComment error: $e');
      return false;
    }
  }

  // ── 댓글 이모지 반응 ──

  /// 이모지 반응 토글 (같은 이모지면 삭제, 다른 이모지면 변경)
  static Future<bool> toggleCommentReaction(
    String updateId,
    String commentId,
    String emoji,
  ) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return false;

      final ref = _db
          .collection('content_hira_updates')
          .doc(updateId)
          .collection('comments')
          .doc(commentId)
          .collection('reactions')
          .doc(uid);

      final existing = await ref.get();
      if (existing.exists && existing.data()?['emoji'] == emoji) {
        // 동일 이모지 → 삭제
        await ref.delete();
      } else {
        // 새 이모지 or 변경
        await ref.set({
          'emoji': emoji,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      return true;
    } catch (e) {
      debugPrint('⚠️ toggleCommentReaction error: $e');
      return false;
    }
  }

  /// 댓글 리액션 실시간 스트림 → {emoji: count} 집계 + 내 선택
  static Stream<Map<String, dynamic>> watchCommentReactions(
    String updateId,
    String commentId,
  ) {
    return _db
        .collection('content_hira_updates')
        .doc(updateId)
        .collection('comments')
        .doc(commentId)
        .collection('reactions')
        .snapshots()
        .map((snap) {
      final counts = <String, int>{};
      String? myEmoji;
      final uid = _auth.currentUser?.uid;
      for (final doc in snap.docs) {
        final emoji = doc.data()['emoji'] as String? ?? '';
        counts[emoji] = (counts[emoji] ?? 0) + 1;
        if (doc.id == uid) myEmoji = emoji;
      }
      return {'counts': counts, 'myEmoji': myEmoji};
    });
  }
}

