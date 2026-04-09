import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/resume.dart';
import 'career_network_dedupe_helper.dart';
import 'career_profile_service.dart';
import 'resume_experience_merge_service.dart';

/// 이력서 → 커리어 카드 자동 동기화 서비스
///
/// 설계서 §5 SSOT 규칙:
/// - 이력서 확정/수정 시 → 커리어 카드(스킬/네트워크) 동기화
/// - "나의 치과 네트워크"는 이력서 경력에서 자동 반영 (필수 자동화)
/// - 커리어 카드에서 스킬은 자유 수정 가능 (이력서와 분리 편집 허용)
///
/// 네트워크 매칭:
/// - 병원명 정규화 후 동일 + 시작 연·월 일치 → 업데이트
/// - `syncedFromResume` + 시작 연도 동일 + `areProbablySameClinic` (월·표기 차이)
/// - 그다음 `syncedFromResume` 이고 시작 연·월만 일치 → 업데이트 (폴백)
/// - 동기화 후 월별 dedupe + 유사 기간·유사 병원명 merge로 최신 1건 유지
class ResumeCareerSyncService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// 이력서 저장 시 호출 — 커리어 카드에 동기화
  static Future<void> syncFromResume(
    Resume resume, {
    bool syncSkills = true,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _syncNetwork(uid, resume.experiences);
      if (syncSkills) {
        await _syncSkills(uid, resume.skills);
      }
      debugPrint('✅ 이력서 → 커리어 카드 동기화 완료');
    } catch (e) {
      debugPrint('⚠️ ResumeCareerSyncService.syncFromResume error: $e');
    }
  }

  /// 이력서 경력 → careerNetwork 서브컬렉션 동기화
  static Future<void> _syncNetwork(
    String uid,
    List<ResumeExperience> experiences,
  ) async {
    final merged = ResumeExperienceMergeService.mergeSimilar(experiences);
    if (merged.isEmpty) return;

    final networkRef =
        _db.collection('users').doc(uid).collection('careerNetwork');

    // 기존 동기화 중복(같은 달 여러 행)을 먼저 정리해 매칭·폴백이 안정적으로 동작하도록 함
    await _dedupeSyncedSameMonth(networkRef);
    await CareerNetworkDedupeHelper.mergeSimilarNetworkEntries(networkRef);

    final existingSnap = await networkRef.get();
    final existing =
        existingSnap.docs.map(DentalNetworkEntry.fromDoc).toList();

    final consumedIds = <String>{};

    for (final exp in merged) {
      if (exp.clinicName.trim().isEmpty) continue;

      final startDate = _parseYearMonth(exp.start);
      if (startDate == null) continue;

      final endDate = exp.end == '재직중' ? null : _parseYearMonth(exp.end);

      DentalNetworkEntry? match = _findMatchByNormalizedName(
        existing,
        exp.clinicName,
        startDate,
        consumedIds,
      );

      match ??= _findMatchFuzzySyncedYear(
        existing,
        exp.clinicName,
        startDate,
        consumedIds,
      );

      match ??= _findSyncedFallback(
        existing,
        startDate,
        consumedIds,
      );

      final entryData = <String, dynamic>{
        'clinicName': exp.clinicName.trim(),
        'startDate': Timestamp.fromDate(startDate),
        'endDate': endDate != null ? Timestamp.fromDate(endDate) : null,
        'syncedFromResume': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (exp.tasks.isNotEmpty) {
        entryData['tags'] = exp.tasks.take(5).toList();
      }
      if (exp.tools.isNotEmpty) {
        entryData['acquiredSkills'] = exp.tools.take(5).toList();
      }

      final matched = match;
      if (matched != null) {
        final matchedId = matched.id;
        await networkRef.doc(matchedId).update(entryData);
        consumedIds.add(matchedId);
        final ix = existing.indexWhere((e) => e.id == matchedId);
        if (ix >= 0) {
          existing[ix] = DentalNetworkEntry(
            id: matchedId,
            clinicName: exp.clinicName.trim(),
            startDate: startDate,
            endDate: endDate,
            tags: exp.tasks.take(5).toList(),
            acquiredSkills: exp.tools.take(5).toList(),
            syncedFromResume: true,
          );
        }
      } else {
        entryData['createdAt'] = FieldValue.serverTimestamp();
        final newRef = await networkRef.add(entryData);
        consumedIds.add(newRef.id);
        existing.add(
          DentalNetworkEntry(
            id: newRef.id,
            clinicName: exp.clinicName.trim(),
            startDate: startDate,
            endDate: endDate,
            tags: exp.tasks.take(5).toList(),
            acquiredSkills: exp.tools.take(5).toList(),
            syncedFromResume: true,
          ),
        );
      }
    }

    await _dedupeSyncedSameMonth(networkRef);
    await CareerNetworkDedupeHelper.mergeSimilarNetworkEntries(networkRef);
  }

  /// 동일 연·월에 `syncedFromResume` 문서가 여러 개면 최신 1건만 남김 (OCR 중복 제거)
  ///
  /// 같은 달에 실제로 2곳을 다닌 경우는 드물며, 중복이면 보통 동일 근무의 표기 차이입니다.
  static Future<void> _dedupeSyncedSameMonth(
    CollectionReference<Map<String, dynamic>> networkRef,
  ) async {
    final snap = await networkRef.get();
    final byMonth = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};

    for (final doc in snap.docs) {
      final d = doc.data();
      if (d['syncedFromResume'] != true) continue;
      final ts = d['startDate'] as Timestamp?;
      if (ts == null) continue;
      final dt = ts.toDate();
      final key =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      byMonth.putIfAbsent(key, () => []).add(doc);
    }

    for (final list in byMonth.values) {
      if (list.length <= 1) continue;

      int compareDocs(
        QueryDocumentSnapshot<Map<String, dynamic>> a,
        QueryDocumentSnapshot<Map<String, dynamic>> b,
      ) {
        final ua = a.data()['updatedAt'] as Timestamp?;
        final ub = b.data()['updatedAt'] as Timestamp?;
        final ca = a.data()['createdAt'] as Timestamp?;
        final cb = b.data()['createdAt'] as Timestamp?;
        final ta = ua ?? ca;
        final tb = ub ?? cb;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      }

      list.sort(compareDocs);
      for (var i = 1; i < list.length; i++) {
        try {
          await networkRef.doc(list[i].id).delete();
        } catch (e) {
          debugPrint('⚠️ dedupe delete ${list[i].id}: $e');
        }
      }
    }
  }

  static Future<void> _syncSkills(
    String uid,
    List<ResumeSkill> resumeSkills,
  ) async {
    if (resumeSkills.isEmpty) return;

    final userRef = _db.collection('users').doc(uid);
    final doc = await userRef.get();
    final careerProfile =
        doc.data()?['careerProfile'] as Map<String, dynamic>? ?? {};
    final existingSkills =
        (careerProfile['skills'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
            ) ??
            {};

    final masterIds =
        CareerProfileService.skillMaster.map((m) => m['id'] as String).toSet();

    final nameToId = <String, String>{};
    for (final m in CareerProfileService.skillMaster) {
      nameToId[m['title'] as String] = m['id'] as String;
    }

    final updates = <String, dynamic>{};

    for (final skill in resumeSkills) {
      String? masterId;
      if (masterIds.contains(skill.id)) {
        masterId = skill.id;
      } else if (nameToId.containsKey(skill.name)) {
        masterId = nameToId[skill.name];
      }

      if (masterId == null) continue;

      final existing = existingSkills[masterId];
      if (existing != null &&
          existing['enabled'] == true &&
          existing['syncedFromResume'] != true) {
        continue;
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

  /// 비교용 병원명 (공백·흔한 구두점 제거 — OCR 표기 차이 완화)
  static String _normalizeClinicName(String raw) {
    var s = raw.trim();
    s = s.replaceAll(RegExp(r'\s+'), '');
    s = s.replaceAll(RegExp(r'[·•\-\(\)\[\]]'), '');
    return s;
  }

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

  static DentalNetworkEntry? _findMatchByNormalizedName(
    List<DentalNetworkEntry> entries,
    String clinicName,
    DateTime startDate,
    Set<String> consumedIds,
  ) {
    final target = _normalizeClinicName(clinicName);
    if (target.isEmpty) return null;

    for (final e in entries) {
      if (consumedIds.contains(e.id)) continue;
      if (_normalizeClinicName(e.clinicName) == target &&
          e.startDate.year == startDate.year &&
          e.startDate.month == startDate.month) {
        return e;
      }
    }
    return null;
  }

  /// 시작 연도 동일 + `syncedFromResume` + 병원명 유사(편집거리≤2 등) — 시작 월이 OCR마다 달라도 같은 행으로 갱신
  static DentalNetworkEntry? _findMatchFuzzySyncedYear(
    List<DentalNetworkEntry> entries,
    String clinicName,
    DateTime startDate,
    Set<String> consumedIds,
  ) {
    for (final e in entries) {
      if (consumedIds.contains(e.id)) continue;
      if (!e.syncedFromResume) continue;
      if (e.startDate.year != startDate.year) continue;
      if (CareerNetworkDedupeHelper.areProbablySameClinic(
            clinicName,
            e.clinicName,
          )) {
        return e;
      }
    }
    return null;
  }

  /// 이력서 동기화 행만 대상으로, 같은 시작 연·월 후보가 **정확히 1건**일 때만 갱신 대상으로 사용
  /// (후보가 2건 이상이면 같은 달 실제 근무 2곳 가능성을 열어 둠)
  static DentalNetworkEntry? _findSyncedFallback(
    List<DentalNetworkEntry> entries,
    DateTime startDate,
    Set<String> consumedIds,
  ) {
    final candidates = entries.where((e) {
      if (consumedIds.contains(e.id)) return false;
      if (!e.syncedFromResume) return false;
      return e.startDate.year == startDate.year &&
          e.startDate.month == startDate.month;
    }).toList();
    if (candidates.length == 1) return candidates.first;
    return null;
  }
}
