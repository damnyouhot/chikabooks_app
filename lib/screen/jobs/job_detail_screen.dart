import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/job.dart';
import '../../services/job_service.dart';

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

    if (widget.autoOpenApply) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openApplyModal(context, job);
      });
    }
  }

  void _openApplyModal(BuildContext context, Job job) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 24, 16, MediaQuery.of(context).viewInsets.bottom + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${job.clinicName} 지원서',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const TextField(decoration: InputDecoration(labelText: '이름')),
            const TextField(decoration: InputDecoration(labelText: '연락처')),
            const TextField(
                decoration: InputDecoration(labelText: '경력/포트폴리오 링크')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('지원서가 제출되었습니다!')),
                );
              },
              child: const Text('제출하기'),
            ),
          ],
        ),
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
            onPressed: () => _openApplyModal(context, job),
            label: const Text('지원하기'),
            icon: const Icon(Icons.edit),
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
                      Icon(Icons.location_on,
                          size: 16, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          job.address,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Text(job.title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              Text(
                  '${job.type} · ${job.career} · ${job.salaryRange[0]}~${job.salaryRange[1]}만원'),
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
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(job.images[i],
                            width: 200, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
