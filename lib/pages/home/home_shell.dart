import 'package:flutter/material.dart';
import '../bond_page.dart';
import '../caring_page.dart';
import '../growth_page.dart';
import '../job_page.dart';
import '../onboarding/onboarding_profile_screen.dart';
import '../../services/user_profile_service.dart';

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

  /// Bond 탭 인덱스
  static const int _bondTabIndex = 1;

  void _onTap(int idx) async {
    // Bond 탭(2번 탭) 클릭 시 프로필 체크
    if (idx == _bondTabIndex) {
      final isCompleted = await UserProfileService.isOnboardingCompleted();
      
      if (!isCompleted && mounted) {
        // 온보딩 화면 표시 (하단 탭 바 보이게)
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => const OnboardingProfileScreen(),
          ),
        );
        
        // 온보딩 완료 후에만 탭 이동
        if (result == true && mounted) {
          setState(() => _selectedIndex = idx);
        }
        return;
      }
    }
    
    setState(() => _selectedIndex = idx);
  }

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
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '나',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: '같이',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: '성장하기',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline),
            activeIcon: Icon(Icons.work),
            label: '도전하기',
          ),
        ],
      ),
    );
  }
}



