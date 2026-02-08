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

  // 서울 시청 기본 위치
  static const _initialPosition = CameraPosition(
    target: LatLng(37.5665, 126.9780),
    zoom: 11,
  );

  late final JobService _jobService;

  @override
  void initState() {
    super.initState();
    // Provider.of는 didChangeDependencies에서 사용하는 것이 안전
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
        if (job.lat == 0 && job.lng == 0) continue; // 좌표 없는 공고 건너뜀

        final marker = Marker(
          markerId: MarkerId(job.id),
          position: LatLng(job.lat, job.lng),
          infoWindow: InfoWindow(
            title: job.clinicName,
            snippet: job.title,
            onTap: () => _onMarkerTap(job),
          ),
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onMarkerTap(Job job) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: job.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialPosition,
            markers: _markers,
            myLocationEnabled: false,
            zoomControlsEnabled: true,
            onMapCreated: (controller) {
              _mapController = controller;
            },
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
