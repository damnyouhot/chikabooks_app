import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import '../models/job.dart';
import '../models/activity_log.dart';
import 'bond_score_service.dart';

class JobService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // ══════════════════════════════════════════════
  // 기존 메서드 (목록용)
  // ══════════════════════════════════════════════

  Future<List<Job>> fetchJobs({
    String careerFilter = '전체',
    String regionFilter = '전체',
    RangeValues? salaryRange,
  }) async {
    final snapshot =
        await _db
            .collection('jobs')
            .orderBy('postedAt', descending: true)
            .get();
    List<Job> jobs = snapshot.docs.map((d) => Job.fromDoc(d)).toList();

    if (careerFilter != '전체') {
      jobs = jobs.where((job) => job.career == careerFilter).toList();
    }
    if (regionFilter != '전체') {
      jobs = jobs.where((job) => job.address.contains(regionFilter)).toList();
    }
    if (salaryRange != null) {
      jobs =
          jobs.where((job) {
            final minSalary = job.salaryRange.first;
            final maxSalary = job.salaryRange.last;
            return maxSalary >= salaryRange.start &&
                minSalary <= salaryRange.end;
          }).toList();
    }

    return jobs;
  }

  Future<Job> fetchJob(String id) async {
    final doc = await _db.collection('jobs').doc(id).get();
    return Job.fromDoc(doc);
  }

  // ══════════════════════════════════════════════
  // ★ 새 메서드: 반경 기반 검색 (지도용)
  // ══════════════════════════════════════════════

  /// 사용자 위치 기준 반경 내 공고 조회
  Future<List<Job>> fetchJobsNearby(
    LatLng userLocation,
    double radiusKm, {
    String? positionFilter,
    Set<String>? conditions,
  }) async {
    try {
      // 1. 모든 공고 가져오기 (추후 GeoHash 최적화 가능)
      final snapshot =
          await _db
              .collection('jobs')
              .orderBy('postedAt', descending: true)
              .limit(200) // 성능을 위해 제한
              .get();

      List<Job> jobs = snapshot.docs.map((d) => Job.fromDoc(d)).toList();

      // 2. 반경 필터링
      jobs =
          jobs.where((job) {
            if (job.lat == 0 && job.lng == 0) return false;
            final distance = calculateDistance(
              userLocation,
              LatLng(job.lat, job.lng),
            );
            return distance <= radiusKm;
          }).toList();

      // 3. 직종 필터
      if (positionFilter != null && positionFilter != '전체') {
        jobs = jobs.where((job) => job.type == positionFilter).toList();
      }

      // 4. 조건칩 필터
      if (conditions != null && conditions.isNotEmpty) {
        jobs =
            jobs.where((job) {
              if (conditions.contains('신입가능') && job.career != '신입')
                return false;
              // 추후 benefits에서 조건 체크 가능
              return true;
            }).toList();
      }

      // 5. 정렬은 호출자가 직접 수행 (calculateDistance 제공)

      // 6. 거리순 정렬 (기본)
      jobs.sort((a, b) {
        final distA = calculateDistance(userLocation, LatLng(a.lat, a.lng));
        final distB = calculateDistance(userLocation, LatLng(b.lat, b.lng));
        return distA.compareTo(distB);
      });

      return jobs;
    } catch (e) {
      debugPrint('⚠️ fetchJobsNearby error: $e');
      return [];
    }
  }

  /// 두 지점 간 거리 계산 (km)
  double calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
          point1.latitude,
          point1.longitude,
          point2.latitude,
          point2.longitude,
        ) /
        1000; // 미터 → km
  }

  /// 마지막 방문 이후 신규 공고 수 조회
  Future<int> fetchNewJobsCountSince(DateTime lastVisit) async {
    try {
      final snapshot =
          await _db
              .collection('jobs')
              .where('postedAt', isGreaterThan: Timestamp.fromDate(lastVisit))
              .get();
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('⚠️ fetchNewJobsCountSince error: $e');
      return 0;
    }
  }

  /// ★ 신규 추가: 최근 24시간 내 신규 공고 요약 (카드용)
  Future<Map<String, dynamic>> getRecentJobsSummary({
    LatLng? userLocation,
    double radiusKm = 10.0,
  }) async {
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(hours: 24));

      // 최근 24시간 공고 조회
      final snapshot =
          await _db
              .collection('jobs')
              .where(
                'postedAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(yesterday),
              )
              .orderBy('postedAt', descending: true)
              .limit(50)
              .get();

      List<Job> jobs = snapshot.docs.map((d) => Job.fromDoc(d)).toList();

      // 위치 기반 필터링 (옵션)
      if (userLocation != null) {
        jobs =
            jobs.where((job) {
              if (job.lat == 0 && job.lng == 0) return false;
              final distance = calculateDistance(
                userLocation,
                LatLng(job.lat, job.lng),
              );
              return distance <= radiusKm;
            }).toList();
      }

      final count = jobs.length;
      final representativeName =
          jobs.isNotEmpty ? (jobs.first.companyName ?? '치과') : '치과';

      return {
        'count': count,
        'representativeName': representativeName,
        'otherCount': count > 1 ? count - 1 : 0,
      };
    } catch (e) {
      debugPrint('❌ getRecentJobsSummary 에러: $e');
      return {'count': 0, 'representativeName': '치과', 'otherCount': 0};
    }
  }

  // ══════════════════════════════════════════════
  // 사용자 위치 저장/조회
  // ══════════════════════════════════════════════

  /// 사용자 마지막 위치 저장
  Future<void> saveUserLocation(LatLng location) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _db.collection('users').doc(uid).update({
        'lastLocation': {
          'lat': location.latitude,
          'lng': location.longitude,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      });
    } catch (e) {
      debugPrint('⚠️ saveUserLocation error: $e');
    }
  }

  /// 사용자 마지막 위치 조회
  Future<LatLng?> getUserLocation() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    try {
      final doc = await _db.collection('users').doc(uid).get();
      final data = doc.data();
      if (data == null) return null;

      final lastLocation = data['lastLocation'] as Map<String, dynamic>?;
      if (lastLocation == null) return null;

      return LatLng(
        lastLocation['lat'] as double,
        lastLocation['lng'] as double,
      );
    } catch (e) {
      debugPrint('⚠️ getUserLocation error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════
  // 알림 설정
  // ══════════════════════════════════════════════

  /// 구인 알림 설정 조회
  Future<Map<String, dynamic>> getNotificationSettings() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return {'enabled': false, 'radiusKm': 3.0};
    }

    try {
      final doc = await _db.collection('users').doc(uid).get();
      final data = doc.data();
      if (data == null) return {'enabled': false, 'radiusKm': 3.0};

      final settings = data['jobNotifications'] as Map<String, dynamic>?;
      if (settings == null) return {'enabled': false, 'radiusKm': 3.0};

      return {
        'enabled': settings['enabled'] ?? false,
        'radiusKm': (settings['radiusKm'] ?? 3.0).toDouble(),
      };
    } catch (e) {
      debugPrint('⚠️ getNotificationSettings error: $e');
      return {'enabled': false, 'radiusKm': 3.0};
    }
  }

  /// 구인 알림 설정 저장
  Future<void> setNotificationSettings({
    required bool enabled,
    required double radiusKm,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _db.collection('users').doc(uid).update({
        'jobNotifications': {
          'enabled': enabled,
          'radiusKm': radiusKm,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      });
    } catch (e) {
      debugPrint('⚠️ setNotificationSettings error: $e');
    }
  }

  // ══════════════════════════════════════════════
  // 기존: 북마크 시스템
  // ══════════════════════════════════════════════

  Stream<List<String>> watchBookmarkedJobIds() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return [];
      return List<String>.from(doc.data()?['bookmarkedJobs'] ?? []);
    });
  }

  Future<void> bookmarkJob(String jobId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _db.collection('users').doc(uid).update({
        'bookmarkedJobs': FieldValue.arrayUnion([jobId]),
      });

      // ★ 북마크 포인트 적용
      await BondScoreService.applyEvent(uid, ActivityType.jobBookmark);

      debugPrint('✅ 북마크 추가 + 포인트 적용: $jobId');
    } catch (e) {
      debugPrint('⚠️ bookmarkJob error: $e');
    }
  }

  Future<void> unbookmarkJob(String jobId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({
      'bookmarkedJobs': FieldValue.arrayRemove([jobId]),
    });
  }

  Future<List<Job>> fetchBookmarkedJobs() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final userDoc = await _db.collection('users').doc(uid).get();
    final List<String> bookmarkedIds = List<String>.from(
      userDoc.data()?['bookmarkedJobs'] ?? [],
    );

    if (bookmarkedIds.isEmpty) return [];

    final jobDocs =
        await _db
            .collection('jobs')
            .where(FieldPath.documentId, whereIn: bookmarkedIds)
            .get();
    return jobDocs.docs.map((doc) => Job.fromDoc(doc)).toList();
  }

  // ══════════════════════════════════════════════
  // ★ 새 메서드: 관심 치과 시스템
  // ══════════════════════════════════════════════

  /// 관심 치과 목록 조회
  Future<List<Map<String, dynamic>>> getWatchedClinics() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    try {
      final doc = await _db.collection('users').doc(uid).get();
      final data = doc.data();
      if (data == null) return [];

      return List<Map<String, dynamic>>.from(data['watchedClinics'] ?? []);
    } catch (e) {
      debugPrint('⚠️ getWatchedClinics error: $e');
      return [];
    }
  }

  /// 관심 치과 추가
  Future<void> addWatchedClinic({
    required String clinicName,
    required double lat,
    required double lng,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _db.collection('users').doc(uid).update({
        'watchedClinics': FieldValue.arrayUnion([
          {
            'clinicName': clinicName,
            'lat': lat,
            'lng': lng,
            'addedAt': FieldValue.serverTimestamp(),
          },
        ]),
      });
    } catch (e) {
      debugPrint('⚠️ addWatchedClinic error: $e');
    }
  }

  /// 관심 치과 제거
  Future<void> removeWatchedClinic(String clinicName) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final clinics = await getWatchedClinics();
      final updatedClinics =
          clinics
              .where((clinic) => clinic['clinicName'] != clinicName)
              .toList();

      await _db.collection('users').doc(uid).update({
        'watchedClinics': updatedClinics,
      });
    } catch (e) {
      debugPrint('⚠️ removeWatchedClinic error: $e');
    }
  }

  // ══════════════════════════════════════════════
  // 지원 관리
  // ══════════════════════════════════════════════

  /// 사용자 프로필 조회 (지원 시 자동 입력용)
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;

      final data = doc.data();
      return {
        'name': data?['nickname'] ?? data?['name'] ?? '',
        'phone': data?['phone'] ?? '',
      };
    } catch (e) {
      debugPrint('⚠️ getUserProfile error: $e');
      return null;
    }
  }

  /// 지원 제출
  Future<void> submitApplication({
    required String jobId,
    required String applicantUid,
    required String name,
    required String phone,
    required String career,
    String message = '',
  }) async {
    try {
      final applicationData = {
        'jobId': jobId,
        'applicantUid': applicantUid,
        'name': name,
        'phone': phone,
        'career': career,
        'message': message,
        'status': 'pending', // pending, viewed, accepted, rejected
        'appliedAt': FieldValue.serverTimestamp(),
      };

      // applications 컬렉션에 저장
      await _db.collection('applications').add(applicationData);

      // 사용자의 지원 내역에 추가
      await _db.collection('users').doc(applicantUid).update({
        'appliedJobs': FieldValue.arrayUnion([jobId]),
      });

      debugPrint('✅ 지원 완료: $jobId');
    } catch (e) {
      debugPrint('⚠️ submitApplication error: $e');
      rethrow;
    }
  }

  /// 내 지원 내역 조회
  Future<List<Map<String, dynamic>>> getMyApplications() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    try {
      final snapshot =
          await _db
              .collection('applications')
              .where('applicantUid', isEqualTo: uid)
              .orderBy('appliedAt', descending: true)
              .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      debugPrint('⚠️ getMyApplications error: $e');
      return [];
    }
  }

  /// 지원 여부 확인
  Future<bool> hasApplied(String jobId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    try {
      final doc = await _db.collection('users').doc(uid).get();
      final appliedJobs = List<String>.from(doc.data()?['appliedJobs'] ?? []);
      return appliedJobs.contains(jobId);
    } catch (e) {
      debugPrint('⚠️ hasApplied error: $e');
      return false;
    }
  }
}
