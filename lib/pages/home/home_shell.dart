import 'package:flutter/material.dart';
import '../bond_page.dart';
import '../caring_page.dart';
import '../growth_page.dart';
import '../job_page.dart';
import '../onboarding/onboarding_profile_screen.dart';
import '../../services/user_profile_service.dart';
import '../../services/onboarding_service.dart';

/// 메인 홈 (탭 네비게이션)
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  /// Bond 탭 인덱스
  static const int _bondTabIndex = 1;

  // ── 탭 위젯 캐시: build()가 호출될 때마다 재생성되지 않도록 State에 보관 ──
  late final CaringPage _caringPage;
  late final BondPage _bondPage;
  late final GrowthPage _growthPage;
  late final JobPage _jobPage;

  /// GrowthPage 서브탭 점프를 전달하는 notifier
  /// → GrowthPage 인스턴스를 재생성하지 않고 서브탭 이동 가능
  final ValueNotifier<int> _growthSubTabNotifier = ValueNotifier<int>(-1);

  @override
  void initState() {
    super.initState();
    _caringPage = CaringPage(
      onTabRequested: _onTabRequested,
      onGrowthSubTabRequested: _onGrowthSubTabRequested,
    );
    _bondPage = const BondPage();
    _growthPage = GrowthPage(subTabNotifier: _growthSubTabNotifier);
    _jobPage = const JobPage();

    // 로그인 직후 온보딩 실행 여부 확인
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnboarding());
  }

  @override
  void dispose() {
    _growthSubTabNotifier.dispose();
    super.dispose();
  }

  /// 로그인 직후 온보딩을 실행해야 하는지 확인
  Future<void> _checkOnboarding() async {
    final should = await OnboardingService.shouldRunOnboarding();
    if (!should || !mounted) return;

    // TODO: 실제 온보딩 화면으로 교체 예정
    // 현재는 플래그만 확인하고 debugPrint로 확인
    debugPrint('🎉 온보딩 시작 조건 충족 → 온보딩 화면 진입 예정');

    // 온보딩 화면 구현 완료 후 아래 주석 해제하여 사용:
    // await Navigator.of(context).push(
    //   MaterialPageRoute(builder: (_) => const AppOnboardingScreen()),
    // );
    // await OnboardingService.completeOnboarding();
  }

  void _onTap(int idx) async {
    // Bond 탭(1번 탭) 클릭 시 프로필 체크
    if (idx == _bondTabIndex) {
      final isCompleted = await UserProfileService.isOnboardingCompleted();

      if (!isCompleted && mounted) {
        // 온보딩 화면 표시 (하단 탭 바 보이게)
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const OnboardingProfileScreen()),
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

  /// CaringPage에서 다른 탭으로 이동하는 콜백
  void _onTabRequested(int index) => setState(() => _selectedIndex = index);

  /// CaringPage에서 성장하기 서브탭을 지정하는 콜백
  void _onGrowthSubTabRequested(int subTab) {
    setState(() => _selectedIndex = 2);
    // 같은 값이 연속 오면 리스너가 감지 못하므로 -1 경유 후 실제 값 설정
    _growthSubTabNotifier.value = -1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _growthSubTabNotifier.value = subTab;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _caringPage,
      _bondPage,
      _growthPage,
      _jobPage,
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
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
            label: '커리어',
          ),
        ],
      ),
    );
  }
}
