import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
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
  NaverMapController? _mapController;
  final Set<NMarker> _markers = {};
  bool _isLoading = true;

  static const _initialPosition = NCameraPosition(
    target: NLatLng(37.5665, 126.9780), // 서울 시청
    zoom: 11,
  );

  @override
  void initState() {
    super.initState();
    _loadJobMarkers();
  }

  Future<void> _loadJobMarkers() async {
    final jobs = await context.read<JobService>().fetchJobs();
    if (!mounted) return;

    final newMarkers = <NMarker>{};
    for (final job in jobs) {
      // ───────────────────────────────────────────────────────────
      final marker = NMarker(
        id: job.id,
        position: NLatLng(job.lat, job.lng),
        caption: NOverlayCaption(text: job.clinicName),
      );
      // ⭐️ 탭 콜백은 이렇게 별도로 지정
      marker.setOnTapListener((NOverlay overlay) {
        _onMarkerTap(marker, job);
      });
      // ───────────────────────────────────────────────────────────
      newMarkers.add(marker);
    }

    if (mounted) {
      setState(() {
        _markers.addAll(newMarkers);
        _isLoading = false;
      });
      _mapController?.addOverlayAll(newMarkers);
    }
  }

  void _onMarkerTap(NMarker marker, Job job) {
    _mapController?.updateCamera(
      NCameraUpdate.scrollAndZoomTo(
        target: marker.position,
        zoom: 15,
      ),
    );
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
          NaverMap(
            options: const NaverMapViewOptions(
              initialCameraPosition: _initialPosition,
            ),
            onMapReady: (controller) {
              _mapController = controller;
              if (_markers.isNotEmpty) {
                _mapController?.addOverlayAll(_markers);
              }
            },
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
