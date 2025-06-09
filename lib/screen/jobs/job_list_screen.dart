import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/job.dart';
import '../../notifiers/job_filter_notifier.dart';
import '../../services/job_service.dart';
import '../../widgets/job_card.dart';
import '../../widgets/filter_bar.dart';
import 'applied_jobs_screen.dart';

class JobListScreen extends StatelessWidget {
  const JobListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final jobFilter = context.watch<JobFilterNotifier>();
    final jobService = context.read<JobService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('구직'),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AppliedJobsScreen()),
              );
            },
            icon: const Icon(Icons.star),
            label: const Text('관심 공고'),
          ),
        ],
      ),
      body: Column(
        children: [
          const FilterBar(),
          Expanded(
            child: FutureBuilder<List<Job>>(
              key: ValueKey(jobFilter.careerFilter),
              future:
                  jobService.fetchJobs(careerFilter: jobFilter.careerFilter),
              builder: (context, snapshot) {
                // ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼ 이 부분 로직 보완 ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('오류 발생: ${snapshot.error}'));
                }
                final jobs = snapshot.data ?? [];

                if (jobs.isEmpty) {
                  return const Center(
                    child: Text(
                      '현재 등록된 공고가 없습니다.',
                      style: TextStyle(fontSize: 15, color: Colors.grey),
                    ),
                  );
                }
                // 모든 조건에 걸리지 않으면, 아래의 ListView.builder를 반환
                return ListView.builder(
                  itemCount: jobs.length,
                  itemBuilder: (_, i) => JobCard(job: jobs[i]),
                );
                // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲ 이 부분 로직 보완 ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲
              },
            ),
          ),
        ],
      ),
    );
  }
}
