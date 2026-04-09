import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/resume.dart';
import 'resume_career_sync_service.dart';
import 'resume_experience_merge_service.dart';

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

  static DocumentReference<Map<String, dynamic>>? get _userDocRef {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  /// AI/OCR로 이력서가 확정되면 호출 — 치과 네트워크 추출 시 기본 소스로 사용
  static Future<void> markLastImportedResume(String resumeId) async {
    final ref = _userDocRef;
    if (ref == null || resumeId.isEmpty) return;
    try {
      await ref.set(
        {
          'lastImportedResumeId': resumeId,
          'lastImportedResumeAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('⚠️ markLastImportedResume: $e');
    }
  }

  /// [markLastImportedResume]으로 저장한 ID (없으면 null)
  static Future<String?> getLastImportedResumeId() async {
    final ref = _userDocRef;
    if (ref == null) return null;
    try {
      final snap = await ref.get();
      return snap.data()?['lastImportedResumeId'] as String?;
    } catch (e) {
      debugPrint('⚠️ getLastImportedResumeId: $e');
      return null;
    }
  }

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

  static bool _creating = false;

  /// 새 이력서 생성 → 생성된 resumeId 반환
  /// 빈 이력서(제목만 있고 내용 없음)가 있으면 재사용
  static Future<String?> createResume({String? title}) async {
    final resolvedTitle = title ?? Resume.kDefaultResumeTitle;
    final uid = _uid;
    if (uid == null) return null;

    // 더블클릭 방지
    if (_creating) {
      debugPrint('⚠️ createResume: 이미 생성 중 — 무시');
      return null;
    }
    _creating = true;

    try {
      // 빈 이력서가 있으면 재사용
      final existing = await _col
          .where('ownerUid', isEqualTo: uid)
          .orderBy('updatedAt', descending: true)
          .limit(20)
          .get();

      for (final doc in existing.docs) {
        final r = Resume.fromDoc(doc);
        if (_isEmpty(r)) {
          debugPrint('♻️ 빈 이력서 재사용: ${doc.id}');
          _creating = false;
          return doc.id;
        }
      }

      // 빈 이력서가 없으면 새로 생성
      final resume = Resume(
        id: '',
        ownerUid: uid,
        title: resolvedTitle,
      );
      final ref = await _col.add(resume.toMap());
      debugPrint('✅ 이력서 생성: ${ref.id}');
      return ref.id;
    } catch (e) {
      debugPrint('⚠️ createResume error: $e');
      return null;
    } finally {
      _creating = false;
    }
  }

  /// 후처리로 경력이 바뀌지 않았을 때 [Resume] 인스턴스 재사용
  static bool _identicalExperienceLists(
    List<ResumeExperience> a,
    List<ResumeExperience> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      if (x.clinicName != y.clinicName ||
          x.region != y.region ||
          x.start != y.start ||
          x.end != y.end ||
          x.achievementsText != y.achievementsText) {
        return false;
      }
      if (!_sameStringList(x.tasks, y.tasks) ||
          !_sameStringList(x.tools, y.tools)) {
        return false;
      }
    }
    return true;
  }

  static bool _sameStringList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// 이력서가 비어있는지 판별 (제목/기본값만 있는 상태)
  static bool _isEmpty(Resume r) {
    return (r.profile == null || r.profile!.name.isEmpty) &&
        r.licenses.isEmpty &&
        r.experiences.isEmpty &&
        r.skills.isEmpty &&
        r.education.isEmpty &&
        r.trainings.isEmpty &&
        r.attachments.isEmpty;
  }

  /// 빈 이력서 일괄 삭제 (현재 사용자의 빈 이력서 중 1개만 남기고 삭제)
  static Future<int> cleanupEmptyResumes() async {
    final uid = _uid;
    if (uid == null) return 0;
    try {
      final snap = await _col
          .where('ownerUid', isEqualTo: uid)
          .get();

      int deleted = 0;
      bool keptOne = false;

      for (final doc in snap.docs) {
        final r = Resume.fromDoc(doc);
        if (_isEmpty(r)) {
          if (!keptOne) {
            keptOne = true;
            continue;
          }
          await doc.reference.delete();
          deleted++;
        }
      }

      debugPrint('🧹 빈 이력서 $deleted건 삭제 완료');
      return deleted;
    } catch (e) {
      debugPrint('⚠️ cleanupEmptyResumes error: $e');
      return 0;
    }
  }

  // ── 수정 ────────────────────────────────────────────────

  /// 이력서 전체 업데이트 + 커리어 카드 동기화
  static Future<bool> updateResume(Resume resume) async {
    try {
      final mergedExperiences =
          ResumeExperienceMergeService.mergeSimilar(resume.experiences);
      final toSave =
          mergedExperiences.length == resume.experiences.length &&
                  _identicalExperienceLists(
                    resume.experiences,
                    mergedExperiences,
                  )
              ? resume
              : Resume(
                  id: resume.id,
                  ownerUid: resume.ownerUid,
                  title: resume.title,
                  createdAt: resume.createdAt,
                  updatedAt: resume.updatedAt,
                  visibility: resume.visibility,
                  profile: resume.profile,
                  licenses: resume.licenses,
                  experiences: mergedExperiences,
                  skills: resume.skills,
                  education: resume.education,
                  trainings: resume.trainings,
                  attachments: resume.attachments,
                );

      await _col.doc(resume.id).update({
        ...toSave.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ 이력서 업데이트: ${resume.id}');

      // 커리어 카드에 자동 동기화
      ResumeCareerSyncService.syncFromResume(toSave);

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

  /// `(복사)` 접미사 대신 `제목 (2)`, `(3)` … 형태로 고유 제목 부여
  static String _baseTitleForDuplicate(String title) {
    var s = title.trim();
    while (true) {
      const copySuffix = ' (복사)';
      if (s.endsWith(copySuffix)) {
        s = s.substring(0, s.length - copySuffix.length).trimRight();
        continue;
      }
      final m = RegExp(r' \((\d+)\)$').firstMatch(s);
      if (m != null) {
        s = s.substring(0, s.length - m.group(0)!.length).trimRight();
        continue;
      }
      break;
    }
    return s.isEmpty ? title.trim() : s;
  }

  /// 내 이력서 제목 중 [base]와 동일하거나 `base (n)` 인 항목의 최대 번호 뒤에 이어지는 제목
  static String _nextDuplicateTitle(String originalTitle, List<Resume> all) {
    final base = _baseTitleForDuplicate(originalTitle);
    var maxN = 0;
    final pattern = RegExp('^${RegExp.escape(base)} \\((\\d+)\\)\$');
    for (final r in all) {
      final t = r.title.trim();
      if (t == base) {
        if (maxN < 1) maxN = 1;
        continue;
      }
      final m = pattern.firstMatch(t);
      if (m != null) {
        final n = int.tryParse(m.group(1) ?? '') ?? 0;
        if (n > maxN) maxN = n;
      }
    }
    return '$base (${maxN + 1})';
  }

  /// 이력서 복제
  static Future<String?> duplicateResume(String resumeId) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final original = await fetchResume(resumeId);
      if (original == null) return null;

      final allMine = await fetchMyResumes();
      final newTitle = _nextDuplicateTitle(original.title, allMine);

      final copy = Resume(
        id: '',
        ownerUid: uid,
        title: newTitle,
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

