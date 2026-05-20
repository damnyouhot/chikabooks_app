import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/analytics/stats_excluded_emails.dart';

/// 대시보드·행동 분석 집계에 포함할 유저 UID 집합.
///
/// `excludeFromStats == false` 이면서 [StatsExcludedEmails] 에 해당하지 않는 UID만 반환합니다.
class StatsUserFilter {
  StatsUserFilter._();

  static Future<Set<String>> validUserIds(FirebaseFirestore db) async {
    final snap = await db
        .collection('users')
        .where('excludeFromStats', isEqualTo: false)
        .get();
    final ids = <String>{};
    for (final doc in snap.docs) {
      if (StatsExcludedEmails.isExcludedUserData(doc.data())) continue;
      ids.add(doc.id);
    }
    return ids;
  }
}
