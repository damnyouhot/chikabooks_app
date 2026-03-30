import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

/// 웹 전용 — 이력서 프로필 사진 업로드 (putData)
class ResumePhotoUploaderImpl {
  static final _storage = FirebaseStorage.instance;
  static const _uuid = Uuid();

  /// 사진 1장 업로드. 반환: downloadURL.
  static Future<String> uploadPhoto({
    required String userId,
    required XFile image,
    void Function(double progress)? onProgress,
  }) async {
    final bytes = await image.readAsBytes();
    final name = image.name;
    final ext = name.contains('.')
        ? name.split('.').last.toLowerCase()
        : 'jpg';
    final fileName = '${_uuid.v4()}.$ext';
    final path = 'resumes/$userId/photos/$fileName';
    final ref = _storage.ref(path);

    final task = ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/$ext'),
    );

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
