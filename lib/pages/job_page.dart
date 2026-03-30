import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../notifiers/job_filter_notifier.dart';
import '../services/job_service.dart';
import '../screen/jobs/job_listings_screen.dart';
import '../screen/jobs/job_map_screen.dart';
import 'career/career_tab.dart';
import 'career/career_skill_section.dart';
import 'settings/settings_page.dart';

/// [careerSkillAutoHintToken]이 증가할 때마다(동일 세션 1회 등) 커리어 카드 탭으로 전환 후 스킬 편집 시트를 연다.
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

/// 커리어(도전하기) 탭 - 탭4
///
/// - 소탭 0: 채용 (JobListingsScreen ↔ JobMapScreen)
/// - 소탭 1: 커리어 카드 (CareerTab)
///
/// [isOnboardingActive] 온보딩 진행 중이면 커리어 카드(소탭1)로 바로 열림
///
/// [careerSkillAutoHintToken]은 홈에서 커리어 탭 3회 진입 시 1회 증가 → 스킬 시트 자동 오픈
class JobPage extends StatefulWidget {
  final bool isOnboardingActive;
  final int careerSkillAutoHintToken;

  const JobPage({
    super.key,
    this.isOnboardingActive = false,
    this.careerSkillAutoHintToken = 0,
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
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) return;

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
          // 탭4(커리어) 진입 시: 온보딩 중이면 소탭1(커리어카드)로 바로 시작
          initialIndex: widget.isOnboardingActive ? 1 : 0,
          child: _CareerSkillAutoHintScope(
            token: widget.careerSkillAutoHintToken,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 공통 타이틀 + 인포/설정 (두 소탭 모두 항상 표시) ──
                const _JobPageTitleBar(),
                // ── 공통 소탭바 (채용 / 커리어 카드) ──
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

// ── 커리어 탭 공통 타이틀 바 (두 소탭 모두 상단에 항상 표시) ──────────
class _JobPageTitleBar extends StatelessWidget {
  const _JobPageTitleBar();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 타이틀 + 아이콘 행 ──
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                '커리어',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
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
        ),
        // ── 서브타이틀 ──
        const Padding(
          padding: EdgeInsets.only(left: 20),
          child: Text(
            '내 커리어를 관리하고 맞춤 공고를 받아보세요.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '커리어',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('이력서와 구인 공고를 관리하는 공간이에요.', style: TextStyle(fontSize: 13, height: 1.5)),
              SizedBox(height: 16),
              Text('📍 채용', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('근처 치과 구인 공고를 목록·지도로 확인해요.', style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
              SizedBox(height: 16),
              Text('📄 커리어 카드', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('이력서를 작성하고 관리해요. 완성된 이력서로 바로 지원할 수 있어요.', style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
              SizedBox(height: 16),
              Text('🌐 웹에서도 이용 가능', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('PC에서 같은 계정으로 접속해 작업할 수 있어요.\nhttps://chikabooks3rd.web.app', style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
              SizedBox(height: 16),
              Text('📎 웹 전용 기능', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('이력서에 자격증·수료증·경력증명서 등 첨부 파일을 추가할 수 있어요.', style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }
}

