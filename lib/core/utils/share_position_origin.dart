import 'package:flutter/material.dart';

/// iOS(특히 iPad)에서 `Share.shareXFiles` 시 popover 앵커로 필요.
/// 영역이 0×0이면 `sharePositionOrigin` 관련 [PlatformException]이 난다.
Rect sharePositionOriginForShare(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box != null && box.hasSize) {
    final w = box.size.width;
    final h = box.size.height;
    if (w > 0 && h > 0) {
      final topLeft = box.localToGlobal(Offset.zero);
      return Rect.fromLTWH(topLeft.dx, topLeft.dy, w, h);
    }
  }
  final size = MediaQuery.sizeOf(context);
  final padding = MediaQuery.paddingOf(context);
  final cx = size.width / 2;
  final cy = padding.top + (size.height - padding.vertical) / 2;
  return Rect.fromCenter(center: Offset(cx, cy), width: 48, height: 48);
}
