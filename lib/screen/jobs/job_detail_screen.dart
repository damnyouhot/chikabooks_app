import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/job.dart';
import '../../services/job_service.dart';

class JobDetailScreen extends StatefulWidget {
  final String jobId;
  // ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼ autoOpenApply 파라미터 다시 추가 ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
  final bool autoOpenApply;
  const JobDetailScreen({
    super.key,
    required this.jobId,
    this.autoOpenApply = false,
  });
  // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲ autoOpenApply 파라미터 다시 추가 ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  // Job 데이터를 저장할 변수를 State 내부에 선언
  Job? _job;

  @override
  void initState() {
    super.initState();
    // initState에서 한 번만 Job 데이터를 불러오도록 수정
    _fetchJobData();
  }

  Future<void> _fetchJobData() async {
    final job = await context.read<JobService>().fetchJob(widget.jobId);
    if (mounted) {
      setState(() {
        _job = job;
      });
      // autoOpenApply가 true이면, 데이터 로딩 후 바로 지원 모달을 엽니다.
      if (widget.autoOpenApply) {
        // 프레임이 렌더링된 후 모달을 열기 위해 addPostFrameCallback 사용
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openApplyModal(context, job);
        });
      }
    }
  }

  void _openApplyModal(BuildContext context, Job job) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 키보드가 올라올 때 UI가 밀리는 것을 방지
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 24, 16, MediaQuery.of(context).viewInsets.bottom + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${job.clinicName} 지원서',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const TextField(decoration: InputDecoration(labelText: '이름')),
            const SizedBox(height: 8),
            const TextField(decoration: InputDecoration(labelText: '연락처')),
            const SizedBox(height: 8),
            const TextField(
                decoration: InputDecoration(labelText: '경력/포트폴리오 링크')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('지원서가 제출되었습니다!')),
                );
              },
              child: const Text('제출하기'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // _job 데이터가 아직 로드되지 않았다면 로딩 인디케이터 표시
    if (_job == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final job = _job!;
    final jobService = context.read<JobService>();

    return StreamBuilder<List<String>>(
      stream: jobService.watchBookmarkedJobIds(),
      builder: (context, bookmarkSnap) {
        final bookmarkedIds = bookmarkSnap.data ?? [];
        final isBookmarked = bookmarkedIds.contains(widget.jobId);

        return Scaffold(
          appBar: AppBar(
            title: Text(job.clinicName),
            actions: [
              IconButton(
                icon: Icon(
                  isBookmarked ? Icons.star : Icons.star_border,
                  color: isBookmarked ? Colors.amber : null,
                ),
                onPressed: () {
                  if (isBookmarked) {
                    jobService.unbookmarkJob(widget.jobId);
                  } else {
                    jobService.bookmarkJob(widget.jobId);
                  }
                },
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openApplyModal(context, job),
            label: const Text('지원하기'),
            icon: const Icon(Icons.edit),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ... (기존 body 내용은 동일하게 유지)
              // 여기부터는 기존에 제공된 body 코드와 동일합니다.
              // 지도 미리보기 (임시)
              Container(
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.grey.shade200,
                ),
                child: const Center(child: Text('Map Preview')),
              ),
              const SizedBox(height: 12),
              Text(job.title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              Text(
                  '${job.type} · ${job.career} · ${job.salaryRange[0]}~${job.salaryRange[1]}만원'),
              const Divider(height: 24),
              Text('업무 내용', style: Theme.of(context).textTheme.titleMedium),
              Text(job.details),
              const SizedBox(height: 12),
              Text('복리후생', style: Theme.of(context).textTheme.titleMedium),
              Wrap(
                spacing: 8,
                children:
                    job.benefits.map((b) => Chip(label: Text(b))).toList(),
              ),
              const SizedBox(height: 12),
              Text('사진', style: Theme.of(context).textTheme.titleMedium),
              if (job.images.isNotEmpty)
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: job.images.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(job.images[i],
                            width: 200, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
