import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../bond_page.dart';
import '../caring_page.dart';
import '../growth_page.dart';
import '../job_page.dart';
import '../onboarding/onboarding_profile_screen.dart';
import '../../services/user_profile_service.dart';
import '../../services/admin_activity_service.dart';
import '../../services/ebook_service.dart';
import '../../features/onboarding/app_onboarding_controller.dart';
import '../../features/onboarding/app_onboarding_overlay.dart';
import '../../core/theme/app_colors.dart';

/// 메인 홈 (탭 네비게이션)
class HomeShell extends StatefulWidget {
  /// OnboardingGate에서 온보딩 여부를 미리 판단해 전달
  /// true = 온보딩 실행, false = 일반 홈 화면
  final bool startWithOnboarding;
  const HomeShell({super.key, this.startWithOnboarding = false});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  /// Bond 탭 인덱스
  static const int _bondTabIndex = 1;

  // ── 탭 위젯 캐시 (JobPage는 온보딩 상태에 따라 build에서 생성) ──
  final _bondKey = GlobalKey<BondPageState>();
  late final BondPage _bondPage;
  late final GrowthPage _growthPage;

  final ValueNotifier<int> _growthSubTabNotifier = ValueNotifier<int>(-1);

  // ── 앱 온보딩 ──
  // OnboardingGate에서 이미 판단 완료 → 즉시 true로 설정
  bool _onboardingChecked = true;
  bool _onboardingActive = false;
  late final AppOnboardingController _onboardingCtrl;

  @override
  void initState() {
    super.initState();
    _bondPage = BondPage(key: _bondKey);
    _growthPage = GrowthPage(subTabNotifier: _growthSubTabNotifier);

    _onboardingCtrl = AppOnboardingController();
    _onboardingCtrl.addListener(() {
      if (mounted) setState(() {});
    });

    // OnboardingGate에서 전달받은 결과를 즉시 적용
    // → 빈 화면 → 일반 화면 → 온보딩 순의 깜빡임 없음
    if (widget.startWithOnboarding) {
      _onboardingActive = true;
      _selectedIndex = 0;
      _onboardingCtrl.start();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // _checkOnboarding() 제거 — OnboardingGate에서 이미 처리됨
      _recordAppOpen();
      AdminActivityService.warmupCache();
      // 로그인 후 아임웹 구매내역 자동 동기화 (fire-and-forget)
      _trySyncImwebPurchases();
    });

    // authStateChanges 리스너: 로그아웃→재로그인 시 OnboardingGate가
    // 새로 생성되어 자동 처리되므로 여기서 온보딩 재체크 불필요
  }

  @override
  void dispose() {
    _growthSubTabNotifier.dispose();
    _onboardingCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  // 앱 실행 기록: lastActiveAt 갱신 + appOpen 이벤트 (모두 fire-and-forget)
  // ─────────────────────────────────────────────────────────
  void _recordAppOpen() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // lastActiveAt 갱신 — UI를 기다리지 않음
    unawaited(
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'lastActiveAt': FieldValue.serverTimestamp()})
          .catchError((_) {}), // 문서 없을 경우 무시
    );

    // 활동 이벤트 기록 (이미 fire-and-forget)
    AdminActivityService.log(ActivityEventType.appOpen, page: 'home');
  }

  // ─────────────────────────────────────────────────────────
  // 아임웹 구매내역 자동 동기화 (로그인 직후 1회, fire-and-forget)
  // 이메일 없는 계정은 조용히 스킵. 실패해도 앱 동작에 영향 없음.
  // ─────────────────────────────────────────────────────────
  void _trySyncImwebPurchases() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null || user.email!.isEmpty) return;

    unawaited(
      Future.delayed(Duration.zero, () async {
        try {
          final service = context.read<EbookService>();
          final result = await service.syncImwebPurchases();
          final synced = result['synced'] as int? ?? 0;
          if (synced > 0 && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('📚 치과책방 구매내역 ${synced}권을 불러왔습니다.'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (_) {
          // 자동 동기화 실패는 무시 (수동 동기화 버튼으로 재시도 가능)
        }
      }),
    );
  }

  void _onOnboardingComplete() {
    setState(() => _onboardingActive = false);
  }

  // ─────────────────────────────────────────────────────────
  // 탭 이동 (TabThemeNotifier 제거 → setState만으로 단순화)
  // ─────────────────────────────────────────────────────────
  void _setTab(int idx) {
    setState(() => _selectedIndex = idx);

    // 결 탭으로 전환 시 닉네임 등 최신 데이터 갱신
    if (idx == _bondTabIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _bondKey.currentState?.refreshData();
      });
    }

    // 탭 진입 이벤트 기록
    const tabEvents = [
      ActivityEventType.viewHome,
      ActivityEventType.viewBond,
      ActivityEventType.viewGrowth,
      ActivityEventType.viewJob,
    ];
    if (idx < tabEvents.length) {
      const tabPages = ['home', 'bond', 'growth', 'job'];
      AdminActivityService.log(tabEvents[idx], page: tabPages[idx]);
    }
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
    // ── 온보딩 체크 완료 전: 빈 화면 표시 (일반 화면이 잠깐 노출되는 현상 방지) ──
    if (!_onboardingChecked) {
      return Scaffold(backgroundColor: AppColors.appBg);
    }

    final pages = <Widget>[
      CaringPage(
        key: const ValueKey('caring'),
        onTabRequested: _onTabRequested,
        onGrowthSubTabRequested: _onGrowthSubTabRequested,
        isOnboardingActive: _onboardingActive,
        onboardingDialogue:
            (_onboardingActive && _onboardingCtrl.isTab0Step)
                ? kStepDialogue[_onboardingCtrl.current]
                : null,
        currentTabIndex: _selectedIndex,
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
              builder:
                  (_, __) => AppOnboardingOverlay(
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
