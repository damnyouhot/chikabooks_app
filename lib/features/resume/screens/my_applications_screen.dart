import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/application.dart';
import '../../../models/job.dart';
import '../../../services/application_service.dart';
import '../../../services/job_service.dart';
import '../../../screen/jobs/job_detail_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// 내 지원 내역 화면
///
/// 지원한 공고 목록을 표시하며, 각 지원 건의 상태를 확인하고
/// 필요 시 지원을 철회할 수 있다.
class MyApplicationsScreen extends StatefulWidget {
  const MyApplicationsScreen({super.key});

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen> {
  // 필터
  ApplicationStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          '내 지원 내역',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Column(
        children: [
          // ── 필터 칩 ──
          _buildFilterChips(),
          // ── 목록 ──
          Expanded(
            child: StreamBuilder<List<Application>>(
              stream: ApplicationService.watchMyApplications(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final all = snap.data ?? [];
                final filtered = _statusFilter == null
                    ? all
                    : all.where((a) => a.status == _statusFilter).toList();

                if (all.isEmpty) return _buildEmpty();
                if (filtered.isEmpty) return _buildNoResults();

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) =>
                      _ApplicationCard(application: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = <({String label, ApplicationStatus? value})>[
      (label: '전체', value: null),
      (label: '지원 완료', value: ApplicationStatus.submitted),
      (label: '열람됨', value: ApplicationStatus.reviewed),
      (label: '연락처 요청', value: ApplicationStatus.contactRequested),
      (label: '연락처 공개', value: ApplicationStatus.contactShared),
      (label: '철회', value: ApplicationStatus.withdrawn),
    ];

    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 4, AppSpacing.md, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final selected = _statusFilter == f.value;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(
                  f.label,
                    style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.white : AppColors.textSecondary,
                  ),
                ),
                selected: selected,
                onSelected: (_) {
                  setState(() => _statusFilter = f.value);
                },
                selectedColor: AppColors.accent,
                backgroundColor: AppColors.white,
                side: BorderSide(
                  color: selected
                      ? AppColors.accent
                      : AppColors.divider,
                ),
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.work_off_outlined,
              size: 56, color: AppColors.textDisabled),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            '아직 지원한 공고가 없어요.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '채용 탭에서 마음에 드는 공고를 찾아보세요!',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.filter_list_off,
              size: 40, color: AppColors.textDisabled),
          const SizedBox(height: AppSpacing.md),
          const Text(
            '해당 상태의 지원 내역이 없습니다.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 지원 카드
// ═══════════════════════════════════════════════════════════

class _ApplicationCard extends StatefulWidget {
  final Application application;
  const _ApplicationCard({required this.application});

  @override
  State<_ApplicationCard> createState() => _ApplicationCardState();
}

class _ApplicationCardState extends State<_ApplicationCard> {
  Job? _job;
  bool _loadingJob = true;
  bool _withdrawing = false;

  Application get app => widget.application;

  @override
  void initState() {
    super.initState();
    _loadJob();
  }

  Future<void> _loadJob() async {
    try {
      final jobService = context.read<JobService>();
      final job = await jobService.fetchJob(app.jobId);
      if (mounted) {
        setState(() {
          _job = job;
          _loadingJob = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingJob = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 공고 상세로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => JobDetailScreen(jobId: app.jobId),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 상단: 상태 뱃지 + 시간 ──
            Row(
              children: [
                _StatusBadge(status: app.status),
                const Spacer(),
                if (app.submittedAt != null)
                  Text(
                    _formatDate(app.submittedAt!),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textDisabled,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // ── 공고 정보 ──
            if (_loadingJob)
              _buildJobShimmer()
            else if (_job != null) ...[
              Text(
                _job!.clinicName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _job!.title,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 13, color: AppColors.textDisabled),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      _job!.district.isNotEmpty
                          ? _job!.district
                          : _job!.address,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textDisabled,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_job!.type} · ${_job!.career}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textDisabled,
                    ),
                  ),
                ],
              ),
            ] else
              Text(
                '공고 정보를 불러올 수 없습니다.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),

            // ── 연락처 공개 상태 ──
            if (app.visibilityGranted.contactShared) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.success.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle,
                        size: 14, color: AppColors.success),
                    const SizedBox(width: 6),
                    const Text(
                      '연락처 공개 완료',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                    if (app.visibilityGranted.sharedAt != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(app.visibilityGranted.sharedAt!),
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.success.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // ── 하단 액션 ──
            if (_canWithdraw) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _withdrawing ? null : _handleWithdraw,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error.withOpacity(0.7),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: _withdrawing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            '지원 철회',
                            style: TextStyle(fontSize: 12),
                          ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool get _canWithdraw =>
      app.status == ApplicationStatus.submitted ||
      app.status == ApplicationStatus.reviewed;

  Future<void> _handleWithdraw() async {
    // 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '지원 철회',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          '정말 이 공고에 대한 지원을 철회하시겠어요?\n철회 후에는 다시 지원할 수 있어요.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('철회하기'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _withdrawing = true);
    final success =
        await ApplicationService.withdrawApplication(app.id);
    if (mounted) {
      setState(() => _withdrawing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? '지원이 철회되었습니다.' : '철회 중 오류가 발생했습니다.',
          ),
        ),
      );
    }
  }

  Widget _buildJobShimmer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 120,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 200,
          height: 12,
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return DateFormat('M월 d일').format(dt);
  }
}

// ═══════════════════════════════════════════════════════════
// 상태 뱃지
// ═══════════════════════════════════════════════════════════

class _StatusBadge extends StatelessWidget {
  final ApplicationStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = _statusInfo;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  (String, Color, IconData) get _statusInfo {
    switch (status) {
      case ApplicationStatus.submitted:
        return ('지원 완료', AppColors.accent, Icons.check_circle_outline);
      case ApplicationStatus.reviewed:
        return ('열람됨', AppColors.warning, Icons.visibility_outlined);
      case ApplicationStatus.contactRequested:
        return ('연락처 요청', AppColors.warning, Icons.mail_outline);
      case ApplicationStatus.contactShared:
        return ('연락처 공개', AppColors.success, Icons.lock_open_outlined);
      case ApplicationStatus.rejected:
        return ('불합격', AppColors.error, Icons.block_outlined);
      case ApplicationStatus.withdrawn:
        return ('철회', AppColors.textDisabled, Icons.undo_outlined);
    }
  }
}

