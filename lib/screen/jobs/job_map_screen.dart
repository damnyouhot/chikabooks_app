import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../data/mock_jobs.dart';
import '../../models/job.dart';
import '../../notifiers/job_filter_notifier.dart';
import '../../services/job_service.dart';
import '../../widgets/job/floating_search_bar.dart';
import '../../widgets/job/map_empty_state_card.dart';
import '../../widgets/job/quick_apply_sheet.dart';
import '../../widgets/job/radius_chip_row.dart';
import 'job_detail_screen.dart';

// ── 디자인 팔레트 ──
const _kAccent = Color(0xFFF7CBCA);
const _kText = Color(0xFF5D6B6B);
const _kShadow = Color(0xFFD5E5E5);
const _kBg = Color(0xFFF5F0F2);
const _kPremium = Color(0xFFF48FB1); // Level 1 전용 핑크

// 앱 세션 내 공고 목록 캐시 (반경/필터 조합 → 결과)
final Map<String, List<Job>> _jobCache = {};

/// 지도 뷰 (4단계 개편)
///
/// ## 레이아웃
/// - 상단 1/4: 프리미엄 공고 가로 슬라이더 (Level 1 광고 카드)
/// - 하단 3/4: Google Maps + Edge Indicator + 검색/반경 오버레이
///
/// ## 마커 스타일
/// - Level 1 (프리미엄): 핑크(rose) 마커, zIndex 2 (위에 표시)
/// - Level 2/3 (일반): 청색(azure) 마커, zIndex 1
///
/// ## Edge Indicator
/// - 현재 지도 뷰포트 밖에 있는 프리미엄 클리닉을 화면 가장자리에 방향 표시
/// - 탭 시 해당 클리닉으로 카메라 이동 + 캐러셀 이동
class JobMapScreen extends StatefulWidget {
  final LatLng? userLocation;

  const JobMapScreen({super.key, this.userLocation});

  @override
  State<JobMapScreen> createState() => _JobMapScreenState();
}

class _JobMapScreenState extends State<JobMapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  bool _isLoading = true;
  List<Job> _allJobs = [];

  // 프리미엄 카드 슬라이더
  final _carouselCtrl = PageController(viewportFraction: 0.88);
  int _carouselPage = 0;

  // Level 2/3 핀 선택 시 하단 미리보기 카드
  Job? _selectedJob;

  // Edge Indicator 계산용
  LatLngBounds? _visibleBounds;
  Timer? _boundsTimer;
  final _mapKey = GlobalKey(); // 지도 영역 크기 측정

  late JobService _jobService;
  late JobFilterNotifier _jobFilter;

  // Level 1 프리미엄 공고 (광고 카드 + 핑크 마커)
  final List<Job> _premiumJobs = mockLevel1Jobs;

  CameraPosition get _initialPosition {
    if (widget.userLocation != null) {
      return CameraPosition(target: widget.userLocation!, zoom: 13);
    }
    return const CameraPosition(
      target: LatLng(37.5665, 126.9780),
      zoom: 11,
    );
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _jobService = context.read<JobService>();
    _jobFilter = context.watch<JobFilterNotifier>();
    if (_isLoading) _loadJobMarkers();
  }

  @override
  void dispose() {
    _carouselCtrl.dispose();
    _boundsTimer?.cancel();
    super.dispose();
  }

  // ── 마커 로드 ────────────────────────────────────────────────────
  Future<void> _loadJobMarkers() async {
    try {
      List<Job> jobs;

      // 캐시 키: 위치 반올림(소수점 2자리) + 반경 + 직무필터 + 조건필터
      final lat = widget.userLocation?.latitude.toStringAsFixed(2) ?? 'null';
      final lng = widget.userLocation?.longitude.toStringAsFixed(2) ?? 'null';
      final cacheKey =
          '$lat,$lng,${_jobFilter.radiusKm},${_jobFilter.positionFilter},${_jobFilter.conditions.join(",")}';

      if (_jobCache.containsKey(cacheKey)) {
        // 캐시 히트 → 즉시 표시 후 백그라운드 갱신
        jobs = _jobCache[cacheKey]!;
        _applyMarkers(jobs);
        _fetchAndRefreshCache(cacheKey);
        return;
      }

      if (widget.userLocation != null) {
        jobs = await _jobService.fetchJobsNearby(
          widget.userLocation!,
          _jobFilter.radiusKm,
          positionFilter: _jobFilter.positionFilter,
          conditions: _jobFilter.conditions,
        );
      } else {
        jobs = await _jobService.fetchJobs();
      }

      // Firestore 비어있으면 Mock 폴백
      if (jobs.isEmpty) {
        jobs = [...mockLevel2Jobs, ...generateMockLevel3Jobs(count: 10)];
      }

      _jobCache[cacheKey] = jobs;
      _applyMarkers(jobs);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 캐시된 결과로 먼저 표시 후, 백그라운드에서 Firestore 재조회해 캐시 갱신
  Future<void> _fetchAndRefreshCache(String cacheKey) async {
    try {
      List<Job> fresh;
      if (widget.userLocation != null) {
        fresh = await _jobService.fetchJobsNearby(
          widget.userLocation!,
          _jobFilter.radiusKm,
          positionFilter: _jobFilter.positionFilter,
          conditions: _jobFilter.conditions,
        );
      } else {
        fresh = await _jobService.fetchJobs();
      }
      if (fresh.isEmpty) return;
      _jobCache[cacheKey] = fresh;
      _applyMarkers(fresh);
    } catch (_) {}
  }

  void _applyMarkers(List<Job> jobs) {
    if (!mounted) return;

    _allJobs = jobs;
    final newMarkers = <Marker>{};

    // Level 1 프리미엄 마커 (핑크/rose, zIndex 높음)
    for (final job in _premiumJobs) {
      if (job.lat == 0 && job.lng == 0) continue;
      newMarkers.add(
        Marker(
          markerId: MarkerId('premium_${job.id}'),
          position: LatLng(job.lat, job.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRose,
          ),
          zIndexInt: 2,
          onTap: () => _onPremiumPinTap(job),
        ),
      );
    }

    // Level 2/3 일반 마커 (청색/azure)
    for (final job in jobs) {
      if (job.lat == 0 && job.lng == 0) continue;
      newMarkers.add(
        Marker(
          markerId: MarkerId(job.id),
          position: LatLng(job.lat, job.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          zIndexInt: 1,
          onTap: () => _onRegularPinTap(job),
        ),
      );
    }

    setState(() {
      _markers
        ..clear()
        ..addAll(newMarkers);
      _isLoading = false;
    });
  }

  // ── 핀 탭 핸들러 ─────────────────────────────────────────────────
  /// 프리미엄 핀 탭 → 캐러셀 해당 카드로 이동
  void _onPremiumPinTap(Job job) {
    final idx = _premiumJobs.indexWhere((j) => j.id == job.id);
    if (idx >= 0) {
      _carouselCtrl.animateToPage(
        idx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
      setState(() {
        _carouselPage = idx;
        _selectedJob = null;
      });
    }
  }

  /// 일반 핀 탭 → 하단 미리보기 카드 표시
  void _onRegularPinTap(Job job) {
    setState(() => _selectedJob = job);
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(job.lat, job.lng)),
    );
  }

  // ── 카드 탭 → 지도 이동 ─────────────────────────────────────────
  void _onCardTap(Job job) {
    if (job.lat != 0 && job.lng != 0) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(job.lat, job.lng), zoom: 15),
        ),
      );
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: job.id)),
    );
  }

  /// 카드의 지도 핀 아이콘 탭 → 지도만 이동 (상세 없이)
  void _onCardPinTap(Job job) {
    if (job.lat == 0 && job.lng == 0) return;
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(job.lat, job.lng), zoom: 15),
      ),
    );
  }

  // ── 카메라 이동 → bounds 업데이트 (디바운스) ─────────────────────
  void _onCameraMove(CameraPosition _) {
    _boundsTimer?.cancel();
    _boundsTimer = Timer(const Duration(milliseconds: 350), () async {
      final bounds = await _mapController?.getVisibleRegion();
      if (mounted && bounds != null) setState(() => _visibleBounds = bounds);
    });
  }

  // ── 반경 변경 ────────────────────────────────────────────────────
  void _onRadiusChanged(double r) {
    _jobFilter.setRadiusKm(r);
    setState(() {
      _isLoading = true;
      _markers.clear();
    });
    _loadJobMarkers();
  }

  String _filterSummary() {
    final parts = ['반경 ${_jobFilter.radiusKm.toStringAsFixed(0)}km'];
    if (_allJobs.isNotEmpty) parts.add('${_allJobs.length}건');
    if (_jobFilter.conditions.isNotEmpty) {
      parts.add(_jobFilter.conditions.join(', '));
    }
    return parts.join(' · ');
  }

  // ── 뷰포트 밖 프리미엄 공고 목록 ────────────────────────────────
  List<Job> _outOfViewPremium(LatLngBounds b) {
    return _premiumJobs.where((j) {
      if (j.lat == 0 && j.lng == 0) return false;
      return j.lat < b.southwest.latitude ||
          j.lat > b.northeast.latitude ||
          j.lng < b.southwest.longitude ||
          j.lng > b.northeast.longitude;
    }).toList();
  }

  LatLng get _viewportCenter {
    if (_visibleBounds == null) {
      return widget.userLocation ?? const LatLng(37.5665, 126.9780);
    }
    return LatLng(
      (_visibleBounds!.northeast.latitude +
              _visibleBounds!.southwest.latitude) /
          2,
      (_visibleBounds!.northeast.longitude +
              _visibleBounds!.southwest.longitude) /
          2,
    );
  }

  // ── Edge Indicator 위젯 목록 ────────────────────────────────────
  List<Widget> _buildEdgeIndicators() {
    if (_visibleBounds == null) return [];
    final outJobs = _outOfViewPremium(_visibleBounds!);
    if (outJobs.isEmpty) return [];

    final box = _mapKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return [];
    final sz = box.size;
    final center = _viewportCenter;
    const pad = 20.0; // 화면 가장자리 여백

    return outJobs.map((job) {
      // atan2: 북=0, 동=π/2 (위도·경도 좌표계)
      final angle = math.atan2(
        job.lng - center.longitude,
        job.lat - center.latitude,
      );
      final sinA = math.sin(angle);
      final cosA = math.cos(angle);
      final hw = sz.width / 2;
      final hh = sz.height / 2;

      double x, y;
      // 어느 쪽 가장자리에 닿는지 계산
      if (cosA.abs() * hw < sinA.abs() * hh) {
        x = sinA > 0 ? sz.width - pad : pad;
        y = (hh - cosA * (hw / sinA.abs())).clamp(pad, sz.height - pad);
      } else {
        y = cosA > 0 ? pad : sz.height - pad;
        x = (hw + sinA * (hh / cosA.abs())).clamp(pad, sz.width - pad);
      }

      return Positioned(
        left: x - 18,
        top: y - 18,
        child: _EdgeIndicator(
          job: job,
          angle: angle,
          onTap: () {
            _mapController?.animateCamera(
              CameraUpdate.newLatLng(LatLng(job.lat, job.lng)),
            );
            final idx = _premiumJobs.indexWhere((j) => j.id == job.id);
            if (idx >= 0) {
              _carouselCtrl.animateToPage(
                idx,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
              );
              setState(() => _carouselPage = idx);
            }
          },
        ),
      );
    }).toList();
  }

  // ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.of(context).size.height;
    // 광고 카드 영역 높이: 화면의 약 27%, 최소 170 · 최대 220
    final adH = (sh * 0.27).clamp(170.0, 220.0);

    return Scaffold(
      body: Column(
        children: [
          // ── 상단 1/4: 프리미엄 공고 슬라이더 ─────────────────
          SizedBox(height: adH, child: _buildAdCarousel()),

          // ── 하단 3/4: 지도 + 오버레이 ────────────────────────
          Expanded(
            child: Stack(
              key: _mapKey,
              children: [
                // Google Maps
                GoogleMap(
                  initialCameraPosition: _initialPosition,
                  markers: _markers,
                  myLocationEnabled: widget.userLocation != null,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  onMapCreated: (c) {
                    _mapController = c;
                    // 초기 뷰포트 bounds 측정
                    Future.delayed(const Duration(milliseconds: 600), () async {
                      final b = await c.getVisibleRegion();
                      if (mounted) setState(() => _visibleBounds = b);
                    });
                  },
                  onCameraMove: _onCameraMove,
                  onTap: (_) => setState(() => _selectedJob = null),
                ),

                // 로딩
                if (_isLoading)
                  Container(
                    color: Colors.white.withValues(alpha: 0.7),
                    child: const Center(child: CircularProgressIndicator()),
                  ),

                // Empty State
                if (!_isLoading && _allJobs.isEmpty)
                  MapEmptyStateCard(
                    onExpandRadius: () => _onRadiusChanged(10.0),
                    onEnableNotification: () {},
                    onCreateJob: () {},
                  ),

                // 검색 바
                FloatingSearchBar(
                  searchQuery: _jobFilter.searchQuery,
                  onSearchChanged: (q) => _jobFilter.setSearchQuery(q),
                  onFilterPressed: () {},
                  filterSummary: _filterSummary(),
                ),

                // 반경 칩
                RadiusChipRow(
                  selectedRadius: _jobFilter.radiusKm,
                  onRadiusChanged: _onRadiusChanged,
                ),

                // Edge Indicators (화면 밖 프리미엄 방향 표시)
                ..._buildEdgeIndicators(),

                // 줌 컨트롤
                Positioned(
                  right: 12,
                  bottom: 120,
                  child: _ZoomControls(
                    onZoomIn: () =>
                        _mapController?.animateCamera(CameraUpdate.zoomIn()),
                    onZoomOut: () =>
                        _mapController?.animateCamera(CameraUpdate.zoomOut()),
                  ),
                ),

                // 하단 미리보기 카드 (일반 핀 탭 시)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  left: 16,
                  right: 16,
                  bottom: _selectedJob != null ? 16 : -260,
                  child: _selectedJob != null
                      ? _PreviewCard(
                          job: _selectedJob!,
                          userLocation: widget.userLocation,
                          jobService: _jobService,
                          onDismiss: () => setState(() => _selectedJob = null),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 프리미엄 광고 카드 슬라이더 ─────────────────────────────────
  Widget _buildAdCarousel() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 섹션 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 13,
                  decoration: BoxDecoration(
                    color: _kPremium,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 7),
                const Text(
                  '프리미엄 공고',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kText,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '핀 탭으로 이동 · 카드 탭으로 상세',
                  style: TextStyle(
                    fontSize: 10,
                    color: _kText.withValues(alpha: 0.4),
                    letterSpacing: -0.2,
                  ),
                ),
                const Spacer(),
                // 페이지 인디케이터
                Text(
                  '${_carouselPage + 1} / ${_premiumJobs.length}',
                  style: TextStyle(
                    fontSize: 11,
                    color: _kText.withValues(alpha: 0.4),
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),

          // 가로 스크롤 카드
          Expanded(
            child: PageView.builder(
              controller: _carouselCtrl,
              onPageChanged: (i) => setState(() => _carouselPage = i),
              itemCount: _premiumJobs.length,
              itemBuilder: (_, i) => _PremiumAdCard(
                job: _premiumJobs[i],
                isSelected: i == _carouselPage,
                onTap: () => _onCardTap(_premiumJobs[i]),
                onPinTap: () => _onCardPinTap(_premiumJobs[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// 프리미엄 광고 카드 (가로 슬라이더 아이템)
// ────────────────────────────────────────────────────────────────────
class _PremiumAdCard extends StatelessWidget {
  final Job job;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onPinTap;

  const _PremiumAdCard({
    required this.job,
    required this.isSelected,
    required this.onTap,
    required this.onPinTap,
  });

  String get _dDayText {
    if (job.closingDate == null) return '상시';
    final diff = job.closingDate!.difference(DateTime.now()).inDays;
    if (diff < 0) return '마감';
    if (diff == 0) return 'D-day';
    return 'D-$diff';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: EdgeInsets.fromLTRB(
        isSelected ? 8 : 4,
        isSelected ? 0 : 4,
        isSelected ? 8 : 4,
        10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? _kPremium.withValues(alpha: 0.6)
              : _kShadow.withValues(alpha: 0.4),
          width: isSelected ? 1.5 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isSelected ? 0.07 : 0.03),
            blurRadius: isSelected ? 12 : 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // 좌: 이미지 / 병원 아이콘
              _CardThumbnail(job: job),
              const SizedBox(width: 14),

              // 우: 텍스트 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 매칭 점수 + D-day
                    Row(
                      children: [
                        if (job.matchScore > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _kPremium.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '매칭 ${job.matchScore}%',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _kPremium,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          _dDayText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _dDayText == 'D-day' || _dDayText == 'D-1'
                                ? const Color(0xFFE57373)
                                : _kText.withValues(alpha: 0.4),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const Spacer(),
                        // 지도 핀 아이콘 (탭 → 지도 이동)
                        GestureDetector(
                          onTap: onPinTap,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.location_on_rounded,
                              size: 18,
                              color: _kPremium.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),

                    // 병원명
                    Text(
                      job.clinicName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kText,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),

                    // 공고 제목
                    Text(
                      job.title,
                      style: TextStyle(
                        fontSize: 11,
                        color: _kText.withValues(alpha: 0.6),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // 직무 · 경력 · 역세권
                    Row(
                      children: [
                        _MiniTag(
                          label: job.type,
                          color: const Color(0xFFE3F2FD),
                          textColor: const Color(0xFF1976D2),
                        ),
                        const SizedBox(width: 4),
                        _MiniTag(
                          label: job.career,
                          color: const Color(0xFFF3E5F5),
                          textColor: const Color(0xFF7B1FA2),
                        ),
                        if (job.isNearStation) ...[
                          const SizedBox(width: 4),
                          _MiniTag(
                            label: '역세권',
                            color: const Color(0xFFE8F5E9),
                            textColor: const Color(0xFF43A047),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 카드 썸네일 ──────────────────────────────────────────────────
class _CardThumbnail extends StatelessWidget {
  final Job job;

  const _CardThumbnail({required this.job});

  @override
  Widget build(BuildContext context) {
    const size = 70.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: job.images.isNotEmpty
            ? Image.network(job.images.first, fit: BoxFit.cover)
            : Container(
                color: _kBg,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_hospital_outlined,
                      size: 22,
                      color: _kPremium.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job.clinicName.length > 3
                          ? job.clinicName.substring(0, 3)
                          : job.clinicName,
                      style: TextStyle(
                        fontSize: 8,
                        color: _kText.withValues(alpha: 0.4),
                        letterSpacing: -0.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ── Edge Indicator (화면 밖 프리미엄 방향 표시) ──────────────────
class _EdgeIndicator extends StatelessWidget {
  final Job job;
  final double angle; // atan2 결과 (북=0, 동=π/2)
  final VoidCallback onTap;

  const _EdgeIndicator({
    required this.job,
    required this.angle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 화살표 회전각 (화면 좌표계: 위=0, 시계방향)
    final rotateAngle = -angle + math.pi / 2;

    final initials = job.clinicName.length >= 2
        ? job.clinicName.substring(0, 2)
        : job.clinicName;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _kPremium,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _kPremium.withValues(alpha: 0.45),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 병원 이니셜
            Text(
              initials,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            // 방향 화살표 (외곽)
            Positioned(
              child: Transform.rotate(
                angle: rotateAngle,
                child: const Icon(
                  Icons.arrow_upward_rounded,
                  size: 10,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 줌 컨트롤 ────────────────────────────────────────────────────
class _ZoomControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const _ZoomControls({required this.onZoomIn, required this.onZoomOut});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZoomBtn(icon: Icons.add, onTap: onZoomIn),
          Divider(height: 0.5, thickness: 0.5, color: _kShadow),
          _ZoomBtn(icon: Icons.remove, onTap: onZoomOut),
        ],
      ),
    );
  }
}

class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ZoomBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, size: 18, color: _kText.withValues(alpha: 0.6)),
      ),
    );
  }
}

// ── 미리보기 카드 (Level 2/3 핀 탭 시 하단 표시) ─────────────────
class _PreviewCard extends StatelessWidget {
  final Job job;
  final LatLng? userLocation;
  final JobService jobService;
  final VoidCallback onDismiss;

  const _PreviewCard({
    required this.job,
    required this.userLocation,
    required this.jobService,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: jobService.watchBookmarkedJobIds(),
      builder: (context, snapshot) {
        final bookmarkedIds = snapshot.data ?? [];
        final isBookmarked = bookmarkedIds.contains(job.id);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 18,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더: 병원명 + 닫기
              Row(
                children: [
                  const Icon(
                    Icons.local_hospital,
                    color: Color(0xFF4FC3F7),
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      job.clinicName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _kText,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 북마크
                  IconButton(
                    onPressed: () async {
                      if (isBookmarked) {
                        await jobService.unbookmarkJob(job.id);
                      } else {
                        await jobService.bookmarkJob(job.id);
                      }
                    },
                    icon: Icon(
                      isBookmarked ? Icons.favorite : Icons.favorite_border,
                      color: isBookmarked
                          ? Colors.red
                          : _kText.withValues(alpha: 0.4),
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  // 닫기
                  GestureDetector(
                    onTap: onDismiss,
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: _kText.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),

              // 공고 제목
              Text(
                job.title,
                style: TextStyle(
                  fontSize: 13,
                  color: _kText.withValues(alpha: 0.65),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // 태그: 직무 · 경력
              Row(
                children: [
                  _MiniTag(
                    label: job.type,
                    color: const Color(0xFFE3F2FD),
                    textColor: const Color(0xFF1976D2),
                  ),
                  const SizedBox(width: 5),
                  _MiniTag(
                    label: job.career,
                    color: const Color(0xFFF3E5F5),
                    textColor: const Color(0xFF7B1FA2),
                  ),
                  if (job.salaryRange[0] > 0) ...[
                    const SizedBox(width: 5),
                    _MiniTag(
                      label: '${job.salaryRange[0]}~${job.salaryRange[1]}만',
                      color: const Color(0xFFFFF8E1),
                      textColor: const Color(0xFFF57F17),
                    ),
                  ],
                  if (userLocation != null) ...[
                    const Spacer(),
                    Text(
                      '${jobService.calculateDistance(userLocation!, LatLng(job.lat, job.lng)).toStringAsFixed(1)}km',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _kAccent.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),

              // 버튼: 1분 지원 + 상세 보기
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final hasApplied =
                            await jobService.hasApplied(job.id);
                        if (!context.mounted) return;
                        if (hasApplied) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('이미 지원한 공고입니다.')),
                          );
                          return;
                        }
                        final result =
                            await QuickApplySheet.show(context, job);
                        if (result == true && context.mounted) {
                          onDismiss();
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kText,
                        side: BorderSide(
                            color: _kAccent.withValues(alpha: 0.8)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        '1분 지원',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => JobDetailScreen(jobId: job.id),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kAccent,
                        foregroundColor: _kText,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        '상세 보기',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── 공용 미니 태그 칩 ──────────────────────────────────────────────
class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _MiniTag({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
