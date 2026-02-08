import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/job.dart';
import '../../services/job_service.dart';
import 'job_detail_screen.dart';

class JobMapScreen extends StatefulWidget {
  const JobMapScreen({super.key});

  @override
  State<JobMapScreen> createState() => _JobMapScreenState();
}

class _JobMapScreenState extends State<JobMapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  bool _isLoading = true;

  // ── 선택된 공고 (미리보기 카드용) ──
  Job? _selectedJob;

  static const _initialPosition = CameraPosition(
    target: LatLng(37.5665, 126.9780),
    zoom: 11,
  );

  late final JobService _jobService;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _jobService = context.read<JobService>();
    if (_isLoading) {
      _loadJobMarkers();
    }
  }

  Future<void> _loadJobMarkers() async {
    try {
      final jobs = await _jobService.fetchJobs();
      if (!mounted) return;

      final newMarkers = <Marker>{};

      for (final job in jobs) {
        if (job.lat == 0 && job.lng == 0) continue;

        final marker = Marker(
          markerId: MarkerId(job.id),
          position: LatLng(job.lat, job.lng),
          // InfoWindow 대신 직접 onTap → 하단 미리보기 카드
          onTap: () => _onMarkerTap(job),
        );
        newMarkers.add(marker);
      }

      if (mounted) {
        setState(() {
          _markers.addAll(newMarkers);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('마커 로딩 실패: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onMarkerTap(Job job) {
    setState(() => _selectedJob = job);
    // 선택한 마커 위치로 카메라 부드럽게 이동
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(job.lat, job.lng)),
    );
  }

  void _dismissCard() {
    if (_selectedJob != null) {
      setState(() => _selectedJob = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── 구글 맵 ──
          GoogleMap(
            initialCameraPosition: _initialPosition,
            markers: _markers,
            myLocationEnabled: false,
            zoomControlsEnabled: true,
            onMapCreated: (controller) => _mapController = controller,
            onTap: (_) => _dismissCard(), // 빈 곳 탭 → 카드 닫기
          ),

          // ── 로딩 인디케이터 ──
          if (_isLoading) const Center(child: CircularProgressIndicator()),

          // ── 하단 미리보기 카드 (슬라이드업 애니메이션) ──
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            left: 16,
            right: 16,
            bottom: _selectedJob != null ? 24 : -200,
            child: _selectedJob != null
                ? _buildPreviewCard(_selectedJob!)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ── 미리보기 카드 위젯 ──
  Widget _buildPreviewCard(Job job) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: job.id)),
        );
      },
      child: Container(
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
            // 상단: 치과 이름
            Row(
              children: [
                const Icon(Icons.local_hospital,
                    color: Color(0xFF4FC3F7), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    job.clinicName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // 공고 제목
            Text(
              job.title,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // 태그 행: 고용형태 / 경력 / 급여
            Row(
              children: [
                _buildTag(
                    job.type, const Color(0xFFE3F2FD), const Color(0xFF1976D2)),
                const SizedBox(width: 6),
                _buildTag(job.career, const Color(0xFFF3E5F5),
                    const Color(0xFF7B1FA2)),
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

            // 주소
            if (job.address.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      job.address,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 12),

            // 자세히 보기 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => JobDetailScreen(jobId: job.id)),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4FC3F7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  '자세히 보기',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
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
