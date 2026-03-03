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
const _kBg = kCBg;

/// 커리어(도전하기) 탭 - 4번째 탭
///
/// - 소탭 0: 공고보기 (JobListingsScreen ↔ JobMapScreen)
/// - 소탭 1: 커리어 카드 (CareerTab)
class JobPage extends StatefulWidget {
  const JobPage({super.key});

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
    await _requestLocationPermission();
    if (mounted) {
      setState(() => _loadingLocation = false);
    }
  }

  Future<void> _requestLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _useSavedLocationFallback();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        await _useSavedLocationFallback();
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
      debugPrint('⚠️ 위치 로드 실패: $e');
      await _useSavedLocationFallback();
    }
  }

  Future<void> _useSavedLocationFallback() async {
    final saved = await _jobService.getUserLocation();
    if (saved != null && mounted) {
      setState(() => _userLocation = saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: DefaultTabController(
          length: 2,
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

    if (_isMapView) {
      return Stack(
        children: [
          JobMapScreen(userLocation: _userLocation),
          // 목록으로 돌아가는 버튼
          Positioned(
            top: 12,
            left: 16,
            child: _ListToggleButton(
              onTap: () => setState(() => _isMapView = false),
            ),
          ),
        ],
      );
    }

    return JobListingsScreen(
      userLocation: _userLocation,
      onMapToggle: () => setState(() => _isMapView = true),
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
              color: const Color(0xFF5D6B6B).withOpacity(0.8),
            ),
            const SizedBox(width: 5),
            Text(
              '목록',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF5D6B6B).withOpacity(0.85),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
