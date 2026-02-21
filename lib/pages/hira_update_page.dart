import 'package:flutter/material.dart';
import '../widgets/hira_update_section.dart';

// ── 디자인 팔레트 (성장 탭과 통일) ──
const _kBg = Color(0xFFF1F7F7);

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




