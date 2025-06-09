import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/job.dart';
import '../../services/job_service.dart';
import '../../widgets/job_card.dart';

class AppliedJobsScreen extends StatelessWidget {
  const AppliedJobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final jobService = context.read<JobService>();

    return Scaffold(
      appBar: AppBar(title: const Text('관심 공고')),
      body: FutureBuilder<List<Job>>(
        future: jobService.fetchBookmarkedJobs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('오류: ${snapshot.error}'));
          }
          final jobs = snapshot.data ?? [];
          if (jobs.isEmpty) {
            return const Center(child: Text('관심 등록한 공고가 없습니다.'));
          }

          return ListView.builder(
            itemCount: jobs.length,
            itemBuilder: (_, i) => JobCard(job: jobs[i]),
          );
        },
      ),
    );
  }
}
