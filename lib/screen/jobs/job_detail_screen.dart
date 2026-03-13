import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_muted_card.dart';
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
                  color: bookmarked ? AppColors.warning : null,
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
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.onAccent,
            elevation: 0,
            label: const Text('원클릭 지원'),
            icon: const Icon(Icons.send_outlined),
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              /* Map Preview — 실제 Google Maps 미니맵 */
              if (job.lat != 0 || job.lng != 0)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
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
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: AppColors.textDisabled,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          job.address,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Text(
                job.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${job.type} · ${job.career} · ${job.salaryRange[0]}~${job.salaryRange[1]}만원',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              Divider(height: 24, color: AppColors.divider),
              Text('업무 내용', style: Theme.of(context).textTheme.titleMedium),
              Text(job.details, style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.md),
              Text('복리후생', style: Theme.of(context).textTheme.titleMedium),
              Wrap(
                spacing: 8,
                children:
                    job.benefits.map((b) => Chip(label: Text(b))).toList(),
              ),
              const SizedBox(height: AppSpacing.md),
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
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: Image.network(
                              job.images[i],
                              width: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
              // ── 지원 안내 ──
              AppMutedCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '원클릭 지원 (이력서 확인 후 제출)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      '누르면 바로 전송되지 않아요. 이력서를 확인/수정한 뒤 제출해요.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
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
