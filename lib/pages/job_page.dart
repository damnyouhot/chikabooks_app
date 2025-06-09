// lib/pages/job_page.dart
import 'package:flutter/material.dart';
import '../screen/jobs/job_list_screen.dart'; // ← 위치 중요!

/// 하단 탭에서 “구직”을 누르면 바로 JobListScreen을 보여주는 래퍼 위젯
class JobPage extends StatelessWidget {
  const JobPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 필요 시 상단에 AppBar를 다시 두고 싶다면 Scaffold를 씌워도 됨
    return const JobListScreen();
  }
}
