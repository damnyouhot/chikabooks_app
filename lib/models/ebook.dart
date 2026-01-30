// lib/models/ebook.dart

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

  factory Ebook.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final j = doc.data()!;
    return Ebook.fromJson(j, id: doc.id);
  }

  factory Ebook.fromJson(Map<String, dynamic> json, {required String id}) {
    final pub = _toDate(json['publishedAt']);
    return Ebook(
      id: id,
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      coverUrl: json['coverUrl'] ?? '',
      description: json['description'] ?? '',
      publishedAt: pub,
      price: _toInt(json['price']),
      productId: json['productId']?.toString() ?? '',  // 숫자여도 문자열로 변환
      fileUrl: json['fileUrl'] ?? '',
    );
  }
  
  /// 다양한 타입을 int로 변환
  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  // ▼▼▼ 오류 해결을 위해 이 부분을 추가합니다 ▼▼▼
  factory Ebook.empty() {
    return Ebook(
      id: '',
      title: '',
      author: '',
      coverUrl: '',
      description: '',
      publishedAt: DateTime.now(),
      price: 0,
      productId: '',
      fileUrl: '',
    );
  }
  // ▲▲▲ 오류 해결을 위해 이 부분을 추가합니다 ▲▲▲

  Map<String, dynamic> toJson() => {
    'title': title,
    'author': author,
    'coverUrl': coverUrl,
    'description': description,
    'publishedAt':
        publishedAt.year * 10000 + publishedAt.month * 100 + publishedAt.day,
    'price': price,
    'productId': productId,
    'fileUrl': fileUrl,
  };

  static DateTime _toDate(dynamic v) {
    if (v is int) {
      final y = v ~/ 10000;
      final m = (v % 10000) ~/ 100;
      final d = v % 100;
      return DateTime(y, m, d);
    }
    if (v is Timestamp) {
      return v.toDate();
    }
    if (v is String) {
      return DateTime.parse(v);
    }
    return DateTime.now();
  }
}
