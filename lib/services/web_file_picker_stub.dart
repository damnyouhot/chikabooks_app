import 'dart:typed_data';

/// 앱(비웹) 빌드에서는 호출되지 않는 stub
/// conditional import로 웹 빌드에서만 web_file_picker_impl.dart가 사용됨
Future<WebPickedFile?> pickFileFromBrowser() async {
  throw UnsupportedError('pickFileFromBrowser는 웹에서만 사용 가능');
}

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
