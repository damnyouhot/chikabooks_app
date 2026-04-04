// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Flutter Web에서 [desktop_drop]이 window 까지 이벤트를 못 올리는 경우를 대비해,
/// document 레벨에서 파일 드롭을 받고 [boundaryKey] 영역 안일 때만 [onDrop]을 호출합니다.
class WebFileDropZone extends StatefulWidget {
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
  State<WebFileDropZone> createState() => _WebFileDropZoneState();
}

class _WebFileDropZoneState extends State<WebFileDropZone> {
  StreamSubscription<html.Event>? _dragOverSub;
  StreamSubscription<html.Event>? _dropSub;
  /// 드래그 중 포인터가 [boundaryKey] 안에 있는지 (콜백 중복 방지)
  bool _inside = false;

  @override
  void initState() {
    super.initState();
    _dragOverSub = html.document.onDragOver.listen(_onDragOver);
    _dropSub = html.document.onDrop.listen(_onDrop);
  }

  @override
  void dispose() {
    _dragOverSub?.cancel();
    _dropSub?.cancel();
    super.dispose();
  }

  bool _hasFiles(html.MouseEvent e) {
    final types = e.dataTransfer.types;
    if (types == null) return false;
    for (var i = 0; i < types.length; i++) {
      if (types[i] == 'Files') return true;
    }
    return false;
  }

  double _clientX(html.MouseEvent e) => e.client.x.toDouble();
  double _clientY(html.MouseEvent e) => e.client.y.toDouble();

  bool _pointInBoundary(num x, num y) {
    final ctx = widget.boundaryKey.currentContext;
    if (ctx == null) return false;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;
    final topLeft = box.localToGlobal(Offset.zero);
    final rect = Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      box.size.width,
      box.size.height,
    );
    return rect.contains(Offset(x.toDouble(), y.toDouble()));
  }

  void _setInside(bool v) {
    if (_inside == v) return;
    _inside = v;
    if (v) {
      widget.onDragEntered?.call();
    } else {
      widget.onDragExited?.call();
    }
  }

  void _onDragOver(html.Event event) {
    final e = event as html.MouseEvent;
    if (!_hasFiles(e)) return;
    e.preventDefault();
    if (_pointInBoundary(_clientX(e), _clientY(e))) {
      _setInside(true);
    } else {
      _setInside(false);
    }
  }

  Future<void> _onDrop(html.Event event) async {
    final e = event as html.MouseEvent;
    if (!_hasFiles(e)) return;
    e.preventDefault();
    _setInside(false);

    if (!_pointInBoundary(_clientX(e), _clientY(e))) return;

    final files = e.dataTransfer.files;
    if (files == null || files.isEmpty) return;

    final out = <XFile>[];
    for (var i = 0; i < files.length; i++) {
      final f = files[i];
      final url = html.Url.createObjectUrlFromBlob(f);
      out.add(XFile(url, name: f.name, mimeType: f.type));
    }
    if (out.isEmpty) return;
    await widget.onDrop(out);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
