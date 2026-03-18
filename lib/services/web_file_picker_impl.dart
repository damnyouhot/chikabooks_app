// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class WebPickedFile {
  final String name;
  final String extension;
  final int size;
  final Uint8List bytes;
  const WebPickedFile({
    required this.name,
    required this.extension,
    required this.size,
    required this.bytes,
  });
}

/// 브라우저 네이티브 input[type=file]로 파일 선택
Future<WebPickedFile?> pickFileFromBrowser() async {
  debugPrint('📂 [WebFilePicker] pickFileFromBrowser() 진입');

  final completer = Completer<WebPickedFile?>();

  final input = html.FileUploadInputElement()
    ..accept = '.pdf,.jpg,.jpeg,.png'
    ..multiple = false;

  bool handled = false;

  input.onChange.listen((event) async {
    if (handled) return;
    handled = true;
    debugPrint('📂 [WebFilePicker] onChange 발생');

    final files = input.files;
    if (files == null || files.isEmpty) {
      debugPrint('📂 [WebFilePicker] 파일 없음');
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final file = files.first;
    debugPrint('📂 [WebFilePicker] 선택: name=${file.name}, size=${file.size}, type=${file.type}');

    try {
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoadEnd.first;

      if (reader.result == null) {
        debugPrint('📂 [WebFilePicker] FileReader 결과 null');
        if (!completer.isCompleted) completer.complete(null);
        return;
      }

      final bytes = Uint8List.fromList(reader.result as List<int>);
      final name  = file.name;
      final dotIdx = name.lastIndexOf('.');
      final ext = dotIdx >= 0 ? name.substring(dotIdx + 1).toLowerCase() : '';

      debugPrint('📂 [WebFilePicker] 읽기 완료: ${bytes.length}bytes, ext=$ext');

      if (!completer.isCompleted) {
        completer.complete(WebPickedFile(
          name: name,
          extension: ext,
          size: file.size,
          bytes: bytes,
        ));
      }
    } catch (e) {
      debugPrint('📂 [WebFilePicker] FileReader 오류: $e');
      if (!completer.isCompleted) completer.complete(null);
    }
  });

  input.click();
  debugPrint('📂 [WebFilePicker] input.click() 완료 — 다이얼로그 열림');

  // 취소 감지: focus 복귀 후 파일 미선택이면 null
  html.window.onFocus.first.then((_) {
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!handled && !completer.isCompleted) {
        debugPrint('📂 [WebFilePicker] 사용자 취소 감지');
        completer.complete(null);
      }
    });
  });

  return completer.future;
}
