// lib/services/epub_utility.dart

import 'dart:typed_data';
import 'package:epubx/epubx.dart';
import 'package:image/image.dart' as img;

class EpubUtility {
  EpubUtility._();

  static Future<Uint8List?> extractCoverImage(Uint8List epubBytes) async {
    try {
      final epubBook = await EpubReader.readBook(epubBytes);
      final coverImageObject = epubBook.CoverImage;

      if (coverImageObject == null) {
        return null;
      }

      // ▼▼▼ 여기가 핵심 수정사항입니다 ▼▼▼
      // CoverImage는 이미 디코딩된 image 객체이므로, 바로 인코딩만 합니다.
      return Uint8List.fromList(img.encodeJpg(coverImageObject, quality: 85));
      // ▲▲▲ 여기가 핵심 수정사항입니다 ▲▲▲
    } catch (e) {
      return null;
    }
  }
}
