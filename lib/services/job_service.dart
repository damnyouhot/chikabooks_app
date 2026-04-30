import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../data/mock_jobs.dart';
import '../models/job.dart';

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
            .orderBy('createdAt', descending: true)
            .get();
    List<Job> jobs =
        snapshot.docs
            .map((d) => Job.fromDoc(d))
            .where((j) => j.isListedInApp)
            .toList();

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

  /// Firestore 없이 목업/플레이스홀더만 사용 (상세 화면 등 안전망)
  Job jobOfflineFallback(String id) => _jobFetchFallback(id);

  /// Firestore 미연결·권한 거부·문서 없음·파싱 실패 시에도 항상 [Job] 반환 (무한 로딩 방지)
  Job _jobFetchFallback(String id) {
    final mock = findMockJobById(id);
    if (mock != null) return mock;
    return Job.fromJson({
      'postedAt': Timestamp.now(),
      'title': '공고를 찾을 수 없어요',
      'clinicName': '',
      'career': '미정',
      'salaryRange': [0, 0],
      'details':
          '삭제되었거나 주소가 잘못되었을 수 있어요. '
          '로그인 상태와 네트워크를 확인해 주세요.',
      'benefits': <String>[],
      'images': <String>[],
    }, docId: id);
  }

  Future<Job> fetchJob(String id) async {
    // 목업 공고는 Firestore 조회 없이 즉시 로컬 데이터 사용 (불필요한 네트워크 지연 방지)
    if (id.startsWith('mock_')) {
      return _jobFetchFallback(id);
    }

    DocumentSnapshot<Map<String, dynamic>>? doc;
    try {
      doc = await _db.collection('jobs').doc(id).get();
    } catch (e, st) {
      debugPrint('⚠️ fetchJob get($id): $e\n$st');
      return _jobFetchFallback(id);
    }

    if (doc.exists && doc.data() != null) {
      try {
        return Job.fromDoc(doc);
      } catch (e, st) {
        debugPrint('⚠️ fetchJob fromDoc($id): $e\n$st');
        return _jobFetchFallback(id);
      }
    }

    return _jobFetchFallback(id);
  }

  // ══════════════════════════════════════════════
  // ★ 페이지네이션 (Level 3 무한 스크롤용)
  // ══════════════════════════════════════════════

  /// Firestore 커서 기반 페이지 단위 공고 조회
  ///
  /// [pageSize] 한 번에 가져올 최대 건수
  /// [startAfter] 이전 페이지의 마지막 DocumentSnapshot (첫 페이지는 null)
  ///
  /// 반환 타입: (jobs, lastDoc, hasMore)
  Future<({List<Job> jobs, DocumentSnapshot? lastDoc, bool hasMore})>
  fetchJobsPaged({
    int pageSize = 15,
    DocumentSnapshot? startAfter,
    int? jobLevel,
  }) async {
    Query<Map<String, dynamic>> q = _db
        .collection('jobs')
        .orderBy('createdAt', descending: true)
        .limit(pageSize);

    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }

    final snap = await q.get();
    final jobs =
        snap.docs
            .map((d) => Job.fromDoc(d))
            .where((j) => j.isListedInApp)
            .where((j) => jobLevel == null || j.jobLevel == jobLevel)
            .toList();
    final lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
    final hasMore = snap.docs.length >= pageSize;

    return (jobs: jobs, lastDoc: lastDoc, hasMore: hasMore);
  }

  /// A/B 클래스처럼 상단 고정 노출되는 실제 공고를 가져온다.
  ///
  /// 복합 인덱스 없이 동작하도록 최신 공고 묶음을 받은 뒤 클라이언트에서
  /// `jobLevel`을 걸러낸다. 현재 앱 노출 상한은 A 8개, B 10개다.
  Future<List<Job>> fetchHighlightedJobs({
    required int jobLevel,
    required int limit,
  }) async {
    try {
      final snap =
          await _db
              .collection('jobs')
              .orderBy('createdAt', descending: true)
              .limit(120)
              .get();
      final jobs =
          snap.docs
              .map((d) => Job.fromDoc(d))
              .where((j) => j.isListedInApp && j.jobLevel == jobLevel)
              .toList();
      jobs.sort((a, b) => b.postedAt.compareTo(a.postedAt));
      return jobs.take(limit).toList();
    } catch (e) {
      debugPrint('⚠️ fetchHighlightedJobs(level=$jobLevel) error: $e');
      return [];
    }
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
              .orderBy('createdAt', descending: true)
              .limit(200) // 성능을 위해 제한
              .get();

      List<Job> jobs =
          snapshot.docs
              .map((d) => Job.fromDoc(d))
              .where((j) => j.isListedInApp)
              .toList();

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
              if (conditions.contains('신입가능') && job.career != '신입') {
                return false;
              }
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
              .where('createdAt', isGreaterThan: Timestamp.fromDate(lastVisit))
              .get();
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('⚠️ fetchNewJobsCountSince error: $e');
      return 0;
    }
  }

  /// 홈 카드용 구인 요약 — 최신 8개만 조회 (빠른 로드)
  ///
  /// 100개 전체 다운로드 → 8개로 교체:
  ///   - count < 8 이면 정확한 수 표시
  ///   - count == 8 이면 "8개 이상" 으로 표시 (hasMore=true 반환)
  Future<Map<String, dynamic>> getRecentJobsSummary({
    LatLng? userLocation,
    double radiusKm = 10.0,
  }) async {
    const kPreviewLimit = 8;
    try {
      // 캐시 우선: 콜드 스타트 시 Firestore 연결 대기 없이 즉시 반환
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _db
            .collection('jobs')
            .orderBy('createdAt', descending: true)
            .limit(kPreviewLimit)
            .get(const GetOptions(source: Source.cache));
        if (snapshot.docs.isEmpty) throw Exception('cache empty');
      } catch (_) {
        snapshot =
            await _db
                .collection('jobs')
                .orderBy('createdAt', descending: true)
                .limit(kPreviewLimit)
                .get();
      }

      List<Job> jobs =
          snapshot.docs
              .map((d) => Job.fromDoc(d))
              .where((j) => j.isListedInApp)
              .toList();

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
      final hasMore = count >= kPreviewLimit; // 8개 채워졌으면 더 있을 수 있음
      final clinicName =
          jobs.isNotEmpty
              ? (jobs.first.clinicName.isNotEmpty
                  ? jobs.first.clinicName
                  : '치과')
              : '치과';

      return {'count': count, 'hasMore': hasMore, 'clinicName': clinicName};
    } catch (e) {
      debugPrint('❌ getRecentJobsSummary 에러: $e');
      return {'count': 0, 'hasMore': false, 'clinicName': '치과'};
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

      debugPrint('✅ 북마크 추가: $jobId');
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
