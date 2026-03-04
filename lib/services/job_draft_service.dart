import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/job_draft.dart';

/// 공고 임시저장(Draft) Firestore 서비스
///
/// Firestore 경로: `jobDrafts/{draftId}`
/// ownerUid 기반 필터링으로 본인 드래프트만 조회
class JobDraftService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('jobDrafts');

  // ══════════════════════════════════════════════
  // 조회
  // ══════════════════════════════════════════════

  /// 내 드래프트 목록 실시간 스트림 (최근 수정순)
  static Stream<List<JobDraft>> watchMyDrafts() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return _col
        .where('ownerUid', isEqualTo: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => JobDraft.fromDoc(d)).toList());
  }

  /// 내 드래프트 목록 1회 조회
  static Future<List<JobDraft>> fetchMyDrafts() async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final snap = await _col
          .where('ownerUid', isEqualTo: uid)
          .orderBy('updatedAt', descending: true)
          .get();
      return snap.docs.map((d) => JobDraft.fromDoc(d)).toList();
    } catch (e) {
      debugPrint('⚠️ fetchMyDrafts error: $e');
      return [];
    }
  }

  /// 특정 드래프트 조회
  static Future<JobDraft?> fetchDraft(String draftId) async {
    try {
      final doc = await _col.doc(draftId).get();
      if (!doc.exists) return null;
      return JobDraft.fromDoc(doc);
    } catch (e) {
      debugPrint('⚠️ fetchDraft error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════
  // 생성
  // ══════════════════════════════════════════════

  /// 새 드래프트 생성 → draftId 반환
  static Future<String?> createDraft({
    String clinicName = '',
    String title = '',
  }) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final draft = JobDraft(
        id: '',
        ownerUid: uid,
        clinicName: clinicName,
        title: title,
      );
      final data = draft.toMap();
      data['createdAt'] = FieldValue.serverTimestamp();
      final ref = await _col.add(data);
      debugPrint('✅ 공고 드래프트 생성: ${ref.id}');
      return ref.id;
    } catch (e) {
      debugPrint('⚠️ createDraft error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════
  // 저장 (upsert)
  // ══════════════════════════════════════════════

  /// 드래프트 저장 (있으면 업데이트, 없으면 생성)
  ///
  /// [draftId] null이면 새로 생성, 있으면 업데이트
  /// 반환: draftId
  static Future<String?> saveDraft({
    String? draftId,
    required Map<String, dynamic> formData,
  }) async {
    final uid = _uid;
    if (uid == null) return null;

    try {
      final data = {
        'ownerUid': uid,
        ...formData,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (draftId != null && draftId.isNotEmpty) {
        // 기존 드래프트 업데이트
        await _col.doc(draftId).update(data);
        debugPrint('✅ 공고 드래프트 업데이트: $draftId');
        return draftId;
      } else {
        // 새 드래프트 생성
        data['createdAt'] = FieldValue.serverTimestamp();
        final ref = await _col.add(data);
        debugPrint('✅ 공고 드래프트 생성: ${ref.id}');
        return ref.id;
      }
    } catch (e) {
      debugPrint('⚠️ saveDraft error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════
  // 삭제
  // ══════════════════════════════════════════════

  /// 드래프트 삭제
  static Future<bool> deleteDraft(String draftId) async {
    try {
      await _col.doc(draftId).delete();
      debugPrint('✅ 공고 드래프트 삭제: $draftId');
      return true;
    } catch (e) {
      debugPrint('⚠️ deleteDraft error: $e');
      return false;
    }
  }
}

