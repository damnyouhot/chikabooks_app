import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/job.dart';
import '../../services/job_service.dart';
import '../../notifiers/job_filter_notifier.dart';
import '../../widgets/job/floating_search_bar.dart';
import '../../widgets/job/radius_chip_row.dart';
import '../../widgets/job/map_empty_state_card.dart';
import '../../widgets/job/quick_apply_sheet.dart';
import 'job_detail_screen.dart';

// ── 디자인 팔레트 ──
const _kAccent = Color(0xFFF7CBCA);
const _kText = Color(0xFF5D6B6B);

class JobMapScreen extends StatefulWidget {
  final LatLng? userLocation; // 사용자 위치

  const JobMapScreen({super.key, this.userLocation});

  @override
  State<JobMapScreen> createState() => _JobMapScreenState();
}

class _JobMapScreenState extends State<JobMapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  bool _isLoading = true;
  List<Job> _allJobs = []; // 전체 공고 목록 (필터링용)

  // ── 선택된 공고 (미리보기 카드용) ──
  Job? _selectedJob;

  late final JobService _jobService;
  late final JobFilterNotifier _jobFilter;

  // ★ 초기 카메라 위치 (사용자 위치 또는 서울 중심)
  CameraPosition get _initialPosition {
    if (widget.userLocation != null) {
      return CameraPosition(target: widget.userLocation!, zoom: 13);
    }
    return const CameraPosition(
      target: LatLng(37.5665, 126.9780), // 서울 중심
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
    if (_isLoading) {
      _loadJobMarkers();
    }
  }

  /// 반경 기반 공고 로드
  Future<void> _loadJobMarkers() async {
    try {
      List<Job> jobs;

      // 사용자 위치가 있으면 반경 기반 검색
      if (widget.userLocation != null) {
        jobs = await _jobService.fetchJobsNearby(
          widget.userLocation!,
          _jobFilter.radiusKm,
          positionFilter: _jobFilter.positionFilter,
          conditions: _jobFilter.conditions,
        );
      } else {
        // 위치 없으면 전체 공고
        jobs = await _jobService.fetchJobs();
      }

      if (!mounted) return;

      _allJobs = jobs;
      final newMarkers = <Marker>{};

      for (final job in jobs) {
        if (job.lat == 0 && job.lng == 0) continue;

        final marker = Marker(
          markerId: MarkerId(job.id),
          position: LatLng(job.lat, job.lng),
          onTap: () => _onMarkerTap(job),
        );
        newMarkers.add(marker);
      }

      if (mounted) {
        setState(() {
          _markers.clear();
          _markers.addAll(newMarkers);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ 마커 로딩 실패: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onMarkerTap(Job job) {
    setState(() => _selectedJob = job);
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(job.lat, job.lng)),
    );
  }

  void _dismissCard() {
    if (_selectedJob != null) {
      setState(() => _selectedJob = null);
    }
  }

  /// 반경 변경 시 마커 새로고침
  void _onRadiusChanged(double newRadius) {
    _jobFilter.setRadiusKm(newRadius);
    setState(() {
      _isLoading = true;
      _markers.clear();
    });
    _loadJobMarkers();
  }

  /// 검색어 변경
  void _onSearchChanged(String query) {
    _jobFilter.setSearchQuery(query);
    // 실시간 검색 필터링은 추후 구현 가능
  }

  /// 필터 버튼 클릭 (TODO: 상세 필터 모달)
  void _onFilterPressed() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('상세 필터 기능은 추후 업데이트됩니다.')));
  }

  /// Empty State 액션들
  void _onExpandRadius() {
    _onRadiusChanged(10.0); // 10km로 확장
  }

  void _onEnableNotification() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('알림 설정은 상단 카드에서 변경하세요.')));
  }

  void _onCreateJob() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('공고 등록 기능은 추후 업데이트됩니다.')));
  }

  /// 필터 요약 문구 생성
  String _getFilterSummary() {
    final parts = <String>[];

    parts.add('반경 ${_jobFilter.radiusKm.toStringAsFixed(0)}km');

    if (_allJobs.isNotEmpty) {
      parts.add('${_allJobs.length}건');
    }

    if (_jobFilter.conditions.isNotEmpty) {
      parts.add(_jobFilter.conditions.join(', '));
    }

    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final hasMarkers = _markers.isNotEmpty;

    return Scaffold(
      body: Stack(
        children: [
          // ── 구글 맵 ──
          GoogleMap(
            initialCameraPosition: _initialPosition,
            markers: _markers,
            myLocationEnabled: widget.userLocation != null,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            onMapCreated: (controller) => _mapController = controller,
            onTap: (_) => _dismissCard(),
          ),

          // ── 로딩 인디케이터 ──
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.7),
              child: const Center(child: CircularProgressIndicator()),
            ),

          // ── Empty State (마커 없을 때) ──
          if (!_isLoading && !hasMarkers)
            MapEmptyStateCard(
              onExpandRadius: _onExpandRadius,
              onEnableNotification: _onEnableNotification,
              onCreateJob: _onCreateJob,
            ),

          // ── FloatingSearchBar (지도 위) ──
          FloatingSearchBar(
            searchQuery: _jobFilter.searchQuery,
            onSearchChanged: _onSearchChanged,
            onFilterPressed: _onFilterPressed,
            filterSummary: _getFilterSummary(),
          ),

          // ── RadiusChipRow (반경 칩) ──
          RadiusChipRow(
            selectedRadius: _jobFilter.radiusKm,
            onRadiusChanged: _onRadiusChanged,
          ),

          // ── 하단 미리보기 카드 ──
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            left: 16,
            right: 16,
            bottom: _selectedJob != null ? 24 : -300,
            child:
                _selectedJob != null
                    ? _buildPreviewCard(_selectedJob!)
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ── 미리보기 카드 위젯 (개선 버전) ──
  Widget _buildPreviewCard(Job job) {
    return StreamBuilder<List<String>>(
      stream: _jobService.watchBookmarkedJobIds(),
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
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단: 치과 이름 + 관심 버튼
              Row(
                children: [
                  const Icon(
                    Icons.local_hospital,
                    color: Color(0xFF4FC3F7),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      job.clinicName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _kText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // ★ 관심 버튼 + 포인트 배지
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () async {
                          if (isBookmarked) {
                            await _jobService.unbookmarkJob(job.id);
                          } else {
                            await _jobService.bookmarkJob(job.id);
                          }
                        },
                        icon: Icon(
                          isBookmarked ? Icons.favorite : Icons.favorite_border,
                          color:
                              isBookmarked
                                  ? Colors.red
                                  : _kText.withOpacity(0.5),
                          size: 22,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      if (!isBookmarked)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: _kAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '+0.3P',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: _kText.withOpacity(0.7),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // 공고 제목
              Text(
                job.title,
                style: TextStyle(fontSize: 14, color: _kText.withOpacity(0.7)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // 태그 행: 고용형태 / 경력 / 급여
              Row(
                children: [
                  _buildTag(
                    job.type,
                    const Color(0xFFE3F2FD),
                    const Color(0xFF1976D2),
                  ),
                  const SizedBox(width: 6),
                  _buildTag(
                    job.career,
                    const Color(0xFFF3E5F5),
                    const Color(0xFF7B1FA2),
                  ),
                  const SizedBox(width: 6),
                  if (job.salaryRange[0] > 0)
                    _buildTag(
                      '${job.salaryRange[0]}~${job.salaryRange[1]}만',
                      const Color(0xFFFFF8E1),
                      const Color(0xFFF57F17),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // 주소 + 거리
              if (job.address.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: _kText.withOpacity(0.4),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        job.address,
                        style: TextStyle(
                          fontSize: 12,
                          color: _kText.withOpacity(0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // 거리 표시 (사용자 위치가 있을 때)
                    if (widget.userLocation != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${_jobService.calculateDistance(widget.userLocation!, LatLng(job.lat, job.lng)).toStringAsFixed(1)}km',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _kAccent.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ],
                ),

              const SizedBox(height: 12),

              // 버튼 행: 1분 지원 + 상세 보기
              Row(
                children: [
                  // 1분 지원 버튼
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        // 이미 지원했는지 확인
                        final hasApplied = await _jobService.hasApplied(job.id);
                        if (hasApplied && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('이미 지원한 공고입니다.')),
                          );
                          return;
                        }

                        // 1분 지원 시트 열기
                        if (mounted) {
                          final result = await QuickApplySheet.show(
                            context,
                            job,
                          );
                          // 지원 성공 시 프리뷰 카드 닫기
                          if (result == true && mounted) {
                            setState(() => _selectedJob = null);
                          }
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kText,
                        side: BorderSide(color: _kAccent, width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '1분 지원',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: _kAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '+1.0P',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: _kText.withOpacity(0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 상세 보기 버튼
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => JobDetailScreen(jobId: job.id),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kAccent,
                        foregroundColor: _kText,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
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

  // ── 태그 칩 위젯 ──
  Widget _buildTag(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
