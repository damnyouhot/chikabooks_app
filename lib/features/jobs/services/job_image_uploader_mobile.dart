import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

/// 모바일 전용 — Firebase Storage 실제 업로드
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
      final path = 'jobs/$jobId/images/$fileName';
      final ref = _storage.ref(path);

      final task = ref.putFile(
        File(file.path),
        SettableMetadata(contentType: 'image/$ext'),
      );

      task.snapshotEvents.listen((snap) {
        if (snap.totalBytes > 0) {
          onProgress?.call(i, snap.bytesTransferred / snap.totalBytes);
        }
      });

      await task;
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


