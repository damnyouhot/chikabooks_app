import 'package:image_picker/image_picker.dart';

import 'resume_photo_uploader_mobile.dart'
    if (dart.library.html) 'resume_photo_uploader_web.dart';

/// 이력서 프로필 사진 업로더 (앱/웹 공통 인터페이스)
class ResumePhotoUploader {
  static Future<String> uploadPhoto({
    required String userId,
    required XFile image,
    void Function(double progress)? onProgress,
  }) =>
      ResumePhotoUploaderImpl.uploadPhoto(
        userId: userId,
        image: image,
        onProgress: onProgress,
      );

  static Future<void> deletePhoto(String downloadUrl) =>
      ResumePhotoUploaderImpl.deletePhoto(downloadUrl);
}
