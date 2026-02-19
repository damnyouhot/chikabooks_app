import 'package:cloud_firestore/cloud_firestore.dart';

/// HIRA 수가/급여 변경 업데이트
class HiraUpdate {
  final String id;
  final String title;
  final String link;
  final DateTime publishedAt;
  final DateTime? effectiveDate; // 시행일 (null이면 미확정)
  final String topic; // 'act' or 'notice'
  final int impactScore;
  final String impactLevel; // 'HIGH', 'MID', 'LOW' (deprecated, 시행일 기준으로 변경)
  final List<String> keywords;
  final List<String> actionHints;
  final DateTime fetchedAt;
  final int commentCount; // 댓글 수 추가

  HiraUpdate({
    required this.id,
    required this.title,
    required this.link,
    required this.publishedAt,
    this.effectiveDate,
    required this.topic,
    required this.impactScore,
    required this.impactLevel,
    required this.keywords,
    required this.actionHints,
    required this.fetchedAt,
    this.commentCount = 0, // 기본값 0
  });

  factory HiraUpdate.fromMap(String id, Map<String, dynamic> map) {
    return HiraUpdate(
      id: id,
      title: map['title'] as String? ?? '',
      link: map['link'] as String? ?? '',
      publishedAt: (map['publishedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      effectiveDate: (map['effectiveDate'] as Timestamp?)?.toDate(),
      topic: map['topic'] as String? ?? 'notice',
      impactScore: map['impactScore'] as int? ?? 0,
      impactLevel: map['impactLevel'] as String? ?? 'LOW',
      keywords: List<String>.from(map['keywords'] ?? []),
      actionHints: List<String>.from(map['actionHints'] ?? []),
      fetchedAt: (map['fetchedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      commentCount: map['commentCount'] as int? ?? 0, // 댓글 수 추가
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'link': link,
      'publishedAt': Timestamp.fromDate(publishedAt),
      'effectiveDate': effectiveDate != null ? Timestamp.fromDate(effectiveDate!) : null,
      'topic': topic,
      'impactScore': impactScore,
      'impactLevel': impactLevel,
      'keywords': keywords,
      'actionHints': actionHints,
      'fetchedAt': Timestamp.fromDate(fetchedAt),
      'commentCount': commentCount, // 댓글 수 추가
    };
  }

  /// 시행일 기준 배지 레벨 계산
  String getBadgeLevel() {
    if (effectiveDate == null) return 'NOTICE'; // 사전공지
    
    final today = DateTime.now();
    final effectiveDay = DateTime(effectiveDate!.year, effectiveDate!.month, effectiveDate!.day);
    final daysUntil = effectiveDay.difference(DateTime(today.year, today.month, today.day)).inDays;
    
    if (daysUntil <= 0) return 'ACTIVE'; // 시행 중
    if (daysUntil <= 30) return 'SOON'; // 30일 이내
    if (daysUntil <= 90) return 'UPCOMING'; // 90일 이내
    return 'NOTICE'; // 사전공지
  }

  /// 배지 텍스트 계산
  String getBadgeText() {
    final level = getBadgeLevel();
    if (level == 'ACTIVE') return '시행 중';
    if (level == 'NOTICE') return '사전공지';
    
    final today = DateTime.now();
    final effectiveDay = DateTime(effectiveDate!.year, effectiveDate!.month, effectiveDate!.day);
    final daysUntil = effectiveDay.difference(DateTime(today.year, today.month, today.day)).inDays;
    return 'D-${daysUntil.toString().padLeft(2, '0')}';
  }
}

/// HIRA Digest (오늘의 상위 3건)
class HiraDigest {
  final String dateKey; // YYYY-MM-DD
  final List<String> topIds;
  final DateTime generatedAt;

  HiraDigest({
    required this.dateKey,
    required this.topIds,
    required this.generatedAt,
  });

  factory HiraDigest.fromMap(String dateKey, Map<String, dynamic> map) {
    return HiraDigest(
      dateKey: dateKey,
      topIds: List<String>.from(map['topIds'] ?? []),
      generatedAt: (map['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'topIds': topIds,
      'generatedAt': Timestamp.fromDate(generatedAt),
    };
  }
}

/// HIRA 댓글
class HiraComment {
  final String id;
  final String uid;
  final String userName;
  final String text;
  final DateTime createdAt;

  HiraComment({
    required this.id,
    required this.uid,
    required this.userName,
    required this.text,
    required this.createdAt,
  });

  factory HiraComment.fromMap(String id, Map<String, dynamic> map) {
    return HiraComment(
      id: id,
      uid: map['uid'] as String? ?? '',
      userName: map['userName'] as String? ?? '익명',
      text: map['text'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'userName': userName,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'isDeleted': false,
    };
  }
}

