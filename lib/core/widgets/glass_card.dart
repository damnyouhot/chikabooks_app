import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// ══════════════════════════════════════════════════════════════
/// GlassCard — 글래스모픽 카드
///
/// BackdropFilter(blur) + 반투명 흰색 배경 + 흰색 테두리
/// 배경에 그라디언트/영상 레이어가 있을 때 사용
/// ══════════════════════════════════════════════════════════════
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius,
    this.opacity = 0.12,
    this.blur = 24.0,
    this.borderOpacity = 0.20,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? radius;

  /// 카드 배경 불투명도 (0.0 ~ 1.0). 기본 0.12 (어두운 배경용 유리 느낌)
  final double opacity;

  /// blur 강도. 기본 24.0
  final double blur;

  /// 테두리 불투명도. 기본 0.20
  final double borderOpacity;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? AppRadius.xl;
    final p = padding ?? const EdgeInsets.all(AppSpacing.xl);
    final borderRadius = BorderRadius.circular(r);

    Widget content = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: p,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: borderRadius,
            border: Border.all(
              color: Colors.white.withOpacity(borderOpacity),
              width: 1.0,
            ),
          ),
          child: child,
        ),
      ),
    );

    if (margin != null) {
      content = Container(margin: margin, child: content);
    }

    if (onTap != null) {
      content = GestureDetector(onTap: onTap, child: content);
    }

    return content;
  }
}

/// 글로우 원형 오버레이 (아나모픽 빛 번짐 효과)
/// Stack의 배경 레이어로 사용
class GlowBlob extends StatelessWidget {
  const GlowBlob({
    super.key,
    required this.color,
    this.width = 200,
    this.height = 260,
    this.opacity = 0.45,
  });

  final Color color;
  final double width;
  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: RadialGradient(
          colors: [
            color.withOpacity(opacity),
            color.withOpacity(0.0),
          ],
        ),
      ),
    );
  }
}

