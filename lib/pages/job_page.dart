import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../notifiers/job_filter_notifier.dart';
import '../services/job_service.dart';
import '../screen/jobs/job_listings_screen.dart';
import '../screen/jobs/job_map_screen.dart';
import 'career/career_tab.dart';
import 'career/career_shared.dart';

// ── 디자인 팔레트 ──
final _kBg = kCBg;

/// 커리어(도전하기) 탭 - 탭4
///
/// - 소탭 0: 공고보기 (JobListingsScreen ↔ JobMapScreen)
/// - 소탭 1: 커리어 카드 (CareerTab)
///
/// [isOnboardingActive] 온보딩 진행 중이면 커리어 카드(소탭1)로 바로 열림
class JobPage extends StatefulWidget {
  final bool isOnboardingActive;
  const JobPage({super.key, this.isOnboardingActive = false});

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
      backgroundColor: _kBg,
      body: SafeArea(
        child: DefaultTabController(
          length: 2,
          // 탭4(커리어) 진입 시: 온보딩 중이면 소탭1(커리어카드)로 바로 시작
          initialIndex: widget.isOnboardingActive ? 1 : 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CareerTabHeader(),
              const SizedBox(height: 6),
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
    );
  }

  Widget _buildJobsTab() {
    if (_loadingLocation) {
      return const Center(child: CircularProgressIndicator());
    }

    // IndexedStack으로 목록/지도를 동시에 유지 → 전환 시 Maps 재초기화 없음
    return IndexedStack(
      index: _isMapView ? 1 : 0,
      children: [
        // 인덱스 0: 공고 목록
        JobListingsScreen(
          userLocation: _userLocation,
          onMapToggle: () => setState(() => _isMapView = true),
        ),
        // 인덱스 1: 지도 (미리 빌드되어 전환 즉시 표시)
        Stack(
          children: [
            JobMapScreen(userLocation: _userLocation),
            Positioned(
              top: 12,
              left: 16,
              child: _ListToggleButton(
                onTap: () => setState(() => _isMapView = false),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 지도 모드에서 목록으로 돌아가는 플로팅 버튼
class _ListToggleButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ListToggleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.list_alt_rounded,
              size: 16,
              color: kCText.withOpacity(0.8),
            ),
            const SizedBox(width: 5),
            Text(
              '목록',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kCText.withOpacity(0.85),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
