import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/resume_draft.dart';

/// 이력서 편집 임시저장 서비스
///
/// Firestore `resumeDrafts/{draftId}` 컬렉션에 편집 중인 이력서 데이터를 저장.
/// - 자동 저장 (30초 간격 / 섹션 변경 시)
/// - 수동 저장 (사용자 요청)
/// - 이력서 확정 저장 시 드래프트 삭제
class ResumeDraftService {
  static final _db = FirebaseFirestore.instance;
  static const _collection = 'resumeDrafts';

  /// 현재 사용자의 드래프트 목록 조회
  static Stream<List<ResumeDraft>> watchMyDrafts() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _db
        .collection(_collection)
        .where('ownerUid', isEqualTo: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ResumeDraft.fromDoc(d)).toList());
  }

  /// 특정 드래프트 조회
  static Future<ResumeDraft?> fetchDraft(String draftId) async {
    try {
      final doc = await _db.collection(_collection).doc(draftId).get();
      if (!doc.exists) return null;
      return ResumeDraft.fromDoc(doc);
    } catch (e) {
      debugPrint('⚠️ ResumeDraftService.fetchDraft: $e');
      return null;
    }
  }

  /// 드래프트 저장 (신규 생성 또는 업데이트)
  ///
  /// [draftId] 가 null이면 새로 생성, 있으면 업데이트.
  /// 반환: 저장된 드래프트 ID
  static Future<String?> saveDraft({
    String? draftId,
    required String title,
    String? resumeId,
    required Map<String, dynamic> data,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    try {
      final draft = ResumeDraft(
        id: draftId ?? '',
        ownerUid: uid,
        title: title,
        resumeId: resumeId,
        data: data,
      );

      if (draftId != null && draftId.isNotEmpty) {
        // 업데이트
        await _db.collection(_collection).doc(draftId).set(
              draft.toMap(),
              SetOptions(merge: true),
            );
        debugPrint('✅ ResumeDraft 업데이트: $draftId');
        return draftId;
      } else {
        // 새로 생성
        final ref = await _db.collection(_collection).add(draft.toMap());
        debugPrint('✅ ResumeDraft 생성: ${ref.id}');
        return ref.id;
      }
    } catch (e) {
      debugPrint('⚠️ ResumeDraftService.saveDraft: $e');
      return null;
    }
  }

  /// 드래프트 삭제 (이력서 확정 저장 후 호출)
  static Future<void> deleteDraft(String draftId) async {
    try {
      await _db.collection(_collection).doc(draftId).delete();
      debugPrint('✅ ResumeDraft 삭제: $draftId');
    } catch (e) {
      debugPrint('⚠️ ResumeDraftService.deleteDraft: $e');
    }
  }

  /// 현재 사용자의 특정 이력서에 대한 드래프트가 있는지 확인
  static Future<ResumeDraft?> findDraftForResume(String resumeId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    try {
      final snap = await _db
          .collection(_collection)
          .where('ownerUid', isEqualTo: uid)
          .where('resumeId', isEqualTo: resumeId)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;
      return ResumeDraft.fromDoc(snap.docs.first);
    } catch (e) {
      debugPrint('⚠️ ResumeDraftService.findDraftForResume: $e');
      return null;
    }
  }
}

