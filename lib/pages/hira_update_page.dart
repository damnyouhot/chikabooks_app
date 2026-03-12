import 'package:flutter/material.dart';
import '../widgets/hira_update_section.dart';

// ── growth 탭 내부: 배경은 growth_page Scaffold가 담당 ──
// 컨테이너 색상을 Neon으로 맞춤
const _kBg = Color(0xFFD1FF00);  // Neon Lime

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













