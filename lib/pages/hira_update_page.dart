import 'package:flutter/material.dart';
import '../widgets/hira_update_section.dart';
import '../core/theme/app_colors.dart';

/// HIRA 수가·급여 변경 포인트 페이지
class HiraUpdatePage extends StatelessWidget {
  const HiraUpdatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.appBg,
      child: SingleChildScrollView(
        child: HiraUpdateSection(),
      ),
    );
  }
}













