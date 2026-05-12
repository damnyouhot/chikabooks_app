import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../models/application.dart';
import '../../../../models/job.dart';
import '../../../../models/resume.dart';
import '../../../../services/application_service.dart';
import '../../../../services/resume_service.dart';
import '../services/job_lookup_cache.dart';
import '../widgets/applicant_web_shell.dart';

/// `/me` — 지원자 대시보드.
///
/// 좌상단 인사 + 카드 4종 위젯:
///  1) 내 지원 현황 (active/총 합)
///  2) 이력서 완성도 (대표 이력서 기준 채워진 섹션 수)
///  3) 빠른 액션 (새 이력서 / 공고 보러가기 / 지원 내역)
///  4) 최근 지원 3건 미리보기
class ApplicantDashboardPage extends StatelessWidget {
  const ApplicantDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final greetName = (user?.displayName?.trim().isNotEmpty == true)
        ? user!.displayName!.trim()
        : (user?.email?.split('@').first ?? '치과위생사');

    return ApplicantWebShell(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Greeting(name: greetName),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoCol = constraints.maxWidth >= 720;
              return twoCol
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _ApplicationsCard()),
                        const SizedBox(width: 16),
                        Expanded(child: _ResumeCard()),
                      ],
                    )
                  : Column(
                      children: [
                        _ApplicationsCard(),
                        const SizedBox(height: 16),
                        _ResumeCard(),
                      ],
                    );
            },
          ),
          const SizedBox(height: 16),
          _QuickActions(),
          const SizedBox(height: 24),
          _RecentApplicationsPreview(),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '안녕하세요, $name 님 👋',
            style: GoogleFonts.notoSansKr(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '오늘도 좋은 공고 함께 찾아볼까요?',
            style: GoogleFonts.notoSansKr(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
    this.onTap,
    this.cta,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  final VoidCallback? onTap;
  final String? cta;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppApplicant.cardRadius),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (cta != null && onTap != null)
                Text(
                  cta!,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              if (cta != null && onTap != null) const SizedBox(width: 4),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textDisabled,
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppApplicant.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppApplicant.cardRadius),
        child: card,
      ),
    );
  }
}

class _ApplicationsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      title: '내 지원 현황',
      icon: Icons.send_outlined,
      iconColor: AppColors.accent,
      cta: '전체 보기',
      onTap: () => context.push('/me/applications'),
      child: StreamBuilder<List<Application>>(
        stream: ApplicationService.watchMyApplications(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 56,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final apps = snap.data ?? const <Application>[];
          final active = apps
              .where((a) =>
                  a.status != ApplicationStatus.withdrawn &&
                  a.status != ApplicationStatus.rejected)
              .length;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$active',
                style: GoogleFonts.notoSansKr(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '/ 전체 ${apps.length}',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const Spacer(),
              if (apps.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '아직 지원한 공고가 없어요',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 12,
                      color: AppColors.textDisabled,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      title: '내 이력서',
      icon: Icons.description_outlined,
      iconColor: AppColors.success,
      cta: '관리',
      onTap: () => context.push('/me/resumes'),
      child: StreamBuilder<List<Resume>>(
        stream: ResumeService.watchMyResumes(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 56,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final resumes = snap.data ?? const <Resume>[];
          if (resumes.isEmpty) {
            return Row(
              children: [
                Text(
                  '아직 이력서가 없어요',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '바로 만들기 →',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                  ),
                ),
              ],
            );
          }
          final primary = resumes.first;
          final filled = _countFilled(primary);
          final pct = (filled / 8 * 100).round();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                primary.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSansKr(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: LinearProgressIndicator(
                  value: filled / 8,
                  minHeight: 6,
                  backgroundColor: AppColors.divider,
                  valueColor:
                      AlwaysStoppedAnimation(AppColors.success),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '완성도 $pct% · $filled/8 섹션 작성',
                style: GoogleFonts.notoSansKr(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  int _countFilled(Resume resume) {
    int count = 0;
    if (resume.profile != null && resume.profile!.name.isNotEmpty) count++;
    if (resume.licenses.isNotEmpty) count++;
    if (resume.experiences.isNotEmpty) count++;
    if (resume.skills.isNotEmpty) count++;
    if (resume.education.isNotEmpty) count++;
    if (resume.trainings.isNotEmpty) count++;
    if (resume.attachments.isNotEmpty) count++;
    if (resume.profile?.summary.isNotEmpty == true) count++;
    return count;
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        Icons.search_rounded,
        '공고 둘러보기',
        '내게 맞는 공고 찾아보기',
        AppColors.accent,
        () => context.go('/'),
      ),
      (
        Icons.edit_note_rounded,
        '이력서 작성',
        '대표 이력서 만들기 / 수정',
        AppColors.success,
        () => context.push('/me/resumes'),
      ),
      (
        Icons.send_rounded,
        '내 지원 내역',
        '진행 중인 지원 확인',
        AppColors.warning,
        () => context.push('/me/applications'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 720 ? 3 : 1;
        final gap = 12.0;
        final w = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final a in actions)
              SizedBox(
                width: w,
                child: _ActionTile(
                  icon: a.$1,
                  title: a.$2,
                  subtitle: a.$3,
                  color: a.$4,
                  onTap: a.$5,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppApplicant.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppApplicant.cardRadius),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(AppApplicant.cardRadius),
            border: Border.all(color: AppColors.divider),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textDisabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentApplicationsPreview extends StatefulWidget {
  @override
  State<_RecentApplicationsPreview> createState() =>
      _RecentApplicationsPreviewState();
}

class _RecentApplicationsPreviewState
    extends State<_RecentApplicationsPreview> {
  final JobLookupCache _cache = JobLookupCache();

  @override
  void dispose() {
    _cache.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      title: '최근 지원',
      icon: Icons.history_rounded,
      iconColor: AppColors.warning,
      cta: '전체',
      onTap: () => context.push('/me/applications'),
      child: StreamBuilder<List<Application>>(
        stream: ApplicationService.watchMyApplications(),
        builder: (context, snap) {
          final apps = snap.data ?? const <Application>[];
          if (apps.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '아직 지원한 공고가 없어요. 마음에 드는 공고에 지원해 보세요.',
                style: GoogleFonts.notoSansKr(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            );
          }
          final preview = apps.take(3).toList();
          // 미리 한 번에 fetch (whereIn 배치) → 카드 3개가 동시에 표시.
          _cache.preload(preview.map((a) => a.jobId));
          return Column(
            children: [
              for (int i = 0; i < preview.length; i++) ...[
                _ApplicationRow(app: preview[i], cache: _cache),
                if (i < preview.length - 1)
                  const Divider(height: 14, color: AppColors.divider),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ApplicationRow extends StatelessWidget {
  const _ApplicationRow({required this.app, required this.cache});
  final Application app;
  final JobLookupCache cache;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/jobs/${app.jobId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.work_outline_rounded,
                size: 16,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FutureBuilder<Job?>(
                future: cache.get(app.jobId),
                builder: (context, jobSnap) {
                  final job = jobSnap.data;
                  final title = job?.title.trim().isNotEmpty == true
                      ? job!.displayTitle
                      : '공고 정보 불러오는 중…';
                  final clinic = job?.clinicName.trim().isNotEmpty == true
                      ? job!.displayClinicName
                      : null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansKr(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (clinic != null) clinic,
                          _statusLabel(app.status),
                        ].join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansKr(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _statusColor(app.status),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textDisabled,
            ),
          ],
        ),
      ),
    );
  }

  static String _statusLabel(ApplicationStatus s) {
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
        return '지원 철회';
    }
  }

  static Color _statusColor(ApplicationStatus s) {
    switch (s) {
      case ApplicationStatus.submitted:
      case ApplicationStatus.reviewed:
        return AppColors.textSecondary;
      case ApplicationStatus.contactRequested:
      case ApplicationStatus.contactShared:
        return AppColors.success;
      case ApplicationStatus.rejected:
        return AppColors.error;
      case ApplicationStatus.withdrawn:
        return AppColors.textDisabled;
    }
  }
}
