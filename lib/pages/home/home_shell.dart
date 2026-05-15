import 'dart:async' show Timer, unawaited;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../bond_page.dart';
import '../caring_page.dart';
import '../growth_page.dart';
import '../job_page.dart';
import '../onboarding/onboarding_profile_screen.dart';
import '../../services/user_profile_service.dart';
import '../../services/admin_activity_service.dart';
import '../../services/ebook_service.dart';
import '../../services/content_read_state_service.dart';
import '../../features/onboarding/app_onboarding_controller.dart';
import '../../features/onboarding/app_onboarding_overlay.dart';
import '../../core/theme/app_colors.dart';
import 'bottom_tab_sub_menu_overlay.dart';
import 'sub_tabs_catalog.dart';

/// 메인 홈 (탭 네비게이션)
class HomeShell extends StatefulWidget {
  /// OnboardingGate에서 온보딩 여부를 미리 판단해 전달
  /// true = 온보딩 실행, false = 일반 홈 화면
  final bool startWithOnboarding;
  final int initialTabIndex;
  final int initialGrowthSubTabIndex;

  const HomeShell({
    super.key,
    this.startWithOnboarding = false,
    this.initialTabIndex = 0,
    this.initialGrowthSubTabIndex = -1,
  });
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  /// Bond 탭 인덱스
  static const int _bondTabIndex = 1;
  static const Map<int, List<String>> _mainNavContentKeys = {
    1: [ContentReadKeys.bondPolls, ContentReadKeys.seniorQuestions],
    2: [
      ContentReadKeys.todayQuiz,
      ContentReadKeys.todayWords,
      ContentReadKeys.hiraPolicyUpdates,
      ContentReadKeys.ebooks,
      ContentReadKeys.savedHiraUpdates,
      ContentReadKeys.savedWords,
    ],
    3: [ContentReadKeys.jobs],
  };

  // ── 탭 위젯 캐시 (JobPage는 온보딩 상태에 따라 build에서 생성) ──
  final _bondKey = GlobalKey<BondPageState>();
  late final BondPage _bondPage;
  late final GrowthPage _growthPage;

  final ValueNotifier<int> _growthSubTabNotifier = ValueNotifier<int>(-1);
  final ValueNotifier<int> _hiraTabRequest = ValueNotifier<int>(-1);
  final ValueNotifier<int> _jobSubTabNotifier = ValueNotifier<int>(-1);

  /// 하단 메인 메뉴 NEW 뱃지용 스트림.
  ///
  /// build() 안에서 매번 새로 만들면 StreamBuilder 가 매 setState 마다 재구독하면서
  /// initialData(빈 집합) 를 잠깐씩 표시 → NEW 뱃지가 깜빡이는 문제 발생.
  /// initState 에서 단 한 번 만들어 보관하면 setState 반복에도 동일 인스턴스 유지.
  late final Stream<Set<int>> _mainNavNewStream;

  // ── 앱 온보딩 ──
  // OnboardingGate에서 이미 판단 완료 → 즉시 true로 설정
  final bool _onboardingChecked = true;
  bool _onboardingActive = false;
  late final AppOnboardingController _onboardingCtrl;

  /// 커리어 탭 3회 진입 시 1회 스킬 시트 자동 오픈용 (JobPage에 전달)
  int _careerSkillAutoHintToken = 0;

  // ─────────────────────────────────────────────────────────
  // 떠오르는 소탭 메뉴 제스처 상태
  // ─────────────────────────────────────────────────────────
  /// 현재 떠오르는 메뉴의 표시 모드 (hidden / hint / interactive)
  SubMenuMode _subMenuMode = SubMenuMode.hidden;

  /// 현재 메뉴가 보여주고 있는 메인 탭 (1=같이, 2=성장, 3=커리어).
  /// hidden 모드여도 페이드 아웃 중일 수 있으므로 유지.
  int _subMenuForTab = -1;

  /// 사용자가 누르고 있는 메인 탭 인덱스 (-1 = 누름 없음)
  int _pressingTab = -1;

  /// 누르고 있는 손가락의 전역 좌표 (interactive 모드일 때 overlay 에 전달)
  Offset? _pointerGlobal;

  /// hint → interactive 전환을 트리거하는 타이머 (200ms)
  Timer? _holdToInteractiveTimer;

  /// hint 모드 자동 페이드 아웃 타이머
  Timer? _hintFadeOutTimer;

  /// 현재 손가락이 호버 중인 소탭 인덱스 (interactive 모드, -1 = 없음)
  int _hoveredSubIndex = -1;

  /// 떠오르는 메뉴 학습 카운트 (SharedPreferences) — 일정 횟수 후 페이드 힌트 축소
  int _subMenuHintShownCount = 0;

  /// 사용자가 한 번이라도 슬라이드로 소탭에 진입한 적이 있는지 (학습 완료 플래그)
  bool _subMenuGestureLearned = false;

  /// SharedPreferences 키
  static const _kHintShownCount = 'home_sub_menu_hint_shown_count';
  static const _kGestureLearned = 'home_sub_menu_gesture_learned';

  /// 페이드 힌트 자동 노출 한도. 이 횟수가 넘어가거나 사용자가 한 번이라도
  /// 슬라이드로 소탭을 골랐으면 짧은 탭에 대한 힌트는 더 이상 띄우지 않는다.
  static const int _kHintAutoShowMax = 30;

  /// 누름 시작 후 이 시간이 지나면 [SubMenuMode.interactive] 로 전환
  static const _kHoldThreshold = Duration(milliseconds: 200);

  /// hint 모드가 화면에 머무는 시간
  static const _kHintLinger = Duration(milliseconds: 800);

  @override
  void initState() {
    super.initState();
    _bondPage = BondPage(key: _bondKey);
    _growthPage = GrowthPage(
      subTabNotifier: _growthSubTabNotifier,
      hiraTabRequestNotifier: _hiraTabRequest,
    );

    _mainNavNewStream = ContentReadStateService.watchNewIndices(
      _mainNavContentKeys,
    );

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
    } else {
      _selectedIndex = widget.initialTabIndex.clamp(0, 3).toInt();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // _checkOnboarding() 제거 — OnboardingGate에서 이미 처리됨
      _recordAppOpen();
      AdminActivityService.warmupCache();
      if (!_onboardingActive &&
          widget.initialTabIndex == 2 &&
          widget.initialGrowthSubTabIndex >= 0) {
        _onGrowthSubTabRequested(widget.initialGrowthSubTabIndex);
      }
      // 로그인 후 아임웹 구매내역 자동 동기화 (fire-and-forget)
      _trySyncImwebPurchases();
      _loadSubMenuLearningState();
    });

    // authStateChanges 리스너: 로그아웃→재로그인 시 OnboardingGate가
    // 새로 생성되어 자동 처리되므로 여기서 온보딩 재체크 불필요
  }

  @override
  void dispose() {
    _holdToInteractiveTimer?.cancel();
    _hintFadeOutTimer?.cancel();
    _growthSubTabNotifier.dispose();
    _hiraTabRequest.dispose();
    _jobSubTabNotifier.dispose();
    _onboardingCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  // 떠오르는 소탭 메뉴 — 학습 상태 로딩/저장
  // ─────────────────────────────────────────────────────────
  Future<void> _loadSubMenuLearningState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _subMenuHintShownCount = prefs.getInt(_kHintShownCount) ?? 0;
        _subMenuGestureLearned = prefs.getBool(_kGestureLearned) ?? false;
      });
    } catch (_) {
      // 학습 상태 로딩 실패 시 기본값(0/false)으로 동작 — 사용성에 영향 없음
    }
  }

  Future<void> _incrementHintShownCount() async {
    _subMenuHintShownCount += 1;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kHintShownCount, _subMenuHintShownCount);
    } catch (_) {
      // 카운트 저장 실패는 무시 (다음 진입에서 다시 세면 됨)
    }
  }

  Future<void> _markGestureLearned() async {
    if (_subMenuGestureLearned) return;
    _subMenuGestureLearned = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kGestureLearned, true);
    } catch (_) {
      // 학습 플래그 저장 실패는 무시
    }
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
    final ebookService = context.read<EbookService>();

    unawaited(
      Future.delayed(Duration.zero, () async {
        try {
          final result = await ebookService.syncImwebPurchases();
          final synced = result['synced'] as int? ?? 0;
          if (synced > 0 && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('📚 하이진랩 구매내역 $synced권을 불러왔습니다.'),
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

  /// 커리어 메인 탭(인덱스 3)에 온보딩이 아닐 때만 방문 카운트. 3번째 방문에서 1회 스킬 시트 오픈 신호.
  Future<void> _maybeTriggerCareerThirdVisitSkillHint() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const kDone = 'career_skill_third_visit_hint_done';
      if (prefs.getBool(kDone) == true) return;

      final n = (prefs.getInt('career_tab_visit_count') ?? 0) + 1;
      await prefs.setInt('career_tab_visit_count', n);

      if (n == 3) {
        await prefs.setBool(kDone, true);
        if (mounted) {
          setState(() => _careerSkillAutoHintToken++);
        }
      }
    } catch (_) {
      // 프리퍼런스 실패 시 온보딩/탭 동작에는 영향 없음
    }
  }

  // ─────────────────────────────────────────────────────────
  // 탭 이동 (TabThemeNotifier 제거 → setState만으로 단순화)
  // ─────────────────────────────────────────────────────────
  void _setTab(int idx) {
    final prev = _selectedIndex;
    setState(() => _selectedIndex = idx);

    if (idx == 3 && prev != 3 && !_onboardingActive) {
      unawaited(_maybeTriggerCareerThirdVisitSkillHint());
    }

    if (idx == _bondTabIndex) {
      _bondKey.currentState?.refreshData();
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
      // 스포트라이트가 아닐 때: 현재 step이 속한 탭만 허용 (캐릭터/타탭 대사 구간에서 임의 이동 방지)
      if (idx != _onboardingCtrl.currentTabIndex) return;
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

  void _onGrowthSubTabRequested(int subTab, {int? hiraInnerTab}) {
    if (_onboardingActive) return;
    _setTab(2);
    _growthSubTabNotifier.value = -1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _growthSubTabNotifier.value = subTab;
      if (hiraInnerTab != null && (hiraInnerTab == 0 || hiraInnerTab == 1)) {
        _hiraTabRequest.value = -1;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _hiraTabRequest.value = hiraInnerTab;
          });
        });
      }
    });
  }

  // ─────────────────────────────────────────────────────────
  // 떠오르는 소탭 메뉴 — 메인 탭별 소탭 점프 통합
  // ─────────────────────────────────────────────────────────
  /// 같이/성장/커리어 어느 메인탭이든 [subIdx] 소탭으로 이동.
  /// 각 페이지가 외부에서 받는 시그널 패턴이 달라 메인탭별 분기.
  ///
  /// "같이" 탭(1)은 첫 진입 시 [OnboardingProfileScreen] 진입 가드가 있으므로
  /// [_onTap] 과 동일한 검사를 거친 뒤에야 소탭 신호를 보낸다.
  Future<void> _jumpToSubTab(int mainTab, int subIdx) async {
    if (_onboardingActive) return;
    if (mainTab < 0 || mainTab > 3) return;
    if (subIdx < 0) return;

    if (mainTab == _bondTabIndex) {
      final isCompleted = await UserProfileService.isOnboardingCompleted();
      if (!mounted) return;
      if (!isCompleted) {
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => const OnboardingProfileScreen(),
          ),
        );
        if (!mounted) return;
        if (result != true) return;
      }
    }

    _setTab(mainTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (mainTab) {
        case 1:
          // 같이 — BondPageState 가 GlobalKey 로 노출됨
          _bondKey.currentState?.selectSubTab(subIdx);
          break;
        case 2:
          // 성장 — 기존 _onGrowthSubTabRequested 가 노티파이어를 -1 → subTab 로 토글
          _growthSubTabNotifier.value = -1;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _growthSubTabNotifier.value = subIdx;
          });
          break;
        case 3:
          // 커리어 — JobPage 의 _ExternalSubTabRequestScope 가 받음
          _jobSubTabNotifier.value = -1;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _jobSubTabNotifier.value = subIdx;
          });
          break;
      }
    });
  }

  // ─────────────────────────────────────────────────────────
  // 떠오르는 소탭 메뉴 — 제스처 진입 (Listener / raw pointer)
  // ─────────────────────────────────────────────────────────
  /// 손가락이 하단 메뉴 영역에 닿았을 때.
  /// [tabIndex] 가 소탭이 있는 탭이면 메뉴 등장 준비, 누름 유지 시 interactive 전환 예약.
  void _onTabPointerDown(int tabIndex, Offset globalPosition) {
    if (_onboardingActive) return;
    if (!SubTabsCatalog.hasSubTabs(tabIndex)) {
      // 소탭이 없는 탭(나)은 평소 동작만, 메뉴는 띄우지 않음
      _pressingTab = tabIndex;
      return;
    }

    _hintFadeOutTimer?.cancel();
    _holdToInteractiveTimer?.cancel();

    _pressingTab = tabIndex;
    _pointerGlobal = globalPosition;
    _hoveredSubIndex = -1;

    // 학습 끝난 사용자는 누르자마자 interactive 로 전환하는 게 자연스럽지만,
    // 그래도 짧은 탭(단순 메인탭 전환) 의도와 구분이 필요하므로 동일한 threshold 사용.
    setState(() {
      _subMenuForTab = tabIndex;
      _subMenuMode = SubMenuMode.hint;
    });

    _holdToInteractiveTimer = Timer(_kHoldThreshold, () {
      if (!mounted) return;
      if (_pressingTab != tabIndex) return;
      HapticFeedback.selectionClick();
      setState(() => _subMenuMode = SubMenuMode.interactive);
    });
  }

  /// 손가락이 움직이는 동안 호출. interactive 모드일 때만 좌표 갱신.
  void _onTabPointerMove(Offset globalPosition) {
    if (_pressingTab < 0) return;
    if (_subMenuMode != SubMenuMode.interactive) {
      // 아직 hint 단계 — 좌표만 저장, UI 갱신은 interactive 전환 시.
      _pointerGlobal = globalPosition;
      return;
    }
    setState(() => _pointerGlobal = globalPosition);
  }

  /// 사용자가 손을 뗐을 때.
  void _onTabPointerUp() {
    final pressed = _pressingTab;
    final wasInteractive = _subMenuMode == SubMenuMode.interactive;
    final hovered = _hoveredSubIndex;

    _holdToInteractiveTimer?.cancel();
    _holdToInteractiveTimer = null;
    _pressingTab = -1;
    _pointerGlobal = null;

    if (pressed < 0) return;

    // interactive 모드에서 소탭 위에서 뗀 경우 → 해당 소탭으로 점프
    if (wasInteractive && hovered >= 0) {
      HapticFeedback.lightImpact();
      _hoveredSubIndex = -1;
      // _subMenuForTab 은 그대로 두고 mode 만 hidden 으로.
      // 위젯이 페이드아웃을 마치면 onDismissed 콜백에서 -1로 정리한다.
      setState(() {
        _subMenuMode = SubMenuMode.hidden;
      });
      unawaited(_markGestureLearned());
      unawaited(_jumpToSubTab(pressed, hovered));
      return;
    }

    // 그 외 → 짧은 탭으로 간주, 평소 _onTap 흐름 진행
    _hoveredSubIndex = -1;
    _handleShortTap(pressed);
  }

  /// 제스처가 시스템에 의해 취소되었을 때 (드래그가 너무 길어 OS 가 끼어듦 등)
  void _onTabPointerCancel() {
    _holdToInteractiveTimer?.cancel();
    _holdToInteractiveTimer = null;
    _pressingTab = -1;
    _pointerGlobal = null;
    _hoveredSubIndex = -1;
    if (_subMenuMode != SubMenuMode.hidden) {
      // _subMenuForTab 은 그대로 두어 페이드아웃이 보이게 한다.
      // onDismissed 콜백에서 트리 정리.
      setState(() {
        _subMenuMode = SubMenuMode.hidden;
      });
    }
  }

  /// 짧은 탭 시 페이드 힌트 + 평소 탭 전환.
  void _handleShortTap(int tabIndex) {
    // 평소 _onTap 흐름 (온보딩/Bond 진입 가드 등 포함)
    _onTap(tabIndex);

    // 학습 완료 사용자에겐 힌트 생략, 학습 중인 사용자에게만 페이드 힌트
    final canShowHint =
        SubTabsCatalog.hasSubTabs(tabIndex) &&
        !_subMenuGestureLearned &&
        _subMenuHintShownCount < _kHintAutoShowMax;

    if (!canShowHint) {
      // 학습 끝 — 메뉴는 페이드아웃으로 부드럽게 사라지게.
      // (이전엔 _subMenuForTab 을 즉시 -1로 비워 위젯을 unmount → 페이드아웃이 안 보였음)
      if (_subMenuMode != SubMenuMode.hidden) {
        setState(() {
          _subMenuMode = SubMenuMode.hidden;
        });
      }
      return;
    }

    setState(() {
      _subMenuForTab = tabIndex;
      _subMenuMode = SubMenuMode.hint;
    });
    unawaited(_incrementHintShownCount());

    _hintFadeOutTimer?.cancel();
    _hintFadeOutTimer = Timer(_kHintLinger, () {
      if (!mounted) return;
      if (_subMenuMode != SubMenuMode.hint) return;
      setState(() {
        _subMenuMode = SubMenuMode.hidden;
      });
    });
  }

  void _onOverlayHoveredSubChanged(int idx) {
    if (idx == _hoveredSubIndex) return;
    if (idx != -1) HapticFeedback.selectionClick();
    setState(() => _hoveredSubIndex = idx);
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
        onboardingTab0LayoutBoost:
            _onboardingActive && _onboardingCtrl.isTab0Step,
        onboardingBoldWord:
            (_onboardingActive &&
                    _onboardingCtrl.current == AppOnboardingStepId.step1a)
                ? '저니'
                : null,
        currentTabIndex: _selectedIndex,
      ),
      _bondPage,
      _growthPage,
      JobPage(
        key: ValueKey('job_$_onboardingActive'),
        isOnboardingActive: _onboardingActive,
        careerSkillAutoHintToken: _careerSkillAutoHintToken,
        subTabRequestNotifier: _jobSubTabNotifier,
      ),
    ];
    final bottomNavHeight = 72.0 + MediaQuery.of(context).viewPadding.bottom;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _selectedIndex, children: pages),
          // 떠오르는 소탭 메뉴 (온보딩 중에는 hidden 으로만 유지되어 그려지지 않음).
          // mode 가 hidden 이어도 _subMenuForTab 이 유지되는 동안에는 위젯이
          // 트리에 살아 있어 페이드아웃 애니메이션이 정상적으로 보인다.
          if (!_onboardingActive && _subMenuForTab > 0)
            BottomTabSubMenuOverlay(
              mainTabIndex: _subMenuForTab,
              mode: _subMenuMode,
              bottomNavHeight: bottomNavHeight,
              pointerGlobalPosition: _pointerGlobal,
              onHoveredSubIndexChanged: _onOverlayHoveredSubChanged,
              onDismissed: () {
                if (!mounted) return;
                // 사용자가 다른 탭을 다시 누르는 등으로 메뉴가 살아난 경우엔 정리하지 않음.
                if (_subMenuMode != SubMenuMode.hidden) return;
                setState(() => _subMenuForTab = -1);
              },
            ),
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
      // BottomNavigationBar: 색상은 AppTheme.light (bottomNavigationBarTheme)에서 고정 관리.
      // 탭 처리는 Listener 가 raw pointer 이벤트로 가로채 짧은 탭/길게 누름 + 슬라이드를 분기한다.
      bottomNavigationBar: StreamBuilder<Set<int>>(
        stream: _mainNavNewStream,
        initialData: const {},
        builder: (context, snapshot) {
          final newMainTabs = snapshot.data ?? const <int>{};
          final tabWidth = screenWidth / 4;

          return SizedBox(
            height: bottomNavHeight,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                if (_onboardingActive) {
                  // 온보딩 중에는 기존 _onTap 로직만 통과시키고 떠오르는 메뉴는 차단.
                  final idx = (event.position.dx / tabWidth)
                      .floor()
                      .clamp(0, 3);
                  _onTap(idx);
                  return;
                }
                final idx = (event.position.dx / tabWidth).floor().clamp(0, 3);
                _onTabPointerDown(idx, event.position);
              },
              onPointerMove:
                  _onboardingActive
                      ? null
                      : (event) => _onTabPointerMove(event.position),
              onPointerUp:
                  _onboardingActive ? null : (_) => _onTabPointerUp(),
              onPointerCancel:
                  _onboardingActive ? null : (_) => _onTabPointerCancel(),
              child: IgnorePointer(
                // BottomNavigationBar 의 자체 탭 처리는 비활성 (위의 Listener 가 담당).
                child: BottomNavigationBar(
                  currentIndex: _selectedIndex,
                  onTap: (_) {},
                  items: [
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.person_outline),
                      activeIcon: Icon(Icons.person),
                      label: '나',
                    ),
                    BottomNavigationBarItem(
                      icon: _NavIconWithNewBadge(
                        icon: Icons.people_outline,
                        showNew: newMainTabs.contains(1),
                      ),
                      activeIcon: _NavIconWithNewBadge(
                        icon: Icons.people,
                        showNew: newMainTabs.contains(1),
                      ),
                      label: '같이',
                    ),
                    BottomNavigationBarItem(
                      icon: _NavIconWithNewBadge(
                        icon: Icons.menu_book_outlined,
                        showNew: newMainTabs.contains(2),
                      ),
                      activeIcon: _NavIconWithNewBadge(
                        icon: Icons.menu_book,
                        showNew: newMainTabs.contains(2),
                      ),
                      label: '성장',
                    ),
                    BottomNavigationBarItem(
                      icon: _NavIconWithNewBadge(
                        icon: Icons.work_outline,
                        showNew: newMainTabs.contains(3),
                      ),
                      activeIcon: _NavIconWithNewBadge(
                        icon: Icons.work,
                        showNew: newMainTabs.contains(3),
                      ),
                      label: '커리어',
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NavIconWithNewBadge extends StatelessWidget {
  const _NavIconWithNewBadge({required this.icon, required this.showNew});

  final IconData icon;
  final bool showNew;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(icon),
          if (showNew)
            const Positioned(top: -7, right: -13, child: _NavNewBadge()),
        ],
      ),
    );
  }
}

class _NavNewBadge extends StatefulWidget {
  const _NavNewBadge();

  @override
  State<_NavNewBadge> createState() => _NavNewBadgeState();
}

class _NavNewBadgeState extends State<_NavNewBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.45,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD84D),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          'NEW',
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: AppColors.blue,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
