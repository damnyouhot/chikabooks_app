import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/job_stats_daily.dart';

/// 공고 조회수/지원수 집계 서비스
///
/// 설계서 2.4.3 기준:
/// - Views: 공고 상세 열람 수 (uid + date 단위 unique)
/// - Applies: 지원 제출 수
/// - 일별 조회수 라인 차트 / 비교표 데이터
class JobStatsService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('jobStatsDaily');

  /// 오늘 날짜키 (yyyyMMdd)
  static String get _todayKey {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }

  /// 문서 ID: {jobId}_{yyyyMMdd}
  static String _docId(String jobId, String dateKey) => '${jobId}_$dateKey';

  // ══════════════════════════════════════════════
  // 조회수 기록
  // ══════════════════════════════════════════════

  /// 공고 상세 열람 시 호출 — 조회수 +1
  ///
  /// 로그인 유저: uid + date 조합으로 unique 집계
  static Future<void> recordView(String jobId) async {
    final uid = _auth.currentUser?.uid;
    final dateKey = _todayKey;
    final docId = _docId(jobId, dateKey);

    try {
      final ref = _col.doc(docId);
      final snap = await ref.get();

      if (!snap.exists) {
        // 첫 조회 → 문서 생성
        await ref.set({
          'jobId': jobId,
          'dateKey': dateKey,
          'views': 1,
          'uniqueViews': 1,
          'applies': 0,
          'viewedUids': uid != null ? [uid] : [],
        });
      } else {
        final data = snap.data()!;
        final viewedUids = List<String>.from(data['viewedUids'] ?? []);
        final isUnique = uid != null && !viewedUids.contains(uid);

        final updates = <String, dynamic>{
          'views': FieldValue.increment(1),
        };
        if (isUnique) {
          updates['uniqueViews'] = FieldValue.increment(1);
          updates['viewedUids'] = FieldValue.arrayUnion([uid]);
        }
        await ref.update(updates);
      }
    } catch (e) {
      debugPrint('⚠️ recordView error: $e');
    }
  }

  /// 지원 제출 시 호출 — applies +1
  static Future<void> recordApply(String jobId) async {
    final dateKey = _todayKey;
    final docId = _docId(jobId, dateKey);

    try {
      final ref = _col.doc(docId);
      final snap = await ref.get();

      if (!snap.exists) {
        await ref.set({
          'jobId': jobId,
          'dateKey': dateKey,
          'views': 0,
          'uniqueViews': 0,
          'applies': 1,
          'viewedUids': [],
        });
      } else {
        await ref.update({'applies': FieldValue.increment(1)});
      }
    } catch (e) {
      debugPrint('⚠️ recordApply error: $e');
    }
  }

  // ══════════════════════════════════════════════
  // 통계 조회
  // ══════════════════════════════════════════════

  /// 특정 공고의 일별 통계 조회 (최근 N일)
  static Future<List<JobStatsDaily>> fetchDailyStats(
    String jobId, {
    int days = 30,
  }) async {
    try {
      final from = DateTime.now().subtract(Duration(days: days));
      final fromKey =
          '${from.year}${from.month.toString().padLeft(2, '0')}${from.day.toString().padLeft(2, '0')}';

      final snap = await _col
          .where('jobId', isEqualTo: jobId)
          .where('dateKey', isGreaterThanOrEqualTo: fromKey)
          .orderBy('dateKey')
          .get();

      return snap.docs.map((d) => JobStatsDaily.fromDoc(d)).toList();
    } catch (e) {
      debugPrint('⚠️ fetchDailyStats error: $e');
      return [];
    }
  }

  /// 특정 공고의 합산 통계 (total views, unique views, applies)
  static Future<Map<String, int>> fetchTotalStats(String jobId) async {
    try {
      final snap = await _col
          .where('jobId', isEqualTo: jobId)
          .get();

      int totalViews = 0;
      int totalUnique = 0;
      int totalApplies = 0;

      for (final doc in snap.docs) {
        final s = JobStatsDaily.fromDoc(doc);
        totalViews += s.views;
        totalUnique += s.uniqueViews;
        totalApplies += s.applies;
      }

      return {
        'views': totalViews,
        'uniqueViews': totalUnique,
        'applies': totalApplies,
      };
    } catch (e) {
      debugPrint('⚠️ fetchTotalStats error: $e');
      return {'views': 0, 'uniqueViews': 0, 'applies': 0};
    }
  }

  /// 여러 공고의 합산 통계 (비교표용)
  static Future<List<Map<String, dynamic>>> fetchComparisonStats(
    List<String> jobIds,
  ) async {
    final results = <Map<String, dynamic>>[];

    for (final jobId in jobIds) {
      final total = await fetchTotalStats(jobId);
      final recent = await _fetchRecentChange(jobId, 7);

      results.add({
        'jobId': jobId,
        ...total,
        'conversion': total['views']! > 0
            ? (total['applies']! / total['views']! * 100)
            : 0.0,
        'recentChange': recent,
      });
    }

    return results;
  }

  /// 최근 N일 대비 변화율 (%)
  static Future<double> _fetchRecentChange(String jobId, int days) async {
    try {
      final now = DateTime.now();
      final recentStart = now.subtract(Duration(days: days));
      final previousStart = now.subtract(Duration(days: days * 2));

      final recentKey =
          '${recentStart.year}${recentStart.month.toString().padLeft(2, '0')}${recentStart.day.toString().padLeft(2, '0')}';
      final previousKey =
          '${previousStart.year}${previousStart.month.toString().padLeft(2, '0')}${previousStart.day.toString().padLeft(2, '0')}';

      final recentSnap = await _col
          .where('jobId', isEqualTo: jobId)
          .where('dateKey', isGreaterThanOrEqualTo: recentKey)
          .get();

      final previousSnap = await _col
          .where('jobId', isEqualTo: jobId)
          .where('dateKey', isGreaterThanOrEqualTo: previousKey)
          .where('dateKey', isLessThan: recentKey)
          .get();

      final recentViews = recentSnap.docs.fold<int>(
        0,
        (sum, d) => sum + ((d.data()['views'] as int?) ?? 0),
      );
      final previousViews = previousSnap.docs.fold<int>(
        0,
        (sum, d) => sum + ((d.data()['views'] as int?) ?? 0),
      );

      if (previousViews == 0) return recentViews > 0 ? 100.0 : 0.0;
      return ((recentViews - previousViews) / previousViews * 100);
    } catch (e) {
      return 0.0;
    }
  }
}

