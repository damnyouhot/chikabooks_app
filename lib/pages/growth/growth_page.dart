import 'package:flutter/material.dart';
import 'dashboard_tab.dart'; // 대시보드 탭 import
import 'selfcare_tab.dart';
import 'study/study_tab.dart';

class GrowthPage extends StatelessWidget {
  const GrowthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // 탭 개수 2개 -> 3개로 변경
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: '대시보드'), // 대시보드 탭 추가
              Tab(text: '가꾸기'),
              Tab(text: '나의 서재'),
            ],
          ),
          Expanded(
            child: const TabBarView(
              children: [
                DashboardTab(), // ① 대시보드 탭 화면
                SelfCareTab(), // ② 가꾸기 탭 화면
                StudyTab(), // ③ 나의 서재 탭 화면
              ],
            ),
          ),
        ],
      ),
    );
  }
}
