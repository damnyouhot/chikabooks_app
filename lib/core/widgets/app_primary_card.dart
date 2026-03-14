import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// ══════════════════════════════════════════════════════════════
/// AppPrimaryCard — Blue 배경 카드
///
/// 사용 위치:
///   - 커리어 카드, 이력서 바로가기 카드
///   - 성장하기 탭 내 Blue 카드 영역
///
/// 원칙:
///   - boxShadow 없음 / Border 없음
///   - 배경: AppColors.cardPrimary (Blue)
///   - 위 텍스트/아이콘: AppColors.onCardPrimary (White)
/// ══════════════════════════════════════════════════════════════
class AppPrimaryCard extends StatelessWidget {
  const AppPrimaryCard({
    super.key,
    required this.child,
    this.padding,
    this.radius,
    this.margin,
    this.onTap,
  });

  final Widget child;

  /// 내부 패딩. 기본값: EdgeInsets.all(AppSpacing.lg) = 16
  final EdgeInsetsGeometry? padding;

  /// 카드 radius. 기본값: AppRadius.xl = 16
  final double? radius;

  /// 외부 마진.
  final EdgeInsetsGeometry? margin;

  /// 탭 콜백. null이면 InkWell 없이 렌더
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? AppRadius.xl;
    final p = padding ?? const EdgeInsets.all(AppSpacing.lg);
    final borderRadius = BorderRadius.circular(r);

    final content = Container(
      margin: margin,
      padding: p,
      decoration: BoxDecoration(
        color: AppColors.cardPrimary,
        borderRadius: borderRadius,
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        splashColor: AppColors.onCardPrimary.withOpacity(0.08),
        highlightColor: AppColors.onCardPrimary.withOpacity(0.04),
        child: content,
      ),
    );
  }
}

