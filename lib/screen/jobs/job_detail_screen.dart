import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_muted_card.dart';
import '../../models/job.dart';
import '../../services/job_service.dart';
import '../../widgets/job/job_detail_widgets.dart';
import '../../features/resume/screens/apply_confirm_screen.dart';
import '../../services/job_stats_service.dart';
import '../../services/admin_activity_service.dart';

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
    final svc = context.read<JobService>();
    Job job;
    try {
      job = await svc.fetchJob(widget.jobId);
    } catch (e, st) {
      debugPrint('⚠️ JobDetailScreen fetchJob: $e\n$st');
      job = svc.jobOfflineFallback(widget.jobId);
    }
    if (!mounted) return;
    setState(() => _job = job);

    try {
      JobStatsService.recordView(widget.jobId);
      AdminActivityService.log(
        ActivityEventType.viewJobDetail,
        page: 'job_detail',
        targetId: widget.jobId,
      );
    } catch (e, st) {
      debugPrint('⚠️ JobDetailScreen analytics: $e\n$st');
    }

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

  String _metaLine(Job job) {
    return job.listRoleLine;
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
                  if (bookmarked) {
                    jobService.unbookmarkJob(widget.jobId);
                  } else {
                    jobService.bookmarkJob(widget.jobId);
                    AdminActivityService.log(
                      ActivityEventType.tapJobSave,
                      page: 'job_detail',
                      targetId: widget.jobId,
                    );
                  }
                },
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              AdminActivityService.log(
                ActivityEventType.tapJobApply,
                page: 'job_detail',
                targetId: widget.jobId,
              );
              _openApplyConfirm(context, job);
            },
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.onAccent,
            elevation: 0,
            label: const Text('원클릭 지원'),
            icon: const Icon(Icons.send_outlined),
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
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
                      liteModeEnabled: true,
                    ),
                  ),
                ),
              if (job.address.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Row(
                    children: [
                      const Icon(
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
              const SizedBox(height: 6),
              Text(
                _metaLine(job),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                job.salaryDisplayLine,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              Divider(height: AppSpacing.xxl, color: AppColors.divider),
              if (job.workHours.isNotEmpty || job.contact.isNotEmpty) ...[
                const JobDetailSectionTitle('근무 조건'),
                if (job.workHours.isNotEmpty)
                  JobDetailInfoRow(
                    icon: Icons.schedule_outlined,
                    label: '근무 시간',
                    value: job.workHours,
                  ),
                if (job.contact.isNotEmpty)
                  JobDetailInfoRow(
                    icon: Icons.phone_outlined,
                    label: '연락처',
                    value: job.contact,
                  ),
                Divider(height: AppSpacing.xxl, color: AppColors.divider),
              ],
              const JobDetailSectionTitle('업무 내용'),
              Text(
                job.details.isNotEmpty ? job.details : '등록된 상세 설명이 없어요.',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (job.benefits.isNotEmpty) ...[
                const JobDetailSectionTitle('복리후생'),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: job.benefits
                      .map((b) => JobBenefitChip(label: b))
                      .toList(),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (job.images.isNotEmpty) ...[
                const JobDetailSectionTitle('사진'),
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: job.images.length,
                    itemBuilder: (_, i) => Padding(
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
                const SizedBox(height: AppSpacing.lg),
              ],
              AppMutedCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '원클릭 지원 (이력서 확인 후 제출)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
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
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }
}
