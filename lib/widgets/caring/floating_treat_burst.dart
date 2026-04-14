import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 작은 먹이 아이콘이 위로 떠오르다 사라지는 오버레이 (퀴즈·투표 보상 피드백)
class FloatingTreatBurst {
  FloatingTreatBurst._();

  /// [iconCount]개의 아이콘을 살짝 퍼뜨려 표시 (2 → x2, 3 → x3 느낌)
  static void show(BuildContext context, {required int iconCount}) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _TreatBurstLayer(
        count: iconCount.clamp(1, 8),
        onDone: () {
          entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _TreatBurstLayer extends StatefulWidget {
  const _TreatBurstLayer({
    required this.count,
    required this.onDone,
  });

  final int count;
  final VoidCallback onDone;

  @override
  State<_TreatBurstLayer> createState() => _TreatBurstLayerState();
}

class _TreatBurstLayerState extends State<_TreatBurstLayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward().whenComplete(() {
        if (mounted) widget.onDone();
      });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final centerX = size.width / 2;
    final baseY = size.height * 0.42;

    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: List.generate(widget.count, (i) {
            final spread = (i - (widget.count - 1) / 2) * 22.0;
            final delay = i * 0.06;
            return AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = ((_c.value - delay).clamp(0.0, 1.0)).toDouble();
                final dy = -120 * Curves.easeOut.transform(t);
                final op = (1.0 - t) * (t < 0.15 ? t / 0.15 : 1.0);
                return Positioned(
                  left: centerX - 14 + spread,
                  top: baseY + dy,
                  child: Opacity(
                    opacity: op.clamp(0.0, 1.0),
                    child: Transform.rotate(
                      angle: (i % 2 == 0 ? 1 : -1) * 0.15 * math.sin(t * math.pi),
                      child: const Text(
                        '🍖',
                        style: TextStyle(fontSize: 17),
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}
