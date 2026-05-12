import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_confirm_modal.dart';
import '../../../../models/application.dart';
import '../../../../models/job.dart';
import '../../../../services/application_service.dart';
import '../services/job_lookup_cache.dart';
import '../widgets/applicant_web_shell.dart';

/// `/me/applications` — 내 지원 내역 페이지.
///
/// 상태별 필터 칩 + 카드 리스트. 각 카드는 공고 정보를 lazy load 하여
/// 제목·치과명·지역을 보여준다.
class ApplicantApplicationsPage extends StatefulWidget {
  const ApplicantApplicationsPage({super.key});

  @override
  State<ApplicantApplicationsPage> createState() =>
      _ApplicantApplicationsPageState();
}

class _ApplicantApplicationsPageState
    extends State<ApplicantApplicationsPage> {
  ApplicationStatus? _filter;
  final JobLookupCache _jobCache = JobLookupCache();

  @override
  void dispose() {
    _jobCache.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ApplicantWebShell(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(),
          const SizedBox(height: 20),
          StreamBuilder<List<Application>>(
            stream: ApplicationService.watchMyApplications(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final all = snap.data ?? const <Application>[];
              final filtered = _filter == null
                  ? all
                  : all.where((a) => a.status == _filter).toList();

              // 표시 대상에 새로 들어온 jobId 만 미리 한번에 fetch.
              _jobCache.preload(filtered.map((a) => a.jobId));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FilterChips(
                    counts: _countByStatus(all),
                    total: all.length,
                    selected: _filter,
                    onChange: (s) => setState(() => _filter = s),
                  ),
                  const SizedBox(height: 16),
                  if (filtered.isEmpty)
                    _EmptyState(filter: _filter)
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius:
                            BorderRadius.circular(AppApplicant.cardRadius),
                        border: Border.all(color: AppColors.divider),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (int i = 0; i < filtered.length; i++) ...[
                            _ApplicationCard(
                              app: filtered[i],
                              cache: _jobCache,
                            ),
                            if (i < filtered.length - 1)
                              const Divider(
                                height: 1,
                                color: AppColors.divider,
                              ),
                          ],
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Map<ApplicationStatus, int> _countByStatus(List<Application> apps) {
    final out = <ApplicationStatus, int>{};
    for (final a in apps) {
      out[a.status] = (out[a.status] ?? 0) + 1;
    }
    return out;
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '내 지원 내역',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '제출한 지원의 상태를 한 곳에서 확인하세요.',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.counts,
    required this.total,
    required this.selected,
    required this.onChange,
  });

  final Map<ApplicationStatus, int> counts;
  final int total;
  final ApplicationStatus? selected;
  final ValueChanged<ApplicationStatus?> onChange;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Chip(
          label: '전체 ($total)',
          active: selected == null,
          onTap: () => onChange(null),
        ),
        for (final s in ApplicationStatus.values)
          if ((counts[s] ?? 0) > 0)
            _Chip(
              label: '${_label(s)} (${counts[s]})',
              active: selected == s,
              onTap: () => onChange(s),
            ),
      ],
    );
  }

  String _label(ApplicationStatus s) {
    switch (s) {
      case ApplicationStatus.submitted:
        return '검토 대기';
      case ApplicationStatus.reviewed:
        return '열람됨';
      case ApplicationStatus.contactRequested:
        return '연락처 요청 받음';
      case ApplicationStatus.contactShared:
        return '연락처 공개';
      case ApplicationStatus.rejected:
        return '불합격';
      case ApplicationStatus.withdrawn:
        return '철회';
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? AppColors.accent.withValues(alpha: 0.1)
          : AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: GoogleFonts.notoSansKr(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: active ? AppColors.accent : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.app, required this.cache});
  final Application app;
  final JobLookupCache cache;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      child: InkWell(
        onTap: () => context.push('/jobs/${app.jobId}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FutureBuilder<Job?>(
                  future: cache.get(app.jobId),
                  builder: (context, snap) {
                    final job = snap.data;
                    final hasTitle =
                        job?.title.trim().isNotEmpty == true;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasTitle ? job!.displayTitle : '공고 정보 불러오는 중…',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.notoSansKr(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (job?.clinicName.trim().isNotEmpty == true)
                              job!.displayClinicName,
                            if (job != null && job.address.isNotEmpty)
                              _shortAddress(job.address),
                          ].where((s) => s.isNotEmpty).join('  ·  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.notoSansKr(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '지원일: ${app.submittedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(app.submittedAt!) : '—'}',
                          style: GoogleFonts.notoSansKr(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDisabled,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusBadge(status: app.status),
                  const SizedBox(height: 8),
                  if (app.status != ApplicationStatus.withdrawn)
                    TextButton.icon(
                      onPressed: () => _confirmWithdraw(context),
                      icon: const Icon(Icons.cancel_outlined, size: 14),
                      label: Text(
                        '지원 철회',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 24),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmWithdraw(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const AppConfirmModal(
        title: '지원을 철회할까요?',
        message: '철회 후에는 같은 공고에 다시 지원할 수 없을 수 있어요.',
        confirmLabel: '철회',
        destructive: true,
      ),
    );
    if (ok != true) return;
    final success =
        await ApplicationService.withdrawApplication(app.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '지원이 철회되었어요.' : '철회에 실패했어요. 잠시 후 다시 시도해주세요.'),
      ),
    );
  }

  static String _shortAddress(String address) {
    final parts = address.trim().split(' ');
    return parts.take(2).join(' ');
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final ApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ApplicationStatus.submitted => (
        '검토 대기',
        AppColors.textSecondary,
      ),
      ApplicationStatus.reviewed => ('열람됨', AppColors.warning),
      ApplicationStatus.contactRequested => (
        '연락처 요청',
        AppColors.success,
      ),
      ApplicationStatus.contactShared => (
        '연락처 공개',
        AppColors.success,
      ),
      ApplicationStatus.rejected => ('불합격', AppColors.error),
      ApplicationStatus.withdrawn => ('철회', AppColors.textDisabled),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label,
        style: GoogleFonts.notoSansKr(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.filter});
  final ApplicationStatus? filter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.send_outlined,
            size: 56,
            color: AppColors.textDisabled,
          ),
          const SizedBox(height: 16),
          Text(
            filter == null
                ? '아직 지원한 공고가 없어요'
                : '해당 상태의 지원이 없어요',
            style: GoogleFonts.notoSansKr(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '마음에 드는 공고에 지원해 보세요.',
            style: GoogleFonts.notoSansKr(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textDisabled,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.search_rounded, size: 16),
            label: Text(
              '공고 둘러보기',
              style: GoogleFonts.notoSansKr(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onAccent,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
