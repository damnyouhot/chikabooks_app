import 'dart:async';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

/// 모바일 전용 — Firebase Storage 실제 업로드 (업로드 전 압축 적용)
class JobImageUploaderImpl {
  static final _storage = FirebaseStorage.instance;
  static const _uuid = Uuid();

  static Future<List<String>> uploadImages({
    required String jobId,
    required List<XFile> images,
    void Function(int index, double progress)? onProgress,
  }) async {
    final urls = <String>[];

    for (int i = 0; i < images.length; i++) {
      final file = images[i];
      final ext =
          file.name.contains('.')
              ? file.name.split('.').last.toLowerCase()
              : 'jpg';
      final fileName = '${_uuid.v4()}.$ext';
      final path = 'jobImages/$jobId/images/$fileName';
      final ref = _storage.ref(path);

      // 업로드 전 압축 (최대 1200px, 품질 80)
      final compressed = await FlutterImageCompress.compressWithFile(
        file.path,
        minWidth: 1200,
        minHeight: 900,
        quality: 80,
        format: ext == 'png' ? CompressFormat.png : CompressFormat.jpeg,
      );

      final UploadTask task;
      if (compressed != null) {
        task = ref.putData(
          compressed,
          SettableMetadata(contentType: 'image/$ext'),
        );
      } else {
        task = ref.putFile(
          File(file.path),
          SettableMetadata(contentType: 'image/$ext'),
        );
      }

      final sub = task.snapshotEvents.listen((snap) {
        if (snap.totalBytes > 0) {
          onProgress?.call(i, snap.bytesTransferred / snap.totalBytes);
        }
      });

      await task;
      await sub.cancel();
      final url = await ref.getDownloadURL();
      urls.add(url);
    }

    return urls;
  }

  static Future<void> deleteImage(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } catch (_) {}
  }
}
