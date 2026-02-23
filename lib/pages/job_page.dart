import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../notifiers/job_filter_notifier.dart';
import '../services/job_service.dart';
import '../services/bond_score_service.dart';
import '../widgets/job/main_title_card.dart';
import '../widgets/job/quick_action_row.dart';
import '../screen/jobs/job_list_screen.dart';
import '../screen/jobs/job_map_screen.dart';
import 'my_activity_page.dart';

// ── 디자인 팔레트 ──
const _kText = Color(0xFF5D6B6B);
const _kBg = Color(0xFFF1F7F7);

/// 도전하기 탭 (4탭)
///
/// 지도 중심 구인/구직 플랫폼
/// - 기본 뷰: 지도
/// - 주변 반경 기반 검색
/// - 알림 설정 통합
class JobPage extends StatefulWidget {
  const JobPage({super.key});

  @override
  State<JobPage> createState() => _JobPageState();
}

class _JobPageState extends State<JobPage> {
  // ── 상태 ──
  bool _isMapView = true; // ★ 기본값: 지도 (기존 false)
  bool _loadingLocation = true;
  LatLng? _userLocation; // 사용자 현재 위치

  // ── 대시보드 데이터 ──
  int _nearbyJobCount = 0; // 반경 내 공고 수
  int _newJobsCount = 0; // 24시간 신규 공고 수
  bool _notificationEnabled = false; // 알림 ON/OFF
  int _watchedClinicsCount = 0; // 관심 치과 수
  int _weeklyJobPoints = 0; // ★ 이번 주 구직 활동 포인트

  late final JobService _jobService;
  late JobFilterNotifier _jobFilter; // final 제거

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 필터 변경 감지 (반경 변경 시 대시보드 새로고침)
    _jobFilter = context.watch<JobFilterNotifier>();
  }

  Future<void> _initializeData() async {
    _jobService = context.read<JobService>();
    _jobFilter = context.read<JobFilterNotifier>();

    // 1. 위치 권한 요청 & 현재 위치 로드
    await _requestLocationPermission();

    // 2. 알림 설정 로드
    await _loadNotificationSettings();

    // 3. 관심 치과 수 로드
    await _loadWatchedClinicsCount();

    // 4. 주간 포인트 로드
    await _loadWeeklyJobPoints();

    // 5. 대시보드 데이터 로드 (반경 내 공고, 신규 공고)
    if (_userLocation != null) {
      await _loadDashboardData();
    }

    if (mounted) {
      setState(() => _loadingLocation = false);
    }
  }

  /// 위치 권한 요청 & 현재 위치 로드
  Future<void> _requestLocationPermission() async {
    try {
      // 1. 서비스 활성화 체크
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('⚠️ 위치 서비스가 비활성화됨');
        // 저장된 위치 폴백
        await _useSavedLocationFallback();
        return;
      }

      // 2. 권한 체크
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('⚠️ 위치 권한이 영구 거부됨');
        await _useSavedLocationFallback();
        return;
      }

      if (permission == LocationPermission.denied) {
        debugPrint('⚠️ 위치 권한이 거부됨');
        await _useSavedLocationFallback();
        return;
      }

      // 3. 현재 위치 가져오기
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      final location = LatLng(position.latitude, position.longitude);

      // 4. 위치 저장
      await _jobService.saveUserLocation(location);

      if (mounted) {
        setState(() => _userLocation = location);
      }

      debugPrint('✅ 위치 획득 성공: ${location.latitude}, ${location.longitude}');
    } catch (e) {
      debugPrint('⚠️ 위치 로드 실패: $e');
      await _useSavedLocationFallback();
    }
  }

  /// 저장된 위치 사용 (폴백)
  Future<void> _useSavedLocationFallback() async {
    final savedLocation = await _jobService.getUserLocation();
    if (savedLocation != null && mounted) {
      setState(() => _userLocation = savedLocation);
      debugPrint(
        '✅ 저장된 위치 사용: ${savedLocation.latitude}, ${savedLocation.longitude}',
      );
    } else {
      debugPrint('⚠️ 저장된 위치 없음 - 지도는 서울 중심으로 표시됩니다.');
    }
  }

  /// 알림 설정 로드
  Future<void> _loadNotificationSettings() async {
    final settings = await _jobService.getNotificationSettings();
    if (mounted) {
      setState(() {
        _notificationEnabled = settings['enabled'] as bool;
        // radiusKm도 필터에 반영 가능
        final radius = settings['radiusKm'] as double;
        _jobFilter.setRadiusKm(radius);
      });
    }
  }

  /// 관심 치과 수 로드
  Future<void> _loadWatchedClinicsCount() async {
    final clinics = await _jobService.getWatchedClinics();
    if (mounted) {
      setState(() => _watchedClinicsCount = clinics.length);
    }
  }

  /// 주간 구직 활동 포인트 로드
  Future<void> _loadWeeklyJobPoints() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final increase = await BondScoreService.getWeeklyScoreIncrease(uid);
      if (mounted) {
        setState(() => _weeklyJobPoints = increase);
      }
    } catch (e) {
      debugPrint('⚠️ 주간 포인트 로드 실패: $e');
    }
  }

  /// 대시보드 데이터 로드
  Future<void> _loadDashboardData() async {
    if (_userLocation == null) return;

    try {
      // 1. 반경 내 공고 수
      final jobs = await _jobService.fetchJobsNearby(
        _userLocation!,
        _jobFilter.radiusKm,
      );

      // 2. 24시간 신규 공고 수
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final newCount = await _jobService.fetchNewJobsCountSince(yesterday);

      if (mounted) {
        setState(() {
          _nearbyJobCount = jobs.length;
          _newJobsCount = newCount;
        });
      }
    } catch (e) {
      debugPrint('⚠️ 대시보드 데이터 로드 실패: $e');
    }
  }

  /// 반경 변경 다이얼로그
  void _showRadiusChangeDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('검색 반경 변경', style: TextStyle(fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  [1.0, 3.0, 5.0, 10.0].map((radius) {
                    final isSelected = _jobFilter.radiusKm == radius;
                    return RadioListTile<double>(
                      value: radius,
                      groupValue: _jobFilter.radiusKm,
                      onChanged: (value) {
                        if (value != null) {
                          _jobFilter.setRadiusKm(value);
                          _loadDashboardData(); // 데이터 새로고침
                          Navigator.pop(context);
                        }
                      },
                      title: Text('${radius.toStringAsFixed(0)}km'),
                      selected: isSelected,
                    );
                  }).toList(),
            ),
          ),
    );
  }

  /// 알림 토글
  void _onNotificationToggle(bool enabled) async {
    setState(() => _notificationEnabled = enabled);
    await _jobService.setNotificationSettings(
      enabled: enabled,
      radiusKm: _jobFilter.radiusKm,
    );
  }

  /// 관심 치과 보기 (TODO: 별도 화면 구현)
  void _onWatchedClinicsPressed() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('관심 치과 기능은 추후 업데이트됩니다.')));
  }

  /// 공고 등록 (TODO: 별도 화면 구현)
  void _onCreateJob() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('공고 등록 기능은 추후 업데이트됩니다.')));
  }

  /// 내 지원/스크랩
  void _onMyApplications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyActivityPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child:
            _loadingLocation
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    // ── MainTitleCard: 내 주변 구인 현황 ──
                    MainTitleCard(
                      nearbyJobCount: _nearbyJobCount,
                      currentRadius: _jobFilter.radiusKm,
                      newJobsCount: _newJobsCount,
                      notificationEnabled: _notificationEnabled,
                      watchedClinicsCount: _watchedClinicsCount,
                      weeklyJobPoints: _weeklyJobPoints, // ★ 주간 포인트 전달
                      onRadiusChange: _showRadiusChangeDialog,
                      onNotificationToggle: _onNotificationToggle,
                      onWatchedClinicsPressed: _onWatchedClinicsPressed,
                    ),

                    // ── 위치 권한 없을 때 안내 (선택적) ──
                    if (_userLocation == null)
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF9C4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFDD835).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_off_outlined,
                              size: 18,
                              color: _kText.withOpacity(0.7),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '위치 권한이 없어 반경 기반 검색이 제한됩니다.\n목록 보기에서는 전체 공고를 확인할 수 있습니다.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _kText.withOpacity(0.8),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── QuickActionRow: 지도/목록 전환 + 액션 버튼 ──
                    QuickActionRow(
                      isMapView: _isMapView,
                      onViewToggle:
                          () => setState(() => _isMapView = !_isMapView),
                      onCreateJob: _onCreateJob,
                      onMyApplications: _onMyApplications,
                    ),

                    // ── 메인 컨텐츠: 지도/목록 ──
                    Expanded(
                      child: IndexedStack(
                        index: _isMapView ? 1 : 0,
                        children: [
                          JobListScreen(userLocation: _userLocation),
                          JobMapScreen(userLocation: _userLocation),
                        ],
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
