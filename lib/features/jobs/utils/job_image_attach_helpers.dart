import 'package:desktop_drop/desktop_drop.dart';
import 'package:image_picker/image_picker.dart';

bool isAllowedJobImageFileName(String name) {
  final lower = name.toLowerCase();
  final dot = lower.lastIndexOf('.');
  if (dot < 0 || dot == lower.length - 1) return false;
  final ext = lower.substring(dot + 1);
  return const {'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'}.contains(ext);
}

/// [DropItemDirectory]은 하위 파일만 펼쳐서 반환한다.
List<XFile> flattenDropItems(List<DropItem> items) {
  final out = <XFile>[];
  void walk(DropItem item) {
    if (item is DropItemDirectory) {
      for (final c in item.children) {
        walk(c);
      }
    } else {
      out.add(item);
    }
  }
  for (final i in items) {
    walk(i);
  }
  return out;
}
