import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/feedback_post.dart';

/// 피드백 서비스
///
/// - feedbacks 컬렉션 CRUD
/// - feedbacks/{id}/comments 서브컬렉션 CRUD
/// - Firebase Storage 이미지 업로드 (feedbacks/{feedbackId}/{idx}.jpg)
class FeedbackService {
  FeedbackService._();

  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static final _storage = FirebaseStorage.instance;

  static const _col = 'feedbacks';

  // ─────────────────────────────────────────────────────────
  // 목록 조회 (Stream)
  // - isAdmin: true  → public + private 모두
  // - isAdmin: false → public만
  // ─────────────────────────────────────────────────────────
  static Stream<List<FeedbackPost>> watchList({bool isAdmin = false}) {
    Query<Map<String, dynamic>> q = _db
        .collection(_col)
        .orderBy('createdAt', descending: true);

    if (!isAdmin) {
      q = q.where('visibility', isEqualTo: 'public');
    }

    return q.snapshots().map(
          (snap) => snap.docs
              .map((d) => FeedbackPost.fromDoc(d))
              .toList(),
        );
  }

  // ─────────────────────────────────────────────────────────
  // 단건 조회 (Stream)
  // ─────────────────────────────────────────────────────────
  static Stream<FeedbackPost?> watchOne(String feedbackId) {
    return _db
        .collection(_col)
        .doc(feedbackId)
        .snapshots()
        .map((doc) => doc.exists ? FeedbackPost.fromDoc(doc) : null);
  }

  // ─────────────────────────────────────────────────────────
  // 피드백 생성
  // ─────────────────────────────────────────────────────────
  static Future<String?> create({
    required FeedbackType type,
    required FeedbackPriority priority,
    required FeedbackVisibility visibility,
    required String text,
    required String displayName,
    required String appVersion,
    required String sourceRoute,
    required String sourceScreenLabel,
    List<XFile> imageFiles = const [],
  }) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      // 1) 빈 문서 먼저 생성해서 ID 확보
      final docRef = _db.collection(_col).doc();
      final feedbackId = docRef.id;

      // 2) 이미지 업로드 (최대 3장)
      final imageUrls = <String>[];
      for (int i = 0; i < imageFiles.take(3).length; i++) {
        final url = await _uploadImage(
          feedbackId: feedbackId,
          index: i,
          file: imageFiles[i],
        );
        if (url != null) imageUrls.add(url);
      }

      // 3) 문서 저장
      final post = FeedbackPost(
        id: feedbackId,
        uid: user.uid,
        authNickname: user.displayName ?? '',
        displayName: displayName.trim(),
        type: type,
        priority: priority,
        visibility: visibility,
        text: text.trim(),
        imageUrls: imageUrls,
        appVersion: appVersion,
        sourceRoute: sourceRoute,
        sourceScreenLabel: sourceScreenLabel,
        adminStatus: FeedbackAdminStatus.pending,
        createdAt: DateTime.now(),
      );

      await docRef.set(post.toMap());
      return feedbackId;
    } catch (e) {
      debugPrint('⚠️ FeedbackService.create error: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────
  // 피드백 수정 (작성자 / 관리자)
  // ─────────────────────────────────────────────────────────
  static Future<bool> updatePost({
    required String feedbackId,
    required String text,
    required FeedbackType type,
    required FeedbackPriority priority,
    required FeedbackVisibility visibility,
  }) async {
    try {
      await _db.collection(_col).doc(feedbackId).update({
        'text': text.trim(),
        'type': type.value,
        'priority': priority.value,
        'visibility': visibility.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('⚠️ FeedbackService.updatePost error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────
  // 피드백 삭제 (작성자 / 관리자)
  // ─────────────────────────────────────────────────────────
  static Future<bool> deletePost(String feedbackId) async {
    try {
      // 댓글 서브컬렉션 일괄 삭제
      final comments = await _db
          .collection(_col)
          .doc(feedbackId)
          .collection('comments')
          .get();
      final batch = _db.batch();
      for (final doc in comments.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_db.collection(_col).doc(feedbackId));
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('⚠️ FeedbackService.deletePost error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────
  // 관리자 상태 업데이트
  // ─────────────────────────────────────────────────────────
  static Future<void> updateAdminStatus(
    String feedbackId,
    FeedbackAdminStatus status,
  ) async {
    await _db.collection(_col).doc(feedbackId).update({
      'adminStatus': status.value,
    });
  }

  // ─────────────────────────────────────────────────────────
  // 댓글 목록 (Stream)
  // ─────────────────────────────────────────────────────────
  static Stream<List<FeedbackComment>> watchComments(String feedbackId) {
    return _db
        .collection(_col)
        .doc(feedbackId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FeedbackComment.fromDoc(d))
            .toList());
  }

  // ─────────────────────────────────────────────────────────
  // 댓글 추가
  // ─────────────────────────────────────────────────────────
  static Future<bool> addComment({
    required String feedbackId,
    required String text,
    required String displayName,
  }) async {
    final user = _auth.currentUser;
    if (user == null || text.trim().isEmpty) return false;

    try {
      final batch = _db.batch();

      final commentRef = _db
          .collection(_col)
          .doc(feedbackId)
          .collection('comments')
          .doc();

      final comment = FeedbackComment(
        id: commentRef.id,
        uid: user.uid,
        authNickname: user.displayName ?? '',
        displayName: displayName.trim(),
        text: text.trim(),
        createdAt: DateTime.now(),
      );

      batch.set(commentRef, comment.toMap());

      // commentCount 증가
      batch.update(
        _db.collection(_col).doc(feedbackId),
        {'commentCount': FieldValue.increment(1)},
      );

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('⚠️ FeedbackService.addComment error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────
  // 댓글 삭제
  // ─────────────────────────────────────────────────────────
  static Future<void> deleteComment(
    String feedbackId,
    String commentId,
  ) async {
    final batch = _db.batch();
    batch.delete(
      _db.collection(_col).doc(feedbackId).collection('comments').doc(commentId),
    );
    batch.update(
      _db.collection(_col).doc(feedbackId),
      {'commentCount': FieldValue.increment(-1)},
    );
    await batch.commit();
  }

  // ─────────────────────────────────────────────────────────
  // 이미지 업로드 (내부)
  // ─────────────────────────────────────────────────────────
  static Future<String?> _uploadImage({
    required String feedbackId,
    required int index,
    required XFile file,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final ref = _storage
          .ref()
          .child('feedbacks/$feedbackId/$index.jpg');

      final metadata = SettableMetadata(contentType: 'image/jpeg');

      if (kIsWeb) {
        await ref.putData(bytes, metadata);
      } else {
        await ref.putData(Uint8List.fromList(bytes), metadata);
      }

      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('⚠️ FeedbackService._uploadImage error: $e');
      return null;
    }
  }
}
