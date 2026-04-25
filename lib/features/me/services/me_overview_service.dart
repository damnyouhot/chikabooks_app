import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../services/job_stats_service.dart';

/// "한눈에 보기" 화면용 집계 결과
class MeOverviewSnapshot {
  final int totalViews30d;
  final int totalUniqueViews30d;
  final int totalApplies30d;
  final double conversionRate30d;

  /// 검수 중 공고 수 (status == 'pending')
  final int pendingJobs;

  /// 게시 중 공고 수 (status == 'active')
  final int activeJobs;

  /// 마감 임박 공고 수 (closingDate가 D-3 이내, 게시중인 것)
  final int expiringJobs;

  /// 신규 지원자 (24시간 내, 미열람) — Sprint 1에선 24시간 내 지원만 카운트
  final int recentApplicants24h;

  /// 게시자 본인이 보유한 지점 수
  final int branchCount;

  /// 사업자 인증 완료된 지점 수
  final int verifiedBranchCount;

  const MeOverviewSnapshot({
    required this.totalViews30d,
    required this.totalUniqueViews30d,
    required this.totalApplies30d,
    required this.conversionRate30d,
    required this.pendingJobs,
    required this.activeJobs,
    required this.expiringJobs,
    required this.recentApplicants24h,
    required this.branchCount,
    required this.verifiedBranchCount,
  });

  static const empty = MeOverviewSnapshot(
    totalViews30d: 0,
    totalUniqueViews30d: 0,
    totalApplies30d: 0,
    conversionRate30d: 0,
    pendingJobs: 0,
    activeJobs: 0,
    expiringJobs: 0,
    recentApplicants24h: 0,
    branchCount: 0,
    verifiedBranchCount: 0,
  );
}

/// /me Overview 데이터 집계 — Sprint 1: 단순 합산형
///
/// Sprint 7에서 `meDailyKpi/{uid}_{yyyyMMdd}` 사전 집계 문서로
/// 옮기는 것을 권장 (현재는 jobs 수가 적다는 가정).
class MeOverviewService {
  MeOverviewService._();

  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// [branchId]가 주어지면 해당 지점 공고만 집계, null이면 전체
  ///
  /// [ownerUid] 를 주입하면 그 사용자 기준으로 집계한다 (계정 격리).
  static Future<MeOverviewSnapshot> fetch({
    String? branchId,
    String? ownerUid,
  }) async {
    final uid = ownerUid ?? _auth.currentUser?.uid;
    if (uid == null) return MeOverviewSnapshot.empty;

    try {
      // 1. 내 공고 목록
      Query<Map<String, dynamic>> q =
          _db.collection('jobs').where('createdBy', isEqualTo: uid);
      if (branchId != null) {
        q = q.where('clinicProfileId', isEqualTo: branchId);
      }
      final jobsSnap = await q.get();
      final jobs = jobsSnap.docs;

      int pending = 0;
      int active = 0;
      int expiring = 0;
      final now = DateTime.now();
      final d3 = now.add(const Duration(days: 3));
      final jobIds = <String>[];

      for (final doc in jobs) {
        final data = doc.data();
        final status = data['status'] as String? ?? 'pending';
        if (status == 'pending') pending++;
        if (status == 'active') {
          active++;
          final closing = (data['closingDate'] as Timestamp?)?.toDate();
          final isAlways = data['isAlwaysHiring'] as bool? ?? false;
          if (!isAlways && closing != null && closing.isBefore(d3)) {
            expiring++;
          }
        }
        jobIds.add(doc.id);
      }

      // 2. 30일 누적 통계 — 공고별 fetchTotalStats 합산 (간단형)
      int views = 0;
      int unique = 0;
      int applies = 0;
      for (final id in jobIds) {
        final t = await JobStatsService.fetchTotalStats(id);
        views += t['views'] ?? 0;
        unique += t['uniqueViews'] ?? 0;
        applies += t['applies'] ?? 0;
      }
      final conv = views > 0 ? (applies / views * 100) : 0.0;

      // 3. 최근 24시간 신규 지원자
      int recent24h = 0;
      if (jobIds.isNotEmpty) {
        final since = Timestamp.fromDate(
          now.subtract(const Duration(hours: 24)),
        );
        // whereIn 은 30개 제한이 있으므로 청크 단위로 분할
        for (var i = 0; i < jobIds.length; i += 10) {
          final chunk = jobIds.sublist(
              i, i + 10 > jobIds.length ? jobIds.length : i + 10);
          final aSnap = await _db
              .collection('applications')
              .where('jobId', whereIn: chunk)
              .where('createdAt', isGreaterThan: since)
              .get();
          recent24h += aSnap.size;
        }
      }

      // 4. 지점·인증 카운트
      final profSnap = await _db
          .collection('clinics_accounts')
          .doc(uid)
          .collection('clinic_profiles')
          .get();
      int branches = profSnap.size;
      int verified = 0;
      for (final p in profSnap.docs) {
        final bv = (p.data()['businessVerification']
            as Map<String, dynamic>?);
        if ((bv?['status'] as String?) == 'verified') verified++;
      }

      return MeOverviewSnapshot(
        totalViews30d: views,
        totalUniqueViews30d: unique,
        totalApplies30d: applies,
        conversionRate30d: conv,
        pendingJobs: pending,
        activeJobs: active,
        expiringJobs: expiring,
        recentApplicants24h: recent24h,
        branchCount: branches,
        verifiedBranchCount: verified,
      );
    } catch (e) {
      debugPrint('⚠️ MeOverviewService.fetch: $e');
      return MeOverviewSnapshot.empty;
    }
  }
}
