import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_muted_card.dart';
import '../../models/job.dart';
import '../../services/job_service.dart';
import '../../widgets/job/job_detail_widgets.dart';
import '../../widgets/job/job_cover_image.dart';
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
              if (job.images.isNotEmpty) ...[
                const JobDetailSectionTitle('사진'),
                _JobImageGallery(images: job.images),
                const SizedBox(height: AppSpacing.lg),
              ],
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

              // 태그 + 마감일 배지
              if (job.tags.isNotEmpty || job.isAlwaysHiring || job.closingDate != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (job.isAlwaysHiring)
                        _DetailBadge(label: '상시채용', color: AppColors.success),
                      if (!job.isAlwaysHiring && job.closingDate != null)
                        _DetailBadge(
                          label: 'D-${job.closingDate!.difference(DateTime.now()).inDays}',
                          color: AppColors.error,
                        ),
                      ...job.tags.map((t) => _DetailBadge(label: t, color: AppColors.accent)),
                    ],
                  ),
                ),

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

              // 교통편 정보
              if (job.transportation != null && job.transportation!.detailLine != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(Icons.subway, size: 16, color: AppColors.accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        job.transportation!.detailLine!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (job.hasParking)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          SizedBox(width: 8),
                          Icon(Icons.local_parking, size: 14, color: AppColors.textDisabled),
                          SizedBox(width: 2),
                          Text('주차', style: TextStyle(fontSize: 11, color: AppColors.textDisabled)),
                        ],
                      ),
                  ],
                ),
              ],

              Divider(height: AppSpacing.xxl, color: AppColors.divider),

              // 병원 정보
              if (job.hospitalType != null || job.chairCount != null || job.staffCount != null) ...[
                const JobDetailSectionTitle('병원 정보'),
                if (job.hospitalType != null)
                  JobDetailInfoRow(
                    icon: Icons.business_outlined,
                    label: '유형',
                    value: job.hospitalTypeLabel,
                  ),
                if (job.chairCount != null)
                  JobDetailInfoRow(
                    icon: Icons.airline_seat_recline_normal_outlined,
                    label: '체어 수',
                    value: '${job.chairCount}대',
                  ),
                if (job.staffCount != null)
                  JobDetailInfoRow(
                    icon: Icons.group_outlined,
                    label: '스탭 수',
                    value: '${job.staffCount}명',
                  ),
                Divider(height: AppSpacing.xxl, color: AppColors.divider),
              ],

              // 근무 조건
              if (job.workHours.isNotEmpty || job.contact.isNotEmpty ||
                  job.workDays.isNotEmpty || job.applyMethod.isNotEmpty) ...[
                const JobDetailSectionTitle('근무 조건'),
                if (job.workDays.isNotEmpty)
                  JobDetailInfoRow(
                    icon: Icons.calendar_month_outlined,
                    label: '근무 요일',
                    value: job.workDaysSummary +
                        (job.weekendWork ? ' (주말근무)' : '') +
                        (job.nightShift ? ' · 야간진료' : ''),
                  ),
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
                if (job.applyMethod.isNotEmpty)
                  JobDetailInfoRow(
                    icon: Icons.send_outlined,
                    label: '지원 방법',
                    value: job.applyMethod
                        .map((m) => Job.applyMethodLabels[m] ?? m)
                        .join(', '),
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

// ── 채용공고 이미지 갤러리 (PageView + 인디케이터) ──────────────
class _JobImageGallery extends StatefulWidget {
  final List<String> images;

  const _JobImageGallery({required this.images});

  @override
  State<_JobImageGallery> createState() => _JobImageGalleryState();
}

class _JobImageGalleryState extends State<_JobImageGallery> {
  late final PageController _ctrl;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.images.length;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: SizedBox(
            height: 220,
            child: PageView.builder(
              controller: _ctrl,
              itemCount: count,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (_, i) => SizedBox.expand(
                child: JobCoverImage(
                  source: widget.images[i],
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
        if (count > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(count, (i) {
              final active = i == _current;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? AppColors.accent : AppColors.divider,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _DetailBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _DetailBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
