import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// ══════════════════════════════════════════════════════════════
/// AppPrimaryButton — Primary CTA 버튼
///
/// 사용 위치:
///   - 지원하기, 저장하기, 확인 등 주요 액션
///
/// 원칙:
///   - 배경: AppColors.accent (Blue)
///   - 텍스트/아이콘: AppColors.onAccent (White)
///   - boxShadow 없음 / Border 없음
///   - 비활성: AppColors.disabledBg + AppColors.disabledText
/// ══════════════════════════════════════════════════════════════
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isEnabled = true,
    this.padding,
    this.radius,
    this.fontSize,
  });

  final String label;
  final VoidCallback? onPressed;

  /// 선택적 아이콘 (레이블 앞에 표시)
  final IconData? icon;

  /// true 이면 스피너 표시 + 탭 비활성
  final bool isLoading;

  /// false 이면 비활성 스타일 적용
  final bool isEnabled;

  /// 내부 패딩. 기본: symmetric(vertical: 14)
  final EdgeInsetsGeometry? padding;

  /// 모서리 반경. 기본: AppRadius.md
  final double? radius;

  /// 폰트 크기. 기본: 14
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? AppRadius.md;
    final active = isEnabled && !isLoading;

    return ElevatedButton(
      onPressed: active ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: active ? AppColors.accent : AppColors.disabledBg,
        foregroundColor: active ? AppColors.onAccent : AppColors.disabledText,
        disabledBackgroundColor: AppColors.disabledBg,
        disabledForegroundColor: AppColors.disabledText,
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: padding ??
            const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: AppSpacing.lg,
            ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r),
        ),
      ),
      child: isLoading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.onAccent),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: fontSize ?? 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
    );
  }
}


