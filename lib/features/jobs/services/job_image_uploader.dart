import 'package:image_picker/image_picker.dart';

// 플랫폼별 구현 조건부 import
import 'job_image_uploader_mobile.dart'
    if (dart.library.html) 'job_image_uploader_web.dart';

/// 구인공고 이미지 업로더 (앱/웹 공통 인터페이스)
///
/// - 모바일: Firebase Storage에 실제 업로드
/// - 웹(현재): Mock URL 반환 (향후 Storage 직접 연동으로 전환 가능)
class JobImageUploader {
  static Future<List<String>> uploadImages({
    required String jobId,
    required List<XFile> images,
    void Function(int index, double progress)? onProgress,
  }) => JobImageUploaderImpl.uploadImages(
    jobId: jobId,
    images: images,
    onProgress: onProgress,
  );

  static Future<void> deleteImage(String downloadUrl) =>
      JobImageUploaderImpl.deleteImage(downloadUrl);
}


