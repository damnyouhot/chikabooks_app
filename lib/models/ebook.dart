import 'package:cloud_firestore/cloud_firestore.dart';

class Ebook {
  final String id;
  final String title;
  final String author;
  final String coverUrl;
  final String description;
  final DateTime publishedAt;
  final int price; // 0 = 무료
  final String productId; // IAP 상품 ID
  final String fileUrl;

  Ebook({
    required this.id,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.description,
    required this.publishedAt,
    required this.price,
    required this.productId,
    required this.fileUrl,
  });

  /// Firestore 문서에서 Ebook 객체 생성
  factory Ebook.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final j = doc.data()!;
    return Ebook.fromJson(j, id: doc.id);
  }

  // ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼ 이 부분이 새로 추가됩니다 ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
  /// Map(Json)에서 Ebook 객체 생성 (MyDeskTab에서 사용)
  factory Ebook.fromJson(Map<String, dynamic> json, {required String id}) {
    final pub = _toDate(json['publishedAt']);
    return Ebook(
      id: id,
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      coverUrl: json['coverUrl'] ?? '',
      description: json['description'] ?? '',
      publishedAt: pub,
      price: (json['price'] ?? 0) as int,
      productId: json['productId'] ?? '',
      fileUrl: json['fileUrl'] ?? '',
    );
  }
  // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲ 이 부분이 새로 추가됩니다 ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲

  /// 저장을 위한 JSON 변환
  Map<String, dynamic> toJson() => {
        'title': title,
        'author': author,
        'coverUrl': coverUrl,
        'description': description,
        'publishedAt': publishedAt.year * 10000 +
            publishedAt.month * 100 +
            publishedAt.day,
        'price': price,
        'productId': productId,
        'fileUrl': fileUrl,
      };

  static DateTime _toDate(dynamic v) {
    if (v is int) {
      final y = v ~/ 10000, m = (v % 10000) ~/ 100, d = v % 100;
      return DateTime(y, m, d);
    }
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.parse(v);
    return DateTime.now();
  }
}
