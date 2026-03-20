import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/job.dart';
import '../../../models/resume.dart';
import '../../../services/resume_service.dart';
import '../../../services/application_service.dart';
import '../../../core/theme/app_colors.dart';
import 'resume_preview_screen.dart';
import 'resume_home_screen.dart';

/// 지원 확인/수정 페이지
///
/// 설계서 2.2.3 기준:
/// 1. 상단 고정 배너: "아직 제출 전"
/// 2. 이력서 선택 드롭다운
/// 3. 지원용 미리보기
/// 4. 익명 공개 미리보기 (병원 시점)
/// 5. 공고별 추가 질문 (향후)
/// 6. 최종 제출 버튼
class ApplyConfirmScreen extends StatefulWidget {
  final Job job;
  const ApplyConfirmScreen({super.key, required this.job});

  @override
  State<ApplyConfirmScreen> createState() => _ApplyConfirmScreenState();
}

class _ApplyConfirmScreenState extends State<ApplyConfirmScreen> {
  List<Resume> _resumes = [];
  Resume? _selectedResume;
  bool _loading = true;
  bool _submitting = false;
  bool _alreadyApplied = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 이미 지원했는지 확인
    final applied = await ApplicationService.hasApplied(widget.job.id);

    // 내 이력서 목록 로드
    final resumes = await ResumeService.fetchMyResumes();

    if (mounted) {
      setState(() {
        _resumes = resumes;
        _alreadyApplied = applied;
        // 가장 최근 이력서를 기본 선택
        if (resumes.isNotEmpty) _selectedResume = resumes.first;
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedResume == null || _submitting) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showSnack('로그인이 필요합니다.');
      return;
    }

    // 필수 필드 검증
    final validation = _validateResume(_selectedResume!);
    if (validation != null) {
      _showSnack(validation);
      return;
    }

    setState(() => _submitting = true);

    final clinicId = ''; // TODO: job 문서에 clinicId 추가 후 매핑
    final result = await ApplicationService.submitApplication(
      jobId: widget.job.id,
      clinicId: clinicId,
      resumeId: _selectedResume!.id,
    );

    if (result != null) {
      // 포인트 적용
      if (mounted) {
        Navigator.pop(context, true);
        _showSnack('✅ 지원이 완료되었어요!');
      }
    } else {
      if (mounted) {
        setState(() => _submitting = false);
        _showSnack('이미 지원했거나 오류가 발생했어요.');
      }
    }
  }

  /// 필수 필드 검증
  String? _validateResume(Resume r) {
    if (r.profile == null || r.profile!.name.isEmpty) {
      return '이력서에 이름이 입력되지 않았어요.';
    }
    if (r.licenses.isEmpty && r.experiences.isEmpty && r.education.isEmpty) {
      return '면허, 경력, 학력 중 최소 1개를 입력해주세요.';
    }
    return null;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.appBg,
        appBar: AppBar(title: const Text('지원하기')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          '지원 확인',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 1. 아직 제출 전 배너 ──
          _buildBanner(),
          const SizedBox(height: 16),

          // ── 공고 요약 ──
          _buildJobSummary(),
          const SizedBox(height: 16),

          // ── 2. 이력서 선택 ──
          _buildResumeSelector(),
          const SizedBox(height: 16),

          // ── 3. 선택한 이력서 미리보기 링크들 ──
          if (_selectedResume != null) ...[
            _buildPreviewButtons(),
            const SizedBox(height: 16),

            // ── 4. 익명 프로필 미리보기 (inline) ──
            _buildAnonymousPreview(),
          ],

          const SizedBox(height: 24),

          // ── 5. 이미 지원한 경우 안내 ──
          if (_alreadyApplied)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppColors.warning),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '이미 지원한 공고예요. 중복 지원은 불가합니다.',
                      style: TextStyle(fontSize: 13, color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 40),
        ],
      ),
      // ── 6. 최종 제출 버튼 ──
      bottomNavigationBar: _buildSubmitBar(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 위젯 빌더들
  // ═══════════════════════════════════════════════════════════

  Widget _buildBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accent.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '지금은 아직 제출 전이에요.\n이력서를 확인한 뒤 하단의 제출하기를 눌러주세요.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.accent,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobSummary() {
    final job = widget.job;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            job.clinicName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            job.title,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          if (job.address.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, size: 13, color: AppColors.textDisabled),
                const SizedBox(width: 3),
                Text(
                  job.address,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textDisabled,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResumeSelector() {
    if (_resumes.isEmpty) {
      // 이력서가 없으면 만들기 유도
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.warning.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(Icons.description_outlined, size: 40,
                color: AppColors.textDisabled),
            const SizedBox(height: 12),
            Text(
              '등록된 이력서가 없어요',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '이력서를 먼저 작성해야 지원할 수 있어요.',
              style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ResumeHomeScreen(),
                  ),
                ).then((_) => _load()); // 돌아오면 새로고침
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('이력서 만들기'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '이력서 선택',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedResume?.id,
              items: _resumes.map((r) {
                final filled = _countFilled(r);
                return DropdownMenuItem(
                  value: r.id,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.title,
                          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '$filled/8',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (id) {
                if (id == null) return;
                setState(() {
                  _selectedResume = _resumes.firstWhere((r) => r.id == id);
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ResumePreviewScreen(resume: _selectedResume!),
                ),
              );
            },
            icon: const Icon(Icons.visibility_outlined, size: 16),
            label: const Text('지원용 미리보기'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: BorderSide(color: AppColors.accent.withOpacity(0.3)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              // DefaultTabController로 익명 탭을 자동 선택하는 방법 대신
              // 직접 탭 인덱스 1로 열기
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ResumePreviewScreen(
                    resume: _selectedResume!,
                    initialTab: 1,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.visibility_off_outlined, size: 16),
            label: const Text('익명 미리보기'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.success,
              side: BorderSide(color: AppColors.success.withOpacity(0.3)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnonymousPreview() {
    final r = _selectedResume!;
    final anonProfile = ApplicationService.buildAnonymousProfile(r);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_off, size: 16, color: AppColors.success),
              const SizedBox(width: 6),
              const Text(
                '병원에 보이는 익명 프로필',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _anonRow('표시명', anonProfile['displayName'] ?? '-'),
          _anonRow('경력', anonProfile['careerYears'] ?? '-'),
          _anonRow('지역', anonProfile['region'] ?? '-'),
          if ((anonProfile['workTypes'] as List?)?.isNotEmpty == true)
            _anonRow('근무형태',
                (anonProfile['workTypes'] as List).join(', ')),
          if ((anonProfile['skills'] as List?)?.isNotEmpty == true)
            _anonRow('스킬',
                (anonProfile['skills'] as List).join(', ')),
          if ((anonProfile['licensesHeld'] as List?)?.isNotEmpty == true)
            _anonRow('자격',
                (anonProfile['licensesHeld'] as List).join(', ')),

          const SizedBox(height: 10),
          Text(
            '* 이름, 연락처, 이메일은 지원 직후 병원에 공개되지 않아요.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.success.withOpacity(0.6),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _anonRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textDisabled,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitBar() {
    final canSubmit = _selectedResume != null &&
        !_alreadyApplied &&
        !_submitting;

    return Container(
      color: AppColors.white,
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: FilledButton(
        onPressed: canSubmit ? _submit : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          disabledBackgroundColor: AppColors.disabledBg,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _submitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: AppColors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                _alreadyApplied
                    ? '이미 지원 완료'
                    : _selectedResume == null
                        ? '이력서를 선택해주세요'
                        : '제출하기',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  int _countFilled(Resume r) {
    int count = 0;
    if (r.profile != null && r.profile!.name.isNotEmpty) count++;
    if (r.profile?.summary.isNotEmpty == true) count++;
    if (r.licenses.isNotEmpty) count++;
    if (r.experiences.isNotEmpty) count++;
    if (r.skills.isNotEmpty) count++;
    if (r.education.isNotEmpty) count++;
    if (r.trainings.isNotEmpty) count++;
    if (r.attachments.isNotEmpty) count++;
    return count;
  }
}

