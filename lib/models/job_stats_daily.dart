import 'package:cloud_firestore/cloud_firestore.dart';

/// 공고 일별 통계
/// Firestore 경로: `jobStatsDaily/{jobId}_{yyyymmdd}`
class JobStatsDaily {
  final String id; // jobId_yyyymmdd
  final String jobId;
  final String dateKey; // yyyymmdd
  final int views;
  final int uniqueViews;
  final int applies;

  const JobStatsDaily({
    required this.id,
    required this.jobId,
    required this.dateKey,
    this.views = 0,
    this.uniqueViews = 0,
    this.applies = 0,
  });

  factory JobStatsDaily.fromMap(Map<String, dynamic> data,
      {required String id}) {
    // id 형식: {jobId}_{yyyymmdd}
    final parts = id.split('_');
    final jobId = parts.length > 1 ? parts.sublist(0, parts.length - 1).join('_') : '';
    final dateKey = parts.isNotEmpty ? parts.last : '';

    return JobStatsDaily(
      id: id,
      jobId: data['jobId'] as String? ?? jobId,
      dateKey: data['dateKey'] as String? ?? dateKey,
      views: data['views'] as int? ?? 0,
      uniqueViews: data['uniqueViews'] as int? ?? 0,
      applies: data['applies'] as int? ?? 0,
    );
  }

  factory JobStatsDaily.fromDoc(DocumentSnapshot doc) {
    return JobStatsDaily.fromMap(
      doc.data() as Map<String, dynamic>,
      id: doc.id,
    );
  }

  /// 전환율 (applies / views)
  double get conversionRate =>
      views > 0 ? (applies / views * 100) : 0;

  Map<String, dynamic> toMap() => {
        'jobId': jobId,
        'dateKey': dateKey,
        'views': views,
        'uniqueViews': uniqueViews,
        'applies': applies,
      };
}

