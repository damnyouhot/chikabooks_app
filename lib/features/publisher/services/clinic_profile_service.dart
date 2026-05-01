import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../models/clinic_profile.dart';
import '../../../services/job_draft_service.dart';

/// 치과 프로필 CRUD 서비스
///
/// Firestore: `clinics_accounts/{uid}/clinic_profiles/{profileId}`
/// 1 계정 → N 치과(지점) 구조를 지원한다.
class ClinicProfileService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('clinics_accounts').doc(uid).collection('clinic_profiles');

  // ── 조회 ──────────────────────────────────────────────

  /// 전체 프로필 목록 (최근 생성순)
  static Future<List<ClinicProfile>> getProfiles() async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final snap = await _col(uid).orderBy('createdAt', descending: true).get();
      return snap.docs
          .map((d) => ClinicProfile.fromDoc(d, ownerUid: uid))
          .toList();
    } catch (e) {
      debugPrint('⚠️ ClinicProfileService.getProfiles: $e');
      return [];
    }
  }

  /// 프로필 목록 실시간 스트림
  ///
  /// [uid] 가 주어지면 그 사용자에 대한 stream 을 만든다 (계정 격리).
  /// 주어지지 않으면 호출 시점의 currentUser 를 사용한다(레거시 호환).
  static Stream<List<ClinicProfile>> watchProfiles({String? uid}) {
    final effectiveUid = uid ?? _uid;
    if (effectiveUid == null) return Stream.value([]);
    return _watchProfilesFor(effectiveUid);
  }

  static Stream<List<ClinicProfile>> _watchProfilesFor(String uid) {
    return _col(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((d) => ClinicProfile.fromDoc(d, ownerUid: uid))
              .toList();
        })
        .transform(
          StreamTransformer.fromHandlers(
            handleError: (
              Object e,
              StackTrace st,
              EventSink<List<ClinicProfile>> sink,
            ) {
              debugPrint('⚠️ ClinicProfileService.watchProfiles: $e');
              sink.addError(e, st);
            },
          ),
        );
  }

  /// 단일 프로필 실시간 스트림 (사업자 인증 상태 반영용)
  static Stream<ClinicProfile?> watchProfile(String profileId) {
    final uid = _uid;
    if (uid == null) return Stream.value(null);
    return _col(uid).doc(profileId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return ClinicProfile.fromDoc(snap, ownerUid: uid);
    });
  }

  /// 단일 프로필 조회
  static Future<ClinicProfile?> getProfile(String profileId) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final doc = await _col(uid).doc(profileId).get();
      if (!doc.exists) return null;
      return ClinicProfile.fromDoc(doc, ownerUid: uid);
    } catch (e) {
      debugPrint('⚠️ ClinicProfileService.getProfile: $e');
      return null;
    }
  }

  /// 프로필이 1개뿐이면 자동 선택용으로 반환, 0개면 null
  static Future<ClinicProfile?> getDefaultProfile() async {
    final profiles = await getProfiles();
    if (profiles.length == 1) return profiles.first;
    return null;
  }

  /// 공고에 자동 연결할 기본 지점.
  ///
  /// 우선순위:
  /// 1. 공고 게시 가능한(verified/provisional) 지점
  /// 2. 이름/주소 등 식별 정보가 있는 지점
  /// 3. 빈 지점
  static Future<ClinicProfile?> getPreferredProfileForJob() async {
    final profiles = await getProfiles();
    if (profiles.isEmpty) return null;
    final publishable = profiles.where((p) => p.canPublishJobs).toList();
    if (publishable.isNotEmpty) return publishable.first;
    final identified =
        profiles
            .where(
              (p) =>
                  p.effectiveName.trim().isNotEmpty ||
                  p.address.trim().isNotEmpty ||
                  p.ownerName.trim().isNotEmpty,
            )
            .toList();
    if (identified.isNotEmpty) return identified.first;
    return profiles.first;
  }

  /// 프로필 개수
  static Future<int> getProfileCount() async {
    final uid = _uid;
    if (uid == null) return 0;
    try {
      final snap = await _col(uid).count().get();
      return snap.count ?? 0;
    } catch (e) {
      debugPrint('⚠️ ClinicProfileService.getProfileCount: $e');
      return 0;
    }
  }

  // ── 생성 ──────────────────────────────────────────────

  /// 공고 편집기용: 프로필이 없으면 기본 프로필을 만들고 드래프트에 `clinicProfileId`를 연결한다.
  static Future<ClinicProfile?> ensureDefaultProfileForDraft({
    required String draftId,
    String? existingClinicProfileId,
  }) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      await migrateIfNeeded();
      if (existingClinicProfileId != null &&
          existingClinicProfileId.isNotEmpty) {
        final existing = await getProfile(existingClinicProfileId);
        if (existing != null) return existing;
      }
      final selected = await getPreferredProfileForJob();
      if (selected == null) {
        final newId = await createProfile();
        if (newId == null) return null;
        await JobDraftService.saveDraft(
          draftId: draftId,
          formData: {'clinicProfileId': newId},
        );
        return getProfile(newId);
      }
      await JobDraftService.saveDraft(
        draftId: draftId,
        formData: {'clinicProfileId': selected.id},
      );
      return selected;
    } catch (e) {
      debugPrint('⚠️ ClinicProfileService.ensureDefaultProfileForDraft: $e');
      return null;
    }
  }

  /// 새 치과 프로필 생성 → profileId 반환
  static Future<String?> createProfile({
    String clinicName = '',
    String displayName = '',
    String address = '',
    String ownerName = '',
    String phone = '',
  }) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final data = {
        'clinicName': clinicName,
        'displayName': displayName.isNotEmpty ? displayName : clinicName,
        'address': address,
        'ownerName': ownerName,
        'phone': phone,
        'businessVerification': const BusinessVerification().toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final ref = await _col(uid).add(data);
      debugPrint('✅ ClinicProfileService: 프로필 생성 ${ref.id}');
      return ref.id;
    } catch (e) {
      debugPrint('⚠️ ClinicProfileService.createProfile: $e');
      return null;
    }
  }

  static Future<bool> deleteProfile(String profileId) async {
    final uid = _uid;
    if (uid == null || profileId.isEmpty) return false;
    try {
      await _col(uid).doc(profileId).delete();
      return true;
    } catch (e) {
      debugPrint('⚠️ ClinicProfileService.deleteProfile: $e');
      return false;
    }
  }

  // ── 수정 ──────────────────────────────────────────────

  /// 프로필 정보 수정 (businessVerification 제외 — 서버만)
  static Future<bool> updateProfile(
    String profileId, {
    String? clinicName,
    String? displayName,
    String? address,
    String? ownerName,
    String? phone,
  }) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (clinicName != null) updates['clinicName'] = clinicName;
      if (displayName != null) updates['displayName'] = displayName;
      if (address != null) updates['address'] = address;
      if (ownerName != null) updates['ownerName'] = ownerName;
      if (phone != null) updates['phone'] = phone;

      await _col(uid).doc(profileId).update(updates);
      return true;
    } catch (e) {
      debugPrint('⚠️ ClinicProfileService.updateProfile: $e');
      return false;
    }
  }

  // ── Lazy Migration ────────────────────────────────────

  /// 기존 clinics_accounts 루트에 치과 정보가 있고
  /// clinic_profiles가 비어 있으면 첫 번째 프로필을 자동 생성한다.
  /// 반환: 마이그레이션이 실행되었으면 true
  static Future<bool> migrateIfNeeded() async {
    final uid = _uid;
    if (uid == null) return false;

    try {
      final masterDoc = await _db.collection('clinics_accounts').doc(uid).get();
      if (!masterDoc.exists) return false;
      final data = masterDoc.data()!;

      // 이미 마이그레이션 완료
      if (data['profilesMigrated'] == true) return false;

      // clinic_profiles가 이미 존재하는지 확인
      final existingCount = await getProfileCount();
      if (existingCount > 0) {
        await _db.collection('clinics_accounts').doc(uid).update({
          'profilesMigrated': true,
        });
        return false;
      }

      // 기존 데이터에서 치과 정보 추출
      final clinicName = data['clinicName'] as String? ?? '';
      final address = data['address'] as String? ?? '';
      final ownerName = data['managerName'] as String? ?? '';
      final phone = data['phone'] as String? ?? '';
      final bizNo = data['businessNumber'] as String? ?? '';
      final clinicVerified = data['clinicVerified'] as bool? ?? false;

      if (clinicName.isEmpty && address.isEmpty && bizNo.isEmpty) {
        // 빈 데이터 → 마이그레이션 불필요
        await _db.collection('clinics_accounts').doc(uid).update({
          'profilesMigrated': true,
        });
        return false;
      }

      // 첫 번째 프로필 생성
      final profileData = {
        'clinicName': clinicName,
        'displayName': clinicName,
        'address': address,
        'ownerName': ownerName,
        'phone': phone,
        'businessVerification': {
          'status': clinicVerified ? 'verified' : 'none',
          'bizNo': bizNo,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _col(uid).add(profileData);

      // 마이그레이션 완료 플래그
      await _db.collection('clinics_accounts').doc(uid).update({
        'profilesMigrated': true,
      });

      debugPrint('✅ ClinicProfileService: Lazy Migration 완료 ($uid)');
      return true;
    } catch (e) {
      debugPrint('⚠️ ClinicProfileService.migrateIfNeeded: $e');
      return false;
    }
  }
}
