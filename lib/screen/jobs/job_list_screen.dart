import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/job.dart';
import '../../notifiers/job_filter_notifier.dart';
import '../../services/job_service.dart';
import '../../widgets/job_card.dart';
import '../../widgets/filter_bar.dart';
// import 'applied_jobs_screen.dart'; // 관심 공고 버튼은 JobPage로 이동했으므로 제거

class JobListScreen extends StatelessWidget {
  const JobListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final jobFilter = context.watch<JobFilterNotifier>();
    final jobService = context.read<JobService>();

    // ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼ Scaffold와 AppBar 제거 ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
    return Column(
      children: [
        const FilterBar(),
        Expanded(
          child: FutureBuilder<List<Job>>(
            key: ValueKey(jobFilter.careerFilter),
            future: jobService.fetchJobs(careerFilter: jobFilter.careerFilter),
            builder: (context, snapshot) {
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
              return ListView.builder(
                itemCount: jobs.length,
                itemBuilder: (_, i) => JobCard(job: jobs[i]),
              );
            },
          ),
        ),
      ],
    );
    // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲ Scaffold와 AppBar 제거 ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲
  }
}
