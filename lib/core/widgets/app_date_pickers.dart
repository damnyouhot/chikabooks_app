import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 앱 톤에 맞춘 날짜 선택 — [showDatePicker]를 [Theme]으로 감싸 primary·surface를 통일한다.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTime? currentDate,
  DatePickerEntryMode initialEntryMode = DatePickerEntryMode.calendar,
  SelectableDayPredicate? selectableDayPredicate,
  String? helpText,
  String? cancelText,
  String? confirmText,
  Locale? locale,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? errorFormatText,
  String? errorInvalidText,
  String? fieldHintText,
  String? fieldLabelText,
  DatePickerMode initialDatePickerMode = DatePickerMode.day,
  RouteSettings? routeSettings,
  TextDirection? textDirection,
  Offset? anchorPoint,
}) {
  final base = Theme.of(context);
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    currentDate: currentDate,
    initialEntryMode: initialEntryMode,
    selectableDayPredicate: selectableDayPredicate,
    helpText: helpText,
    cancelText: cancelText,
    confirmText: confirmText,
    locale: locale,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    errorFormatText: errorFormatText,
    errorInvalidText: errorInvalidText,
    fieldHintText: fieldHintText,
    fieldLabelText: fieldLabelText,
    initialDatePickerMode: initialDatePickerMode,
    routeSettings: routeSettings,
    textDirection: textDirection,
    anchorPoint: anchorPoint,
    builder: (dialogContext, child) {
      return Theme(
        data: base.copyWith(
          colorScheme: base.colorScheme.copyWith(
            primary: AppColors.cardPrimary,
            onPrimary: AppColors.onCardEmphasis,
            surface: AppColors.appBg,
            onSurface: AppColors.textPrimary,
            surfaceContainerHighest: AppColors.surfaceMuted,
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      );
    },
  );
}
