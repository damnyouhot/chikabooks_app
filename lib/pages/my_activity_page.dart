import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/job_service.dart';
import '../../models/job.dart';
import '../screen/jobs/job_detail_screen.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/app_muted_card.dart';
import '../core/widgets/app_badge.dart';

/// 내 활동 페이지
///
/// 지원 내역 + 북마크한 공고 관리
class MyActivityPage extends StatefulWidget {
  const MyActivityPage({super.key});

  @override
  State<MyActivityPage> createState() => _MyActivityPageState();
}

class _MyActivityPageState extends State<MyActivityPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          '내 활동',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textSecondary, // 이전 _kText.withOpacity(0.5)
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          tabs: const [Tab(text: '지원 내역'), Tab(text: '관심 공고')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_ApplicationsTab(), _BookmarksTab()],
      ),
    );
  }
}

/// 지원 내역 탭
class _ApplicationsTab extends StatelessWidget {
  const _ApplicationsTab();

  @override
  Widget build(BuildContext context) {
    final jobService = context.read<JobService>();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: jobService.getMyApplications(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              '오류 발생: ${snapshot.error}',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary, // 이전 _kText.withOpacity(0.6)
              ),
            ),
          );
        }

        final applications = snapshot.data ?? [];

        if (applications.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 64,
                  color: AppColors.textDisabled, // 이전 _kText.withOpacity(0.3)
                ),
                SizedBox(height: 16),
                Text(
                  '아직 지원한 공고가 없습니다',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary, // 이전 _kText.withOpacity(0.5)
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: applications.length,
          itemBuilder: (context, index) {
            final application = applications[index];
            return _ApplicationCard(application: application);
          },
        );
      },
    );
  }
}

/// 지원 카드
class _ApplicationCard extends StatelessWidget {
  final Map<String, dynamic> application;

  const _ApplicationCard({required this.application});

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return '검토 중';
      case 'viewed':
        return '열람됨';
      case 'accepted':
        return '합격';
      case 'rejected':
        return '불합격';
      default:
        return '알 수 없음';
    }
  }

  // 상태에 따른 시스템 토큰 색상 반환
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;  // 이전 Colors.orange
      case 'viewed':
        return AppColors.accent;   // 이전 Colors.blue
      case 'accepted':
        return AppColors.success;  // 이전 Colors.green
      case 'rejected':
        return AppColors.error;    // 이전 Colors.red
      default:
        return AppColors.textDisabled; // 이전 Colors.grey
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobId = application['jobId'] as String;
    final status = application['status'] as String? ?? 'pending';
    final appliedAt = application['appliedAt'];

    return FutureBuilder<Job?>(
      future: context.read<JobService>().fetchJob(jobId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final job = snapshot.data!;
        final statusColor = _getStatusColor(status);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppMutedCard(
            radius: AppRadius.md,
            padding: const EdgeInsets.all(AppSpacing.lg),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => JobDetailScreen(jobId: jobId),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상태 배지 → AppBadge 공용 컴포넌트 적용
                AppBadge(
                  label: _getStatusText(status),
                  bgColor: statusColor.withOpacity(0.12),
                  textColor: statusColor,
                ),
                const SizedBox(height: 12),

                // 병원명
                Text(
                  job.clinicName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),

                // 공고 제목
                Text(
                  job.title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary, // 이전 _kText.withOpacity(0.7)
                  ),
                ),
                const SizedBox(height: 8),

                // 지원 정보
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 14,
                      color: AppColors.textDisabled, // 이전 _kText.withOpacity(0.5)
                    ),
                    const SizedBox(width: 4),
                    Text(
                      application['name'] ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary, // 이전 _kText.withOpacity(0.6)
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.work_outline,
                      size: 14,
                      color: AppColors.textDisabled,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      application['career'] ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // 지원 일시
                if (appliedAt != null)
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 14,
                        color: AppColors.textDisabled, // 이전 _kText.withOpacity(0.5)
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${appliedAt.toDate().year}-'
                        '${appliedAt.toDate().month.toString().padLeft(2, '0')}-'
                        '${appliedAt.toDate().day.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 관심 공고 탭
class _BookmarksTab extends StatelessWidget {
  const _BookmarksTab();

  @override
  Widget build(BuildContext context) {
    final jobService = context.read<JobService>();

    return FutureBuilder<List<Job>>(
      future: jobService.fetchBookmarkedJobs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              '오류 발생: ${snapshot.error}',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          );
        }

        final jobs = snapshot.data ?? [];

        if (jobs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.favorite_border,
                  size: 64,
                  color: AppColors.textDisabled, // 이전 _kText.withOpacity(0.3)
                ),
                SizedBox(height: 16),
                Text(
                  '관심 등록한 공고가 없습니다',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: jobs.length,
          itemBuilder: (context, index) {
            final job = jobs[index];
            return _BookmarkCard(job: job);
          },
        );
      },
    );
  }
}

/// 북마크 카드
class _BookmarkCard extends StatelessWidget {
  final Job job;

  const _BookmarkCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final jobService = context.read<JobService>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppMutedCard(
        radius: AppRadius.md,
        padding: const EdgeInsets.all(AppSpacing.lg),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: job.id)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 병원명
                      Text(
                        job.clinicName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // 공고 제목
                      Text(
                        job.title,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary, // 이전 _kText.withOpacity(0.7)
                        ),
                      ),
                    ],
                  ),
                ),

                // 북마크 해제 버튼
                IconButton(
                  onPressed: () {
                    jobService.unbookmarkJob(job.id);
                    (context as Element).markNeedsBuild();
                  },
                  icon: const Icon(Icons.favorite, color: AppColors.error), // 이전 Colors.red
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 태그 → AppBadge 공용 컴포넌트 적용
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                AppBadge(
                  label: job.type.isNotEmpty ? job.type : '직무',
                  bgColor: AppColors.accent.withOpacity(0.10),
                  textColor: AppColors.accent,
                ),
                if (job.employmentType.isNotEmpty)
                  AppBadge(
                    label: job.employmentType,
                    bgColor: AppColors.surfaceMuted,
                    textColor: AppColors.textSecondary,
                  ),
                if (job.career.isNotEmpty && job.career != '미정')
                  AppBadge(
                    label: job.career,
                    bgColor: AppColors.surfaceMuted,
                    textColor: AppColors.textSecondary,
                  ),
                AppBadge(
                  label: job.salaryDisplayLine,
                  bgColor: AppColors.warning.withOpacity(0.12),
                  textColor: AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 주소
            if (job.address.isNotEmpty)
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 14,
                    color: AppColors.textDisabled, // 이전 _kText.withOpacity(0.4)
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      job.address,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary, // 이전 _kText.withOpacity(0.5)
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
