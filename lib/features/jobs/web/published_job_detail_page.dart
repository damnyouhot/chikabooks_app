import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import '../../../core/widgets/web_site_footer.dart';
import '../../../models/job.dart';
import '../../../services/job_draft_service.dart';
import '../../../services/job_stats_service.dart';
import '../../auth/web/web_account_menu_button.dart';
import 'job_applicants_page.dart';
import 'job_post_top_bar.dart';

/// 게시 완료 후 병원이 공고 상태와 지원자를 관리하는 상세 화면.
class PublishedJobDetailPage extends StatefulWidget {
  const PublishedJobDetailPage({super.key, required this.jobId});

  final String jobId;

  @override
  State<PublishedJobDetailPage> createState() => _PublishedJobDetailPageState();
}

class _PublishedJobDetailPageState extends State<PublishedJobDetailPage> {
  bool _busy = false;

  DocumentReference<Map<String, dynamic>> get _jobRef =>
      FirebaseFirestore.instance.collection('jobs').doc(widget.jobId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.webPublisherPageBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (kIsWeb)
            JobPostTopBar(
              currentStep: const JobPostStep(title: '공고 관리'),
              prevStep: JobPostStep.input,
              onPrev: () => context.go('/post-job/input'),
              trailing: const WebAccountMenuButton(),
            ),
          Expanded(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _jobRef.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _CenteredMessage(
                    title: '공고를 불러오지 못했어요.',
                    message: '잠시 후 다시 확인해 주세요.',
                    actionLabel: '공고 선택으로',
                    onAction: () => context.go('/post-job/input'),
                  );
                }

                final doc = snapshot.data;
                if (doc == null || !doc.exists || doc.data() == null) {
                  return _CenteredMessage(
                    title: '공고를 찾을 수 없어요.',
                    message: '삭제되었거나 접근할 수 없는 공고입니다.',
                    actionLabel: '공고 선택으로',
                    onAction: () => context.go('/post-job/input'),
                  );
                }

                final data = doc.data()!;
                if (!_canManage(data)) {
                  return _CenteredMessage(
                    title: '관리 권한이 없어요.',
                    message: '이 계정으로 작성한 공고만 관리할 수 있습니다.',
                    actionLabel: '공고 선택으로',
                    onAction: () => context.go('/post-job/input'),
                  );
                }

                final job = Job.fromJson(data, docId: doc.id);
                return _buildContent(job, data);
              },
            ),
          ),
          if (kIsWeb) const WebSiteFooter(backgroundColor: AppColors.white),
        ],
      ),
    );
  }

  bool _canManage(Map<String, dynamic> data) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    return data['createdBy'] == uid ||
        data['ownerUid'] == uid ||
        data['clinicId'] == uid;
  }

  Widget _buildContent(Job job, Map<String, dynamic> data) {
    final createdAt = _dateFrom(data['createdAt']) ?? job.postedAt;
    final closingDate = job.closingDate;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 34, 24, 38),
          children: [
            _buildHero(job, createdAt, closingDate),
            const SizedBox(height: 18),
            _buildActionBar(job),
            const SizedBox(height: 18),
            _buildStatsAndApplicants(job),
            const SizedBox(height: 18),
            _buildJobInfo(job),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(Job job, DateTime createdAt, DateTime? closingDate) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppPublisher.inputPanelRadius),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusPill(status: job.status ?? 'pending'),
                    _SmallMetaPill(
                      icon: Icons.schedule_rounded,
                      label: '게시 ${_dateLabel(createdAt)}',
                    ),
                    if (closingDate != null)
                      _SmallMetaPill(
                        icon: Icons.event_available_rounded,
                        label: '마감 ${_dateLabel(closingDate)}',
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  job.title.isEmpty ? '(제목 없음)' : job.title,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  [
                    if (job.clinicName.isNotEmpty) job.clinicName,
                    if (job.type.isNotEmpty) job.type,
                    if (job.employmentType.isNotEmpty) job.employmentType,
                  ].join(' · '),
                  style: GoogleFonts.notoSansKr(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: 170,
            height: AppPublisher.ctaHeight,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : () => _copyToDraft(job),
              icon:
                  _busy
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.edit_note_rounded, size: 19),
              label: const Text('복사해서 수정'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppPublisher.buttonRadius,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(Job job) {
    final status = (job.status ?? 'pending').toLowerCase();
    final canClose = status == 'active';
    final canRepublish = status == 'closed';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppPublisher.inputPanelRadius),
        border: Border.all(color: AppColors.divider),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => JobApplicantsPage(
                          jobId: job.id,
                          jobTitle: job.title,
                        ),
                  ),
                ),
            icon: const Icon(Icons.people_outline_rounded, size: 18),
            label: const Text('지원자 보기'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _copyToDraft(job),
            icon: const Icon(Icons.content_copy_rounded, size: 17),
            label: const Text('새 공고로 복사'),
          ),
          if (canClose)
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _updateStatus('closed'),
              icon: const Icon(Icons.pause_circle_outline_rounded, size: 18),
              label: const Text('마감하기'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.destructive,
              ),
            ),
          if (canRepublish)
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _updateStatus('pending'),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('재게시 요청'),
            ),
          TextButton.icon(
            onPressed: _busy ? null : () => _confirmDelete(job.title),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('삭제'),
            style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsAndApplicants(Job job) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: FutureBuilder<Map<String, int>>(
            future: JobStatsService.fetchTotalStats(job.id),
            builder: (context, snapshot) {
              final stats = snapshot.data ?? const {};
              return _InfoPanel(
                title: '성과 요약',
                children: [
                  _MetricRow(label: '조회수', value: '${stats['views'] ?? 0}'),
                  _MetricRow(
                    label: '유니크 조회',
                    value: '${stats['uniqueViews'] ?? 0}',
                  ),
                  _MetricRow(label: '지원수', value: '${stats['applies'] ?? 0}'),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream:
                FirebaseFirestore.instance
                    .collection('applications')
                    .where('jobId', isEqualTo: job.id)
                    .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? const [];
              final contactRequested =
                  docs
                      .where((d) => d.data()['status'] == 'contactRequested')
                      .length;
              return _InfoPanel(
                title: '지원자 현황',
                children: [
                  _MetricRow(label: '전체 지원자', value: '${docs.length}'),
                  _MetricRow(label: '연락처 요청', value: '$contactRequested'),
                  _InlineAction(
                    label: '지원자 목록 열기',
                    onTap:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => JobApplicantsPage(
                                  jobId: job.id,
                                  jobTitle: job.title,
                                ),
                          ),
                        ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildJobInfo(Job job) {
    final items =
        [
          ('병원명', job.clinicName),
          ('근무지', job.address),
          ('급여', job.salaryDisplayLine),
          ('근무시간', job.workHours),
          ('연락처', job.contact),
          ('교통', job.transportation?.summaryLine ?? ''),
        ].where((item) => item.$2.trim().isNotEmpty).toList();
    return _InfoPanel(
      title: '공고 주요 정보',
      children: [
        if (items.isEmpty)
          Text(
            '표시할 주요 정보가 아직 부족합니다.',
            style: GoogleFonts.notoSansKr(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          )
        else
          for (final item in items) _MetricRow(label: item.$1, value: item.$2),
      ],
    );
  }

  Future<void> _copyToDraft(Job job) async {
    setState(() => _busy = true);
    try {
      final id = await JobDraftService.saveDraftAsCopyFromPublishedJob(job);
      if (!mounted) return;
      if (id == null) {
        _showSnack('복사에 실패했어요. 잠시 후 다시 시도해 주세요.');
        return;
      }
      context.push('/post-job/edit/$id', extra: {'sourceType': 'copy'});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _busy = true);
    try {
      await _jobRef.update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        _showSnack(status == 'closed' ? '공고를 마감했어요.' : '재게시 요청 상태로 변경했어요.');
      }
    } catch (_) {
      if (mounted) _showSnack('상태 변경에 실패했어요. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete(String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AppConfirmModal(
            title: '공고 삭제',
            message:
                '"${title.isEmpty ? '제목 없음' : title}" 공고를 삭제할까요?\n삭제 후에는 복구할 수 없어요.',
            confirmLabel: '삭제',
            destructive: true,
          ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _jobRef.delete();
      if (!mounted) return;
      context.go('/post-job/input');
      _showSnack('공고를 삭제했어요.');
    } catch (_) {
      if (mounted) _showSnack('삭제에 실패했어요. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.notoSansKr())),
    );
  }

  DateTime? _dateFrom(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _dateLabel(DateTime value) => DateFormat('yyyy.MM.dd').format(value);
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppPublisher.inputPanelRadius),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: GoogleFonts.notoSansKr(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: GoogleFonts.notoSansKr(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.notoSansKr(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineAction extends StatelessWidget {
  const _InlineAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.chevron_right_rounded, size: 18),
        label: Text(label),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'active' => ('게시중', AppColors.accent),
      'closed' => ('마감', AppColors.textDisabled),
      'rejected' => ('반려', AppColors.destructive),
      _ => ('검수중', AppColors.warning),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(AppPublisher.softRadius),
      ),
      child: Text(
        label,
        style: GoogleFonts.notoSansKr(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _SmallMetaPill extends StatelessWidget {
  const _SmallMetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.webPublisherPageBg,
        borderRadius: BorderRadius.circular(AppPublisher.softRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.notoSansKr(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppPublisher.inputPanelRadius),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 42,
              color: AppColors.textDisabled,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansKr(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansKr(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: AppPublisher.ctaHeight,
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppPublisher.buttonRadius,
                    ),
                  ),
                ),
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
