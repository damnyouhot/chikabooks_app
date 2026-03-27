import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 근무 상태 종류
enum WorkStatus {
  student('재학 중'),
  working('재직 중'),
  leave('휴직 중'),
  seeking('구직 중');

  const WorkStatus(this.label);
  final String label;
}

/// 온보딩 Step4에서 수집한 정보 저장 서비스
class OnboardingWorkplaceService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// users/{uid} 에 onboarding 정보 저장 +
  /// careerProfile.identity 업데이트 +
  /// careerNetwork 에 첫 번째 항목 추가
  static Future<void> saveWorkplaceInfo({
    required WorkStatus status,
    required String placeName, // 치과명 또는 학교명
    List<String> specialtyTags = const [],
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    final isStudent = status == WorkStatus.student;
    final tags =
        isStudent
            ? <String>[]
            : specialtyTags.map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

    try {
      // 1) users/{uid} 기본 정보 저장
      await _db.collection('users').doc(uid).set({
        'onboardingWorkStatus': status.name,
        'onboardingPlaceName': placeName.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2) careerProfile.identity 업데이트
      final careerStatus = _mapToCareerStatus(status);
      await _db.collection('users').doc(uid).set({
        'careerProfile': {
          'identity': {
            'status': careerStatus,
            'clinicName': isStudent ? '' : placeName.trim(),
            'currentStartDate': Timestamp.fromDate(
              DateTime(now.year, now.month, 1),
            ),
            'specialtyTags': tags,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        },
      }, SetOptions(merge: true));

      // 3) careerNetwork 에 첫 번째 항목 추가 (학생이면 스킵)
      if (!isStudent && placeName.trim().isNotEmpty) {
        final networkRef = _db
            .collection('users')
            .doc(uid)
            .collection('careerNetwork');

        // 이미 동일한 치과명이 있으면 중복 추가하지 않음
        final existing =
            await networkRef
                .where('clinicName', isEqualTo: placeName.trim())
                .limit(1)
                .get();

        if (existing.docs.isEmpty) {
          await networkRef.add({
            'clinicName': placeName.trim(),
            'startDate': Timestamp.fromDate(
              DateTime(now.year, now.month, 1),
            ),
            'endDate':
                status == WorkStatus.seeking
                    ? Timestamp.fromDate(DateTime(now.year, now.month, 1))
                    : null,
            'tags': List<String>.from(tags),
            'acquiredSkills': <String>[],
            'syncedFromOnboarding': true,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      debugPrint('✅ OnboardingWorkplaceService: 저장 완료 (${status.name} / $placeName)');
    } catch (e) {
      debugPrint('⚠️ OnboardingWorkplaceService.saveWorkplaceInfo 실패: $e');
      rethrow;
    }
  }

  static String _mapToCareerStatus(WorkStatus s) {
    switch (s) {
      case WorkStatus.student:
        return 'student';
      case WorkStatus.working:
        return 'working';
      case WorkStatus.leave:
        return 'leave';
      case WorkStatus.seeking:
        return 'seeking';
    }
  }
}

