import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/application.dart';
import '../models/resume.dart';
import 'job_stats_service.dart';

/// 지원서 관련 Firestore 서비스
///
/// 설계서 기준:
/// - 지원 시 이력서 기반 데이터 제출
/// - 익명 프로필 → 연락처 요청 → 승인 순서
/// - applications/{applicationId} 루트 컬렉션
class ApplicationService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('applications');

  // ══════════════════════════════════════════════
  // 지원 제출
  // ══════════════════════════════════════════════

  /// 지원서 제출 (이력서 기반)
  ///
  /// [jobId] 공고 ID
  /// [clinicId] 병원 ID (공고 문서에서 가져옴)
  /// [resumeId] 선택한 이력서 ID
  /// [answers] 공고별 추가 답변 (선택)
  static Future<String?> submitApplication({
    required String jobId,
    required String clinicId,
    required String resumeId,
    Map<String, dynamic> answers = const {},
  }) async {
    final uid = _uid;
    if (uid == null) return null;

    try {
      // 중복 지원 방지
      final existing = await _col
          .where('jobId', isEqualTo: jobId)
          .where('applicantUid', isEqualTo: uid)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        debugPrint('⚠️ 이미 지원한 공고: $jobId');
        return null; // 이미 지원함
      }

      final app = Application(
        id: '',
        jobId: jobId,
        clinicId: clinicId,
        applicantUid: uid,
        resumeId: resumeId,
        answers: answers,
      );

      final ref = await _col.add(app.toMap());

      // 사용자 문서에 지원 내역 추가
      await _db.collection('users').doc(uid).update({
        'appliedJobs': FieldValue.arrayUnion([jobId]),
      });

      // 통계 기록
      await JobStatsService.recordApply(jobId);

      debugPrint('✅ 지원 제출: ${ref.id}');
      return ref.id;
    } catch (e) {
      debugPrint('⚠️ submitApplication error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════
  // 조회
  // ══════════════════════════════════════════════

  /// 내 지원 목록 실시간 스트림
  static Stream<List<Application>> watchMyApplications() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return _col
        .where('applicantUid', isEqualTo: uid)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Application.fromDoc(d)).toList());
  }

  /// 내 지원 목록 1회 조회
  static Future<List<Application>> fetchMyApplications() async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final snap = await _col
          .where('applicantUid', isEqualTo: uid)
          .orderBy('submittedAt', descending: true)
          .get();
      return snap.docs.map((d) => Application.fromDoc(d)).toList();
    } catch (e) {
      debugPrint('⚠️ fetchMyApplications error: $e');
      return [];
    }
  }

  /// 특정 공고에 이미 지원했는지 확인
  static Future<bool> hasApplied(String jobId) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      final snap = await _col
          .where('jobId', isEqualTo: jobId)
          .where('applicantUid', isEqualTo: uid)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (e) {
      debugPrint('⚠️ hasApplied error: $e');
      return false;
    }
  }

  /// 특정 공고의 지원자 수 조회 (병원용)
  static Future<int> getApplicantCount(String jobId) async {
    try {
      final snap = await _col
          .where('jobId', isEqualTo: jobId)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      debugPrint('⚠️ getApplicantCount error: $e');
      return 0;
    }
  }

  // ══════════════════════════════════════════════
  // 지원 취소 / 철회
  // ══════════════════════════════════════════════

  /// 지원 철회
  static Future<bool> withdrawApplication(String applicationId) async {
    try {
      await _col.doc(applicationId).update({
        'status': ApplicationStatus.withdrawn.name,
      });
      debugPrint('✅ 지원 철회: $applicationId');
      return true;
    } catch (e) {
      debugPrint('⚠️ withdrawApplication error: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════
  // 연락처 공개 관리
  // ══════════════════════════════════════════════

  /// 지원자가 연락처 공개 승인 (병원의 요청에 대해)
  static Future<bool> approveContactShare(String applicationId) async {
    try {
      await _col.doc(applicationId).update({
        'visibilityGranted.contactShared': true,
        'visibilityGranted.sharedAt': FieldValue.serverTimestamp(),
        'status': ApplicationStatus.contactShared.name,
      });
      return true;
    } catch (e) {
      debugPrint('⚠️ approveContactShare error: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════
  // 익명 프로필 생성 유틸
  // ══════════════════════════════════════════════

  /// 이력서 → 익명 프로필 요약 (병원에 보여줄 데이터)
  static Map<String, dynamic> buildAnonymousProfile(Resume resume) {
    final profile = resume.profile;
    final totalExperience = resume.experiences.length;

    // 경력 연차 계산
    int totalMonths = 0;
    for (final exp in resume.experiences) {
      final startParts = exp.start.split('-');
      final endParts = exp.end == '재직중'
          ? [DateTime.now().year.toString(), DateTime.now().month.toString()]
          : exp.end.split('-');
      if (startParts.length >= 2 && endParts.length >= 2) {
        try {
          final startYear = int.parse(startParts[0]);
          final startMonth = int.parse(startParts[1]);
          final endYear = int.parse(endParts[0]);
          final endMonth = int.parse(endParts[1]);
          totalMonths += (endYear - startYear) * 12 + (endMonth - startMonth);
        } catch (_) {}
      }
    }
    final years = totalMonths ~/ 12;

    return {
      'displayName': '지원자 #${DateTime.now().millisecondsSinceEpoch % 10000}',
      'careerYears': years > 0 ? '${years}년차' : '신입',
      'workTypes': profile?.workTypes ?? [],
      'region': profile?.region ?? '',
      'skills': resume.skills.map((s) => s.name).toList(),
      'licensesHeld': resume.licenses.where((l) => l.has).map((l) => l.type).toList(),
      'experienceCount': totalExperience,
    };
  }
}

