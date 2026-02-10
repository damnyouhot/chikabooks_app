import 'package:flutter/material.dart';
import 'selfcare_tab.dart';
import 'study/study_tab.dart';

class GrowthPage extends StatelessWidget {
  const GrowthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: '가꾸기'),
              Tab(text: '나의 기록'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                SelfCareTab(),
                StudyTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
