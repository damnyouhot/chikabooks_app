import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/job.dart';
import '../../services/job_service.dart';

class JobDetailScreen extends StatefulWidget {
  final String jobId;
  final bool autoOpenApply;
  const JobDetailScreen({
    super.key,
    required this.jobId,
    this.autoOpenApply = false,
  });

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  Job? _job;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final job = await context.read<JobService>().fetchJob(widget.jobId);
    if (!mounted) return;
    setState(() => _job = job);

    if (widget.autoOpenApply) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openApplyModal(context, job);
      });
    }
  }

  /// 간편 지원 모달 (방법 A)
  void _openApplyModal(BuildContext context, Job job) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final introController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 24, 20, MediaQuery.of(context).viewInsets.bottom + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                const Icon(Icons.edit_document, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${job.clinicName} 간편 지원',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // 입력 필드들
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '이름 *',
                hintText: '홍길동',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: '연락처 *',
                hintText: '010-1234-5678',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: introController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '한줄 소개',
                hintText: '예: 3년차 치과위생사, 임플란트 전문',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
            ),
            const SizedBox(height: 12),

            // 이력서 첨부 (선택)
            OutlinedButton.icon(
              onPressed: () {
                // TODO: 파일 선택 기능
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('이력서 첨부 기능은 준비 중입니다')),
                );
              },
              icon: const Icon(Icons.attach_file),
              label: const Text('이력서 첨부 (선택)'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'PDF, 한글 파일을 첨부할 수 있습니다',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),

            const SizedBox(height: 20),

            // 제출 버튼
            FilledButton.icon(
              onPressed: () {
                if (nameController.text.isEmpty || phoneController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('이름과 연락처를 입력해주세요')),
                  );
                  return;
                }
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${job.clinicName}에 지원서가 제출되었습니다!'),
                    backgroundColor: Colors.green,
                  ),
                );
                // TODO: Firestore에 지원 내역 저장
              },
              icon: const Icon(Icons.send),
              label: const Text('지원하기'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 직접 연락하기 모달 (방법 B)
  void _openContactModal(BuildContext context, Job job) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '직접 연락하기',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '아래 연락처로 직접 문의해주세요',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const Divider(height: 24),

            // 전화 연락
            if (job.contactPhone.isNotEmpty)
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.phone, color: Colors.white),
                ),
                title: const Text('전화 문의'),
                subtitle: Text(job.contactPhone),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final uri = Uri.parse('tel:${job.contactPhone}');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
              ),

            // 이메일 연락
            if (job.contactEmail.isNotEmpty)
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.email, color: Colors.white),
                ),
                title: const Text('이메일 문의'),
                subtitle: Text(job.contactEmail),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final uri = Uri.parse(
                    'mailto:${job.contactEmail}?subject=[지원문의] ${job.title}',
                  );
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
              ),

            // 연락처 없는 경우
            if (job.contactPhone.isEmpty && job.contactEmail.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      '등록된 연락처가 없습니다',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_job == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final job = _job!;
    final jobService = context.read<JobService>();

    return StreamBuilder<List<String>>(
      stream: jobService.watchBookmarkedJobIds(),
      builder: (context, snap) {
        final ids = snap.data ?? [];
        final bookmarked = ids.contains(widget.jobId);

        return Scaffold(
          appBar: AppBar(
            title: Text(job.clinicName),
            actions: [
              // 북마크 버튼
              IconButton(
                icon: Icon(
                  bookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: bookmarked ? Colors.amber : null,
                ),
                onPressed: () {
                  bookmarked
                      ? jobService.unbookmarkJob(widget.jobId)
                      : jobService.bookmarkJob(widget.jobId);
                },
              ),
              // 공유 버튼
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  // TODO: 공유 기능
                },
              ),
            ],
          ),
          // 하단 고정 버튼
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 직접 연락하기 버튼
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openContactModal(context, job),
                      icon: const Icon(Icons.call),
                      label: const Text('연락하기'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 50),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 간편 지원 버튼
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () => _openApplyModal(context, job),
                      icon: const Icon(Icons.edit),
                      label: const Text('간편 지원'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 50),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 상단 요약 카드
              _buildSummaryCard(job),
              const SizedBox(height: 16),

              // 급여 정보
              _buildInfoSection(
                icon: Icons.payments,
                title: '급여',
                content: job.salaryRange[0] == 0 && job.salaryRange[1] == 0
                    ? '협의'
                    : '${job.salaryRange[0]}~${job.salaryRange[1]}만원',
              ),

              // 근무 정보
              if (job.workHours.isNotEmpty || job.workDays.isNotEmpty)
                _buildInfoSection(
                  icon: Icons.schedule,
                  title: '근무시간',
                  content: '${job.workDays} ${job.workHours}'.trim(),
                ),

              // 업무 내용
              _buildDetailSection('담당 업무', job.details),

              // 자격 요건
              if (job.requirements.isNotEmpty)
                _buildDetailSection('자격 요건', job.requirements),

              // 우대 사항
              if (job.preferences.isNotEmpty)
                _buildDetailSection('우대 사항', job.preferences),

              // 복리후생
              if (job.benefits.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('복리후생', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: job.benefits.map((b) => Chip(
                    label: Text(b),
                    backgroundColor: Colors.blue.shade50,
                  )).toList(),
                ),
              ],

              // 병원 소개
              if (job.clinicIntro.isNotEmpty)
                _buildDetailSection('병원 소개', job.clinicIntro),

              // 병원 사진
              if (job.images.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('병원 사진', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: job.images.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          job.images[i],
                          width: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 200,
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              // 하단 여백
              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }

  /// 상단 요약 카드
  Widget _buildSummaryCard(Job job) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 급구 + 마감일 배지
            Row(
              children: [
                if (job.isUrgent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '급구',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                if (job.isUrgent) const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: job.isExpired ? Colors.grey : Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    job.deadlineText,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 제목
            Text(
              job.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // 병원명 + 주소
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${job.clinicName} · ${job.address}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 태그들
            Wrap(
              spacing: 8,
              children: [
                _buildTag(job.jobPosition, Colors.purple),
                _buildTag(job.type, Colors.teal),
                _buildTag(job.career, Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }

  Widget _buildInfoSection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            '$title: ',
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            content,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(color: Colors.grey[700], height: 1.5),
          ),
        ],
      ),
    );
  }
}
