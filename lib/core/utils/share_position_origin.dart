import 'package:flutter/material.dart';

/// iOS(특히 iPad)에서 `Share.shareXFiles` 시 popover 앵커로 필요.
///
/// 반환되는 [Rect]는 반드시 다음 조건을 모두 만족해야 한다.
/// - 너비/높이가 0보다 큼
/// - 현재 화면(source view) 좌표 공간 안에 완전히 들어감
///
/// 그렇지 않으면 iOS 측에서 다음과 같은 [PlatformException]이 발생한다.
///   `sharePositionOrigin: argument must be set, ... must be non-zero
///    and within coordinate space of source view: {{0,0},{W,H}}`
///
/// 따라서 RenderBox로 계산한 글로벌 사각형을 화면 영역과 intersect 하여
/// clamp 하고, 비정상적인 경우 화면 중앙의 작은 박스로 fallback 한다.
Rect sharePositionOriginForShare(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final padding = MediaQuery.paddingOf(context);
  final screen = Rect.fromLTWH(0, 0, size.width, size.height);

  Rect fallback() {
    final cx = size.width / 2;
    final cy = padding.top + (size.height - padding.vertical) / 2;
    return Rect.fromCenter(center: Offset(cx, cy), width: 48, height: 48);
  }

  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) {
    return fallback();
  }

  final w = box.size.width;
  final h = box.size.height;
  if (w <= 0 || h <= 0) {
    return fallback();
  }

  final topLeft = box.localToGlobal(Offset.zero);
  final raw = Rect.fromLTWH(topLeft.dx, topLeft.dy, w, h);

  // 화면 좌표계 안으로 clamp.
  final clamped = raw.intersect(screen);
  if (clamped.isEmpty ||
      clamped.width <= 0 ||
      clamped.height <= 0 ||
      !clamped.isFinite) {
    return fallback();
  }

  return clamped;
}
