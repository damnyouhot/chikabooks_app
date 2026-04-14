import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_muted_card.dart';
import '../../data/mock_jobs.dart';
import '../../models/job.dart';
import '../../notifiers/job_filter_notifier.dart';
import '../../services/job_service.dart';
import '../../widgets/job/filter_bottom_sheet.dart';
import '../../widgets/job/floating_search_bar.dart';
import '../../widgets/job/job_level1_carousel.dart';
import '../../widgets/job/map_empty_state_card.dart';
import '../../widgets/job/quick_apply_sheet.dart';
import '../../widgets/job/radius_chip_row.dart';
import 'job_detail_screen.dart';
// 앱 세션 내 공고 목록 캐시 (반경/필터 조합 → 결과)
final Map<String, List<Job>> _jobCache = {};

// Level 1 프리미엄 전용 의미색 (핑크 → Blue 시스템 편입)
// 섹션 헤더·배지·Edge Indicator는 AppColors.accent(Blue) 사용

/// 지도 뷰 (4단계 개편)
///
/// ## 레이아웃
/// - 상단: [JobLevel1Carousel] — 목록 탭 고정 캐러셀과 동일(무한 PageView·4초 자동)
/// - 하단: Google Maps + Edge Indicator + 검색/반경 오버레이
///
/// ## 마커 스타일
/// - Level 1 (프리미엄): Rose 마커, zIndex 2 (위에 표시)
/// - Level 2/3 (일반): Azure 마커, zIndex 1
///
/// ## Edge Indicator
/// - 현재 지도 뷰포트 밖에 있는 프리미엄 클리닉을 화면 가장자리에 방향 표시
/// - 탭 시 해당 클리닉으로 카메라 이동 + 캐러셀 이동
class JobMapScreen extends StatefulWidget {
  final LatLng? userLocation;

  /// 목록 모드로 전환하는 콜백 (RadiusChipRow 우측 "목록" 버튼)
  final VoidCallback? onListToggle;

  const JobMapScreen({super.key, this.userLocation, this.onListToggle});

  @override
  State<JobMapScreen> createState() => _JobMapScreenState();
}

class _JobMapScreenState extends State<JobMapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  bool _isLoading = true;
  List<Job> _allJobs = [];

  /// 목록 [JobLevel1Carousel]과 동일 캐러셀 — 핀/엣지에서 [scrollToPage] 연동
  final GlobalKey<JobLevel1CarouselState> _level1CarouselKey =
      GlobalKey<JobLevel1CarouselState>();

  // Level 2/3 핀 선택 시 하단 미리보기 카드
  Job? _selectedJob;

  // Edge Indicator 계산용
  LatLngBounds? _visibleBounds;
  Timer? _boundsTimer;
  final _mapKey = GlobalKey(); // 지도 영역 크기 측정

  late JobService _jobService;
  late JobFilterNotifier _jobFilter;
  /// 필터·검색·반경 등 변경 시 마커 재로드
  String? _lastMarkerFilterSignature;

  // Level 1 프리미엄 공고 (광고 카드 + Rose 마커)
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _jobService = context.read<JobService>();
    _jobFilter = context.watch<JobFilterNotifier>();
    final sig = _markerFilterSignature(_jobFilter);
    if (_lastMarkerFilterSignature != sig) {
      _lastMarkerFilterSignature = sig;
      _loadJobMarkers();
    }
  }

  /// 캐시/재로드 키 — 목록 탭과 동일하게 검색·근무형태까지 포함
  String _markerFilterSignature(JobFilterNotifier f) {
    final lat = widget.userLocation?.latitude.toStringAsFixed(2) ?? 'null';
    final lng = widget.userLocation?.longitude.toStringAsFixed(2) ?? 'null';
    final cond = List<String>.from(f.conditions)..sort();
    return '$lat|$lng|${f.radiusKm}|${f.positionFilter}|${cond.join(',')}|${f.employmentType}|${f.searchQuery.trim()}';
  }

  /// 목록(Level3)과 동일한 클라이언트 필터 (검색어·근무형태)
  List<Job> _applyClientFilters(List<Job> jobs) {
    final f = _jobFilter;
    var out = jobs;
    final sq = f.searchQuery.trim().toLowerCase();
    if (sq.isNotEmpty) {
      out =
          out.where((j) {
            return j.clinicName.toLowerCase().contains(sq) ||
                j.address.toLowerCase().contains(sq) ||
                j.district.toLowerCase().contains(sq);
          }).toList();
    }
    if (f.employmentType != '전체') {
      final want = f.employmentType;
      out =
          out.where((j) {
            final et = j.employmentType.trim();
            if (et.isNotEmpty) {
              return et.contains(want) || want.contains(et);
            }
            return j.type.contains(want);
          }).toList();
    }
    return out;
  }

  @override
  void dispose() {
    _boundsTimer?.cancel();
    super.dispose();
  }

  // ── 마커 로드 ────────────────────────────────────────────────────
  Future<void> _loadJobMarkers() async {
    try {
      List<Job> jobs;

      final cacheKey = _markerFilterSignature(_jobFilter);

      if (_jobCache.containsKey(cacheKey)) {
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

      // Firestore 비어있으면 Mock 폴백 (반경 필터도 동일하게 적용)
      if (jobs.isEmpty) {
        final mockAll = [...mockLevel2Jobs, ...generateMockLevel3Jobs(count: 10)];
        if (widget.userLocation != null) {
          final userLoc = widget.userLocation!;
          final radiusKm = _jobFilter.radiusKm;
          jobs = mockAll.where((job) {
            if (job.lat == 0 && job.lng == 0) return false;
            return _jobService.calculateDistance(
                  userLoc,
                  LatLng(job.lat, job.lng),
                ) <=
                radiusKm;
          }).toList();
          // 반경 내에 아무것도 없으면 전체 Mock 표시 (빈 지도 방지)
          if (jobs.isEmpty) jobs = mockAll;
        } else {
          jobs = mockAll;
        }
      }

      jobs = _applyClientFilters(jobs);
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
      final filtered = _applyClientFilters(fresh);
      _jobCache[cacheKey] = filtered;
      _applyMarkers(filtered);
    } catch (_) {}
  }

  void _applyMarkers(List<Job> jobs) {
    if (!mounted) return;

    _allJobs = jobs;
    final newMarkers = <Marker>{};

    // Level 1 프리미엄 마커 (Rose, zIndex 높음)
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

    // Level 2/3 일반 마커 (Azure)
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
      _level1CarouselKey.currentState?.scrollToPage(idx);
      setState(() => _selectedJob = null);
    }
  }

  /// 일반 핀 탭 → 하단 미리보기 카드 표시
  void _onRegularPinTap(Job job) {
    setState(() => _selectedJob = job);
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(job.lat, job.lng)),
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
              _level1CarouselKey.currentState?.scrollToPage(idx);
            }
          },
        ),
      );
    }).toList();
  }

  // ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Stack이 viewInsets를 직접 읽어 키보드 대응 → Scaffold 자동 리사이즈 끔
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          // ── 상단: 프리미엄 공고 슬라이더 (컨텐츠 기반 높이) ──────
          _buildAdCarousel(),

          // ── 하단: 지도 + 오버레이 ────────────────────────────────
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
                    color: AppColors.white.withValues(alpha: 0.7),
                    child: const Center(child: CircularProgressIndicator()),
                  ),

                // Empty State
                if (!_isLoading && _allJobs.isEmpty)
                  MapEmptyStateCard(
                    onExpandRadius: () => _onRadiusChanged(20.0),
                    onEnableNotification: () {},
                    onCreateJob: () {},
                  ),

                // 검색 바 (목록 탭과 동일 스케일·필터 칩)
                FloatingSearchBar(
                  searchQuery: _jobFilter.searchQuery,
                  onSearchChanged: (q) => _jobFilter.setSearchQuery(q),
                  onFilterPressed: () =>
                      FilterBottomSheet.show(context, _jobFilter),
                  filterSummary: _filterSummary(),
                  activeFilterCount: _jobFilter.activeCount,
                  onListToggle: widget.onListToggle,
                ),

                // 반경 칩
                RadiusChipRow(
                  selectedRadius: _jobFilter.radiusKm,
                  onRadiusChanged: _onRadiusChanged,
                ),

                // Edge Indicators (화면 밖 프리미엄 방향 표시)
                ..._buildEdgeIndicators(),

                // 줌 컨트롤 — 반경칩 + 검색바 위
                Positioned(
                  right: 12,
                  bottom: 112,
                  child: _ZoomControls(
                    onZoomIn: () =>
                        _mapController?.animateCamera(CameraUpdate.zoomIn()),
                    onZoomOut: () =>
                        _mapController?.animateCamera(CameraUpdate.zoomOut()),
                  ),
                ),

                // 하단 미리보기 카드 (일반 핀 탭 시) — 검색바 위
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  left: 16,
                  right: 16,
                  bottom: _selectedJob != null ? 106 : -260,
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

  /// 목록 탭 고정 캐러셀과 동일 위젯 — viewportFraction·AnimatedContainer 제거로 깜박임 방지
  Widget _buildAdCarousel() {
    return Material(
      color: AppColors.appBg,
      child: JobLevel1Carousel(
        key: _level1CarouselKey,
        jobs: _premiumJobs,
        onJobTap: (context, job) {
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
        },
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
        decoration: const BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
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
                color: AppColors.onAccent,
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
                  color: AppColors.onAccent,
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
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZoomBtn(icon: Icons.add, onTap: onZoomIn),
          Divider(height: 0.5, thickness: 0.5, color: AppColors.divider),
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
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, size: 18, color: AppColors.textSecondary),
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

        return AppMutedCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
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
                      job.displayClinicName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
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
                          : AppColors.textDisabled,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // 닫기
                  GestureDetector(
                    onTap: onDismiss,
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: AppColors.textDisabled,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),

              // 공고 제목
              Text(
                job.displayTitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.sm),

              // 태그: 직무 · 고용 · 경력 · 급여
              Row(
                children: [
                  _MiniTag(
                    label: job.type.isNotEmpty ? job.type : '직무',
                    color: AppColors.accent.withValues(alpha: 0.12),
                    textColor: AppColors.accent,
                  ),
                  if (job.employmentType.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    _MiniTag(
                      label: job.employmentType,
                      color: AppColors.surfaceMuted,
                      textColor: AppColors.textSecondary,
                    ),
                  ],
                  if (job.career.isNotEmpty && job.career != '미정') ...[
                    const SizedBox(width: 5),
                    _MiniTag(
                      label: job.career,
                      color: AppColors.surfaceMuted,
                      textColor: AppColors.textSecondary,
                    ),
                  ],
                  const SizedBox(width: 5),
                  _MiniTag(
                    label: job.salaryDisplayLine,
                    color: AppColors.warning.withValues(alpha: 0.14),
                    textColor: AppColors.warning,
                  ),
                  if (userLocation != null) ...[
                    const Spacer(),
                    Text(
                      '${jobService.calculateDistance(userLocation!, LatLng(job.lat, job.lng)).toStringAsFixed(1)}km',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.sm + 2),

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
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.divider),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
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
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => JobDetailScreen(jobId: job.id),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onAccent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
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
        // 직무/경력/역세권/급여 고유 의미색 유지 (호출자가 지정)
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.xs - 1),
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
