import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart' show AppRadius, AppSpacing;
import '../../../../core/widgets/app_modal_scaffold.dart';
import '../../../../models/applicant_pool_entry.dart';
import '../../../../models/resume.dart';
import '../../../../services/applicant_pool_service.dart';

/// 지원자 이력서 readonly 다이얼로그.
///
/// 1차 단계에서는 Firestore rules 가 본인 이력서 read 만 허용하므로,
/// 직접 조회가 실패할 수 있다. 그럴 땐 안내 문구를 보여주고 운영자가
/// 카드의 메타 정보로만 판단하도록 유도.
class ApplicantResumeDialog extends StatelessWidget {
  const ApplicantResumeDialog({
    super.key,
    required this.applicant,
    required this.resumeId,
  });

  final JoinedApplicant applicant;
  final String resumeId;

  @override
  Widget build(BuildContext context) {
    return AppModalDialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined,
                      color: AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      applicant.displayName.isNotEmpty
                          ? '${applicant.displayName} · 이력서'
                          : '지원자 이력서',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<Resume?>(
                future: ApplicantPoolService.tryReadResume(resumeId),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(
                                strokeWidth: 2)));
                  }
                  final resume = snap.data;
                  if (resume == null) {
                    return _NoAccess(applicant: applicant);
                  }
                  return _ResumeContent(resume: resume);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoAccess extends StatelessWidget {
  const _NoAccess({required this.applicant});
  final JoinedApplicant applicant;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.2)),
            ),
            child: const Text(
              '지원자가 연락처/이력서 공개를 승인하지 않으면 직접 열람할 수 없어요.\n'
              '"이력서 열람 요청" 기능은 다음 단계에서 추가될 예정입니다.\n\n'
              '아래 운영자 메모와 지원 이력만 우선 확인하세요.',
              style: TextStyle(height: 1.5),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('지원 이력 (${applicant.applications.length}건)',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...applicant.applications.map((j) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.work_outline, size: 18),
                title: Text(j.jobTitle?.isNotEmpty == true
                    ? j.jobTitle!
                    : j.jobId),
                subtitle: Text(j.submittedAt == null
                    ? ''
                    : '${j.submittedAt!.year}.${j.submittedAt!.month.toString().padLeft(2, '0')}.${j.submittedAt!.day.toString().padLeft(2, '0')} · ${j.status}'),
              )),
          if (applicant.memo.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const Text('운영자 메모',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(applicant.memo,
                style: const TextStyle(height: 1.5)),
          ],
        ],
      ),
    );
  }
}

class _ResumeContent extends StatelessWidget {
  const _ResumeContent({required this.resume});
  final Resume resume;

  @override
  Widget build(BuildContext context) {
    final p = resume.profile;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p != null) ...[
            Text(p.name.isEmpty ? '(이름 없음)' : p.name,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text([
              if (p.region.isNotEmpty) p.region,
              if (p.workTypes.isNotEmpty) p.workTypes.join(' · '),
            ].join(' · '),
                style: const TextStyle(
                    color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 12),
            if (p.headline.isNotEmpty)
              Text(p.headline,
                  style:
                      const TextStyle(fontWeight: FontWeight.w700)),
            if (p.summary.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(p.summary, style: const TextStyle(height: 1.6)),
            ],
            const Divider(height: 32),
          ],
          if (resume.licenses.isNotEmpty) ...[
            _section('자격증'),
            ...resume.licenses
                .where((l) => l.has)
                .map((l) => _row('• ${l.type}')),
            const SizedBox(height: 16),
          ],
          if (resume.experiences.isNotEmpty) ...[
            _section('경력'),
            ...resume.experiences.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                      '• ${e.clinicName}${e.region.isNotEmpty ? ' · ${e.region}' : ''} (${e.start} ~ ${e.end})'),
                )),
            const SizedBox(height: 16),
          ],
          if (resume.skills.isNotEmpty) ...[
            _section('스킬'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: resume.skills
                  .map((s) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.accent
                              .withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(s.name,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.accent)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
          if (resume.education.isNotEmpty) ...[
            _section('학력'),
            ...resume.education.map((e) => _row(
                '• ${e.school} · ${e.major}${e.gradYear != null ? ' (${e.gradYear})' : ''}')),
          ],
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary)),
      );

  Widget _row(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: const TextStyle(height: 1.6)),
      );
}
