// lib/services/storage_service.dart

import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  StorageService._();

  static final _storage = FirebaseStorage.instance;

  static Future<String> uploadEpub({
    required String docId,
    required Uint8List bytes,
  }) async {
    final ref = _storage.ref().child('ebooks/$docId.epub');
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'application/epub+zip'),
    );
    return await task.ref.getDownloadURL();
  }

  // ▼▼▼ 표지 이미지 업로드 함수 추가 ▼▼▼
  static Future<String> uploadCoverImage({
    required String ebookId,
    required Uint8List bytes,
  }) async {
    final ref = _storage.ref().child('ebook_covers/$ebookId.jpg');
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await task.ref.getDownloadURL();
  }
  // ▲▲▲ 표지 이미지 업로드 함수 추가 ▲▲▲
}
