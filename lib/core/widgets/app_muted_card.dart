import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// ══════════════════════════════════════════════════════════════
/// AppMutedCard — Muted surface 배경 카드 (회색 계열)
///
/// 사용 위치:
///   - 퀴즈 성적 카드 (_QuizStatsCard)
///   - 퀴즈 문제 카드 (_QuizCard)
///   - HIRA 업데이트 카드 (HiraUpdateCard)
///   - 내 서재 타일 (_MyBookTile, _SavedHiraTile)
///
/// 원칙:
///   - boxShadow 없음 / Border 없음
///   - 배경: AppColors.surfaceMuted
///   - 위 텍스트/아이콘: AppColors.textPrimary (Black)
/// ══════════════════════════════════════════════════════════════
class AppMutedCard extends StatelessWidget {
  const AppMutedCard({
    super.key,
    required this.child,
    this.padding,
    this.radius,
    this.onTap,
  });

  final Widget child;

  /// 내부 패딩. 기본값: EdgeInsets.all(AppSpacing.lg) = 16
  final EdgeInsetsGeometry? padding;

  /// 카드 radius. 기본값: AppRadius.lg = 14
  final double? radius;

  /// 탭 콜백. null이면 InkWell 없이 렌더
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? AppRadius.lg;
    final p = padding ?? const EdgeInsets.all(AppSpacing.lg);
    final borderRadius = BorderRadius.circular(r);

    final content = Container(
      padding: p,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
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
        child: content,
      ),
    );
  }
}

