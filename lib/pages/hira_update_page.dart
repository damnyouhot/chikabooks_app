import 'package:flutter/material.dart';
import '../widgets/hira_update_section.dart';
import '../core/theme/tab_theme.dart';

// ── growth 탭 내부: 배경은 growth_page Scaffold가 담당 ──
// 색상 변경 → app_colors.dart Primitive만 수정하면 자동 반영
final _kBg = TabTheme.growth.bg;  // Neon Lime

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













