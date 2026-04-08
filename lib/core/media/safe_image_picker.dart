import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// [ImagePicker]의 카메라·갤러리 호출을 iOS/iPad/Android에서 안전하게 감싼 유틸.
///
/// - Info.plist의 [NSCameraUsageDescription] 등은 반드시 설정해야 TCC 크래시를 막을 수 있음.
/// - 취소(null)·권한 거부·미지원 기기는 예외/스낵바로 처리.
class SafeImagePicker {
  SafeImagePicker._();

  /// 단일 촬영. 웹에서는 null (호출부에서 카메라 버튼 비표시 권장).
  static Future<XFile?> pickSingleFromCamera({
    required BuildContext context,
    required ImagePicker picker,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
  }) async {
    if (kIsWeb) return null;

    if (!picker.supportsImageSource(ImageSource.camera)) {
      _snack(context, '이 기기에서는 카메라를 사용할 수 없어요.');
      return null;
    }

    try {
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: preferredCameraDevice,
        requestFullMetadata: false,
      );
      if (!context.mounted) return null;
      if (photo == null) return null;
      if (!_isValidPickedFile(photo)) {
        _snack(context, '사진을 불러오지 못했어요. 다시 시도해 주세요.');
        return null;
      }
      return photo;
    } on PlatformException catch (e) {
      if (!context.mounted) return null;
      _snack(context, _cameraPlatformMessage(e));
      return null;
    } catch (e, st) {
      debugPrint('SafeImagePicker.pickSingleFromCamera: $e\n$st');
      if (context.mounted) {
        _snack(context, '카메라를 사용할 수 없어요. 설정에서 권한을 확인해 주세요.');
      }
      return null;
    }
  }

  /// 갤러리 다중 선택 (웹 포함).
  static Future<List<XFile>> pickMultiFromGallery({
    required BuildContext context,
    required ImagePicker picker,
  }) async {
    try {
      final images = await picker.pickMultiImage(
        requestFullMetadata: false,
      );
      if (!context.mounted) return [];
      if (images.isEmpty) return [];

      final valid = <XFile>[];
      for (final f in images) {
        if (_isValidPickedFile(f)) {
          valid.add(f);
        }
      }
      if (valid.length < images.length && context.mounted) {
        _snack(context, '일부 사진을 불러오지 못했어요.');
      }
      return valid;
    } on PlatformException catch (e) {
      if (!context.mounted) return [];
      _snack(context, _galleryPlatformMessage(e));
      return [];
    } catch (e, st) {
      debugPrint('SafeImagePicker.pickMultiFromGallery: $e\n$st');
      if (context.mounted) {
        _snack(context, '사진을 선택할 수 없어요. 설정에서 사진 권한을 확인해 주세요.');
      }
      return [];
    }
  }

  static bool _isValidPickedFile(XFile f) {
    if (f.name.isEmpty) return false;
    if (!kIsWeb && f.path.isEmpty) return false;
    return true;
  }

  static void _snack(BuildContext context, String text) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  static String _cameraPlatformMessage(PlatformException e) {
    final c = e.code.toLowerCase();
    if (c.contains('permission') || c.contains('denied')) {
      return '카메라 권한이 필요해요. 설정에서 앱 권한을 허용해 주세요.';
    }
    if (c.contains('camera') && c.contains('unavailable')) {
      return '카메라를 사용할 수 없어요.';
    }
    final m = e.message;
    if (m != null && m.isNotEmpty) return m;
    return '카메라를 열 수 없어요.';
  }

  static String _galleryPlatformMessage(PlatformException e) {
    final c = e.code.toLowerCase();
    if (c.contains('permission') || c.contains('denied')) {
      return '사진 보관함 권한이 필요해요. 설정에서 허용해 주세요.';
    }
    final m = e.message;
    if (m != null && m.isNotEmpty) return m;
    return '사진을 선택할 수 없어요.';
  }
}
