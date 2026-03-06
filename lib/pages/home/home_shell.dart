import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../bond_page.dart';
import '../caring_page.dart';
import '../growth_page.dart';
import '../job_page.dart';
import '../onboarding/onboarding_profile_screen.dart';
import '../../services/user_profile_service.dart';
import '../../services/onboarding_service.dart';
import '../../features/onboarding/app_onboarding_controller.dart';
import '../../features/onboarding/app_onboarding_overlay.dart';

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

  // ── 탭 위젯 캐시 ──
  late final BondPage _bondPage;
  late final GrowthPage _growthPage;
  late final JobPage _jobPage;

  final ValueNotifier<int> _growthSubTabNotifier = ValueNotifier<int>(-1);

  // ── 앱 온보딩 ──
  bool _onboardingActive = false;
  late final AppOnboardingController _onboardingCtrl;

  // ── 2번 탭 잠금 툴팁 ──
  OverlayEntry? _bondTooltip;

  @override
  void initState() {
    super.initState();
    _bondPage = const BondPage();
    _growthPage = GrowthPage(subTabNotifier: _growthSubTabNotifier);
    _jobPage = const JobPage();

    _onboardingCtrl = AppOnboardingController();
    // step 변경 시 HomeShell 리빌드 → CaringPage에 새 대사 전달
    _onboardingCtrl.addListener(() {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnboarding());
  }

  @override
  void dispose() {
    _growthSubTabNotifier.dispose();
    _onboardingCtrl.dispose();
    _bondTooltip?.remove();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  // 온보딩 체크 + 시작
  // ─────────────────────────────────────────────────────────
  Future<void> _checkOnboarding() async {
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
    // CaringPage 상단 4카드 + 하단 4버튼 페이드인은 해당 탭이 그냥 활성화되며 보임
  }

  // ─────────────────────────────────────────────────────────
  // 탭 이동 (온보딩 중에는 오버레이가 요청한 탭만 허용)
  // ─────────────────────────────────────────────────────────
  void _onTap(int idx) async {
    // ── 온보딩 중: 지정 탭만 허용, 그 외 차단 ──
    if (_onboardingActive) {
      // 2번 탭(같이)은 항상 차단
      if (idx == _bondTabIndex) return;
      // 커리어 탭 유도 step이면 커리어 탭만 허용
      if (_onboardingCtrl.isSpotlight && idx != 3) return;
      setState(() => _selectedIndex = idx);
      return;
    }

    // ── 일반 모드 ──
    if (idx == _bondTabIndex) {
      // 3일 이내면 툴팁 표시
      final isUnlocked = await _isBondTabUnlocked();
      if (!isUnlocked) {
        _showBondTooltip();
        return;
      }

      final isCompleted = await UserProfileService.isOnboardingCompleted();
      if (!isCompleted && mounted) {
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const OnboardingProfileScreen()),
        );
        if (result == true && mounted) {
          setState(() => _selectedIndex = idx);
        }
        return;
      }
    }

    setState(() => _selectedIndex = idx);
  }

  /// firstLaunchAt 기준 3일 경과 여부
  Future<bool> _isBondTabUnlocked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final firstLaunch = prefs.getInt('firstLaunchAt');
      if (firstLaunch == null) {
        await prefs.setInt(
          'firstLaunchAt',
          DateTime.now().millisecondsSinceEpoch,
        );
        return false;
      }
      final first = DateTime.fromMillisecondsSinceEpoch(firstLaunch);
      return DateTime.now().difference(first).inDays >= 3;
    } catch (_) {
      return true;
    }
  }

  /// 2번 탭 잠금 툴팁 표시 (탭 버튼 위에 작게)
  void _showBondTooltip() {
    _bondTooltip?.remove();
    _bondTooltip = null;

    final overlay = Overlay.of(context);
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder:
          (ctx) => Positioned(
            bottom: kBottomNavigationBarHeight + 8,
            left: MediaQuery.of(ctx).size.width / 4 + 4,
            right: MediaQuery.of(ctx).size.width * 2 / 4 + 4,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3D3535).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '같이 탭은 앱 설치 3일 후 가능해요',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    decoration: TextDecoration.none,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
    );

    _bondTooltip = entry;
    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 2), () {
      entry.remove();
      if (_bondTooltip == entry) _bondTooltip = null;
    });
  }

  void _onTabRequested(int index) {
    if (_onboardingActive) return;
    setState(() => _selectedIndex = index);
  }

  void _onGrowthSubTabRequested(int subTab) {
    if (_onboardingActive) return;
    setState(() => _selectedIndex = 2);
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
      // CaringPage는 온보딩 상태를 실시간으로 전달하기 위해 build()에서 생성
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
      _jobPage,
    ];

    return Scaffold(
      body: Stack(
        children: [
          // ── 탭 콘텐츠 ──
          IndexedStack(index: _selectedIndex, children: pages),

          // ── 온보딩 오버레이 ──
          if (_onboardingActive)
            ListenableBuilder(
              listenable: _onboardingCtrl,
              builder:
                  (_, __) => AppOnboardingOverlay(
                    controller: _onboardingCtrl,
                    onTabChangeRequest: (idx) {
                      setState(() => _selectedIndex = idx);
                    },
                    onComplete: _onOnboardingComplete,
                  ),
            ),
        ],
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
            label: '커리어',
          ),
        ],
      ),
    );
  }
}
