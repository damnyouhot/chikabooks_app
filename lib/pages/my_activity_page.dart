import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/job_service.dart';
import '../../models/job.dart';
import '../screen/jobs/job_detail_screen.dart';

// ── 디자인 팔레트 ──
const _kAccent = Color(0xFFF7CBCA);
const _kText = Color(0xFF5D6B6B);
const _kBg = Color(0xFFF1F7F7);

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
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '내 활동',
          style: TextStyle(
            color: _kText,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: _kText),
        bottom: TabBar(
          controller: _tabController,
          labelColor: _kText,
          unselectedLabelColor: _kText.withOpacity(0.5),
          indicatorColor: _kAccent,
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
              style: TextStyle(fontSize: 14, color: _kText.withOpacity(0.6)),
            ),
          );
        }

        final applications = snapshot.data ?? [];

        if (applications.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 64,
                  color: _kText.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  '아직 지원한 공고가 없습니다',
                  style: TextStyle(
                    fontSize: 14,
                    color: _kText.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'viewed':
        return Colors.blue;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
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
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final job = snapshot.data!;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => JobDetailScreen(jobId: jobId),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상태 배지
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _getStatusText(status),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 병원명
                  Text(
                    job.clinicName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _kText,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // 공고 제목
                  Text(
                    job.title,
                    style: TextStyle(
                      fontSize: 13,
                      color: _kText.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 지원 정보
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: _kText.withOpacity(0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        application['name'] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: _kText.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.work_outline,
                        size: 14,
                        color: _kText.withOpacity(0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        application['career'] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: _kText.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // 지원 일시
                  if (appliedAt != null)
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: _kText.withOpacity(0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${appliedAt.toDate().year}-${appliedAt.toDate().month.toString().padLeft(2, '0')}-${appliedAt.toDate().day.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: _kText.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
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
              style: TextStyle(fontSize: 14, color: _kText.withOpacity(0.6)),
            ),
          );
        }

        final jobs = snapshot.data ?? [];

        if (jobs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.favorite_border,
                  size: 64,
                  color: _kText.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  '관심 등록한 공고가 없습니다',
                  style: TextStyle(
                    fontSize: 14,
                    color: _kText.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: job.id)),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                            color: _kText,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // 공고 제목
                        Text(
                          job.title,
                          style: TextStyle(
                            fontSize: 13,
                            color: _kText.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 북마크 해제 버튼
                  IconButton(
                    onPressed: () {
                      jobService.unbookmarkJob(job.id);
                      // 상태 새로고침을 위해 setState 트리거
                      (context as Element).markNeedsBuild();
                    },
                    icon: const Icon(Icons.favorite, color: Colors.red),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 태그
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildTag(
                    job.type,
                    const Color(0xFFE3F2FD),
                    const Color(0xFF1976D2),
                  ),
                  _buildTag(
                    job.career,
                    const Color(0xFFF3E5F5),
                    const Color(0xFF7B1FA2),
                  ),
                  if (job.salaryRange[0] > 0)
                    _buildTag(
                      '${job.salaryRange[0]}~${job.salaryRange[1]}만',
                      const Color(0xFFFFF8E1),
                      const Color(0xFFF57F17),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // 주소
              if (job.address.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: _kText.withOpacity(0.4),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        job.address,
                        style: TextStyle(
                          fontSize: 12,
                          color: _kText.withOpacity(0.5),
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
      ),
    );
  }

  Widget _buildTag(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}



