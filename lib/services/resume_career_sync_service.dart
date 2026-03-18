import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/resume.dart';
import 'career_profile_service.dart';

/// 이력서 → 커리어 카드 자동 동기화 서비스
///
/// 설계서 §5 SSOT 규칙:
/// - 이력서 확정/수정 시 → 커리어 카드(스킬/네트워크) 동기화
/// - "나의 치과 네트워크"는 이력서 경력에서 자동 반영 (필수 자동화)
/// - 커리어 카드에서 스킬은 자유 수정 가능 (이력서와 분리 편집 허용)
class ResumeCareerSyncService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// 이력서 저장 시 호출 — 커리어 카드에 동기화
  ///
  /// [resume] 저장된 이력서 데이터
  /// [syncSkills] true이면 스킬도 동기화 (기본: true, 초회 동기화 시만)
  static Future<void> syncFromResume(
    Resume resume, {
    bool syncSkills = true,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      // 1. 경력 → 치과 네트워크 동기화
      await _syncNetwork(uid, resume.experiences);

      // 2. 스킬 → 커리어 프로필 동기화 (선택)
      if (syncSkills) {
        await _syncSkills(uid, resume.skills);
      }

      debugPrint('✅ 이력서 → 커리어 카드 동기화 완료');
    } catch (e) {
      debugPrint('⚠️ ResumeCareerSyncService.syncFromResume error: $e');
    }
  }

  /// 이력서 경력 → careerNetwork 서브컬렉션 동기화
  ///
  /// 전략: 기존 네트워크 엔트리를 clinicName+start 기준으로 매칭
  /// - 매칭되면 업데이트
  /// - 매칭 안 되면 새로 추가
  /// - 이력서에 없는 엔트리는 건드리지 않음 (수동 추가된 것일 수 있음)
  static Future<void> _syncNetwork(
    String uid,
    List<ResumeExperience> experiences,
  ) async {
    if (experiences.isEmpty) return;

    final networkRef =
        _db.collection('users').doc(uid).collection('careerNetwork');

    // 기존 엔트리 로드
    final existingSnap = await networkRef.get();
    final existing = existingSnap.docs.map(DentalNetworkEntry.fromDoc).toList();

    for (final exp in experiences) {
      if (exp.clinicName.trim().isEmpty) continue;

      // YYYY-MM → DateTime 파싱
      final startDate = _parseYearMonth(exp.start);
      if (startDate == null) continue;

      final endDate =
          exp.end == '재직중' ? null : _parseYearMonth(exp.end);

      // 기존 엔트리에서 clinicName + 비슷한 시작일로 매칭
      final match = _findMatch(existing, exp.clinicName, startDate);

      final entryData = <String, dynamic>{
        'clinicName': exp.clinicName.trim(),
        'startDate': Timestamp.fromDate(startDate),
        'endDate': endDate != null ? Timestamp.fromDate(endDate) : null,
        'tags': exp.tasks.take(5).toList(), // 경력 업무를 태그로
        'acquiredSkills': exp.tools.take(5).toList(),
        'syncedFromResume': true, // 자동 동기화 표시
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (match != null) {
        // 업데이트
        await networkRef.doc(match.id).update(entryData);
      } else {
        // 새로 추가
        entryData['createdAt'] = FieldValue.serverTimestamp();
        await networkRef.add(entryData);
      }
    }
  }

  /// 이력서 스킬 → careerProfile.skills 동기화
  ///
  /// 전략: 이력서 스킬 중 skillMaster에 매칭되는 것만 반영
  /// 기존에 사용자가 직접 수정한 스킬은 유지 (overwrite 안 함)
  static Future<void> _syncSkills(
    String uid,
    List<ResumeSkill> resumeSkills,
  ) async {
    if (resumeSkills.isEmpty) return;

    final userRef = _db.collection('users').doc(uid);

    // 기존 스킬 로드
    final doc = await userRef.get();
    final careerProfile =
        doc.data()?['careerProfile'] as Map<String, dynamic>? ?? {};
    final existingSkills =
        (careerProfile['skills'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
            ) ??
            {};

    // skillMaster ID 셋
    final masterIds =
        CareerProfileService.skillMaster.map((m) => m['id'] as String).toSet();

    // 이력서 스킬명 → skillMaster ID 매핑
    final nameToId = <String, String>{};
    for (final m in CareerProfileService.skillMaster) {
      nameToId[m['title'] as String] = m['id'] as String;
    }

    final updates = <String, dynamic>{};

    for (final skill in resumeSkills) {
      // ID가 직접 매칭되거나, 이름으로 매칭
      String? masterId;
      if (masterIds.contains(skill.id)) {
        masterId = skill.id;
      } else if (nameToId.containsKey(skill.name)) {
        masterId = nameToId[skill.name];
      }

      if (masterId == null) continue;

      // 기존에 사용자가 직접 수정한 스킬이면 건너뜀
      final existing = existingSkills[masterId];
      if (existing != null &&
          existing['enabled'] == true &&
          existing['syncedFromResume'] != true) {
        continue; // 사용자가 직접 설정한 것 — 존중
      }

      updates['careerProfile.skills.$masterId'] = {
        'enabled': true,
        'syncedFromResume': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };
    }

    if (updates.isNotEmpty) {
      await userRef.update(updates);
    }
  }

  // ── 유틸 ────────────────────────────────────────────

  /// 'YYYY-MM' → DateTime
  static DateTime? _parseYearMonth(String s) {
    if (s.isEmpty) return null;
    final parts = s.split('-');
    if (parts.length < 2) return null;
    try {
      return DateTime(int.parse(parts[0]), int.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }

  /// 기존 엔트리에서 clinicName + 시작일 비슷한 것 찾기
  static DentalNetworkEntry? _findMatch(
    List<DentalNetworkEntry> entries,
    String clinicName,
    DateTime startDate,
  ) {
    for (final e in entries) {
      if (e.clinicName.trim() == clinicName.trim() &&
          (e.startDate.year == startDate.year &&
              e.startDate.month == startDate.month)) {
        return e;
      }
    }
    return null;
  }
}

