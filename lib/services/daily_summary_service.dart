import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 일일 요약 카드 데이터
class DailySummary {
  final String dateKey;
  final Map<String, int> activityCounts; // uid -> 활동 횟수
  final String summaryMessage;
  final String ctaMessage;
  final DateTime createdAt;

  const DailySummary({
    required this.dateKey,
    required this.activityCounts,
    required this.summaryMessage,
    required this.ctaMessage,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'dateKey': dateKey,
      'activityCounts': activityCounts,
      'summaryMessage': summaryMessage,
      'ctaMessage': ctaMessage,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory DailySummary.fromMap(Map<String, dynamic> map) {
    return DailySummary(
      dateKey: map['dateKey'] as String,
      activityCounts: Map<String, int>.from(map['activityCounts'] as Map),
      summaryMessage: map['summaryMessage'] as String,
      ctaMessage: map['ctaMessage'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}

/// 일일 요약 서비스
class DailySummaryService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// KST 기준 오늘 dateKey
  static String todayDateKey() {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    return '${kst.year}-${kst.month.toString().padLeft(2, '0')}-${kst.day.toString().padLeft(2, '0')}';
  }

  /// 활동 수에 따른 요약 메시지 생성
  static String getSummaryMessage(Map<String, int> activityCounts) {
    final activeMembers = activityCounts.values.where((c) => c >= 1).length;
    
    switch (activeMembers) {
      case 3:
        return '오늘 우리 셋 다 움직였다 ✨';
      case 2:
        return '오늘은 두 명이 함께했다 🌙';
      case 1:
        final activeName = activityCounts.entries
            .firstWhere((e) => e.value >= 1, orElse: () => const MapEntry('', 0))
            .key;
        if (activeName.isEmpty) return '오늘은 조용한 날';
        return '오늘은 $activeName님이 버텼다 (나머지 자리도 기다릴게)';
      default:
        return '오늘은 조용한 날 (내일 한 칸만 채워도 충분해)';
    }
  }

  /// 활동 수에 따른 CTA 메시지 생성
  static String getCTAMessage(Map<String, int> activityCounts, String myUid) {
    final myActivity = activityCounts[myUid] ?? 0;
    if (myActivity == 0) {
      return '한 문장만 남겨볼까요?';
    } else if (myActivity >= 3) {
      return '오늘도 수고했어요 👏';
    } else {
      return '조금만 더 함께해볼까요?';
    }
  }

  /// 오늘의 요약 데이터 생성 (파트너 그룹 기준)
  /// 
  /// 실제로는 Cloud Functions에서 매일 19:00에 자동 생성해야 하지만,
  /// 클라이언트에서도 on-demand로 생성 가능
  static Future<DailySummary?> generateTodaySummary({
    required String groupId,
    required List<String> memberUids,
  }) async {
    try {
      final dateKey = todayDateKey();
      
      // 각 멤버의 오늘 활동 수 집계
      // (실제로는 activityLogs, bondPosts, 투표 등을 집계해야 함)
      final activityCounts = <String, int>{};
      for (final uid in memberUids) {
        // TODO: 실제 활동 집계 로직
        // 임시로 랜덤 값
        activityCounts[uid] = 0; // 실제 집계로 대체 필요
      }

      final myUid = _auth.currentUser?.uid ?? '';
      final summaryMessage = getSummaryMessage(activityCounts);
      final ctaMessage = getCTAMessage(activityCounts, myUid);

      return DailySummary(
        dateKey: dateKey,
        activityCounts: activityCounts,
        summaryMessage: summaryMessage,
        ctaMessage: ctaMessage,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('⚠️ generateTodaySummary error: $e');
      return null;
    }
  }

  /// 오늘의 요약 카드 가져오기
  static Future<DailySummary?> getTodaySummary(String groupId) async {
    try {
      final dateKey = todayDateKey();
      
      final doc = await _db
          .collection('partnerGroups')
          .doc(groupId)
          .collection('dailySummaries')
          .doc(dateKey)
          .get();

      if (!doc.exists || doc.data() == null) return null;
      return DailySummary.fromMap(doc.data()!);
    } catch (e) {
      debugPrint('⚠️ getTodaySummary error: $e');
      return null;
    }
  }

  /// 저녁 7시 이후 요약 카드를 보여야 하는지 확인
  static bool shouldShowSummary() {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    return kst.hour >= 19; // 19:00 이후
  }
}


