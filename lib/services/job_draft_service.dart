import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/job.dart';
import '../models/job_draft.dart';
import '../models/published_job_to_draft_mapper.dart';

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

  /// 최근 수정순 정렬 (클라이언트)
  ///
  /// `where + orderBy(updatedAt)` 는 복합 인덱스가 필요해, 인덱스 미배포 시 쿼리가 실패한다.
  /// 동일 필터(`ownerUid`)만 사용한 뒤 메모리에서 정렬하면 단일 필드 인덱스로 동작한다.
  static List<JobDraft> _sortDraftsByUpdatedDesc(List<JobDraft> list) {
    list.sort((a, b) {
      final ta = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return list;
  }

  /// 내 드래프트 목록 실시간 스트림 (최근 수정순)
  static Stream<List<JobDraft>> watchMyDrafts() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return _col
        .where('ownerUid', isEqualTo: uid)
        .snapshots()
        .map((s) {
          final list = s.docs.map((d) => JobDraft.fromDoc(d)).toList();
          return _sortDraftsByUpdatedDesc(list);
        });
  }

  /// 내 드래프트 목록 1회 조회
  static Future<List<JobDraft>> fetchMyDrafts() async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final snap = await _col.where('ownerUid', isEqualTo: uid).get();
      final list = snap.docs.map((d) => JobDraft.fromDoc(d)).toList();
      return _sortDraftsByUpdatedDesc(list);
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

  /// 임시저장 초안을 복제해 새 임시저장을 만든 뒤 새 문서 ID를 반환한다.
  static Future<String?> saveDraftAsCopyFromDraft(JobDraft d) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final map = Map<String, dynamic>.from(d.toMap());
      map.remove('updatedAt');
      map.remove('ownerUid');
      return saveDraft(
        formData: {
          ...map,
          'sourceType': 'copy',
          'copiedFromDraftId': d.id,
          'currentStep': 'ai_generated',
          'aiParseStatus': 'done',
          'editorStep': 'step3',
        },
      );
    } catch (e) {
      debugPrint('⚠️ saveDraftAsCopyFromDraft error: $e');
      return null;
    }
  }

  /// 게시된 공고([Job])를 복제해 새 임시저장을 만든 뒤 새 문서 ID를 반환한다.
  static Future<String?> saveDraftAsCopyFromPublishedJob(Job job) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      return saveDraft(formData: publishedJobCopyDraftFormData(job));
    } catch (e) {
      debugPrint('⚠️ saveDraftAsCopyFromPublishedJob error: $e');
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

