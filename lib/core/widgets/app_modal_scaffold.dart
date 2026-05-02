import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// 크림 배경 카드만 (외부 [Dialog] 없이 삽입할 때).
///
/// 게이지 정보 팝업(`caring_page` `_showGaugeInfo`)과 동일 토큰:
/// - `AppColors.appBg`, `AppRadius.xl`, `AppColors.divider`
class AppModalCard extends StatelessWidget {
  const AppModalCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.borderOpacity = 1.0,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// `1.0` — 게이지 팝업과 동일. `0.7` — 속닥 확인 다이얼로그와 동일.
  final double borderOpacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.appBg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: AppColors.divider.withValues(alpha: borderOpacity),
        ),
      ),
      child: child,
    );
  }
}

/// 투명 [Dialog] + [AppModalCard].
///
/// 사용 예:
/// ```dart
/// showDialog<void>(
///   context: context,
///   builder: (ctx) => AppModalDialog(
///     child: Text('내용'),
///   ),
/// );
/// ```
///
/// 기본 `insetPadding`은 게이지 팝업과 동일(좌우 28). 확인 모달은
/// [AppConfirmModal]에서 `AppSpacing.xl` 전방향 패딩을 쓴다.
class AppModalDialog extends StatelessWidget {
  const AppModalDialog({
    super.key,
    required this.child,
    this.insetPadding,
    this.borderOpacity = 1.0,
    this.cardPadding = const EdgeInsets.all(AppSpacing.lg),
  });

  final Widget child;
  final EdgeInsets? insetPadding;
  final double borderOpacity;
  final EdgeInsetsGeometry cardPadding;

  static const EdgeInsets _defaultInset = EdgeInsets.symmetric(horizontal: 28);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: insetPadding ?? _defaultInset,
      child: AppModalCard(
        padding: cardPadding,
        borderOpacity: borderOpacity,
        child: child,
      ),
    );
  }
}

/// 앱 전역 바텀시트 기본값 — [AppModalDialog]와 동일 계열(상단 라운드·배리어).
///
/// 기본 [backgroundColor]는 `Colors.transparent`로, 자식이 카드 배경을 직접 그리는
/// 패턴(`FilterBottomSheet` 등)과 호환된다. 배경을 채우려면 [backgroundColor]를 넘긴다.
Future<T?> showAppModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  Color? backgroundColor,
  Color? barrierColor,
  ShapeBorder? shape,
  Clip clipBehavior = Clip.antiAlias,
  bool enableDrag = true,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    backgroundColor: backgroundColor ?? Colors.transparent,
    barrierColor: barrierColor ?? AppColors.black.withValues(alpha: 0.45),
    shape:
        shape ??
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
    clipBehavior: clipBehavior,
    enableDrag: enableDrag,
    isDismissible: isDismissible,
    builder: builder,
  );
}
