import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

/// 웹 전용 — Firebase Storage putData(bytes) 실 업로드
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
      final bytes = await images[i].readAsBytes();
      final name = images[i].name;
      final ext = name.contains('.')
          ? name.split('.').last.toLowerCase()
          : 'jpg';
      final fileName = '${_uuid.v4()}.$ext';
      final path = 'jobs/$jobId/images/$fileName';
      final ref = _storage.ref(path);

      final task = ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/$ext'),
      );

      final sub = task.snapshotEvents.listen((snap) {
        if (snap.totalBytes > 0) {
          onProgress?.call(i, snap.bytesTransferred / snap.totalBytes);
        }
      });

      await task;
      await sub.cancel();
      urls.add(await ref.getDownloadURL());
    }

    return urls;
  }

  static Future<void> deleteImage(String downloadUrl) async {
    try {
      await _storage.refFromURL(downloadUrl).delete();
    } catch (_) {}
  }
}
