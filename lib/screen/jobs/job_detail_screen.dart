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

/// 공고 상세 화면 — 웹 [JobPostPreview]와 동일 섹션·순서·2열 그리드 구조
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
  static const double _sectionDivH = 36;

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
        if (mounted && _job != null) _openApplyConfirm(context, _job!);
      });
    }
  }

  void _openApplyConfirm(BuildContext context, Job job) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ApplyConfirmScreen(job: job)),
    );
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  bool _hasText(String? s) => (s?.trim().isNotEmpty ?? false);

  String _hireRolesLine(Job job) {
    if (job.hireRoles.isNotEmpty) return job.hireRoles.join(', ');
    if (job.type.isNotEmpty) return job.type;
    return '';
  }

  String? _workDaysLabel(Job job) {
    if (job.workDays.isEmpty) return null;
    return job.workDays.map((d) => Job.workDayLabels[d] ?? d).join(', ');
  }

  String _transportValue(Job job) {
    final t = job.transportation;
    if (t == null) return '';
    final station = t.subwayStationName?.trim() ?? '';
    if (station.isEmpty) return '';
    final parts = <String>[station];
    if (t.exitNumber != null && t.exitNumber!.trim().isNotEmpty) {
      parts.add('${t.exitNumber!.trim()}');
    }
    if (t.walkingMinutes != null) parts.add('도보 ${t.walkingMinutes}분');
    if (t.walkingDistanceMeters != null) parts.add('(${t.walkingDistanceMeters}m)');
    return parts.join(' · ');
  }

  String _dateFmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 2열 그리드 — 홀수 개 행은 마지막을 전체 폭으로
  Widget _infoGrid(List<Widget> rows) {
    final out = <Widget>[];
    for (var i = 0; i < rows.length; i += 2) {
      if (i + 1 < rows.length) {
        out.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: rows[i]),
            const SizedBox(width: 10),
            Expanded(child: rows[i + 1]),
          ],
        ));
      } else {
        out.add(rows[i]);
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: out);
  }

  Divider get _divider => Divider(height: _sectionDivH, color: AppColors.divider);

  // ── sections ─────────────────────────────────────────────────────────────

  List<Widget> _sectionBasicInfo(Job job) {
    final hireLine = _hireRolesLine(job);
    final dutyLine = job.mainDutiesList.isNotEmpty
        ? job.mainDutiesList.join(', ')
        : '';
    final rows = <Widget>[
      if (_hasText(job.clinicName))
        JobDetailInfoRow(
          icon: Icons.storefront_outlined,
          label: '치과명',
          value: job.clinicName.trim(),
        ),
      if (_hasText(job.career) && job.career != '미정')
        JobDetailInfoRow(
          icon: Icons.work_history_outlined,
          label: '경력',
          value: job.career.trim(),
        ),
      if (_hasText(hireLine))
        JobDetailInfoRow(
          icon: Icons.badge_outlined,
          label: '채용직',
          value: hireLine.trim(),
        ),
      if (_hasText(dutyLine))
        JobDetailInfoRow(
          icon: Icons.task_alt_outlined,
          label: '담당 업무',
          value: dutyLine.trim(),
        ),
      if (_hasText(job.education))
        JobDetailInfoRow(
          icon: Icons.school_outlined,
          label: '학력',
          value: job.education.trim(),
        ),
      if (_hasText(job.employmentType))
        JobDetailInfoRow(
          icon: Icons.work_outline,
          label: '고용 형태',
          value: job.employmentType.trim(),
        ),
      if (_hasText(job.salaryDisplayLine))
        JobDetailInfoRow(
          icon: Icons.payments_outlined,
          label: '급여',
          value: job.salaryDisplayLine,
        ),
    ];
    if (rows.isEmpty) return [];
    return [
      const JobDetailSectionTitle('기본 정보'),
      _infoGrid(rows),
      _divider,
    ];
  }

  List<Widget> _sectionWorkConditions(Job job) {
    final wd = _workDaysLabel(job);
    final rows = <Widget>[
      if (_hasText(job.workHours))
        JobDetailInfoRow(
          icon: Icons.schedule_outlined,
          label: '근무 시간',
          value: job.workHours.trim(),
        ),
      if (_hasText(wd))
        JobDetailInfoRow(
          icon: Icons.calendar_month_outlined,
          label: '근무 요일',
          value: wd!.trim(),
        ),
      if (job.weekendWork)
        const JobDetailInfoRow(
          icon: Icons.weekend_outlined,
          label: '주말 근무',
          value: '있음',
        ),
      if (job.nightShift)
        const JobDetailInfoRow(
          icon: Icons.nights_stay_outlined,
          label: '야간 진료',
          value: '있음',
        ),
    ];
    if (rows.isEmpty) return [];
    return [
      const JobDetailSectionTitle('근무 조건'),
      _infoGrid(rows),
      _divider,
    ];
  }

  List<Widget> _sectionPromotionalImages(Job job) {
    if (job.promotionalImageUrls.isEmpty) return [];
    return [
      ...job.promotionalImageUrls.map(
        (url) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Image.network(
              url,
              width: double.infinity,
              fit: BoxFit.fitWidth,
              errorBuilder: (_, __, ___) => Container(
                width: double.infinity,
                height: 120,
                color: AppColors.surfaceMuted,
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.textDisabled,
                ),
              ),
            ),
          ),
        ),
      ),
      _divider,
    ];
  }

  List<Widget> _sectionHospital(Job job) {
    final rows = <Widget>[
      if (job.hospitalType != null && job.hospitalType!.isNotEmpty)
        JobDetailInfoRow(
          icon: Icons.business_outlined,
          label: '병원 유형',
          value: Job.hospitalTypeLabels[job.hospitalType] ?? job.hospitalType!,
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
      if (job.specialties.isNotEmpty)
        JobDetailInfoRow(
          icon: Icons.medical_services_outlined,
          label: '주요 진료 과목',
          value: job.specialties.join(', '),
        ),
      if (job.hasOralScanner != null)
        JobDetailInfoRow(
          icon: Icons.precision_manufacturing_outlined,
          label: '구강 스캐너',
          value: job.hasOralScanner! ? '보유' : '없음',
        ),
      if (job.hasCT != null)
        JobDetailInfoRow(
          icon: Icons.view_in_ar_outlined,
          label: 'CT',
          value: job.hasCT! ? '보유' : '없음',
        ),
      if (job.has3DPrinter != null)
        JobDetailInfoRow(
          icon: Icons.threed_rotation_outlined,
          label: '3D 프린터',
          value: job.has3DPrinter! ? '보유' : '없음',
        ),
      if (_hasText(job.digitalEquipmentRaw))
        JobDetailInfoRow(
          icon: Icons.more_horiz,
          label: '기타 장비',
          value: job.digitalEquipmentRaw!.trim(),
        ),
    ];
    if (rows.isEmpty) return [];
    return [
      const JobDetailSectionTitle('병원 정보'),
      _infoGrid(rows),
      _divider,
    ];
  }

  List<Widget> _sectionBenefits(Job job) {
    if (job.benefits.isEmpty) return [];
    return [
      const JobDetailSectionTitle('복리후생'),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: job.benefits.map((b) => JobBenefitChip(label: b)).toList(),
      ),
      _divider,
    ];
  }

  List<Widget> _sectionApply(Job job) {
    final rows = <Widget>[
      if (job.applyMethod.isNotEmpty)
        JobDetailInfoRow(
          icon: Icons.send_outlined,
          label: '지원 방법',
          value: job.applyMethod
              .map((m) => Job.applyMethodLabels[m] ?? m)
              .join(', '),
        ),
      if (job.requiredDocuments.isNotEmpty)
        JobDetailInfoRow(
          icon: Icons.description_outlined,
          label: '제출 서류',
          value: job.requiredDocuments.join(', '),
        ),
      JobDetailInfoRow(
        icon: Icons.all_inclusive,
        label: '상시채용',
        value: job.isAlwaysHiring ? '예' : '아니오',
      ),
      if (job.closingDate != null)
        JobDetailInfoRow(
          icon: Icons.event_busy_outlined,
          label: '마감일',
          value: _dateFmt(job.closingDate!),
        ),
    ];
    return [
      const JobDetailSectionTitle('지원 방법 · 마감'),
      _infoGrid(rows),
      _divider,
    ];
  }

  List<Widget> _sectionDescription(Job job) {
    return [
      const JobDetailSectionTitle('상세 내용'),
      Text(
        job.details.isNotEmpty ? job.details : '등록된 상세 설명이 없어요.',
        style: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: AppColors.textSecondary,
        ),
      ),
      _divider,
    ];
  }

  List<Widget> _sectionAddress(Job job) {
    final tv = _transportValue(job);
    final rows = <Widget>[
      if (_hasText(job.address))
        JobDetailInfoRow(
          icon: Icons.location_on_outlined,
          label: '주소',
          value: job.address.trim(),
        ),
      if (_hasText(job.contact))
        JobDetailInfoRow(
          icon: Icons.phone_outlined,
          label: '연락처',
          value: job.contact.trim(),
        ),
      if (_hasText(tv))
        JobDetailInfoRow(
          icon: Icons.subway_outlined,
          label: '교통',
          value: tv.trim(),
        ),
      if (job.hasParking)
        const JobDetailInfoRow(
          icon: Icons.local_parking_outlined,
          label: '주차',
          value: '가능',
        ),
    ];
    final hasLatLng = job.lat != 0 || job.lng != 0;
    if (rows.isEmpty && !hasLatLng) return [];
    return [
      const JobDetailSectionTitle('주소 · 연락처 · 교통'),
      if (hasLatLng) ...[
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: SizedBox(
            height: 160,
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
        const SizedBox(height: AppSpacing.md),
      ],
      if (rows.isNotEmpty) Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
      if (job.subwayLines.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(left: 26, top: AppSpacing.xs, bottom: AppSpacing.sm),
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: job.subwayLines
                .map((l) => Text(
                      l,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ))
                .toList(),
          ),
        ),
    ];
  }

  // ── build ─────────────────────────────────────────────────────────────────

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
            title: Text(job.displayClinicName),
            actions: [
              IconButton(
                icon: Icon(
                  bookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: bookmarked ? AppColors.accent : null,
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
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              88,
            ),
            children: [
              // 공고 제목
              Text(
                job.displayTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.35,
                  height: 1.25,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 이미지 갤러리
              if (job.images.isNotEmpty) ...[
                _JobImageGallery(images: job.images),
                const SizedBox(height: AppSpacing.lg),
              ],

              // ── 기본 정보 ──
              ..._sectionBasicInfo(job),
              // ── 근무 조건 ──
              ..._sectionWorkConditions(job),
              // ── 홍보 이미지 ──
              ..._sectionPromotionalImages(job),
              // ── 병원 정보 ──
              ..._sectionHospital(job),
              // ── 복리후생 ──
              ..._sectionBenefits(job),
              // ── 지원 방법·마감 ──
              ..._sectionApply(job),
              // ── 상세 내용 ──
              ..._sectionDescription(job),
              // ── 주소·연락처·교통 ──
              ..._sectionAddress(job),

              const SizedBox(height: AppSpacing.xl),
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

// ── 이미지 갤러리 ──────────────────────────────────────────────────────────
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
            child: count == 1
                ? JobCoverImage(source: widget.images[0], fit: BoxFit.cover)
                : PageView.builder(
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
