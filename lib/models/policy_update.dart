import 'package:cloud_firestore/cloud_firestore.dart';

/// 제도 변경 정보 모델
class PolicyUpdate {
  final String id;
  final String title;
  final String summary;
  final DateTime effectiveDate;
  final String category; // insurance, law, personnel, etc
  final int priority; // 1-5
  final bool isActive;
  final String sourceName; // HIRA, 보건복지부 등
  final String sourceUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  PolicyUpdate({
    required this.id,
    required this.title,
    required this.summary,
    required this.effectiveDate,
    required this.category,
    required this.priority,
    required this.isActive,
    required this.sourceName,
    required this.sourceUrl,
    required this.createdAt,
    this.updatedAt,
  });

  /// Firestore 문서에서 객체 생성
  factory PolicyUpdate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PolicyUpdate(
      id: doc.id,
      title: data['title'] ?? '',
      summary: data['summary'] ?? '',
      effectiveDate: (data['effectiveDate'] as Timestamp).toDate(),
      category: data['category'] ?? 'other',
      priority: data['priority'] ?? 5,
      isActive: data['isActive'] ?? false,
      sourceName: data['sourceName'] ?? '',
      sourceUrl: data['sourceUrl'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt:
          data['updatedAt'] != null
              ? (data['updatedAt'] as Timestamp).toDate()
              : null,
    );
  }

  /// Firestore 문서로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'summary': summary,
      'effectiveDate': Timestamp.fromDate(effectiveDate),
      'category': category,
      'priority': priority,
      'isActive': isActive,
      'sourceName': sourceName,
      'sourceUrl': sourceUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// D-day 계산
  int get daysUntil {
    final now = DateTime.now();
    final diff = effectiveDate.difference(now);
    return diff.inDays;
  }

  /// D-day 문자열 (예: "D-12")
  String get ddayString {
    final days = daysUntil;
    if (days < 0) return 'D+${-days}';
    if (days == 0) return 'D-day';
    return 'D-$days';
  }
}
