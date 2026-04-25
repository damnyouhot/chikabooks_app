import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/resume.dart';
import 'resume_career_sync_service.dart';

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
      final snap =
          await _col
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
  ///
  /// 중복 방지: 이미 빈 이력서(작성 안 한 기본 이력서)가 있으면 그것을 재사용.
  /// `forceNew: true`이면 항상 새로 생성.
  static Future<String?> createResume({
    String title = '기본 이력서',
    bool forceNew = false,
  }) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      // 기존 빈 이력서 재사용
      if (!forceNew) {
        final existing = await _findEmptyResume(uid);
        if (existing != null) {
          debugPrint('♻️ 기존 빈 이력서 재사용: $existing');
          return existing;
        }
      }

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

  /// 비어있는 이력서(profile/licenses/experiences/skills 등 전부 빈) 찾기
  /// 가장 최근 빈 이력서의 id 반환, 없으면 null
  static Future<String?> _findEmptyResume(String uid) async {
    try {
      final snap =
          await _col
              .where('ownerUid', isEqualTo: uid)
              .orderBy('updatedAt', descending: true)
              .limit(20) // 최근 20개만 검사
              .get();

      for (final doc in snap.docs) {
        final r = Resume.fromDoc(doc);
        if (_isEmptyResume(r)) {
          return doc.id;
        }
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ _findEmptyResume error: $e');
      return null;
    }
  }

  static bool _isEmptyResume(Resume r) {
    final profileEmpty =
        r.profile == null ||
        ((r.profile!.name).isEmpty && (r.profile!.summary).isEmpty);
    return profileEmpty &&
        r.licenses.isEmpty &&
        r.experiences.isEmpty &&
        r.skills.isEmpty &&
        r.education.isEmpty &&
        r.trainings.isEmpty &&
        r.attachments.isEmpty;
  }

  // ── 수정 ────────────────────────────────────────────────

  /// 이력서 전체 업데이트 + 커리어 카드 동기화
  static Future<bool> updateResume(Resume resume) async {
    try {
      await _col.doc(resume.id).update({
        ...resume.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ 이력서 업데이트: ${resume.id}');

      // 커리어 카드에 자동 동기화
      ResumeCareerSyncService.syncFromResume(resume);

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
        'sections.$sectionKey':
            sectionData is List
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
      final snap = await _col.where('ownerUid', isEqualTo: uid).count().get();
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

  // ── 마지막 OCR 가져오기 이력서 마킹 ────────────────────────
  // OCR 흐름으로 만든 이력서 ID 를 사용자 문서에 1개만 보관해 두고,
  // 경력 추출 다이얼로그(career_network_section)에서 우선순위 정렬에 사용한다.

  /// OCR 가져오기로 방금 생성/연결된 이력서 ID 를 사용자 문서에 기록.
  static Future<void> markLastImportedResume(String resumeId) async {
    final uid = _uid;
    if (uid == null || resumeId.isEmpty) return;
    try {
      await _db.collection('users').doc(uid).set({
        'lastImportedResumeId': resumeId,
        'lastImportedResumeAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ markLastImportedResume error: $e');
    }
  }

  /// 마지막으로 OCR 가져오기로 만든 이력서 ID 조회 (없으면 null).
  static Future<String?> getLastImportedResumeId() async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final snap = await _db.collection('users').doc(uid).get();
      final v = snap.data()?['lastImportedResumeId'];
      if (v is String && v.isNotEmpty) return v;
      return null;
    } catch (e) {
      debugPrint('⚠️ getLastImportedResumeId error: $e');
      return null;
    }
  }
}
