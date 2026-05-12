import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../models/job.dart';
import '../../../../services/admin_activity_service.dart';
import '../../../../services/job_service.dart';
import '../../../../services/job_stats_service.dart';
import '../widgets/applicant_web_shell.dart';

/// 웹 일반계정용 공고 상세 페이지.
///
/// 레이아웃:
///  - 넓은 폭(≥880px): 좌측에 본문(이미지·메타·상세·조건·위치),
///    우측에 지원 카드(지원하기 / 찜 / 메타 요약)를 함께 노출.
///  - 좁은 폭: 본문 → 지원 카드 순서로 스택 정렬.
///
/// (실제 sticky 고정 동작은 Phase 2 에서 [SliverPersistentHeader] 등으로 도입 예정)
///
/// 라우터 가드(`/jobs/`)에서 비로그인은 이미 `/login`으로 보내지므로
/// 이 페이지는 항상 로그인된 상태에서만 진입한다.
class ApplicantJobDetailPage extends StatefulWidget {
  const ApplicantJobDetailPage({super.key, required this.jobId});

  final String jobId;

  @override
  State<ApplicantJobDetailPage> createState() => _ApplicantJobDetailPageState();
}

class _ApplicantJobDetailPageState extends State<ApplicantJobDetailPage> {
  Job? _job;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = context.read<JobService>();
    try {
      final job = await svc.fetchJob(widget.jobId);
      if (!mounted) return;
      setState(() {
        _job = job;
        _loading = false;
      });
      try {
        JobStatsService.recordView(widget.jobId);
        AdminActivityService.log(
          ActivityEventType.viewJobDetail,
          page: 'applicant_job_detail',
          targetId: widget.jobId,
        );
      } catch (_) {}
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _job = svc.jobOfflineFallback(widget.jobId);
        _loading = false;
      });
    }
  }

  void _onApply() {
    if (_job == null) return;
    context.push('/jobs/${_job!.id}/apply');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ApplicantWebShell(
        body: Padding(
          padding: EdgeInsets.symmetric(vertical: 80),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final job = _job!;

    return ApplicantWebShell(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 880;
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BackButton(),
                const SizedBox(height: 12),
                _JobMainContent(job: job),
                const SizedBox(height: 20),
                _ApplyCard(job: job, onApply: _onApply),
                const SizedBox(height: 60),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BackButton(),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: _JobMainContent(job: job)),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: 320,
                    child: _ApplyCard(job: job, onApply: _onApply),
                  ),
                ],
              ),
              const SizedBox(height: 60),
            ],
          );
        },
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () {
          if (Navigator.of(context).canPop()) {
            context.pop();
          } else {
            context.go('/');
          }
        },
        icon: const Icon(Icons.arrow_back_rounded, size: 18),
        label: Text(
          '공고 목록으로',
          style: GoogleFonts.notoSansKr(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
      ),
    );
  }
}

class _JobMainContent extends StatelessWidget {
  const _JobMainContent({required this.job});
  final Job job;

  @override
  Widget build(BuildContext context) {
    final image = job.images.isNotEmpty
        ? job.images.first
        : (job.promotionalImageUrls.isNotEmpty
            ? job.promotionalImageUrls.first
            : null);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppApplicant.cardRadius),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (image != null)
            AspectRatio(
              aspectRatio: 21 / 9,
              child: Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.surfaceMuted,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.business_rounded,
                    size: 56,
                    color: AppColors.textDisabled,
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Tier(job.jobLevel),
                const SizedBox(height: 8),
                Text(
                  job.displayClinicName,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  job.displayTitle,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    height: 1.3,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 18),
                _MetaRow(job: job),
                const SizedBox(height: 24),
                const _SectionTitle('상세 내용'),
                Text(
                  job.details.trim().isEmpty
                      ? '상세 설명이 등록되지 않았어요.'
                      : job.details.trim(),
                  style: GoogleFonts.notoSansKr(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                    height: 1.7,
                  ),
                ),
                if (job.benefits.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const _SectionTitle('복리·복지'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final b in job.benefits) _Chip(label: b),
                    ],
                  ),
                ],
                if (job.mainDutiesList.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const _SectionTitle('담당 업무'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final d in job.mainDutiesList)
                        _Chip(label: d),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                const _SectionTitle('근무 정보'),
                _InfoGrid(rows: _buildInfoRows(job)),
                if (job.address.trim().isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const _SectionTitle('위치'),
                  Text(
                    job.address,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_InfoRow> _buildInfoRows(Job job) {
    final rows = <_InfoRow>[];
    if (job.career.isNotEmpty && job.career != '미정') {
      rows.add(_InfoRow('경력', job.career));
    }
    if (job.employmentType.isNotEmpty) {
      rows.add(_InfoRow('고용 형태', job.employmentType));
    }
    if (job.workHours.isNotEmpty) {
      rows.add(_InfoRow('근무 시간', job.workHours));
    }
    if (job.workDays.isNotEmpty) {
      rows.add(_InfoRow(
        '근무 요일',
        job.workDays
            .map((d) => Job.workDayLabels[d] ?? d)
            .join(', '),
      ));
    }
    if (job.education.isNotEmpty) {
      rows.add(_InfoRow('학력', job.education));
    }
    if (job.applyMethod.isNotEmpty) {
      rows.add(_InfoRow(
        '지원 방법',
        job.applyMethod
            .map(_applyMethodLabel)
            .join(', '),
      ));
    }
    if (job.closingDate != null) {
      rows.add(_InfoRow(
        '마감일',
        DateFormat('yyyy년 M월 d일').format(job.closingDate!),
      ));
    }
    return rows;
  }

  String _applyMethodLabel(String code) {
    switch (code) {
      case 'online':
        return '온라인 지원';
      case 'phone':
        return '전화 지원';
      case 'email':
        return '이메일 지원';
      default:
        return code;
    }
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.job});
  final Job job;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _meta(Icons.payments_outlined, job.salaryDisplayLine,
            color: AppColors.accent),
        if (job.address.trim().isNotEmpty)
          _meta(Icons.location_on_outlined, _shortAddress(job)),
        if (job.career.isNotEmpty && job.career != '미정')
          _meta(Icons.work_history_outlined, job.career),
        if (job.employmentType.isNotEmpty)
          _meta(Icons.badge_outlined, job.employmentType),
      ],
    );
  }

  Widget _meta(IconData icon, String text, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color ?? AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.notoSansKr(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  String _shortAddress(Job job) {
    final d = job.district.trim();
    if (d.isNotEmpty) return d;
    final parts = job.address.trim().split(' ');
    return parts.take(3).join(' ');
  }
}

class _Tier extends StatelessWidget {
  const _Tier(this.level);
  final int level;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (level) {
      1 => (
        'PREMIUM',
        AppColors.cardEmphasis,
        AppColors.onCardEmphasis,
      ),
      2 => (
        '추천',
        AppColors.accent.withValues(alpha: 0.1),
        AppColors.accent,
      ),
      _ => ('일반', AppColors.surfaceMuted, AppColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label,
        style: GoogleFonts.notoSansKr(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.notoSansKr(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          color: AppColors.textPrimary,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: GoogleFonts.notoSansKr(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _InfoRow {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.rows});
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      runSpacing: 14,
      spacing: 0,
      children: [
        for (final r in rows)
          SizedBox(
            width: MediaQuery.of(context).size.width >= 720
                ? 320
                : double.infinity,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 88,
                  child: Text(
                    r.label,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDisabled,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    r.value,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ApplyCard extends StatelessWidget {
  const _ApplyCard({required this.job, required this.onApply});
  final Job job;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppApplicant.cardRadius),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '지원하기',
            style: GoogleFonts.notoSansKr(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '내 이력서로 1분 안에 지원할 수 있어요.',
            style: GoogleFonts.notoSansKr(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: Text(
                '이 공고에 지원하기',
                style: GoogleFonts.notoSansKr(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('찜 기능은 곧 제공될 예정이에요.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.bookmark_border_rounded, size: 18),
            label: Text(
              '찜하기',
              style: GoogleFonts.notoSansKr(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.divider),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '급여',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDisabled,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  job.salaryDisplayLine,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '게시일',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDisabled,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('yyyy년 M월 d일').format(job.postedAt),
                  style: GoogleFonts.notoSansKr(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
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
