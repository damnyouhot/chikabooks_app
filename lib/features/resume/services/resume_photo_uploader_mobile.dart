import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

/// 모바일 전용 — 이력서 프로필 사진 업로드 (압축 후 Storage)
class ResumePhotoUploaderImpl {
  static final _storage = FirebaseStorage.instance;
  static const _uuid = Uuid();

  /// 사진 1장 업로드. 반환: downloadURL.
  static Future<String> uploadPhoto({
    required String userId,
    required XFile image,
    void Function(double progress)? onProgress,
  }) async {
    final ext = image.name.contains('.')
        ? image.name.split('.').last.toLowerCase()
        : 'jpg';
    final fileName = '${_uuid.v4()}.$ext';
    final path = 'resumes/$userId/photos/$fileName';
    final ref = _storage.ref(path);

    final compressed = await FlutterImageCompress.compressWithFile(
      image.path,
      minWidth: 600,
      minHeight: 800,
      quality: 85,
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
        File(image.path),
        SettableMetadata(contentType: 'image/$ext'),
      );
    }

    task.snapshotEvents.listen((snap) {
      if (snap.totalBytes > 0) {
        onProgress?.call(snap.bytesTransferred / snap.totalBytes);
      }
    });

    await task;
    return ref.getDownloadURL();
  }

  static Future<void> deletePhoto(String downloadUrl) async {
    try {
      await _storage.refFromURL(downloadUrl).delete();
    } catch (_) {}
  }
}
