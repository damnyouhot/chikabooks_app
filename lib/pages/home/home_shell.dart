import 'package:flutter/material.dart';
import '../bond_page.dart';
import '../caring_page.dart';
import '../growth_page.dart';
import '../job_page.dart';

/// 메인 홈 (탭 네비게이션)
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  /// 성장 탭 인덱스
  static const int _growthTabIndex = 2;

  void _onTap(int idx) => setState(() => _selectedIndex = idx);

  /// CaringPage에서 "성장 탭으로 이동" 콜백
  void _goToGrowthTab() => setState(() => _selectedIndex = _growthTabIndex);

  @override
  Widget build(BuildContext context) {
    // CaringPage에 탭 전환 콜백 주입
    final pages = <Widget>[
      CaringPage(onNavigateToGrowth: _goToGrowthTab),
      const BondPage(),
      const GrowthPage(),
      const JobPage(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF1E88E5),
        unselectedItemColor: Colors.grey[350],
        selectedFontSize: 11,
        unselectedFontSize: 11,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.spa_outlined),
            activeIcon: Icon(Icons.spa),
            label: '돌보기',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.all_inclusive_outlined),
            activeIcon: Icon(Icons.all_inclusive),
            label: '결',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: '성장',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline),
            activeIcon: Icon(Icons.work),
            label: '나아가기',
          ),
        ],
      ),
    );
  }
}

