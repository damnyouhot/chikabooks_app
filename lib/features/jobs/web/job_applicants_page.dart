import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/application.dart';
import '../../../models/resume.dart';
import '../../../services/resume_service.dart';
import 'web_typography.dart';

/// 공고별 지원자 목록 페이지 (웹)
///
/// 설계서 2.4.2 기준:
/// - 익명 프로필 카드 리스트
/// - 연락처 요청 버튼
/// - 첨부파일 열람 (contactShared 시만)
class JobApplicantsPage extends StatefulWidget {
  final String jobId;
  final String jobTitle;
  const JobApplicantsPage({
    super.key,
    required this.jobId,
    required this.jobTitle,
  });

  @override
  State<JobApplicantsPage> createState() => _JobApplicantsPageState();
}

class _JobApplicantsPageState extends State<JobApplicantsPage> {
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: WebTypo.themeData(Theme.of(context)),
      child: Scaffold(
        backgroundColor: AppColors.appBg,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '지원자 목록',
                style: WebTypo.sectionTitle(color: AppColors.textPrimary),
              ),
              Text(
                widget.jobTitle,
                style: WebTypo.caption(
                    color: AppColors.textSecondary, size: 12),
              ),
            ],
          ),
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: _buildApplicantList(),
          ),
        ),
      ),
    );
  }

  Widget _buildApplicantList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('applications')
          .where('jobId', isEqualTo: widget.jobId)
          .orderBy('submittedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _buildEmpty();
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final app = Application.fromDoc(docs[i]);
            return _ApplicantCard(application: app);
          },
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline, size: 56,
              color: AppColors.textDisabled),
          const SizedBox(height: 16),
          Text(
            '아직 지원자가 없습니다.',
            style: WebTypo.body(color: AppColors.textDisabled),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 지원자 카드 (익명 프로필)
// ═══════════════════════════════════════════════════════════

class _ApplicantCard extends StatefulWidget {
  final Application application;
  const _ApplicantCard({required this.application});

  @override
  State<_ApplicantCard> createState() => _ApplicantCardState();
}

class _ApplicantCardState extends State<_ApplicantCard> {
  Resume? _resume;
  bool _loadingResume = true;
  bool _requesting = false;

  Application get app => widget.application;

  @override
  void initState() {
    super.initState();
    _loadResume();
  }

  Future<void> _loadResume() async {
    if (app.resumeId.isEmpty) {
      setState(() => _loadingResume = false);
      return;
    }
    try {
      final resume = await ResumeService.fetchResume(app.resumeId);
      if (mounted) {
        setState(() {
          _resume = resume;
          _loadingResume = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingResume = false);
    }
  }

  /// 연락처 요청 (지원자에게 푸시 → 승인 시 공개)
  /// MVP에서는 즉시 contactShared 플래그 변경 (실제론 승인 필요)
  Future<void> _requestContact() async {
    setState(() => _requesting = true);
    try {
      await FirebaseFirestore.instance
          .collection('applications')
          .doc(app.id)
          .update({
        'status': ApplicationStatus.contactRequested.name,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('연락처 요청이 전송되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('요청 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingResume) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    final contactShared = app.visibilityGranted.contactShared;
    final dateStr = app.submittedAt != null
        ? DateFormat('yyyy.MM.dd HH:mm').format(app.submittedAt!)
        : '-';

    // 익명 프로필 구성
    final profile = _resume?.profile;
    final yearText = _calcCareerYears();
    final skills = _resume?.skills.map((s) => s.name).toList() ?? [];
    final licenses =
        _resume?.licenses.where((l) => l.has).map((l) => l.type).toList() ??
            [];
    final workTypes = profile?.workTypes ?? [];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 0.8),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더: 지원자 번호 + 지원일 + 상태
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person_outline,
                    size: 20, color: AppColors.accent.withOpacity(0.6)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contactShared && profile != null
                          ? profile.name
                          : '지원자 #${app.id.substring(0, 6).toUpperCase()}',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 11,
                        color: AppColors.textDisabled,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(app.status),
            ],
          ),
          const SizedBox(height: 14),

          // 익명 정보
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _infoChip(Icons.work_outline, yearText),
              if (profile?.region.isNotEmpty == true)
                _infoChip(Icons.location_on_outlined, profile!.region),
              if (workTypes.isNotEmpty)
                _infoChip(
                    Icons.schedule_outlined, workTypes.join(', ')),
            ],
          ),

          if (skills.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: skills.map((s) => _skillTag(s)).toList(),
            ),
          ],

          if (licenses.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children:
                  licenses.map((l) => _licenseTag(l)).toList(),
            ),
          ],

          // 연락처 공개 정보 or 요청 버튼
          const SizedBox(height: 14),
          if (contactShared && profile != null)
            _buildContactInfo(profile)
          else
            _buildContactRequestButton(),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(ApplicationStatus status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case ApplicationStatus.submitted:
        bg = AppColors.accent.withOpacity(0.1);
        fg = AppColors.accent;
        label = '지원';
        break;
      case ApplicationStatus.reviewed:
        bg = AppColors.warning.withOpacity(0.1);
        fg = AppColors.warning;
        label = '열람';
        break;
      case ApplicationStatus.contactRequested:
        bg = AppColors.warning.withOpacity(0.1);
        fg = AppColors.warning;
        label = '요청중';
        break;
      case ApplicationStatus.contactShared:
        bg = AppColors.success.withOpacity(0.1);
        fg = AppColors.success;
        label = '공개';
        break;
      case ApplicationStatus.rejected:
        bg = AppColors.textDisabled.withOpacity(0.1);
        fg = AppColors.textDisabled;
        label = '거절';
        break;
      case ApplicationStatus.withdrawn:
        bg = AppColors.textDisabled.withOpacity(0.1);
        fg = AppColors.textDisabled;
        label = '철회';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: GoogleFonts.notoSansKr(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textDisabled),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.notoSansKr(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _skillTag(String skill) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        skill,
        style: GoogleFonts.notoSansKr(
          fontSize: 11,
          color: AppColors.accent.withOpacity(0.7),
        ),
      ),
    );
  }

  Widget _licenseTag(String license) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.06),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_outlined,
              size: 12, color: AppColors.success.withOpacity(0.7)),
          const SizedBox(width: 3),
          Text(
            license,
            style: GoogleFonts.notoSansKr(
              fontSize: 11,
              color: AppColors.success.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo(ResumeProfile profile) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.success.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, size: 14, color: AppColors.success),
              const SizedBox(width: 6),
              Text(
                '연락처 공개됨',
                style: GoogleFonts.notoSansKr(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (profile.name.isNotEmpty)
            _contactRow('이름', profile.name),
          if (profile.phone.isNotEmpty)
            _contactRow('연락처', profile.phone),
          if (profile.email.isNotEmpty)
            _contactRow('이메일', profile.email),
        ],
      ),
    );
  }

  Widget _contactRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: GoogleFonts.notoSansKr(
                fontSize: 12,
                color: AppColors.textDisabled,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.notoSansKr(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRequestButton() {
    final isRequested =
        app.status == ApplicationStatus.contactRequested;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed:
            (isRequested || _requesting) ? null : _requestContact,
        icon: Icon(
          isRequested ? Icons.hourglass_top : Icons.mail_outline,
          size: 16,
        ),
        label: Text(isRequested ? '승인 대기중' : '연락처 요청'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: BorderSide(color: AppColors.accent.withOpacity(0.3)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          textStyle: GoogleFonts.notoSansKr(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _calcCareerYears() {
    if (_resume == null || _resume!.experiences.isEmpty) return '신입';
    int totalMonths = 0;
    for (final exp in _resume!.experiences) {
      final startParts = exp.start.split('-');
      final endParts = exp.end == '재직중'
          ? [
              DateTime.now().year.toString(),
              DateTime.now().month.toString()
            ]
          : exp.end.split('-');
      if (startParts.length >= 2 && endParts.length >= 2) {
        try {
          totalMonths += (int.parse(endParts[0]) - int.parse(startParts[0])) *
                  12 +
              (int.parse(endParts[1]) - int.parse(startParts[1]));
        } catch (_) {}
      }
    }
    final years = totalMonths ~/ 12;
    return years > 0 ? '${years}년차' : '신입';
  }
}
