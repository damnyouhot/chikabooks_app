import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/ebook.dart';

class EbookService {
  final _db = FirebaseFirestore.instance;

  /// 실시간 스트림
  Stream<List<Ebook>> watchEbooks() {
    debugPrint('[EbookService] watchEbooks()');
    return _db
        .collection('ebooks')
        .orderBy('publishedAt', descending: true)
        .snapshots()
        .map((qs) => qs.docs.map(Ebook.fromDoc).toList());
  }

  /// 단일 전자책
  Future<Ebook> fetchEbook(String id) async {
    final doc = await _db.collection('ebooks').doc(id).get();
    return Ebook.fromDoc(doc);
  }
}
