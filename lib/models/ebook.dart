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

  /// coverUrl의 Storage 경로에서 카테고리 폴더명을 자동 추출합니다.
  ///
  /// Firebase Storage URL 두 가지 패턴 모두 지원:
  ///   패턴 A: .../o/ebooks%2F임상스킬%2F파일명.jpg → '임상스킬'
  ///   패턴 B: .../o/ebooks/임상스킬/파일명.jpg     → '임상스킬'
  ///
  /// BG, 썸네일, ebooks, ebook_covers 등 최상위 폴더는 '기타'로 반환합니다.
  /// fileUrl의 Storage 경로에서 카테고리를 추출합니다.
  ///
  /// Storage 구조 예시: gs://BUCKET/보험청구/파일명.pdf
  /// → 최상위 폴더명이 카테고리 (예: '보험청구', '임상스킬', '자기계발')
  ///
  /// fileUrl이 없으면 coverUrl에서 시도합니다.
  String get category {
    final url = fileUrl.isNotEmpty ? fileUrl : coverUrl;
    return _parseCategory(url);
  }

  static String _parseCategory(String url) {
    try {
      if (url.isEmpty) return '기타';

      // 쿼리스트링 제거
      final raw = url.split('?').first;

      // /o/ 이후 경로 추출
      final oIdx = raw.indexOf('/o/');
      if (oIdx == -1) return '기타';
      final pathPart = raw.substring(oIdx + 3);

      // %2F 포함 전체 디코딩 (%2F → /, 한글 인코딩 → 한글)
      final decoded = Uri.decodeComponent(pathPart);

      // / 로 세그먼트 분리
      final segments = decoded.split('/').where((s) => s.isNotEmpty).toList();

      // 카테고리로 쓰지 않을 최상위 폴더명
      const rootFolders = {
        'BG', '썸네일', 'ebook_covers', 'ebooks', 'images',
        'ebook_files', 'files', '',
      };

      for (final seg in segments) {
        if (rootFolders.contains(seg)) continue;
        if (seg.contains('.')) continue; // 확장자 있으면 파일명 → 스킵
        return seg; // 첫 번째 유효 폴더명 = 카테고리
      }
      return '기타';
    } catch (_) {
      return '기타';
    }
  }

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
