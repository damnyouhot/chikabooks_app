// lib/services/storage_service.dart
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

/// Firebase Storage 헬퍼
class StorageService {
  static final _storage = FirebaseStorage.instance;

  /// bytes →  `ebooks/{docId}.epub`  업로드 후 downloadURL 반환
  static Future<String> uploadEpub({
    required String docId,
    required Uint8List bytes,
  }) async {
    final ref = _storage.ref('ebooks/$docId.epub');
    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'application/epub+zip'),
    );
    return ref.getDownloadURL();
  }

  /// 필요 시 삭제(편집 화면에서 교체 전 호출해도 됨)
  static Future<void> deleteEpub(String docId) async {
    await _storage.ref('ebooks/$docId.epub').delete();
  }
}
