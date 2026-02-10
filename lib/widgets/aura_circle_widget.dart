import 'dart:math';
import 'package:flutter/material.dart';

/// 중앙 원 + 확산광(오라) 위젯
///
/// [bondScore] (0~100)에 따라 오라가 원 둘레를 감싸는 각도(0~360°)가 결정됩니다.
/// 호흡 애니메이션: opacity sin wave (blur sigma 고정)
/// 렌더링: CustomPainter + MaskFilter.blur + RepaintBoundary
class AuraCircleWidget extends StatefulWidget {
  /// 결 점수 (0~100)
  final double bondScore;

  /// 원 전체 크기 (width = height)
  final double size;

  /// 원 내부 메인 텍스트
  final String mainText;

  /// 원 하단 보조 텍스트 (예: "결 52")
  final String? subText;

  /// 원 탭 콜백
  final VoidCallback? onTap;

  /// 원 길게 누르기 콜백
  final VoidCallback? onLongPress;

  const AuraCircleWidget({
    super.key,
    required this.bondScore,
    this.size = 260,
    this.mainText = '오늘도 여기.',
    this.subText,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<AuraCircleWidget> createState() => _AuraCircleWidgetState();
}

class _AuraCircleWidgetState extends State<AuraCircleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathController;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final circleInnerRadius = widget.size * 0.35;

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── 오라 + 원 (CustomPainter) ──
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _breathController,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _AuraPainter(
                      bondScore: widget.bondScore,
                      breathValue: _breathController.value,
                    ),
                  );
                },
              ),
            ),

            // ── 원 내부 텍스트 ──
            SizedBox(
              width: circleInnerRadius * 1.5,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.mainText,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF424242),
                      height: 1.5,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (widget.subText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.subText!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey[400],
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 오라 + 원을 그리는 CustomPainter
///
/// 3-layer 확산광: outer(넓고 흐릿) → mid → core(좁고 선명)
/// 색상: 시안 → 블루 그라데이션
class _AuraPainter extends CustomPainter {
  final double bondScore;
  final double breathValue;

  _AuraPainter({
    required this.bondScore,
    required this.breathValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final circleRadius = size.width * 0.35;
    final auraRadius = size.width * 0.42;

    // 호흡: 부드러운 sin wave (0.55 ~ 1.0)
    final breathOpacity = 0.55 + 0.45 * sin(breathValue * pi);

    // 오라 각도: bondScore/100 * 360°
    final sweepAngle = (bondScore / 100.0).clamp(0.0, 1.0) * 2 * pi;
    const startAngle = -pi / 2; // 12시 방향에서 시작

    // ── 오라 그리기 (3겹 확산) ──
    if (sweepAngle > 0.01) {
      final auraRect = Rect.fromCircle(center: center, radius: auraRadius);

      // Layer 1: 외곽 확산 (가장 넓고 흐릿)
      final outerGlow = Paint()
        ..color = const Color(0xFF00BCD4).withOpacity(0.18 * breathOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 38
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
      canvas.drawArc(auraRect, startAngle, sweepAngle, false, outerGlow);

      // Layer 2: 중간 확산
      final midGlow = Paint()
        ..color = const Color(0xFF0097A7).withOpacity(0.30 * breathOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawArc(auraRect, startAngle, sweepAngle, false, midGlow);

      // Layer 3: 코어 (가장 좁고 선명)
      final coreGlow = Paint()
        ..color = const Color(0xFF1E88E5).withOpacity(0.45 * breathOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawArc(auraRect, startAngle, sweepAngle, false, coreGlow);
    }

    // ── 흰색 원 (중앙) ──
    canvas.drawCircle(
      center,
      circleRadius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    // ── 원 경계: 극미세 그림자 (라인 아닌 블러) ──
    canvas.drawCircle(
      center,
      circleRadius,
      Paint()
        ..color = const Color(0xFFE0E0E0).withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  @override
  bool shouldRepaint(covariant _AuraPainter oldDelegate) {
    return oldDelegate.bondScore != bondScore ||
        oldDelegate.breathValue != breathValue;
  }
}

