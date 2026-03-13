import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// ══════════════════════════════════════════════════════════════
/// AppMutedButton — Muted surface 배경의 소형 버튼
///
/// 사용 위치:
///   - HIRA 카드 하단 "원문 보기", "저장", "댓글" 버튼
///   - 기타 보조 액션 버튼
///
/// 원칙:
///   - 기본 배경: AppColors.surfaceMuted
///   - 활성 배경: activeColor (저장됨 등 상태 표현 시)
///   - boxShadow 없음 / Border 없음
///   - 텍스트/아이콘: AppColors.textSecondary
/// ══════════════════════════════════════════════════════════════
class AppMutedButton extends StatelessWidget {
  const AppMutedButton({
    super.key,
    required this.onTap,
    this.label,
    this.icon,
    this.isActive = false,
    this.activeColor,
    this.padding,
  });

  final VoidCallback onTap;

  /// 버튼 텍스트. null이면 아이콘만 표시
  final String? label;

  /// 버튼 아이콘. null이면 텍스트만 표시
  final IconData? icon;

  /// 활성 상태 여부 (저장됨 등)
  final bool isActive;

  /// 활성 시 배경색. 기본: AppColors.surfaceMuted (비활성과 동일, 색으로만 구분 필요 시 지정)
  final Color? activeColor;

  /// 내부 패딩. 기본값: symmetric(horizontal:12, vertical:10)
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final bgColor = isActive
        ? (activeColor ?? AppColors.surfaceMuted)
        : AppColors.surfaceMuted;

    final contentColor = AppColors.textSecondary;

    final borderRadius = BorderRadius.circular(AppRadius.md);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ??
            const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: borderRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null)
              Icon(icon, size: 14, color: contentColor),
            if (icon != null && label != null)
              const SizedBox(width: AppSpacing.xs),
            if (label != null)
              Text(
                label!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: contentColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

