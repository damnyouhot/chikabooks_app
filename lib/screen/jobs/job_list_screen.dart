import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/job.dart';
import '../../notifiers/job_filter_notifier.dart';
import '../../services/job_service.dart';
import '../../widgets/job_card.dart';
import '../../widgets/filter_bar.dart';

class JobListScreen extends StatelessWidget {
  const JobListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final jobFilter = context.watch<JobFilterNotifier>();
    final jobService = context.read<JobService>();

    return Column(
      children: [
        const FilterBar(),
        Expanded(
          child: FutureBuilder<List<Job>>(
            key: ValueKey(
              "${jobFilter.careerFilter}_${jobFilter.regionFilter}_"
              "${jobFilter.positionFilter}_${jobFilter.searchQuery}_"
              "${jobFilter.salaryRange}",
            ),
            future: jobService.fetchJobs(
              careerFilter: jobFilter.careerFilter,
              regionFilter: jobFilter.regionFilter,
              salaryRange: jobFilter.salaryRange,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('오류 발생: ${snapshot.error}'));
              }

              List<Job> jobs = snapshot.data ?? [];

              // 클라이언트 사이드 필터링 (직종, 검색어)
              if (jobFilter.positionFilter != '전체') {
                jobs = jobs.where((job) => 
                  job.jobPosition == jobFilter.positionFilter
                ).toList();
              }

              if (jobFilter.searchQuery.isNotEmpty) {
                final query = jobFilter.searchQuery.toLowerCase();
                jobs = jobs.where((job) =>
                  job.clinicName.toLowerCase().contains(query) ||
                  job.address.toLowerCase().contains(query) ||
                  job.title.toLowerCase().contains(query)
                ).toList();
              }

              if (jobs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        '조건에 맞는 공고가 없습니다.',
                        style: TextStyle(fontSize: 15, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => jobFilter.resetFilters(),
                        child: const Text('필터 초기화'),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  // 새로고침 시 다시 빌드
                  (context as Element).markNeedsBuild();
                },
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: jobs.length,
                  itemBuilder: (_, i) => JobCard(job: jobs[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
