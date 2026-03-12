import 'package:flutter/material.dart';
import '../widgets/hira_update_section.dart';
import '../core/theme/app_colors.dart';

// ── growth 탭 내부: 배경은 AppColors.appBg 참조 ──
const _kBg = AppColors.appBg;

/// HIRA 수가·급여 변경 포인트 페이지
class HiraUpdatePage extends StatelessWidget {
  const HiraUpdatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBg,
      child: const SingleChildScrollView(
        child: HiraUpdateSection(),
      ),
    );
  }
}













