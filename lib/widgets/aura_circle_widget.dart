import 'dart:math';
import 'package:flutter/material.dart';

/// 중앙 원 + 확산광(오라) 위젯 v2
///
/// 오라 = SweepGradient 기반 부드러운 확산광 (구름/안개 느낌)
/// 발화 = 텍스트 변경 시 펄스 애니메이션 (팽창+밝기)
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
    with TickerProviderStateMixin {
  // 호흡 애니메이션 (항상 반복)
  late AnimationController _breathController;

  // 발화(펄스) 애니메이션 (텍스트 변경 시 1회)
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();

    // 호흡: 느린 사이클 (5초)
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat(reverse: true);

    // 펄스: 텍스트 변경 시 1회 재생 (800ms)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutCubic),
    );
    _pulseOpacity = Tween<double>(begin: 0.55, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(covariant AuraCircleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 텍스트가 바뀌면 펄스 발화
    if (oldWidget.mainText != widget.mainText) {
      _pulseController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _breathController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final circleInnerRadius = widget.size * 0.33;

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
                animation:
                    Listenable.merge([_breathController, _pulseController]),
                builder: (context, _) {
                  return CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _AuraPainterV2(
                      bondScore: widget.bondScore,
                      breathValue: _breathController.value,
                      pulseScale: _pulseScale.value,
                      pulseOpacity: _pulseOpacity.value,
                    ),
                  );
                },
              ),
            ),

            // ── 원 내부 텍스트 ──
            SizedBox(
              width: circleInnerRadius * 1.6,
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

/// 오라 페인터 v2 — SweepGradient 기반 부드러운 확산광
///
/// 이전 v1의 drawArc(stroke) 방식은 "네온 링" 느낌이었음.
/// v2는 SweepGradient + 넓은 strokeWidth + 높은 blurSigma로
/// "구름/안개" 같은 부드러운 확산광 구현.
class _AuraPainterV2 extends CustomPainter {
  final double bondScore;
  final double breathValue; // 0~1 호흡
  final double pulseScale; // 1.0~1.18 펄스 팽창
  final double pulseOpacity; // 0.55~0.0 펄스 추가 밝기

  _AuraPainterV2({
    required this.bondScore,
    required this.breathValue,
    required this.pulseScale,
    required this.pulseOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseCircleRadius = size.width * 0.35;

    // 호흡에 따른 미세 반경 변화 (±3px)
    final breathDelta = sin(breathValue * pi) * 3.0;
    final circleRadius = baseCircleRadius + breathDelta;

    // 오라 비율: bondScore/100 → 0.0 ~ 1.0
    final ratio = (bondScore / 100.0).clamp(0.0, 1.0);

    // 호흡 opacity: 0.55 ~ 1.0 범위
    final breathOpacity = 0.55 + 0.45 * sin(breathValue * pi);

    if (ratio > 0.01) {
      // ── Layer 1: 넓은 확산광 (가장 바깥, 구름/안개 느낌) ──
      _drawAuraLayer(
        canvas: canvas,
        center: center,
        radius: (circleRadius + 28) * pulseScale,
        sweepFraction: ratio,
        blurSigma: 45,
        opacity: (0.12 * breathOpacity + pulseOpacity * 0.15).clamp(0.0, 1.0),
        strokeWidth: 55,
      );

      // ── Layer 2: 중간 확산광 ──
      _drawAuraLayer(
        canvas: canvas,
        center: center,
        radius: (circleRadius + 14) * pulseScale,
        sweepFraction: ratio,
        blurSigma: 28,
        opacity: (0.20 * breathOpacity + pulseOpacity * 0.2).clamp(0.0, 1.0),
        strokeWidth: 36,
      );

      // ── Layer 3: 코어 확산광 (원에 가까운 은은한 빛) ──
      _drawAuraLayer(
        canvas: canvas,
        center: center,
        radius: (circleRadius + 5) * pulseScale,
        sweepFraction: ratio,
        blurSigma: 16,
        opacity: (0.28 * breathOpacity + pulseOpacity * 0.25).clamp(0.0, 1.0),
        strokeWidth: 20,
      );
    }

    // ── 펄스 링 (발화 시 퍼지는 파동) ──
    if (pulseOpacity > 0.01) {
      final pulseRing = Paint()
        ..color = Color(0xFF00BCD4).withOpacity(pulseOpacity * 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * pulseScale);
      canvas.drawCircle(center, circleRadius * pulseScale + 20, pulseRing);
    }

    // ── 흰색 원 (중앙) ──
    canvas.drawCircle(
      center,
      circleRadius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    // ── 원 경계: 극미세 블러 (선이 아닌 그림자) ──
    canvas.drawCircle(
      center,
      circleRadius,
      Paint()
        ..color = const Color(0xFFE8E8F0).withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  /// SweepGradient 기반 오라 레이어 1개 그리기
  ///
  /// 시안→블루 연속 그라데이션, 끝은 투명으로 자연스럽게 사라짐.
  /// drawArc(선) 대신 drawCircle + SweepGradient.shader 로
  /// gradient가 투명 영역을 담당 → 구름 느낌.
  void _drawAuraLayer({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double sweepFraction,
    required double blurSigma,
    required double opacity,
    required double strokeWidth,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);

    // SweepGradient: 12시 방향에서 시작
    // 시안 → 블루 → 투명 으로 부드럽게 전환
    final gradient = SweepGradient(
      startAngle: -pi / 2,
      endAngle: 2 * pi - pi / 2,
      colors: [
        Color(0xFF00E5FF).withOpacity(opacity * 0.7), // 시안 (시작)
        Color(0xFF00BCD4).withOpacity(opacity), // 시안-틸
        Color(0xFF1E88E5).withOpacity(opacity), // 블루
        Color(0xFF1E88E5).withOpacity(opacity * 0.3), // 블루 (페이드)
        Colors.transparent, // 투명 (끝)
        Colors.transparent, // 투명 (나머지)
      ],
      stops: [
        0.0,
        sweepFraction * 0.3,
        sweepFraction * 0.7,
        sweepFraction * 0.92,
        sweepFraction, // 여기서 투명으로 전환
        1.0,
      ],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);

    // 원형 전체를 그리되, gradient가 투명 처리를 담당
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _AuraPainterV2 old) {
    return old.bondScore != bondScore ||
        old.breathValue != breathValue ||
        old.pulseScale != pulseScale ||
        old.pulseOpacity != pulseOpacity;
  }
}
