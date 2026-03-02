import 'package:image_picker/image_picker.dart';

/// 웹 전용 — Firebase Storage 직접 업로드 대신 Mock 반환
/// (향후 firebase_storage 웹 지원 안정화 시 실 연동으로 교체 가능)
class JobImageUploaderImpl {
  static Future<List<String>> uploadImages({
    required String jobId,
    required List<XFile> images,
    void Function(int index, double progress)? onProgress,
  }) async {
    for (int i = 0; i < images.length; i++) {
      for (double p = 0.25; p <= 1.0; p += 0.25) {
        await Future.delayed(const Duration(milliseconds: 80));
        onProgress?.call(i, p);
      }
    }
    return List.generate(images.length, (i) => 'mock://web-upload/$jobId/$i');
  }

  static Future<void> deleteImage(String downloadUrl) async {
    // 웹 Mock — 아무 동작 없음
  }
}


