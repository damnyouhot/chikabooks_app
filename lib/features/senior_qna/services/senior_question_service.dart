import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../services/user_profile_service.dart';
import '../../../services/caring_treat_service.dart';
import '../../../services/admin_activity_service.dart';
import '../data/senior_stickers.dart';
import '../models/senior_question.dart';
import 'senior_question_image_service.dart';

class SeniorQuestionService {
  SeniorQuestionService._();

  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static const _collection = 'seniorQuestions';
  static const int reportHideThreshold = 5;
  static const int maxBodyLength = 3000;
  static const int maxCommentLength = 500;
  static const int maxStickerCount = maxSeniorStickersPerEntry;
  static const int maxNicknameLength = 30;
  static const List<String> categories = ['관계', '커리어', '마음', '기타'];

  static CollectionReference<Map<String, dynamic>> get _questions =>
      _db.collection(_collection);

  static Stream<List<SeniorQuestion>> watchQuestions() {
    return _questions
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map(SeniorQuestion.fromDoc)
                  .where((question) => !question.isDeleted)
                  .toList(),
        );
  }

  static Future<String?> createQuestion({
    required String body,
    required String category,
    required bool isAnonymous,
    List<XFile> images = const [],
    String? stickerId,
    List<String> stickerIds = const [],
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final trimmed = body.trim();
    if (trimmed.isEmpty || trimmed.length > maxBodyLength) return null;
    if (!categories.contains(category)) return null;
    final normalizedStickerIds = _normalizeStickerIds([
      ...stickerIds,
      if (stickerId != null) stickerId,
    ]);
    final normalizedStickerId =
        normalizedStickerIds.isEmpty ? null : normalizedStickerIds.first;

    try {
      final docRef = _questions.doc();
      final nickname = await _nicknameForWrite(isAnonymous);
      final imageUrls = await SeniorQuestionImageService.uploadAll(
        questionId: docRef.id,
        files: images,
      );

      await docRef.set({
        'uid': uid,
        'authorNickname': nickname,
        'category': _normalizeCategory(category),
        'isAnonymous': isAnonymous,
        'body': trimmed,
        'imageUrls': imageUrls,
        'stickerId': normalizedStickerId,
        'stickerIds': normalizedStickerIds,
        'likeCount': 0,
        'cheerCount': 0,
        'commentCount': 0,
        'reportCount': 0,
        'isHidden': false,
        'isDeleted': false,
        'hiddenReason': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': null,
      });
      await CaringTreatService.tryGrantWhisperWrite(
        contentType: 'question',
        contentId: docRef.id,
      );
      AdminActivityService.log(
        ActivityEventType.whisperCreateComplete,
        page: 'bond_whisper',
        targetId: docRef.id,
        extra: {
          'whisperCategory': _normalizeCategory(category),
          'hasImage': imageUrls.isNotEmpty,
          'hasSticker': normalizedStickerIds.isNotEmpty,
          'stickerCount': normalizedStickerIds.length,
          'isAnonymous': isAnonymous,
        },
      );
      return docRef.id;
    } catch (e) {
      debugPrint('⚠️ SeniorQuestionService.createQuestion: $e');
      return null;
    }
  }

  static Future<bool> updateQuestion({
    required String questionId,
    required String body,
    required String category,
    required bool isAnonymous,
    bool removeImages = false,
    XFile? replacementImage,
    String? stickerId,
    List<String> stickerIds = const [],
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    final trimmed = body.trim();
    if (trimmed.isEmpty || trimmed.length > maxBodyLength) return false;
    if (!categories.contains(category)) return false;
    final normalizedStickerIds = _normalizeStickerIds([
      ...stickerIds,
      if (stickerId != null) stickerId,
    ]);
    final normalizedStickerId =
        normalizedStickerIds.isEmpty ? null : normalizedStickerIds.first;

    try {
      final ref = _questions.doc(questionId);
      final snap = await ref.get();
      final data = snap.data();
      if (data == null || data['uid'] != uid) return false;

      final updateData = <String, dynamic>{
        'body': trimmed,
        'category': _normalizeCategory(category),
        'isAnonymous': isAnonymous,
        'authorNickname': await _nicknameForWrite(isAnonymous),
        'stickerId': normalizedStickerId,
        'stickerIds': normalizedStickerIds,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (replacementImage != null) {
        final imageUrl =
            await SeniorQuestionImageService.uploadQuestionReplacementImage(
              questionId: questionId,
              file: replacementImage,
            );
        if (imageUrl == null) return false;
        updateData['imageUrls'] = [imageUrl];
      } else if (removeImages) {
        updateData['imageUrls'] = <String>[];
      }

      await ref.update(updateData);
      return true;
    } catch (e) {
      debugPrint('⚠️ SeniorQuestionService.updateQuestion: $e');
      return false;
    }
  }

  static Future<bool> deleteQuestion(String questionId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    try {
      final ref = _questions.doc(questionId);
      final snap = await ref.get();
      final data = snap.data();
      if (data == null || data['uid'] != uid) return false;

      await ref.update({
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await CaringTreatService.revokeWhisperWrite(
        contentType: 'question',
        contentId: questionId,
      );
      return true;
    } catch (e) {
      debugPrint('⚠️ SeniorQuestionService.deleteQuestion: $e');
      return false;
    }
  }

  static Future<bool> toggleQuestionReaction({
    required String questionId,
    required String type,
  }) async {
    final field = type == 'cheers' ? 'cheerCount' : 'likeCount';
    final r = await _toggleReaction(
      targetRef: _questions.doc(questionId),
      reactionCollection: type,
      countField: field,
    );
    if (r.success) {
      final suffix = type == 'cheers' ? 'cheer' : 'like';
      final grantKey = 'q_${questionId}_$suffix';
      if (!r.reactionAdded) {
        await CaringTreatService.revokeWhisperReaction(grantKey: grantKey);
        return r.success;
      }
      await CaringTreatService.tryGrantWhisperReaction(grantKey: grantKey);
      AdminActivityService.log(
        ActivityEventType.whisperReaction,
        page: 'bond_whisper',
        targetId: questionId,
        extra: {
          'reactionTarget': 'question',
          'reactionType': type == 'cheers' ? 'cheer' : 'like',
        },
      );
    }
    return r.success;
  }

  static Stream<bool> watchQuestionReactionSelected({
    required String questionId,
    required String type,
  }) {
    return _watchReactionSelected(_questions.doc(questionId).collection(type));
  }

  static Stream<List<SeniorComment>> watchComments(String questionId) {
    return _questions
        .doc(questionId)
        .collection('comments')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map(SeniorComment.fromDoc)
                  .where((comment) => !comment.isDeleted)
                  .toList(),
        );
  }

  static Future<List<SeniorComment>> fetchSharePreviewComments(
    String questionId, {
    int limit = 2,
  }) async {
    try {
      final snap =
          await _questions
              .doc(questionId)
              .collection('comments')
              .orderBy('createdAt')
              .limit(12)
              .get();
      return snap.docs
          .map(SeniorComment.fromDoc)
          .where((comment) => !comment.isDeleted && !comment.isHidden)
          .take(limit)
          .toList(growable: false);
    } catch (e) {
      debugPrint('⚠️ SeniorQuestionService.fetchSharePreviewComments: $e');
      return const [];
    }
  }

  static Future<bool> addComment({
    required String questionId,
    required String body,
    required bool isAnonymous,
    XFile? image,
    String? stickerId,
    List<String> stickerIds = const [],
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    final trimmed = body.trim();
    if (trimmed.length > maxCommentLength) return false;
    final normalizedStickerIds = _normalizeStickerIds([
      ...stickerIds,
      if (stickerId != null) stickerId,
    ]);
    if (trimmed.isEmpty && image == null && normalizedStickerIds.isEmpty) {
      return false;
    }

    try {
      final questionRef = _questions.doc(questionId);
      final commentRef = questionRef.collection('comments').doc();
      final nickname = await _nicknameForWrite(isAnonymous);
      final imageUrl =
          image == null
              ? null
              : await SeniorQuestionImageService.uploadCommentImage(
                questionId: questionId,
                commentId: commentRef.id,
                file: image,
              );
      if (trimmed.isEmpty && imageUrl == null && normalizedStickerIds.isEmpty) {
        return false;
      }
      final storedBody = _bodyForStorage(trimmed, normalizedStickerIds);
      final batch = _db.batch();
      batch.set(
        commentRef,
        _commentMap(
          uid,
          nickname,
          isAnonymous,
          storedBody,
          imageUrl == null ? const [] : [imageUrl],
          normalizedStickerIds,
        ),
      );
      batch.update(questionRef, {'commentCount': FieldValue.increment(1)});
      await batch.commit();
      await CaringTreatService.tryGrantWhisperWrite(
        contentType: 'comment',
        contentId: commentRef.id,
      );
      AdminActivityService.log(
        ActivityEventType.whisperComment,
        page: 'bond_whisper',
        targetId: questionId,
        extra: {
          'commentId': commentRef.id,
          'hasImage': imageUrl != null,
          'hasSticker': normalizedStickerIds.isNotEmpty,
          'stickerCount': normalizedStickerIds.length,
          'isAnonymous': isAnonymous,
        },
      );
      return true;
    } catch (e) {
      debugPrint('⚠️ SeniorQuestionService.addComment: $e');
      return false;
    }
  }

  static Future<bool> toggleCommentLike({
    required String questionId,
    required String commentId,
  }) async {
    final r = await _toggleReaction(
      targetRef: _questions
          .doc(questionId)
          .collection('comments')
          .doc(commentId),
      reactionCollection: 'likes',
      countField: 'likeCount',
    );
    if (r.success) {
      final grantKey = 'c_${questionId}_${commentId}_like';
      if (!r.reactionAdded) {
        await CaringTreatService.revokeWhisperReaction(grantKey: grantKey);
        return r.success;
      }
      await CaringTreatService.tryGrantWhisperReaction(grantKey: grantKey);
      AdminActivityService.log(
        ActivityEventType.whisperReaction,
        page: 'bond_whisper',
        targetId: questionId,
        extra: {
          'reactionTarget': 'comment',
          'commentId': commentId,
          'reactionType': 'like',
        },
      );
    }
    return r.success;
  }

  static Stream<bool> watchCommentLikeSelected({
    required String questionId,
    required String commentId,
  }) {
    return _watchReactionSelected(
      _questions
          .doc(questionId)
          .collection('comments')
          .doc(commentId)
          .collection('likes'),
    );
  }

  static Stream<List<SeniorReply>> watchReplies({
    required String questionId,
    required String commentId,
  }) {
    return _questions
        .doc(questionId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map(SeniorReply.fromDoc)
                  .where((reply) => !reply.isDeleted)
                  .toList(),
        );
  }

  static Future<bool> addReply({
    required String questionId,
    required String commentId,
    required String body,
    required bool isAnonymous,
    XFile? image,
    String? stickerId,
    List<String> stickerIds = const [],
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    final trimmed = body.trim();
    if (trimmed.length > maxCommentLength) return false;
    final normalizedStickerIds = _normalizeStickerIds([
      ...stickerIds,
      if (stickerId != null) stickerId,
    ]);
    if (trimmed.isEmpty && image == null && normalizedStickerIds.isEmpty) {
      return false;
    }

    try {
      final commentRef = _questions
          .doc(questionId)
          .collection('comments')
          .doc(commentId);
      final replyRef = commentRef.collection('replies').doc();
      final nickname = await _nicknameForWrite(isAnonymous);
      final imageUrl =
          image == null
              ? null
              : await SeniorQuestionImageService.uploadReplyImage(
                questionId: questionId,
                commentId: commentId,
                replyId: replyRef.id,
                file: image,
              );
      if (trimmed.isEmpty && imageUrl == null && normalizedStickerIds.isEmpty) {
        return false;
      }
      final storedBody = _bodyForStorage(trimmed, normalizedStickerIds);
      final batch = _db.batch();
      batch.set(
        replyRef,
        _replyMap(
          uid,
          nickname,
          isAnonymous,
          storedBody,
          imageUrl == null ? const [] : [imageUrl],
          normalizedStickerIds,
        ),
      );
      batch.update(commentRef, {'replyCount': FieldValue.increment(1)});
      await batch.commit();
      await CaringTreatService.tryGrantWhisperWrite(
        contentType: 'reply',
        contentId: replyRef.id,
      );
      AdminActivityService.log(
        ActivityEventType.whisperReply,
        page: 'bond_whisper',
        targetId: questionId,
        extra: {
          'commentId': commentId,
          'replyId': replyRef.id,
          'hasImage': imageUrl != null,
          'hasSticker': normalizedStickerIds.isNotEmpty,
          'stickerCount': normalizedStickerIds.length,
          'isAnonymous': isAnonymous,
        },
      );
      return true;
    } catch (e) {
      debugPrint('⚠️ SeniorQuestionService.addReply: $e');
      return false;
    }
  }

  static Future<bool> toggleReplyLike({
    required String questionId,
    required String commentId,
    required String replyId,
  }) async {
    final replyRef = _questions
        .doc(questionId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .doc(replyId);
    final r = await _toggleReaction(
      targetRef: replyRef,
      reactionCollection: 'likes',
      countField: 'likeCount',
    );
    if (r.success) {
      final grantKey = 'r_${questionId}_${commentId}_${replyId}_like';
      if (!r.reactionAdded) {
        await CaringTreatService.revokeWhisperReaction(grantKey: grantKey);
        return r.success;
      }
      await CaringTreatService.tryGrantWhisperReaction(grantKey: grantKey);
      AdminActivityService.log(
        ActivityEventType.whisperReaction,
        page: 'bond_whisper',
        targetId: questionId,
        extra: {
          'reactionTarget': 'reply',
          'commentId': commentId,
          'replyId': replyId,
          'reactionType': 'like',
        },
      );
    }
    return r.success;
  }

  static Stream<bool> watchReplyLikeSelected({
    required String questionId,
    required String commentId,
    required String replyId,
  }) {
    return _watchReactionSelected(
      _questions
          .doc(questionId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .doc(replyId)
          .collection('likes'),
    );
  }

  static Future<bool> reportQuestion(String questionId) {
    return _reportDocument(_questions.doc(questionId));
  }

  static Future<bool> reportComment({
    required String questionId,
    required String commentId,
  }) {
    return _reportDocument(
      _questions.doc(questionId).collection('comments').doc(commentId),
    );
  }

  static Future<bool> reportReply({
    required String questionId,
    required String commentId,
    required String replyId,
  }) {
    return _reportDocument(
      _questions
          .doc(questionId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .doc(replyId),
    );
  }

  static Future<bool> deleteReply({
    required String questionId,
    required String commentId,
    required String replyId,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    try {
      final commentRef = _questions
          .doc(questionId)
          .collection('comments')
          .doc(commentId);
      final ref = commentRef.collection('replies').doc(replyId);
      final snap = await ref.get();
      final data = snap.data();
      if (data == null || data['uid'] != uid) return false;
      if (data['isDeleted'] == true) return true;

      final batch = _db.batch();
      batch.update(ref, {
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.update(commentRef, {'replyCount': FieldValue.increment(-1)});
      await batch.commit();
      await CaringTreatService.revokeWhisperWrite(
        contentType: 'reply',
        contentId: replyId,
      );
      return true;
    } catch (e) {
      debugPrint('⚠️ SeniorQuestionService.deleteReply: $e');
      return false;
    }
  }

  static Future<bool> restoreDocument(DocumentReference ref) async {
    try {
      if (!await UserProfileService.isAdmin()) return false;
      await ref.update({
        'isHidden': false,
        'hiddenReason': null,
        'restoredAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('⚠️ SeniorQuestionService.restoreDocument: $e');
      return false;
    }
  }

  static DocumentReference<Map<String, dynamic>> questionRef(String id) =>
      _questions.doc(id);

  static DocumentReference<Map<String, dynamic>> commentRef(
    String questionId,
    String commentId,
  ) => _questions.doc(questionId).collection('comments').doc(commentId);

  static DocumentReference<Map<String, dynamic>> replyRef(
    String questionId,
    String commentId,
    String replyId,
  ) => commentRef(questionId, commentId).collection('replies').doc(replyId);

  static Future<String> _nicknameForWrite(bool isAnonymous) async {
    if (isAnonymous) return '';
    final profile = await UserProfileService.getMyProfile();
    var nickname = profile?.nickname.trim() ?? '';
    if (nickname.length > maxNicknameLength) {
      nickname = nickname.substring(0, maxNicknameLength);
    }
    return nickname;
  }

  static String _normalizeCategory(String raw) {
    return categories.contains(raw) ? raw : categories.first;
  }

  static String? _normalizeStickerId(String? raw) {
    final v = raw?.trim();
    if (v == null || v.isEmpty) return null;
    return v.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  static List<String> _normalizeStickerIds(List<String> rawIds) {
    final ids = <String>[];
    for (final raw in rawIds) {
      final normalized = _normalizeStickerId(raw);
      if (normalized == null) continue;
      ids.add(normalized);
      if (ids.length >= maxStickerCount) break;
    }
    return ids;
  }

  static String _bodyForStorage(String trimmed, List<String> stickerIds) {
    if (trimmed.isNotEmpty || stickerIds.isEmpty) return trimmed;
    return seniorStickerFallbackBodyForIds(stickerIds);
  }

  static Map<String, dynamic> _commentMap(
    String uid,
    String nickname,
    bool isAnonymous,
    String body,
    List<String> imageUrls,
    List<String> stickerIds,
  ) => {
    'uid': uid,
    'authorNickname': nickname,
    'isAnonymous': isAnonymous,
    'body': body,
    'imageUrls': imageUrls,
    'stickerId': stickerIds.isEmpty ? null : stickerIds.first,
    'stickerIds': stickerIds,
    'likeCount': 0,
    'replyCount': 0,
    'reportCount': 0,
    'isHidden': false,
    'isDeleted': false,
    'hiddenReason': null,
    'createdAt': FieldValue.serverTimestamp(),
  };

  static Future<bool> updateComment({
    required String questionId,
    required String commentId,
    required String body,
    required bool isAnonymous,
    bool removeImages = false,
    XFile? replacementImage,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    final trimmed = body.trim();
    if (trimmed.length > maxCommentLength) return false;

    try {
      final ref = commentRef(questionId, commentId);
      final snap = await ref.get();
      final data = snap.data();
      if (data == null || data['uid'] != uid) return false;
      final existingImageUrls = List<String>.from(
        data['imageUrls'] as List? ?? const [],
      );
      final willHaveImage =
          replacementImage != null ||
          (!removeImages && existingImageUrls.isNotEmpty);
      if (trimmed.isEmpty && !willHaveImage) return false;

      final updateData = <String, dynamic>{
        'body': trimmed,
        'isAnonymous': isAnonymous,
        'authorNickname': await _nicknameForWrite(isAnonymous),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (replacementImage != null) {
        final imageUrl = await SeniorQuestionImageService.uploadCommentImage(
          questionId: questionId,
          commentId: commentId,
          file: replacementImage,
        );
        if (imageUrl == null) return false;
        updateData['imageUrls'] = [imageUrl];
      } else if (removeImages) {
        updateData['imageUrls'] = <String>[];
      }

      await ref.update(updateData);
      return true;
    } catch (e) {
      debugPrint('⚠️ SeniorQuestionService.updateComment: $e');
      return false;
    }
  }

  static Future<bool> deleteComment({
    required String questionId,
    required String commentId,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    try {
      final questionRef = _questions.doc(questionId);
      final ref = commentRef(questionId, commentId);
      final snap = await ref.get();
      final data = snap.data();
      if (data == null || data['uid'] != uid) return false;
      if (data['isDeleted'] == true) return true;

      final batch = _db.batch();
      batch.update(ref, {
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.update(questionRef, {'commentCount': FieldValue.increment(-1)});
      await batch.commit();
      await CaringTreatService.revokeWhisperWrite(
        contentType: 'comment',
        contentId: commentId,
      );
      return true;
    } catch (e) {
      debugPrint('⚠️ SeniorQuestionService.deleteComment: $e');
      return false;
    }
  }

  static Map<String, dynamic> _replyMap(
    String uid,
    String nickname,
    bool isAnonymous,
    String body,
    List<String> imageUrls,
    List<String> stickerIds,
  ) => {
    'uid': uid,
    'authorNickname': nickname,
    'isAnonymous': isAnonymous,
    'body': body,
    'imageUrls': imageUrls,
    'stickerId': stickerIds.isEmpty ? null : stickerIds.first,
    'stickerIds': stickerIds,
    'likeCount': 0,
    'reportCount': 0,
    'isHidden': false,
    'isDeleted': false,
    'hiddenReason': null,
    'createdAt': FieldValue.serverTimestamp(),
  };

  static Future<({bool success, bool reactionAdded})> _toggleReaction({
    required DocumentReference<Map<String, dynamic>> targetRef,
    required String reactionCollection,
    required String countField,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return (success: false, reactionAdded: false);
    try {
      final reactionRef = targetRef.collection(reactionCollection).doc(uid);
      var reactionAdded = false;
      await _db.runTransaction((tx) async {
        final reactionSnap = await tx.get(reactionRef);
        if (reactionSnap.exists) {
          tx.delete(reactionRef);
          tx.update(targetRef, {countField: FieldValue.increment(-1)});
          reactionAdded = false;
        } else {
          tx.set(reactionRef, {
            'uid': uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
          tx.update(targetRef, {countField: FieldValue.increment(1)});
          reactionAdded = true;
        }
      });
      return (success: true, reactionAdded: reactionAdded);
    } catch (e) {
      debugPrint('⚠️ SeniorQuestionService._toggleReaction: $e');
      return (success: false, reactionAdded: false);
    }
  }

  static Stream<bool> _watchReactionSelected(
    CollectionReference<Map<String, dynamic>> reactionCollection,
  ) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(false);
    return reactionCollection.doc(uid).snapshots().map((snap) => snap.exists);
  }

  static Future<bool> _reportDocument(
    DocumentReference<Map<String, dynamic>> targetRef,
  ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    try {
      final reportRef = targetRef.collection('reports').doc(uid);
      return await _db.runTransaction((tx) async {
        final reportSnap = await tx.get(reportRef);
        if (reportSnap.exists) return false;
        final targetSnap = await tx.get(targetRef);
        if (!targetSnap.exists) return false;
        final currentCount = targetSnap.data()?['reportCount'] as int? ?? 0;
        final nextCount = currentCount + 1;
        tx.set(reportRef, {
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.update(targetRef, {
          'reportCount': FieldValue.increment(1),
          'lastReportedAt': FieldValue.serverTimestamp(),
          if (nextCount >= reportHideThreshold) ...{
            'isHidden': true,
            'hiddenReason': 'auto_hide_by_reports',
            'hiddenAt': FieldValue.serverTimestamp(),
          },
        });
        return true;
      });
    } catch (e) {
      debugPrint('⚠️ SeniorQuestionService._reportDocument: $e');
      return false;
    }
  }
}
