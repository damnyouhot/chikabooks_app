import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/resume.dart';
import 'career_profile_service.dart';

/// 온보딩·커리어 카드 → 이력서 자동 채움 (비어 있는 섹션만)
///
/// - 경력: `careerNetwork` 전부 (없으면 온보딩 `onboardingPlaceName` 1건)
/// - 스킬: `careerProfile.skills` 중 enabled + [CareerProfileService.skillMaster] 매핑
/// - 학력: 재학 중 온보딩만, 학력 블록이 비었을 때 학교명 후보
class ResumePrefillService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// [resume]의 빈 경력/스킬/학력을 채운 복사본과, 변경 여부
  static Future<(Resume, bool)> mergeCareerSourcesIfNeeded(Resume resume) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return (resume, false);

    try {
      final userSnap = await _db.collection('users').doc(uid).get();
      final userData = userSnap.data() ?? {};

      var experiences = resume.experiences;
      var skills = resume.skills;
      var education = resume.education;
      var changed = false;

      if (experiences.isEmpty) {
        final built = await _buildExperiences(uid, userData);
        if (built.isNotEmpty) {
          experiences = built;
          changed = true;
        }
      }

      if (skills.isEmpty) {
        final built = _buildSkillsFromCareerProfile(userData);
        if (built.isNotEmpty) {
          skills = built;
          changed = true;
        }
      }

      if (education.isEmpty) {
        final built = _buildEducationFromOnboarding(userData);
        if (built != null) {
          education = [built];
          changed = true;
        }
      }

      if (!changed) return (resume, false);

      return (
        Resume(
          id: resume.id,
          ownerUid: resume.ownerUid,
          title: resume.title,
          createdAt: resume.createdAt,
          updatedAt: resume.updatedAt,
          visibility: resume.visibility,
          profile: resume.profile,
          licenses: resume.licenses,
          experiences: experiences,
          skills: skills,
          education: education,
          trainings: resume.trainings,
          attachments: resume.attachments,
        ),
        true,
      );
    } catch (e) {
      debugPrint('⚠️ ResumePrefillService.mergeCareerSourcesIfNeeded: $e');
      return (resume, false);
    }
  }

  static Future<List<ResumeExperience>> _buildExperiences(
    String uid,
    Map<String, dynamic> userData,
  ) async {
    final netSnap =
        await _db
            .collection('users')
            .doc(uid)
            .collection('careerNetwork')
            .orderBy('startDate', descending: true)
            .get();

    final out = <ResumeExperience>[];
    for (final doc in netSnap.docs) {
      final e = DentalNetworkEntry.fromDoc(doc);
      if (e.clinicName.trim().isEmpty) continue;
      out.add(_networkEntryToExperience(e));
    }

    if (out.isNotEmpty) return out;

    final place = (userData['onboardingPlaceName'] as String?)?.trim() ?? '';
    final status = userData['onboardingWorkStatus'] as String? ?? '';
    if (place.isEmpty || status == 'student') return [];

    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    final endLabel =
        status == 'seeking' ? _yyyyMm(start) : '재직중';

    return [
      ResumeExperience(
        clinicName: place,
        region: '',
        start: _yyyyMm(start),
        end: endLabel,
        tasks: const [],
        tools: const [],
      ),
    ];
  }

  static ResumeExperience _networkEntryToExperience(DentalNetworkEntry e) {
    final start = _yyyyMm(e.startDate);
    final String end;
    if (e.isCurrent) {
      end = '재직중';
    } else if (e.endDate != null) {
      end = _yyyyMm(e.endDate!);
    } else {
      end = '재직중';
    }
    return ResumeExperience(
      clinicName: e.clinicName.trim(),
      region: '',
      start: start,
      end: end,
      tasks: List<String>.from(e.tags),
      tools: List<String>.from(e.acquiredSkills),
    );
  }

  static String _yyyyMm(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static List<ResumeSkill> _buildSkillsFromCareerProfile(
    Map<String, dynamic> userData,
  ) {
    final career =
        userData['careerProfile'] as Map<String, dynamic>? ?? {};
    final raw = career['skills'] as Map<String, dynamic>? ?? {};
    final out = <ResumeSkill>[];

    for (final m in CareerProfileService.skillMaster) {
      final id = m['id'] as String;
      final title = m['title'] as String;
      final entry = raw[id];
      if (entry is! Map) continue;
      final enabled = entry['enabled'] as bool? ?? false;
      if (!enabled) continue;
      var level = (entry['level'] as num?)?.toInt() ?? 3;
      if (level < 1) level = 1;
      if (level > 5) level = 5;
      // 이력서 스킬 칩은 한글 라벨을 id로 사용 (section_skills.dart)
      out.add(ResumeSkill(id: title, name: title, level: level));
    }
    return out;
  }

  static ResumeEducation? _buildEducationFromOnboarding(
    Map<String, dynamic> userData,
  ) {
    final status = userData['onboardingWorkStatus'] as String? ?? '';
    if (status != 'student') return null;
    final place = (userData['onboardingPlaceName'] as String?)?.trim() ?? '';
    if (place.isEmpty) return null;
    return ResumeEducation(school: place, major: '', gradYear: null);
  }
}
