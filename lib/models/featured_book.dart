import 'package:cloud_firestore/cloud_firestore.dart';

/// 추천 책 (이주의 책) 모델
class FeaturedBook {
  final String id;
  final String bookId; // books 컬렉션 참조
  final String subtitle;
  final DateTime weekStart;
  final DateTime weekEnd;
  final int order;
  final bool isActive;

  FeaturedBook({
    required this.id,
    required this.bookId,
    required this.subtitle,
    required this.weekStart,
    required this.weekEnd,
    required this.order,
    required this.isActive,
  });

  /// Firestore 문서에서 객체 생성
  factory FeaturedBook.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FeaturedBook(
      id: doc.id,
      bookId: data['bookId'] ?? '',
      subtitle: data['subtitle'] ?? '',
      weekStart: (data['weekStart'] as Timestamp).toDate(),
      weekEnd: (data['weekEnd'] as Timestamp).toDate(),
      order: data['order'] ?? 0,
      isActive: data['isActive'] ?? false,
    );
  }

  /// Firestore 문서로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'bookId': bookId,
      'subtitle': subtitle,
      'weekStart': Timestamp.fromDate(weekStart),
      'weekEnd': Timestamp.fromDate(weekEnd),
      'order': order,
      'isActive': isActive,
    };
  }

  /// 현재 주차에 해당하는지 확인
  bool get isCurrent {
    final now = DateTime.now();
    return now.isAfter(weekStart) && now.isBefore(weekEnd) && isActive;
  }
}
