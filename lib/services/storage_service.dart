import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

/// Firebase Storage 관련 유틸리티를 모아 둔 서비스.
/// 모든 메서드는 `static` 으로 제공하므로 인스턴스를 만들 필요가 없습니다.
class StorageService {
  StorageService._(); // 인스턴스화 방지용 private 생성자

  /// ePub 파일을 `ebooks/{docId}.epub` 경로에 업로드한 뒤
  /// 다운로드 URL(String)을 반환합니다.
  static Future<String> uploadEpub({
    required String docId,
    required Uint8List bytes,
  }) async {
    final ref = FirebaseStorage.instance.ref().child('ebooks/$docId.epub');

    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'application/epub+zip'),
    );

    return await task.ref.getDownloadURL();
  }
}
