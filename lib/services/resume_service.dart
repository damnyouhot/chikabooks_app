import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/resume.dart';

/// 이력서 Firestore CRUD 서비스
///
/// Firestore 경로: `resumes/{resumeId}` (루트 컬렉션)
/// ownerUid 기반 필터링으로 본인 이력서만 조회
class ResumeService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('resumes');

  // ── 조회 ────────────────────────────────────────────────

  /// 내 이력서 목록 실시간 스트림 (최근 수정순)
  static Stream<List<Resume>> watchMyResumes() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return _col
        .where('ownerUid', isEqualTo: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Resume.fromDoc(d)).toList());
  }

  /// 내 이력서 목록 1회 조회
  static Future<List<Resume>> fetchMyResumes() async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final snap = await _col
          .where('ownerUid', isEqualTo: uid)
          .orderBy('updatedAt', descending: true)
          .get();
      return snap.docs.map((d) => Resume.fromDoc(d)).toList();
    } catch (e) {
      debugPrint('⚠️ fetchMyResumes error: $e');
      return [];
    }
  }

  /// 특정 이력서 조회
  static Future<Resume?> fetchResume(String resumeId) async {
    try {
      final doc = await _col.doc(resumeId).get();
      if (!doc.exists) return null;
      return Resume.fromDoc(doc);
    } catch (e) {
      debugPrint('⚠️ fetchResume error: $e');
      return null;
    }
  }

  /// 특정 이력서 실시간 스트림
  static Stream<Resume?> watchResume(String resumeId) {
    return _col.doc(resumeId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Resume.fromDoc(doc);
    });
  }

  // ── 생성 ────────────────────────────────────────────────

  /// 새 이력서 생성 → 생성된 resumeId 반환
  static Future<String?> createResume({String title = '기본 이력서'}) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final resume = Resume(
        id: '', // Firestore가 자동 생성
        ownerUid: uid,
        title: title,
      );
      final ref = await _col.add(resume.toMap());
      debugPrint('✅ 이력서 생성: ${ref.id}');
      return ref.id;
    } catch (e) {
      debugPrint('⚠️ createResume error: $e');
      return null;
    }
  }

  // ── 수정 ────────────────────────────────────────────────

  /// 이력서 전체 업데이트
  static Future<bool> updateResume(Resume resume) async {
    try {
      await _col.doc(resume.id).update({
        ...resume.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ 이력서 업데이트: ${resume.id}');
      return true;
    } catch (e) {
      debugPrint('⚠️ updateResume error: $e');
      return false;
    }
  }

  /// 이력서 제목만 변경
  static Future<bool> updateTitle(String resumeId, String newTitle) async {
    try {
      await _col.doc(resumeId).update({
        'title': newTitle,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('⚠️ updateTitle error: $e');
      return false;
    }
  }

  /// 특정 섹션만 업데이트 (부분 저장)
  static Future<bool> updateSection(
    String resumeId,
    String sectionKey,
    dynamic sectionData,
  ) async {
    try {
      await _col.doc(resumeId).update({
        'sections.$sectionKey': sectionData is List
            ? sectionData.map((e) => e.toMap()).toList()
            : (sectionData as dynamic).toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('⚠️ updateSection error: $e');
      return false;
    }
  }

  /// 공개 설정 변경
  static Future<bool> updateVisibility(
    String resumeId,
    ResumeVisibility visibility,
  ) async {
    try {
      await _col.doc(resumeId).update({
        'visibility': visibility.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('⚠️ updateVisibility error: $e');
      return false;
    }
  }

  // ── 삭제 ────────────────────────────────────────────────

  /// 이력서 삭제
  static Future<bool> deleteResume(String resumeId) async {
    try {
      await _col.doc(resumeId).delete();
      debugPrint('✅ 이력서 삭제: $resumeId');
      return true;
    } catch (e) {
      debugPrint('⚠️ deleteResume error: $e');
      return false;
    }
  }

  // ── 유틸리티 ────────────────────────────────────────────

  /// 이력서 개수 조회
  static Future<int> getResumeCount() async {
    final uid = _uid;
    if (uid == null) return 0;
    try {
      final snap = await _col
          .where('ownerUid', isEqualTo: uid)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      debugPrint('⚠️ getResumeCount error: $e');
      return 0;
    }
  }

  /// 이력서 복제
  static Future<String?> duplicateResume(String resumeId) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final original = await fetchResume(resumeId);
      if (original == null) return null;

      final copy = Resume(
        id: '',
        ownerUid: uid,
        title: '${original.title} (복사)',
        visibility: original.visibility,
        profile: original.profile,
        licenses: original.licenses,
        experiences: original.experiences,
        skills: original.skills,
        education: original.education,
        trainings: original.trainings,
        attachments: original.attachments,
      );
      final ref = await _col.add(copy.toMap());
      return ref.id;
    } catch (e) {
      debugPrint('⚠️ duplicateResume error: $e');
      return null;
    }
  }
}

