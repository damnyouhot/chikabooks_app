import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/quiz_content_config.dart';
import '../models/quiz_pool_item.dart';
import '../models/quiz_schedule.dart';
import 'quiz_content_config_service.dart';

/// `quiz_meta/state` 대시보드용 보정.
///
/// 배포 CF가 `usedNationalCount` 등을 안 채운 레거시 meta·스케줄 불일치 시,
/// 현재 사이클 [quiz_schedule] 스냅샷으로 소모·잔여를 다시 계산한다.
class QuizMetaOpsService {
  QuizMetaOpsService._();

  static final _db = FirebaseFirestore.instance;

  static Future<QuizMetaState?> enrichForDashboard(QuizMetaState? meta) async {
    if (meta == null) return null;
    try {
      final cfg = await QuizContentConfigService.getConfig();
      final poolSnap =
          await _db
              .collection('quiz_pool')
              .where('isActive', isEqualTo: true)
              .get();

      final usedIds = await _usedIdsForCurrentCycle(meta.cycleCount);
      final analytics = _computeAnalytics(
        poolSnap.docs,
        usedIds,
        cfg,
      );

      return QuizMetaState(
        cycleCount: meta.cycleCount,
        totalActiveCount: analytics.totalActiveCount,
        totalNationalActiveCount: analytics.totalNationalActiveCount,
        totalClinicalActiveCount: analytics.totalClinicalActiveCount,
        usedNationalCount: analytics.usedNationalCount,
        usedClinicalCount: analytics.usedClinicalCount,
        lastScheduledDate: meta.lastScheduledDate,
        dailyCount: meta.dailyCount,
        usedCount: analytics.usedNationalCount + analytics.usedClinicalCount,
      );
    } catch (e) {
      debugPrint('⚠️ QuizMetaOpsService.enrichForDashboard: $e');
      return meta;
    }
  }

  static Future<Set<String>> _usedIdsForCurrentCycle(int cycleCount) async {
    final snap = await _db.collection('quiz_schedule').get();
    final ids = <String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      if ((data['cycleCount'] as num?)?.toInt() != cycleCount) continue;
      final raw = data['quizIds'] as List? ?? [];
      for (final id in raw) {
        if (id is String && id.isNotEmpty) ids.add(id);
      }
    }
    return ids;
  }

  static _QuizMetaAnalytics _computeAnalytics(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> poolDocs,
    Set<String> usedIds,
    QuizContentConfig cfg,
  ) {
    var totalNational = 0;
    var totalClinical = 0;
    var usedNational = 0;
    var usedClinical = 0;

    for (final doc in poolDocs) {
      final data = doc.data();
      if (!_poolDocMatchesContentPacks(data, cfg)) continue;
      final t = _quizQuestionType(data);
      if (t == QuizPoolItem.kNationalExam) {
        totalNational++;
        if (usedIds.contains(doc.id)) usedNational++;
      } else {
        totalClinical++;
        if (usedIds.contains(doc.id)) usedClinical++;
      }
    }

    return _QuizMetaAnalytics(
      totalActiveCount: totalNational + totalClinical,
      totalNationalActiveCount: totalNational,
      totalClinicalActiveCount: totalClinical,
      usedNationalCount: usedNational,
      usedClinicalCount: usedClinical,
    );
  }

  static String _quizQuestionType(Map<String, dynamic> data) {
    return data['questionType'] == QuizPoolItem.kNationalExam
        ? QuizPoolItem.kNationalExam
        : QuizPoolItem.kClinical;
  }

  static bool _poolDocMatchesContentPacks(
    Map<String, dynamic> data,
    QuizContentConfig cfg,
  ) {
    return _clinicalMatches(data, cfg) && _nationalMatches(data, cfg);
  }

  static bool _clinicalMatches(Map<String, dynamic> data, QuizContentConfig cfg) {
    if (_quizQuestionType(data) != QuizPoolItem.kClinical) return true;
    if (cfg.currentClinicalPackId.isEmpty) return true;
    final pid = (data['packId'] as String?)?.trim() ?? '';
    if (pid.isEmpty) return cfg.includeClinicalWithoutPack;
    return pid == cfg.currentClinicalPackId;
  }

  static bool _nationalMatches(Map<String, dynamic> data, QuizContentConfig cfg) {
    if (_quizQuestionType(data) != QuizPoolItem.kNationalExam) return true;
    if (cfg.currentNationalPackId.isEmpty) return true;
    final pid = (data['packId'] as String?)?.trim() ?? '';
    if (pid.isEmpty) return cfg.includeNationalWithoutPack;
    return pid == cfg.currentNationalPackId;
  }
}

class _QuizMetaAnalytics {
  const _QuizMetaAnalytics({
    required this.totalActiveCount,
    required this.totalNationalActiveCount,
    required this.totalClinicalActiveCount,
    required this.usedNationalCount,
    required this.usedClinicalCount,
  });

  final int totalActiveCount;
  final int totalNationalActiveCount;
  final int totalClinicalActiveCount;
  final int usedNationalCount;
  final int usedClinicalCount;
}
