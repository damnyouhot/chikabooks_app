import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// [수정] 오류를 해결하기 위해 절대 경로로 변경
import 'package:chikabooks_app/providers/job_provider.dart';
import 'package:chikabooks_app/models/job_model.dart';
import 'package:chikabooks_app/widgets/job_card.dart';

class JobPage extends StatefulWidget {
  // [수정] 생성자를 최신 스타일로 변경
  const JobPage({super.key});

  @override
  State<JobPage> createState() => _JobPageState();
}

class _JobPageState extends State<JobPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<JobProvider>(context, listen: false).fetchJobs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('직업 선택')),
      body: Consumer<JobProvider>(
        builder: (context, jobProvider, child) {
          // [수정] 코드 스타일 개선을 위해 if문에 중괄호 추가
          if (jobProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (jobProvider.jobs.isEmpty) {
            return const Center(child: Text('직업 정보가 없습니다.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: jobProvider.jobs.length,
            itemBuilder: (context, index) {
              Job job = jobProvider.jobs[index];
              return JobCard(job: job);
            },
          );
        },
      ),
    );
  }
}
