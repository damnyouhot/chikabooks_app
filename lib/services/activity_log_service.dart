import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/activity_log.dart';
import '../models/partner_group.dart';

/// 파트너 활동 요약 서비스
/// CaringPage 진입 시 unread 로그를 actorUid별로 묶어 카드 표시용
class ActivityLogService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// 마지막 읽은 시간 가져오기
  static Future<DateTime?> getLastReadAt(String groupId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    try {
      final doc = await _db
          .collection('users')
          .doc(uid)
          .collection('partnerReads')
          .doc(groupId)
          .get();
      if (!doc.exists) return null;
      final ts = doc.data()?['lastReadAt'];
      if (ts is Timestamp) return ts.toDate();
      return null;
    } catch (e) {
      debugPrint('⚠️ getLastReadAt error: $e');
      return null;
    }
  }

  /// 읽음 처리
  static Future<void> markAsRead(String groupId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('partnerReads')
          .doc(groupId)
          .set({'lastReadAt': FieldValue.serverTimestamp()});
    } catch (e) {
      debugPrint('⚠️ markAsRead error: $e');
    }
  }

  /// unread 활동 로그 가져오기 (lastReadAt 이후)
  static Future<List<ActivityLog>> getUnreadLogs(String groupId) async {
    final lastRead = await getLastReadAt(groupId);

    try {
      Query<Map<String, dynamic>> query = _db
          .collection('partnerGroups')
          .doc(groupId)
          .collection('activityLogs')
          .orderBy('createdAt', descending: true)
          .limit(50);

      if (lastRead != null) {
        query = query.where('createdAt',
            isGreaterThan: Timestamp.fromDate(lastRead));
      }

      final snap = await query.get();
      return snap.docs.map(ActivityLog.fromDoc).toList();
    } catch (e) {
      debugPrint('⚠️ getUnreadLogs error: $e');
      return [];
    }
  }

  /// actorUid별로 그룹핑된 요약 데이터
  /// 반환: { uid → List<ActivityLog> }
  static Future<Map<String, List<ActivityLog>>> getGroupedSummary(
      String groupId) async {
    final myUid = _auth.currentUser?.uid;
    final logs = await getUnreadLogs(groupId);

    final grouped = <String, List<ActivityLog>>{};
    for (final log in logs) {
      // 내 활동은 제외
      if (log.actorUid == myUid) continue;
      grouped.putIfAbsent(log.actorUid, () => []);
      grouped[log.actorUid]!.add(log);
    }
    return grouped;
  }

  /// 요약 텍스트 생성 (아이콘 나열, 과시/숫자 최소)
  static String summarizeIcons(List<ActivityLog> logs) {
    final icons = <String>{};
    for (final log in logs) {
      icons.add(log.summaryIcon);
    }
    return icons.join(' ');
  }

  /// 멤버 메타와 결합한 요약 아이템 목록
  static Future<List<PartnerSummaryItem>> buildSummaryItems(
    String groupId,
    List<GroupMemberMeta> members,
  ) async {
    final grouped = await getGroupedSummary(groupId);
    final items = <PartnerSummaryItem>[];

    for (final entry in grouped.entries) {
      final uid = entry.key;
      final logs = entry.value;
      final member = members.where((m) => m.uid == uid).firstOrNull;
      if (member == null) continue;

      items.add(PartnerSummaryItem(
        memberMeta: member,
        logs: logs,
        iconSummary: summarizeIcons(logs),
      ));
    }

    return items;
  }
}

/// 요약 카드 1줄에 해당하는 데이터
class PartnerSummaryItem {
  final GroupMemberMeta memberMeta;
  final List<ActivityLog> logs;
  final String iconSummary; // "✍️ 💛 📖"

  const PartnerSummaryItem({
    required this.memberMeta,
    required this.logs,
    required this.iconSummary,
  });
}



