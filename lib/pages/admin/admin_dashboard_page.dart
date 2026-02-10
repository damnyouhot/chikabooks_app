import 'package:flutter/material.dart';
import '../ebook/ebook_list_page.dart';
import 'admin_ebook_create_page.dart';
import 'admin_item_create_page.dart'; // 아이템 등록 페이지 import
import 'admin_quiz_create_page.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4, // 탭 개수 3개 -> 4개로 변경
      child: Scaffold(
        appBar: AppBar(
          title: const Text('관리자 대시보드'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '전자책 목록'),
              Tab(text: '전자책 등록'),
              Tab(text: '퀴즈 등록'),
              Tab(text: '아이템 등록'), // 아이템 등록 탭 추가
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            EbookListPage(),
            AdminEbookCreatePage(),
            AdminQuizCreatePage(),
            AdminItemCreatePage(), // 아이템 등록 페이지 연결
          ],
        ),
      ),
    );
  }
}
