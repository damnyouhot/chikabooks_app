import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/app_modal_scaffold.dart';
import '../notifiers/job_filter_notifier.dart';
import '../services/job_service.dart';
import '../screen/jobs/job_listings_screen.dart';
import '../screen/jobs/job_map_screen.dart';
import 'career/career_tab.dart';
import 'career/career_skill_section.dart';
import 'settings/settings_page.dart';

/// [careerSkillAutoHintToken]이 증가할 때마다(동일 세션 1회 등) 커리어 관리 소탭으로 전환 후 스킬 편집 시트를 연다.
class _CareerSkillAutoHintScope extends StatefulWidget {
  final int token;
  final Widget child;

  const _CareerSkillAutoHintScope({
    required this.token,
    required this.child,
  });

  @override
  State<_CareerSkillAutoHintScope> createState() =>
      _CareerSkillAutoHintScopeState();
}

class _CareerSkillAutoHintScopeState extends State<_CareerSkillAutoHintScope> {
  int _lastHandledToken = 0;

  @override
  void initState() {
    super.initState();
    _lastHandledToken = widget.token;
  }

  void _scheduleOpenIfNeeded(int newToken) {
    if (newToken <= _lastHandledToken) return;
    _lastHandledToken = newToken;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final tc = DefaultTabController.maybeOf(context);
      if (tc != null) {
        tc.animateTo(1);
      }
      CareerSkillEditSheet.show(context);
    });
  }

  @override
  void didUpdateWidget(_CareerSkillAutoHintScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.token != oldWidget.token) {
      _scheduleOpenIfNeeded(widget.token);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 외부([HomeShell] 의 떠오르는 소탭 메뉴 등)에서 보내오는 소탭 요청을 받아
/// [DefaultTabController] 에 반영한다. [_CareerSkillAutoHintScope] 와 동일한
/// 패턴으로 [DefaultTabController] 자식 트리 안에 두어야 한다.
///
/// 추가로 [onCurrentChanged] 가 주어지면, 외부 요청 / 사용자 스와이프 / 탭바
/// 어디서 일어났든 **소탭 인덱스가 실제로 바뀌어 정착했을 때** 한 번씩 보고한다.
class _ExternalSubTabRequestScope extends StatefulWidget {
  final ValueNotifier<int>? notifier;
  final ValueChanged<int>? onCurrentChanged;
  final Widget child;

  const _ExternalSubTabRequestScope({
    required this.notifier,
    required this.child,
    this.onCurrentChanged,
  });

  @override
  State<_ExternalSubTabRequestScope> createState() =>
      _ExternalSubTabRequestScopeState();
}

class _ExternalSubTabRequestScopeState
    extends State<_ExternalSubTabRequestScope> {
  ValueNotifier<int>? _bound;
  TabController? _attachedController;
  int _lastReportedIndex = -1;

  @override
  void initState() {
    super.initState();
    _bind(widget.notifier);
  }

  @override
  void didUpdateWidget(covariant _ExternalSubTabRequestScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.notifier != oldWidget.notifier) {
      _unbind();
      _bind(widget.notifier);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // DefaultTabController 가 트리 위쪽에 생긴 직후 한 번, 그리고 컨트롤러가
    // 교체되는 (사실상 거의 없는) 케이스를 대비해 의존성 변경 시점에 재바인딩.
    _attachTabController(DefaultTabController.maybeOf(context));
  }

  @override
  void dispose() {
    _unbind();
    _detachTabController();
    super.dispose();
  }

  void _bind(ValueNotifier<int>? n) {
    if (n == null) return;
    _bound = n;
    n.addListener(_onRequest);
  }

  void _unbind() {
    _bound?.removeListener(_onRequest);
    _bound = null;
  }

  void _attachTabController(TabController? tc) {
    if (identical(tc, _attachedController)) return;
    _detachTabController();
    _attachedController = tc;
    if (tc == null) return;
    tc.addListener(_onTabChanged);
    // 진입 직후 현재 인덱스(초기값) 도 한 번 보고 — 음영 표시 기본값 제공.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _attachedController != tc) return;
      _reportIndex(tc.index);
    });
  }

  void _detachTabController() {
    _attachedController?.removeListener(_onTabChanged);
    _attachedController = null;
  }

  void _onTabChanged() {
    final tc = _attachedController;
    if (tc == null) return;
    // 애니메이션 중간 프레임은 무시하고 정착한 인덱스만 보고.
    if (tc.indexIsChanging) return;
    _reportIndex(tc.index);
  }

  void _reportIndex(int idx) {
    if (idx == _lastReportedIndex) return;
    _lastReportedIndex = idx;
    widget.onCurrentChanged?.call(idx);
  }

  void _onRequest() {
    final idx = _bound?.value ?? -1;
    if (idx < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final tc = DefaultTabController.maybeOf(context);
      if (tc == null) return;
      if (idx < 0 || idx >= tc.length) return;
      if (tc.index != idx) tc.animateTo(idx);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 커리어(도전하기) 탭 - 탭4
///
/// - 소탭 0: 채용 · 지원 (JobListingsScreen ↔ JobMapScreen)
/// - 소탭 1: 커리어 관리 (CareerTab)
///
/// [isOnboardingActive] 온보딩 진행 중이면 커리어 관리(소탭1)로 바로 열림
///
/// [careerSkillAutoHintToken]은 홈에서 커리어 탭 3회 진입 시 1회 증가 → 스킬 시트 자동 오픈
class JobPage extends StatefulWidget {
  final bool isOnboardingActive;
  final int careerSkillAutoHintToken;

  /// 외부([HomeShell] 의 떠오르는 소탭 메뉴 등)에서 소탭 전환을 요청할 때 사용.
  /// 값을 0(공고 보기) 또는 1(커리어 관리) 로 설정하면 해당 소탭으로 이동.
  /// -1 은 무시. 같은 값을 다시 보내면 [ValueNotifier] 가 알림을 보내지 않으므로,
  /// HomeShell 측에서는 보낼 때마다 -1 → 목표값 순으로 리셋 후 갱신한다.
  final ValueNotifier<int>? subTabRequestNotifier;

  /// 현재 소탭 인덱스가 바뀔 때마다 호출. (외부 요청·내부 스와이프 모두 포함)
  /// [HomeShell] 이 소탭 메뉴에서 "지금 떼면 갈 곳" 음영 표시용으로 사용한다.
  final ValueChanged<int>? onSubTabChanged;

  const JobPage({
    super.key,
    this.isOnboardingActive = false,
    this.careerSkillAutoHintToken = 0,
    this.subTabRequestNotifier,
    this.onSubTabChanged,
  });

  @override
  State<JobPage> createState() => _JobPageState();
}

class _JobPageState extends State<JobPage> {
  bool _isMapView = false;
  bool _loadingLocation = true;
  LatLng? _userLocation;

  late final JobService _jobService;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.watch<JobFilterNotifier>();
  }

  Future<void> _initializeData() async {
    _jobService = context.read<JobService>();

    // 저장된 위치를 먼저 즉시 사용 → 로딩 완료 처리 (화면 전환 블로킹 제거)
    final saved = await _jobService.getUserLocation();
    if (mounted) {
      setState(() {
        _userLocation = saved;
        _loadingLocation = false;
      });
    }

    // GPS 실측값은 백그라운드로 갱신 (UI 블로킹 없음)
    _refreshLocationInBackground();
  }

  Future<void> _refreshLocationInBackground() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        final agreed = await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AppModalDialog(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '위치 권한 안내',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      '주변 치과 구인 정보를 거리 기준으로 보여드리기 위해 위치 권한이 필요해요.\n'
                      '앱이 화면에 보이는 동안에만 사용하며, 백그라운드에서는 위치를 수집하지 않습니다.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              backgroundColor: AppColors.surfaceMuted,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            child: const Text('나중에'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('허용하기'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
        );
        if (agreed != true) return;
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 3),
      );
      final location = LatLng(position.latitude, position.longitude);
      await _jobService.saveUserLocation(location);
      if (mounted) setState(() => _userLocation = location);
    } catch (e) {
      debugPrint('⚠️ 백그라운드 위치 갱신 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: SafeArea(
        child: DefaultTabController(
          length: 2,
          // 탭4(커리어) 진입 시: 온보딩 중이면 소탭1(커리어 관리)로 바로 시작
          initialIndex: widget.isOnboardingActive ? 1 : 0,
          child: _CareerSkillAutoHintScope(
            token: widget.careerSkillAutoHintToken,
            child: _ExternalSubTabRequestScope(
              notifier: widget.subTabRequestNotifier,
              onCurrentChanged: widget.onSubTabChanged,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 상단 인포/설정 (두 소탭 모두 항상 표시) ──
                  const _JobPageTitleBar(),
                  // ── 공통 소탭바 (채용 · 지원 / 커리어 관리) ──
                  const CareerTabHeader(),
                  // 소탭 본문
                  Expanded(
                    child: TabBarView(
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildJobsTab(),
                        const CareerTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJobsTab() {
    final Widget content;
    if (_loadingLocation) {
      content = const Center(child: CircularProgressIndicator());
    } else {
      // IndexedStack으로 목록/지도를 동시에 유지 → 전환 시 Maps 재초기화 없음
      content = IndexedStack(
        index: _isMapView ? 1 : 0,
        children: [
          JobListingsScreen(
            userLocation: _userLocation,
            onMapToggle: () => setState(() => _isMapView = true),
          ),
          JobMapScreen(
            userLocation: _userLocation,
            onListToggle: () => setState(() => _isMapView = false),
          ),
        ],
      );
    }

    return content;
  }
}

// ── 커리어 탭 상단 바: 인포/설정 (두 소탭 모두 항상 표시) ──────────
class _JobPageTitleBar extends StatelessWidget {
  const _JobPageTitleBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xl,
        right: 4,
        bottom: AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(),
          IconButton(
            icon: const Icon(
              Icons.info_outline,
              color: AppColors.textSecondary,
              size: 18,
            ),
            onPressed: () => _showInfoDialog(context),
          ),
          IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: AppColors.textDisabled,
              size: 20,
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder:
          (ctx) => AppModalDialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '커리어',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(ctx).height * 0.55,
                  ),
                  child: const SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '이력서와 구인 공고를 관리하는 공간이에요.',
                          style: TextStyle(fontSize: 13, height: 1.5),
                        ),
                        SizedBox(height: 16),
                        Text(
                          '📍 채용',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '근처 치과 구인 공고를 목록·지도로 확인해요.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          '📄 커리어 관리',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '이력서를 작성하고 관리해요. 완성된 이력서로 바로 지원할 수 있어요.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          '🌐 웹에서도 이용 가능',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'PC에서 같은 계정으로 접속해 작업할 수 있어요.\nhttps://chikabooks3rd.web.app',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          '📎 웹 전용 기능',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '이력서에 자격증·수료증·경력증명서 등 첨부 파일을 추가할 수 있어요.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      backgroundColor: AppColors.surfaceMuted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: const Text('닫기'),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

