import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/job.dart';
import '../../services/job_service.dart';
import '../../features/resume/screens/apply_confirm_screen.dart';
import '../../services/job_stats_service.dart';

class JobDetailScreen extends StatefulWidget {
  final String jobId;
  final bool autoOpenApply;
  const JobDetailScreen({
    super.key,
    required this.jobId,
    this.autoOpenApply = false,
  });

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  Job? _job;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final job = await context.read<JobService>().fetchJob(widget.jobId);
    if (!mounted) return;
    setState(() => _job = job);

    // 조회수 기록
    JobStatsService.recordView(widget.jobId);

    if (widget.autoOpenApply) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _job != null) {
          _openApplyConfirm(context, _job!);
        }
      });
    }
  }

  void _openApplyConfirm(BuildContext context, Job job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApplyConfirmScreen(job: job),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_job == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final job = _job!;
    final jobService = context.read<JobService>();

    return StreamBuilder<List<String>>(
      stream: jobService.watchBookmarkedJobIds(),
      builder: (context, snap) {
        final ids = snap.data ?? [];
        final bookmarked = ids.contains(widget.jobId);

        return Scaffold(
          appBar: AppBar(
            title: Text(job.clinicName),
            actions: [
              IconButton(
                icon: Icon(
                  bookmarked ? Icons.star : Icons.star_border,
                  color: bookmarked ? Colors.amber : null,
                ),
                onPressed: () {
                  bookmarked
                      ? jobService.unbookmarkJob(widget.jobId)
                      : jobService.bookmarkJob(widget.jobId);
                },
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openApplyConfirm(context, job),
            label: const Text('원클릭 지원'),
            icon: const Icon(Icons.send_outlined),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              /* Map Preview — 실제 Google Maps 미니맵 */
              if (job.lat != 0 || job.lng != 0)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 180,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(job.lat, job.lng),
                        zoom: 15,
                      ),
                      markers: {
                        Marker(
                          markerId: const MarkerId('clinic'),
                          position: LatLng(job.lat, job.lng),
                        ),
                      },
                      zoomControlsEnabled: false,
                      scrollGesturesEnabled: false,
                      rotateGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                      zoomGesturesEnabled: false,
                      myLocationButtonEnabled: false,
                      liteModeEnabled: true, // 정적 이미지로 렌더 (가볍고 빠름)
                    ),
                  ),
                ),
              if (job.address.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          job.address,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                job.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${job.type} · ${job.career} · ${job.salaryRange[0]}~${job.salaryRange[1]}만원',
              ),
              const Divider(height: 24),
              Text('업무 내용', style: Theme.of(context).textTheme.titleMedium),
              Text(job.details),
              const SizedBox(height: 12),
              Text('복리후생', style: Theme.of(context).textTheme.titleMedium),
              Wrap(
                spacing: 8,
                children:
                    job.benefits.map((b) => Chip(label: Text(b))).toList(),
              ),
              const SizedBox(height: 12),
              Text('사진', style: Theme.of(context).textTheme.titleMedium),
              if (job.images.isNotEmpty)
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: job.images.length,
                    itemBuilder:
                        (_, i) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              job.images[i],
                              width: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                  ),
                ),
              const SizedBox(height: 20),
              // ── 지원 안내 ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90D9).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF4A90D9).withOpacity(0.12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '원클릭 지원 (이력서 확인 후 제출)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3D4A5C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '누르면 바로 전송되지 않아요. 이력서를 확인/수정한 뒤 제출해요.',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF3D4A5C).withOpacity(0.5),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 80), // FAB와 겹치지 않게 여백
            ],
          ),
        );
      },
    );
  }
}
