import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

/// 기록하기 사진 압축 · 업로드 · 삭제 전담 서비스
///
/// Storage 경로: diary_posts/{uid}/{noteId}/image_0.jpg
class DiaryImageService {
  static final _storage = FirebaseStorage.instance;

  static const int maxImages = 3;
  static const int _quality = 75;
  static const int _maxDimension = 1280;

  /// 갤러리에서 이미지 선택 (최대 [remaining]장)
  static Future<List<XFile>> pickImages({required int remaining}) async {
    if (remaining <= 0) return [];
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(limit: remaining);
    if (picked.length > remaining) return picked.sublist(0, remaining);
    return picked;
  }

  /// 이미지 압축 → JPEG bytes 반환
  /// 긴 변 1280px 이하, 품질 75
  static Future<Uint8List?> compress(XFile file) async {
    try {
      if (kIsWeb) {
        return await file.readAsBytes();
      }
      final result = await FlutterImageCompress.compressWithFile(
        file.path,
        minWidth: _maxDimension,
        minHeight: _maxDimension,
        quality: _quality,
        format: CompressFormat.jpeg,
      );
      if (result == null || result.isEmpty) {
        debugPrint('⚠️ [DiaryImage] 압축 실패, 원본 사용');
        return await file.readAsBytes();
      }
      debugPrint('📸 [DiaryImage] 압축: ${(result.length / 1024).toStringAsFixed(0)}KB');
      return Uint8List.fromList(result);
    } catch (e) {
      debugPrint('⚠️ [DiaryImage] compress 에러: $e');
      return await file.readAsBytes();
    }
  }

  /// 압축된 이미지들을 Storage에 업로드, downloadUrl 목록 반환
  static Future<List<String>> uploadAll({
    required String uid,
    required String noteId,
    required List<XFile> files,
  }) async {
    final urls = <String>[];
    for (var i = 0; i < files.length; i++) {
      final bytes = await compress(files[i]);
      if (bytes == null) continue;

      final ref = _storage.ref('diary_posts/$uid/$noteId/image_$i.jpg');
      final task = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await task.ref.getDownloadURL();
      urls.add(url);
      debugPrint('📸 [DiaryImage] 업로드 완료 $i → ${url.substring(0, 60)}...');
    }
    return urls;
  }

  /// noteId에 연결된 모든 이미지 삭제
  static Future<void> deleteAll({
    required String uid,
    required String noteId,
    required List<String> imageUrls,
  }) async {
    for (var i = 0; i < imageUrls.length; i++) {
      try {
        final ref = _storage.ref('diary_posts/$uid/$noteId/image_$i.jpg');
        await ref.delete();
        debugPrint('🗑️ [DiaryImage] 삭제 완료: image_$i.jpg');
      } catch (e) {
        debugPrint('⚠️ [DiaryImage] 삭제 실패 image_$i: $e');
      }
    }
  }
}
