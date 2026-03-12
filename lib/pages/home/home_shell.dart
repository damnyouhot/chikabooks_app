import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../bond_page.dart';
import '../caring_page.dart';
import '../growth_page.dart';
import '../job_page.dart';
import '../onboarding/onboarding_profile_screen.dart';
import '../../services/user_profile_service.dart';
import '../../services/onboarding_service.dart';
import '../../features/onboarding/app_onboarding_controller.dart';
import '../../features/onboarding/app_onboarding_overlay.dart';
// TabThemeNotifier 제거: 단일 컬러 시스템으로 통일
// BottomNavBar 색상은 AppTheme.light (bottomNavigationBarTheme) 에서 고정 관리

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

  // ── 탭 위젯 캐시 (JobPage는 온보딩 상태에 따라 build에서 생성) ──
  late final BondPage _bondPage;
  late final GrowthPage _growthPage;

  final ValueNotifier<int> _growthSubTabNotifier = ValueNotifier<int>(-1);

  // ── 앱 온보딩 ──
  bool _onboardingActive = false;
  late final AppOnboardingController _onboardingCtrl;

  @override
  void initState() {
    super.initState();
    _bondPage = const BondPage();
    _growthPage = GrowthPage(subTabNotifier: _growthSubTabNotifier);

    _onboardingCtrl = AppOnboardingController();
    _onboardingCtrl.addListener(() {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnboarding());

    FirebaseAuth.instance.authStateChanges().skip(1).listen((user) {
      if (!mounted) return;
      final newUid = user?.uid;
      if (newUid != null && !_onboardingActive) {
        _checkOnboarding();
      }
    });
  }

  @override
  void dispose() {
    _growthSubTabNotifier.dispose();
    _onboardingCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  // 온보딩 체크 + 시작
  // ─────────────────────────────────────────────────────────
  Future<void> _checkOnboarding() async {
    await Future.delayed(const Duration(milliseconds: 600));
    final should = await OnboardingService.shouldRunOnboarding();
    if (!should || !mounted) return;
    setState(() {
      _onboardingActive = true;
      _selectedIndex = 0;
    });
    _onboardingCtrl.start();
  }

  void _onOnboardingComplete() {
    setState(() => _onboardingActive = false);
  }

  // ─────────────────────────────────────────────────────────
  // 탭 이동 (TabThemeNotifier 제거 → setState만으로 단순화)
  // ─────────────────────────────────────────────────────────
  void _setTab(int idx) {
    setState(() => _selectedIndex = idx);
  }

  void _onTap(int idx) async {
    // ── 온보딩 중: 지정 탭만 허용, 그 외 차단 ──
    if (_onboardingActive) {
      if (idx == _bondTabIndex) return;

      if (_onboardingCtrl.isSpotlight) {
        final step = _onboardingCtrl.current;
        if (step == AppOnboardingStepId.step5 && idx != 3) return;
        if (step == AppOnboardingStepId.step5b && idx != 2) return;
        if (step == AppOnboardingStepId.step8 && idx != 0) return;
        setState(() => _selectedIndex = idx);
        _onboardingCtrl.advance();
        return;
      }
      _setTab(idx);
      return;
    }

    // ── 일반 모드 ──
    if (idx == _bondTabIndex) {
      final isCompleted = await UserProfileService.isOnboardingCompleted();
      if (!isCompleted && mounted) {
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const OnboardingProfileScreen()),
        );
        if (result == true && mounted) {
          _setTab(idx);
        }
        return;
      }
    }

    _setTab(idx);
  }

  void _onTabRequested(int index) {
    if (_onboardingActive) return;
    _setTab(index);
  }

  void _onGrowthSubTabRequested(int subTab) {
    if (_onboardingActive) return;
    _setTab(2);
    _growthSubTabNotifier.value = -1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _growthSubTabNotifier.value = subTab;
    });
  }

  // ─────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      CaringPage(
        key: const ValueKey('caring'),
        onTabRequested: _onTabRequested,
        onGrowthSubTabRequested: _onGrowthSubTabRequested,
        isOnboardingActive: _onboardingActive,
        onboardingDialogue: (_onboardingActive && _onboardingCtrl.isTab0Step)
            ? kStepDialogue[_onboardingCtrl.current]
            : null,
      ),
      _bondPage,
      _growthPage,
      JobPage(
        key: ValueKey('job_$_onboardingActive'),
        isOnboardingActive: _onboardingActive,
      ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _selectedIndex, children: pages),
          if (_onboardingActive)
            ListenableBuilder(
              listenable: _onboardingCtrl,
              builder: (_, __) => AppOnboardingOverlay(
                key: const ValueKey('onboarding_overlay'),
                controller: _onboardingCtrl,
                onTabChangeRequest: (idx) {
                  _setTab(idx);
                },
                onComplete: _onOnboardingComplete,
              ),
            ),
        ],
      ),
      // BottomNavigationBar: 색상은 AppTheme.light (bottomNavigationBarTheme)에서 고정 관리
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTap,
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
