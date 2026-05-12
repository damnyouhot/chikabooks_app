import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../models/job.dart';
import '../../../../models/resume.dart';
import '../../../../services/application_service.dart';
import '../../../../services/job_service.dart';
import '../../../../services/resume_service.dart';
import '../widgets/applicant_web_shell.dart';

/// `/jobs/:id/apply` — 웹 지원 확인 페이지.
///
/// 흐름:
///  1) Job 로드 + 내 이력서 목록 + 중복 지원 확인을 병렬 처리.
///  2) 대표 이력서로 기본 선택 → 사용자가 다른 이력서로 바꿀 수 있음.
///  3) 필수 필드 검증 후 [ApplicationService.submitApplication] 호출.
///  4) 성공 시 `/me/applications` 로 이동.
class ApplyConfirmWebPage extends StatefulWidget {
  const ApplyConfirmWebPage({super.key, required this.jobId});

  final String jobId;

  @override
  State<ApplyConfirmWebPage> createState() => _ApplyConfirmWebPageState();
}

class _ApplyConfirmWebPageState extends State<ApplyConfirmWebPage> {
  Job? _job;
  List<Resume> _resumes = [];
  Resume? _selected;
  bool _loading = true;
  bool _submitting = false;
  bool _alreadyApplied = false;

  /// `Job` 모델에는 노출되지 않지만 Firestore raw 도큐먼트에 들어 있는
  /// 공고 소유자(`clinicId` / `ownerUid`). 지원서 제출 시 함께 저장하여
  /// 클리닉 측 지원자 풀 집계가 누락되지 않게 한다.
  String _clinicIdResolved = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _fetchJobWithClinicId(widget.jobId),
        ResumeService.fetchMyResumes(),
        ApplicationService.hasApplied(widget.jobId),
      ]);
      if (!mounted) return;
      final tuple = results[0] as (Job, String);
      final job = tuple.$1;
      final clinicId = tuple.$2;
      final resumes = results[1] as List<Resume>;
      final applied = results[2] as bool;
      setState(() {
        _job = job;
        _clinicIdResolved = clinicId;
        _resumes = resumes;
        _alreadyApplied = applied;
        if (resumes.isNotEmpty) _selected = resumes.first;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// Job 본체와 raw 도큐먼트 메타(`clinicId`/`ownerUid`)를 한 번에 가져온다.
  ///
  /// 모킹된 `mock_*` 공고는 Firestore에 실제 문서가 없으므로 fallback Job 만 반환.
  Future<(Job, String)> _fetchJobWithClinicId(String id) async {
    final svc = context.read<JobService>();
    if (id.startsWith('mock_')) {
      return (svc.jobOfflineFallback(id), '');
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('jobs')
          .doc(id)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        Job parsed;
        try {
          parsed = Job.fromDoc(doc);
        } catch (_) {
          parsed = svc.jobOfflineFallback(id);
        }
        final clinicId =
            (data['clinicId'] as String?)?.trim().isNotEmpty == true
                ? (data['clinicId'] as String).trim()
                : (data['ownerUid'] as String?)?.trim() ?? '';
        return (parsed, clinicId);
      }
    } catch (e) {
      debugPrint('⚠️ ApplyConfirmWebPage._fetchJobWithClinicId($id): $e');
    }
    return (svc.jobOfflineFallback(id), '');
  }

  String? _validate(Resume r) {
    if (r.profile == null || r.profile!.name.trim().isEmpty) {
      return '이력서에 이름이 입력되지 않았어요.';
    }
    if (r.licenses.isEmpty &&
        r.experiences.isEmpty &&
        r.education.isEmpty) {
      return '면허, 경력, 학력 중 최소 1개를 입력해 주세요.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_selected == null || _submitting || _job == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _toast('로그인이 필요합니다.');
      return;
    }
    final err = _validate(_selected!);
    if (err != null) {
      _toast(err);
      return;
    }

    setState(() => _submitting = true);

    final result = await ApplicationService.submitApplication(
      jobId: _job!.id,
      // _load() 시점에 raw 문서에서 추출. 일부 레거시 공고는 비어 있을 수 있음.
      clinicId: _clinicIdResolved,
      resumeId: _selected!.id,
    );

    if (!mounted) return;
    if (result != null) {
      _toast('✅ 지원이 완료되었어요!');
      context.go('/me/applications');
    } else {
      setState(() => _submitting = false);
      _toast('이미 지원했거나 오류가 발생했어요.');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ApplicantWebShell(
        body: Padding(
          padding: EdgeInsets.symmetric(vertical: 80),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_job == null) {
      return ApplicantWebShell(
        body: Padding(
          padding: const EdgeInsets.symmetric(vertical: 80),
          child: Center(
            child: Text(
              '공고를 불러올 수 없어요. 잠시 후 다시 시도해 주세요.',
              style: GoogleFonts.notoSansKr(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return ApplicantWebShell(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BackToJobButton(jobId: _job!.id),
          const SizedBox(height: 12),
          _Banner(alreadyApplied: _alreadyApplied),
          const SizedBox(height: 16),
          _JobSummary(job: _job!),
          const SizedBox(height: 16),
          _ResumeSelector(
            resumes: _resumes,
            selected: _selected,
            onChange: (r) => setState(() => _selected = r),
          ),
          const SizedBox(height: 24),
          _SubmitBar(
            disabled:
                _alreadyApplied || _selected == null || _submitting,
            submitting: _submitting,
            label: _alreadyApplied ? '이미 지원한 공고예요' : '지원 제출하기',
            onSubmit: _submit,
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

class _BackToJobButton extends StatelessWidget {
  const _BackToJobButton({required this.jobId});
  final String jobId;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => context.go('/jobs/$jobId'),
        icon: const Icon(Icons.arrow_back_rounded, size: 18),
        label: Text(
          '공고로 돌아가기',
          style: GoogleFonts.notoSansKr(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.alreadyApplied});
  final bool alreadyApplied;

  @override
  Widget build(BuildContext context) {
    if (alreadyApplied) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 18,
              color: AppColors.warning,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '이미 지원한 공고예요. 중복 지원은 불가합니다.',
                style: GoogleFonts.notoSansKr(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warning,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: AppColors.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '아직 제출 전이에요. 이력서를 확인한 뒤 아래 제출하기 버튼을 눌러주세요.',
              style: GoogleFonts.notoSansKr(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JobSummary extends StatelessWidget {
  const _JobSummary({required this.job});
  final Job job;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppApplicant.cardRadius),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '지원 공고',
            style: GoogleFonts.notoSansKr(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textDisabled,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            job.displayClinicName,
            style: GoogleFonts.notoSansKr(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            job.displayTitle,
            style: GoogleFonts.notoSansKr(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _meta(
                Icons.payments_outlined,
                job.salaryDisplayLine,
                color: AppColors.accent,
              ),
              if (job.address.isNotEmpty)
                _meta(Icons.location_on_outlined, job.address),
              if (job.career.isNotEmpty && job.career != '미정')
                _meta(Icons.work_history_outlined, job.career),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.notoSansKr(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ResumeSelector extends StatelessWidget {
  const _ResumeSelector({
    required this.resumes,
    required this.selected,
    required this.onChange,
  });

  final List<Resume> resumes;
  final Resume? selected;
  final ValueChanged<Resume?> onChange;

  @override
  Widget build(BuildContext context) {
    if (resumes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppApplicant.cardRadius),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '이력서가 아직 없어요',
              style: GoogleFonts.notoSansKr(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '지원하려면 먼저 이력서를 작성해 주세요.',
              style: GoogleFonts.notoSansKr(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => context.push('/me/resumes'),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(
                '이력서 만들기',
                style: GoogleFonts.notoSansKr(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppApplicant.cardRadius),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '제출할 이력서 선택',
            style: GoogleFonts.notoSansKr(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              for (final r in resumes)
                _ResumeRadioTile(
                  resume: r,
                  selected: selected?.id == r.id,
                  onTap: () => onChange(r),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResumeRadioTile extends StatelessWidget {
  const _ResumeRadioTile({
    required this.resume,
    required this.selected,
    required this.onTap,
  });

  final Resume resume;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final updated = resume.updatedAt;
    final updatedText = updated != null
        ? '수정 ${DateFormat('yyyy-MM-dd').format(updated)}'
        : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.06)
            : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: selected
                    ? AppColors.accent.withValues(alpha: 0.6)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: selected
                      ? AppColors.accent
                      : AppColors.textDisabled,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resume.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansKr(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          updatedText,
                          '면허 ${resume.licenses.length}',
                          '경력 ${resume.experiences.length}',
                        ].where((s) => s.isNotEmpty).join('  ·  '),
                        style: GoogleFonts.notoSansKr(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      context.push('/me/resumes/edit/${resume.id}'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 28),
                  ),
                  child: Text(
                    '편집',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.disabled,
    required this.submitting,
    required this.label,
    required this.onSubmit,
  });

  final bool disabled;
  final bool submitting;
  final String label;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: disabled ? null : onSubmit,
        icon: submitting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.onAccent,
                ),
              )
            : const Icon(Icons.send_rounded, size: 18),
        label: Text(
          submitting ? '제출 중…' : label,
          style: GoogleFonts.notoSansKr(
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          disabledBackgroundColor: AppColors.disabledBg,
          disabledForegroundColor: AppColors.disabledText,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}
