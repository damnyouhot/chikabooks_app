import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

class SeniorQuestionImageService {
  SeniorQuestionImageService._();

  static final _storage = FirebaseStorage.instance;

  static const int maxImages = 1;
  static const int _quality = 80;
  static const int _maxDimension = 1280;

  static Future<List<XFile>> pickImages({required int remaining}) async {
    if (remaining <= 0) return [];
    final picker = ImagePicker();
    if (remaining == 1) {
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: _quality,
        maxWidth: _maxDimension.toDouble(),
      );
      return picked == null ? [] : [picked];
    }
    final picked = await picker.pickMultiImage(limit: remaining);
    return picked.length > remaining ? picked.sublist(0, remaining) : picked;
  }

  static Future<Uint8List?> compress(XFile file) async {
    try {
      if (kIsWeb) return await file.readAsBytes();
      final result = await FlutterImageCompress.compressWithFile(
        file.path,
        minWidth: _maxDimension,
        minHeight: _maxDimension,
        quality: _quality,
        format: CompressFormat.jpeg,
      );
      if (result == null || result.isEmpty) return await file.readAsBytes();
      return Uint8List.fromList(result);
    } catch (e) {
      debugPrint('⚠️ SeniorQuestionImageService.compress: $e');
      return await file.readAsBytes();
    }
  }

  static Future<List<String>> uploadAll({
    required String questionId,
    required List<XFile> files,
  }) async {
    final urls = <String>[];
    for (var i = 0; i < files.take(maxImages).length; i++) {
      final bytes = await compress(files[i]);
      if (bytes == null) continue;
      final ref = _storage.ref('seniorQuestions/$questionId/images/$i.jpg');
      final task = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      urls.add(await task.ref.getDownloadURL());
    }
    return urls;
  }

  static Future<String?> uploadQuestionReplacementImage({
    required String questionId,
    required XFile file,
  }) async {
    final bytes = await compress(file);
    if (bytes == null) return null;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref(
      'seniorQuestions/$questionId/images/edit_$stamp.jpg',
    );
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return task.ref.getDownloadURL();
  }

  static Future<String?> uploadCommentImage({
    required String questionId,
    required String commentId,
    required XFile file,
  }) async {
    final bytes = await compress(file);
    if (bytes == null) return null;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref(
      'seniorQuestions/$questionId/images/comment_${commentId}_$stamp.jpg',
    );
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return task.ref.getDownloadURL();
  }
}
