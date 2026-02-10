import 'dart:math';
import 'package:flutter/material.dart';

/// 중앙 원 + 확산광(오라) 위젯 v3
///
/// 기본: 360도 오라가 잔잔한 물결처럼 천천히 움직임
/// 발화: 텍스트 변경 시 오라가 드라마틱하게 팽창·밝아짐
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
    this.size = 300,
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
  // 물결 애니메이션 (항상 반복, 느리게)
  late AnimationController _waveController;

  // 발화(드라마틱) 애니메이션 (텍스트 변경 시 1회)
  late AnimationController _speakController;

  @override
  void initState() {
    super.initState();

    // 물결: 10초 주기 무한 반복 (잔잔한 물결)
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 10000),
    )..repeat();

    // 발화: 2초짜리 드라마틱 효과 (1회성)
    _speakController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
  }

  @override
  void didUpdateWidget(covariant AuraCircleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 텍스트가 바뀌면 → 발화 (드라마틱 모션)
    if (oldWidget.mainText != widget.mainText) {
      _speakController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _speakController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final circleInnerRadius = widget.size * 0.37;

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
                    Listenable.merge([_waveController, _speakController]),
                builder: (context, _) {
                  return CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _AuraWavePainter(
                      bondScore: widget.bondScore,
                      wavePhase: _waveController.value,
                      speakProgress: _speakController.value,
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

/// 360도 물결 오라 페인터
///
/// idle: 4개 레이어가 각각 다른 위상으로 천천히 팽창/수축 (잔잔한 물결)
/// speak: 진폭·밝기·회전속도 급상승 + 파동 링 2개 추가 (드라마틱)
class _AuraWavePainter extends CustomPainter {
  final double bondScore;
  final double wavePhase; // 0~1 (continuous loop)
  final double speakProgress; // 0~1 (one-shot, 0=idle)

  _AuraWavePainter({
    required this.bondScore,
    required this.wavePhase,
    required this.speakProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseCircleRadius = size.width * 0.40;
    final ratio = (bondScore / 100.0).clamp(0.0, 1.0);

    // 발화 강도: sin curve로 자연스럽게 상승 → 하강
    final speakIntensity = sin(speakProgress * pi);

    // ── 물결 파라미터 ──
    // idle(잔잔한 물결): 진폭 2~4px (결에 따라)
    // speak(드라마틱): 진폭 최대 18px
    final idleAmplitude = 2.0 + ratio * 2.0;
    const speakAmplitude = 18.0;
    final amplitude =
        idleAmplitude + (speakAmplitude - idleAmplitude) * speakIntensity;

    // 기본 opacity: 결에 따라 0.08~0.30
    final idleOpacity = 0.08 + ratio * 0.22;
    // 발화 시 추가 밝기
    final extraOpacity = 0.25 * speakIntensity;

    // 그라데이션 회전 (idle: 느리게, speak: 빠르게)
    final rotationSpeed = 0.3 + speakIntensity * 2.5;
    final baseRotation = wavePhase * 2 * pi * rotationSpeed;

    // ── 4개의 물결 레이어 (360도 전체 감싸기) ──
    for (int i = 0; i < 4; i++) {
      final phaseOffset = i * pi / 2; // 각 레이어마다 90도 위상차
      final layerWave = sin(wavePhase * 2 * pi + phaseOffset);

      // 각 레이어의 반경: 안쪽부터 바깥으로
      final layerBaseOffset = 8.0 + i * 7.0;
      final layerRadius =
          baseCircleRadius + layerBaseOffset + amplitude * layerWave;

      // 안쪽 레이어일수록 밝고, 바깥일수록 투명
      final layerFade = 1.0 - i * 0.2;
      final opacityWave =
          0.75 + 0.25 * cos(wavePhase * 2 * pi + phaseOffset * 0.7);
      final layerOpacity =
          ((idleOpacity + extraOpacity) * layerFade * opacityWave)
              .clamp(0.0, 1.0);

      // blur: 바깥 레이어일수록 더 퍼짐
      final blurSigma = 14.0 + i * 10.0 + speakIntensity * 8.0;
      final strokeWidth = 18.0 + i * 8.0 + speakIntensity * 12.0;

      _drawWaveLayer(
        canvas: canvas,
        center: center,
        radius: layerRadius,
        opacity: layerOpacity,
        blurSigma: blurSigma,
        strokeWidth: strokeWidth,
        rotationAngle: baseRotation + i * 0.4 + wavePhase * i * 0.5,
      );
    }

    // ── 발화 시 추가 파동 링 (팽창하며 사라짐) ──
    if (speakIntensity > 0.01) {
      // 파동 1: 메인 파동
      final pulseRadius = baseCircleRadius + 35 * speakProgress;
      final pulseOpacity = speakIntensity * 0.35;
      canvas.drawCircle(
        center,
        pulseRadius,
        Paint()
          ..color = const Color(0xFF00BCD4).withOpacity(pulseOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0 * (1.0 - speakProgress * 0.5)
          ..maskFilter =
              MaskFilter.blur(BlurStyle.normal, 10 + speakProgress * 8),
      );

      // 파동 2: 약간 딜레이된 두 번째 파동
      final pulse2Raw = (speakProgress - 0.15).clamp(0.0, 1.0);
      if (pulse2Raw > 0) {
        final pulse2Intensity = sin(pulse2Raw / 0.85 * pi);
        canvas.drawCircle(
          center,
          baseCircleRadius + 25 * pulse2Raw,
          Paint()
            ..color =
                const Color(0xFF00E5FF).withOpacity(pulse2Intensity * 0.2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
        );
      }
    }

    // ── 그림자 (1시→7시 방향, 빛 = 우상단 → 그림자 = 좌하단) ──
    const shadowDist = 6.0;
    final shadowOffsetX = cos(120 * pi / 180) * shadowDist;
    final shadowOffsetY = sin(120 * pi / 180) * shadowDist;
    final shadowCenter = Offset(
      center.dx + shadowOffsetX,
      center.dy + shadowOffsetY,
    );

    // 그림자 Layer 1: 넓고 흐린
    canvas.drawCircle(
      shadowCenter + Offset(shadowOffsetX * 0.5, shadowOffsetY * 0.5),
      baseCircleRadius + 2,
      Paint()
        ..color = const Color(0xFF9E9EBE).withOpacity(0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // 그림자 Layer 2: 가까운 진한 그림자
    canvas.drawCircle(
      shadowCenter,
      baseCircleRadius,
      Paint()
        ..color = const Color(0xFF8888AA).withOpacity(0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // ── 원 내부: 미세 호흡 (반경 ±1.5px) ──
    final breathDelta = sin(wavePhase * 2 * pi) * 1.5;
    final circleRadius = baseCircleRadius + breathDelta;

    // 흰색 원
    canvas.drawCircle(
      center,
      circleRadius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    // 경계: 극미세 블러 (선이 아닌 은은한 그림자)
    canvas.drawCircle(
      center,
      circleRadius,
      Paint()
        ..color = const Color(0xFFE0E0ED).withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  /// 360도 SweepGradient 기반 물결 레이어 1개
  ///
  /// 시안→틸→블루→틸→시안 그라데이션이 원 전체를 감싸며
  /// 회전·블러로 잔잔한 물결/구름 느낌 표현.
  void _drawWaveLayer({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double opacity,
    required double blurSigma,
    required double strokeWidth,
    required double rotationAngle,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 360도 전체를 감싸는 SweepGradient (회전 적용)
    final gradient = SweepGradient(
      colors: [
        Color(0xFF00E5FF).withOpacity(opacity),
        Color(0xFF00BCD4).withOpacity(opacity * 0.85),
        Color(0xFF1E88E5).withOpacity(opacity * 0.65),
        Color(0xFF00BCD4).withOpacity(opacity * 0.85),
        Color(0xFF00E5FF).withOpacity(opacity),
      ],
      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      transform: GradientRotation(rotationAngle),
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _AuraWavePainter old) {
    return old.bondScore != bondScore ||
        old.wavePhase != wavePhase ||
        old.speakProgress != speakProgress;
  }
}
