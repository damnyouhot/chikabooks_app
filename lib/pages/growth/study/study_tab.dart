// lib/pages/growth/study/study_tab.dart

import 'package:flutter/material.dart';
import 'mydesk_tab.dart';
import 'ebook_list_page.dart';

class StudyTab extends StatelessWidget {
  const StudyTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // 서브탭 개수: 나의 책상, 치과책방
      child: Column(
        children: [
          // 상단 탭바
          TabBar(
            labelColor: Colors.pink,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.pink,
            tabs: const [
              Tab(text: '나의 책상'),
              Tab(text: '치과책방'),
            ],
          ),
          // 각 탭에 들어갈 화면
          Expanded(
            child: TabBarView(
              children: [
                const MyDeskTab(), // 기존 내 책상 화면
                const EbookListPage(), // 치과책방(전자책 리스트)
              ],
            ),
          ),
        ],
      ),
    );
  }
}
