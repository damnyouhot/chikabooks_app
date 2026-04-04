import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// 웹이 아닌 플랫폼 — [child]만 그대로 반환합니다.
class WebFileDropZone extends StatelessWidget {
  const WebFileDropZone({
    super.key,
    required this.child,
    required this.boundaryKey,
    required this.onDrop,
    this.onDragEntered,
    this.onDragExited,
  });

  final Widget child;
  final GlobalKey boundaryKey;
  final Future<void> Function(List<XFile> files) onDrop;
  final VoidCallback? onDragEntered;
  final VoidCallback? onDragExited;

  @override
  Widget build(BuildContext context) => child;
}
