import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../models/clinic_profile.dart' show BizVerificationStatus, ClinicProfile;
import '../../../models/job_draft.dart';
import '../../../services/job_draft_service.dart';
import '../../publisher/services/clinic_profile_service.dart';
import '../../publisher/widgets/biz_license_upload_section.dart';
import '../../publisher/widgets/publisher_clinic_identity_section.dart';
import '../ui/job_post_form.dart';
import '../ui/job_post_preview.dart';

/// AI 초안 편집 페이지 (/post-job/edit/:draftId)
///
/// AI가 추출한 초안을 JobPostForm에 채운 상태로 보여주고,
/// 사용자가 수정 후 게시 단계로 넘어간다.
class JobDraftEditorPage extends StatefulWidget {
  final String draftId;
  const JobDraftEditorPage({super.key, required this.draftId});

  @override
  State<JobDraftEditorPage> createState() => _JobDraftEditorPageState();
}

class _JobDraftEditorPageState extends State<JobDraftEditorPage> {
  JobPostData _data = JobPostData();
  /// Firestore 반영 후에만 폼 마운트 — 빈 initialData로 TextEditingController 고정 방지
  bool _draftReady = false;
  String? _loadError;
  /// [JobPostData.toMap]에 없는 드래프트 메타 — 폼 임시저장 시 항상 병합
  Map<String, dynamic> _extraDraftFields = {};
  DateTime? _draftUpdatedAt;
  ClinicProfile? _selectedProfile;
  bool _isLoadingAi = false;
  /// [ClinicProfileService.ensureDefaultProfileForDraft] 완료 후 true
  bool _profileReady = false;
  String _editorStep = 'step1';
  String? _aiError;

  Map<String, dynamic> _persistExtraFromDraft(JobDraft d) {
    final m = <String, dynamic>{};
    if (d.currentStep != null && d.currentStep!.isNotEmpty) {
      m['currentStep'] = d.currentStep;
    }
    if (d.aiParseStatus != null && d.aiParseStatus!.isNotEmpty) {
      m['aiParseStatus'] = d.aiParseStatus;
    }
    if (d.sourceType != null && d.sourceType!.isNotEmpty) {
      m['sourceType'] = d.sourceType;
    }
    if (d.rawInputText != null && d.rawInputText!.trim().isNotEmpty) {
      m['rawInputText'] = d.rawInputText;
    }
    if (d.rawImageUrls.isNotEmpty) m['rawImageUrls'] = d.rawImageUrls;
    if (d.clinicProfileId != null && d.clinicProfileId!.isNotEmpty) {
      m['clinicProfileId'] = d.clinicProfileId;
    }
    if (d.editorStep != null && d.editorStep!.isNotEmpty) {
      m['editorStep'] = d.editorStep;
    }
    return m;
  }

  @override
  void initState() {
    super.initState();
    _loadDraftAndParse();
  }

  Future<void> _loadDraftAndParse() async {
    final draft = await JobDraftService.fetchDraft(widget.draftId);
    if (!mounted) return;
    if (draft == null) {
      setState(() {
        _draftReady = true;
        _loadError = '임시저장 초안을 찾을 수 없어요. 목록에서 다시 선택해 주세요.';
      });
      return;
    }

    final step = draft.currentStep ?? '';
    final aiStatus = draft.aiParseStatus ?? 'idle';
    final needsAi =
        step == 'input' && aiStatus != 'running' && aiStatus != 'done';

    // AI 분석이 필요하면 우측은 폼 대신 로딩만 (빈 폼 1프레임 노출 방지)
    if (needsAi) {
      setState(() => _isLoadingAi = true);
    }

    _applyDraftToData(draft);
    await _ensureProfile(draft);
    if (!mounted) return;

    if (needsAi) {
      await JobDraftService.saveDraft(
        draftId: widget.draftId,
        formData: {
          ..._persistExtraFromDraft(draft),
          'aiParseStatus': 'running',
        },
      );
      if (mounted) {
        setState(() {
          _extraDraftFields = {
            ..._extraDraftFields,
            'aiParseStatus': 'running',
          };
        });
      }

      if (!mounted) return;
      final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
      await _callAiParsing(
        sourceType: extra?['sourceType'] as String? ??
            draft.sourceType ?? 'text',
        rawText: draft.rawInputText ?? '',
        imageUrls: draft.rawImageUrls,
      );
    }
  }

  Future<void> _ensureProfile(JobDraft draft) async {
    setState(() => _profileReady = false);
    final p = await ClinicProfileService.ensureDefaultProfileForDraft(
      draftId: widget.draftId,
      existingClinicProfileId: draft.clinicProfileId,
    );
    if (!mounted) return;
    if (p == null) {
      setState(() {
        _profileReady = true;
        _loadError = '치과 프로필을 준비하지 못했어요. 잠시 후 다시 시도해 주세요.';
      });
      return;
    }
    setState(() {
      _selectedProfile = p;
      _profileReady = true;
      _extraDraftFields = {
        ..._extraDraftFields,
        'clinicProfileId': p.id,
      };
    });
  }

  void _applyDraftToData(JobDraft draft) {
    setState(() {
      _draftReady = true;
      _draftUpdatedAt = draft.updatedAt;
      _extraDraftFields = _persistExtraFromDraft(draft);
      _editorStep = draft.editorStep ?? 'step1';
      _data = JobPostData(
        clinicName: draft.clinicName,
        title: draft.title,
        role: draft.role,
        career: draft.career,
        employmentType: draft.employmentType,
        workHours: draft.workHours,
        salary: draft.salary,
        benefits: List.from(draft.benefits),
        description: draft.description,
        address: draft.address,
        contact: draft.contact,
        hospitalType: draft.hospitalType,
        chairCount: draft.chairCount,
        staffCount: draft.staffCount,
        workDays: List.from(draft.workDays),
        weekendWork: draft.weekendWork,
        nightShift: draft.nightShift,
        applyMethod: List.from(draft.applyMethod),
        isAlwaysHiring: draft.isAlwaysHiring,
        closingDate: draft.closingDate,
        subwayStationName: draft.subwayStationName,
        subwayLines: List.from(draft.subwayLines),
        walkingDistanceMeters: draft.walkingDistanceMeters,
        walkingMinutes: draft.walkingMinutes,
        exitNumber: draft.exitNumber,
        parking: draft.parking,
        lat: draft.lat,
        lng: draft.lng,
        tags: List.from(draft.tags),
      );
    });
  }

  Future<void> _callAiParsing({
    required String sourceType,
    required String rawText,
    required List<String> imageUrls,
  }) async {
    setState(() {
      _isLoadingAi = true;
      _aiError = null;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'parseJobImagesToForm',
      );
      final result = await callable.call({
        'imageUrls': imageUrls,
        'sourceType': sourceType,
        'rawText': rawText,
      });

      final res = Map<String, dynamic>.from(result.data as Map);
      if (!mounted) return;

      setState(() {
        _data = _data.copyWith(
          clinicName: _firstNonEmpty(res['clinicName'], _data.clinicName),
          title: _firstNonEmpty(res['title'], _data.title),
          role: _firstNonEmpty(res['role'], _data.role),
          career: _firstNonEmpty(res['career'], _data.career),
          employmentType: _firstNonEmpty(res['employmentType'], _data.employmentType),
          workHours: _firstNonEmpty(res['workHours'], _data.workHours),
          salary: _firstNonEmpty(res['salary'], _data.salary),
          benefits: (res['benefits'] as List?)?.cast<String>().where((s) => s.isNotEmpty).toList() ?? _data.benefits,
          description: _firstNonEmpty(res['description'], _data.description),
          address: _firstNonEmpty(res['address'], _data.address),
          contact: _firstNonEmpty(res['contact'], _data.contact),
          hospitalType: _firstNonEmptyNullable(res['hospitalType'], _data.hospitalType),
          workDays: (res['workDays'] as List?)?.cast<String>().where((s) => s.isNotEmpty).toList() ?? _data.workDays,
          weekendWork: _parseBool(res['weekendWork']) ?? _data.weekendWork,
          nightShift: _parseBool(res['nightShift']) ?? _data.nightShift,
        );
      });

      await JobDraftService.saveDraft(
        draftId: widget.draftId,
        formData: {
          ..._data.toMap(),
          ..._extraDraftFields,
          'currentStep': 'ai_generated',
          'aiParseStatus': 'done',
        },
      );
      if (mounted) {
        setState(() {
          _extraDraftFields = {
            ..._extraDraftFields,
            'currentStep': 'ai_generated',
            'aiParseStatus': 'done',
          };
        });
      }
    } catch (e) {
      await JobDraftService.saveDraft(
        draftId: widget.draftId,
        formData: {
          ..._extraDraftFields,
          'aiParseStatus': 'failed',
        },
      );
      if (mounted) {
        setState(() {
          _extraDraftFields = {
            ..._extraDraftFields,
            'aiParseStatus': 'failed',
          };
        });
      }
      if (mounted) {
        String msg = 'AI 분석 중 오류가 발생했어요. 직접 입력하셔도 됩니다.';
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('timeout') || errStr.contains('deadline')) {
          msg = 'AI 분석 시간이 초과했어요. 텍스트가 너무 길면 줄여서 다시 시도해 주세요.';
        } else if (errStr.contains('not-found') || errStr.contains('image')) {
          msg = '이미지를 불러올 수 없어요. 다른 이미지로 다시 시도해 주세요.';
        } else if (errStr.contains('network') || errStr.contains('unavailable')) {
          msg = '네트워크 오류가 발생했어요. 인터넷 연결을 확인해 주세요.';
        }
        setState(() => _aiError = msg);
      }
    } finally {
      if (mounted) setState(() => _isLoadingAi = false);
    }
  }

  String _firstNonEmpty(dynamic a, String fallback) {
    final s = a as String? ?? '';
    return s.isNotEmpty ? s : fallback;
  }

  String? _firstNonEmptyNullable(dynamic a, String? fallback) {
    final s = a as String? ?? '';
    return s.isNotEmpty ? s : fallback;
  }

  bool? _parseBool(dynamic v) {
    if (v is bool) return v;
    if (v is String) {
      final lower = v.toLowerCase().trim();
      if (lower.contains('있') || lower.contains('예') || lower == 'true' || lower == 'yes') return true;
      if (lower.contains('없') || lower.contains('아니') || lower == 'false' || lower == 'no') return false;
    }
    return null;
  }

  void _onDataChanged(JobPostData d) => setState(() => _data = d);

  Future<void> _setEditorStep(String step) async {
    setState(() => _editorStep = step);
    await JobDraftService.saveDraft(
      draftId: widget.draftId,
      formData: {
        ..._extraDraftFields,
        'editorStep': step,
      },
    );
    if (mounted) {
      setState(() {
        _extraDraftFields = {
          ..._extraDraftFields,
          'editorStep': step,
        };
      });
    }
  }

  Future<void> _goNextStep() async {
    if (_editorStep == 'step1') {
      await _setEditorStep('step2');
      return;
    }
    if (_editorStep == 'step2') {
      final pid = _selectedProfile?.id;
      if (pid != null) {
        final p = await ClinicProfileService.getProfile(pid);
        if (p != null && mounted) {
          setState(() {
            _selectedProfile = p;
            _data = _data.copyWith(
              clinicName: _data.clinicName.isEmpty
                  ? p.effectiveName
                  : _data.clinicName,
              address:
                  _data.address.isEmpty ? p.address : _data.address,
            );
          });
        }
      }
      await _setEditorStep('step3');
    }
  }

  void _goPrevStep() {
    if (_editorStep == 'step3') {
      _setEditorStep('step2');
    } else if (_editorStep == 'step2') {
      _setEditorStep('step1');
    }
  }

  Future<void> _goToPublish() async {
    final pid = _selectedProfile?.id;
    if (pid == null) return;
    final fresh = await ClinicProfileService.getProfile(pid);
    if (!mounted) return;
    if (fresh == null || !fresh.isBusinessVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '사업자 인증이 완료된 후 게시 단계로 이동할 수 있어요.',
            style: GoogleFonts.notoSansKr(fontSize: 14),
          ),
        ),
      );
      return;
    }
    setState(() => _selectedProfile = fresh);
    // 최종 데이터 저장
    await JobDraftService.saveDraft(
      draftId: widget.draftId,
      formData: {
        ..._data.toMap(),
        ..._extraDraftFields,
        'currentStep': 'review',
      },
    );
    if (mounted) context.push('/post-job/publish/${widget.draftId}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.webPublisherPageBg,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(child: _buildBodyAfterLoad()),
        ],
      ),
    );
  }

  Widget _buildBodyAfterLoad() {
    if (!_draftReady) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.accent),
            ),
            const SizedBox(height: 16),
            Text(
              '저장된 공고를 불러오는 중…',
              style: GoogleFonts.notoSansKr(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.error.withValues(alpha: 0.85)),
              const SizedBox(height: 16),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansKr(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/post-job/input'),
                child: Text(
                  '돌아가기',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (!_profileReady) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.accent),
            ),
            const SizedBox(height: 16),
            Text(
              '치과 프로필을 준비하는 중…',
              style: GoogleFonts.notoSansKr(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) {
          return _buildNarrowLayout();
        }
        return _buildWideLayout();
      },
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.canPop() ? context.pop() : context.go('/post-job/input'),
            icon: const Icon(Icons.arrow_back, size: 20, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 8),
          Text(
            '공고 편집',
            style: GoogleFonts.notoSansKr(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          if (_selectedProfile != null) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppPublisher.softRadius),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
              ),
              child: Text(
                _selectedProfile!.effectiveName,
                style: GoogleFonts.notoSansKr(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
          const Spacer(),
          SizedBox(
            height: AppPublisher.ctaHeight,
            child: ElevatedButton(
              onPressed: _goToPublish,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppPublisher.buttonRadius),
                ),
              ),
              child: Text(
                '게시 단계로',
                style: GoogleFonts.notoSansKr(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390),
                child: JobPostPreview(data: _data),
              ),
            ),
          ),
        ),
        Container(width: 1, color: AppColors.divider),
        Expanded(
          flex: 6,
          child: _buildFormSection(),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return _buildFormSection();
  }

  Widget _buildFormSection() {
    if (_isLoadingAi) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(60),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.accent),
              ),
              const SizedBox(height: 24),
              Text(
                'AI가 공고 내용을 분석하고 있어요...',
                style: GoogleFonts.notoSansKr(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '이미지·텍스트에서 치과 정보와 근무 조건을 추출합니다',
                style: GoogleFonts.notoSansKr(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final pid = _selectedProfile?.id;
    if (pid == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<ClinicProfile?>(
      stream: ClinicProfileService.watchProfile(pid),
      initialData: _selectedProfile,
      builder: (context, snap) {
        final profile = snap.data ?? _selectedProfile!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_aiError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        border: const Border(
                          left: BorderSide(color: AppColors.error, width: 3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              size: 18, color: AppColors.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _aiError!,
                              style: GoogleFonts.notoSansKr(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildVerificationStickyBanner(profile),
                  const SizedBox(height: 12),
                  _buildStepIndicator(),
                  const SizedBox(height: 20),
                  if (_editorStep == 'step1') _buildStep1Body(profile),
                  if (_editorStep == 'step2')
                    PublisherClinicIdentitySection(
                      profile: profile,
                      onSaved: () async {
                        final u =
                            await ClinicProfileService.getProfile(profile.id);
                        if (u != null && mounted) {
                          setState(() => _selectedProfile = u);
                        }
                      },
                    ),
                  if (_editorStep == 'step3')
                    JobPostForm(
                      key: ValueKey('editor_s3_${widget.draftId}'),
                      initialData: _data,
                      draftId: widget.draftId,
                      publisherWebStyle: true,
                      publisherWebEditorStep: 'step3',
                      extraDraftFields: _extraDraftFields,
                      initialDraftUpdatedAt: _draftUpdatedAt,
                      onDataChanged: _onDataChanged,
                      onDraftIdChanged: (_) {},
                      onSubmit: (_) async => _goToPublish(),
                    ),
                  const SizedBox(height: 28),
                  _buildStepNav(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerificationStickyBanner(ClinicProfile profile) {
    if (profile.isBusinessVerified) return const SizedBox.shrink();
    final bv = profile.businessVerification;
    final fr = bv.failReason;
    String msg;
    if (fr == 'nts_api_error') {
      msg = '인증 지연 중입니다. 잠시 후 다시 시도해 주세요.';
    } else if (bv.status == BizVerificationStatus.pendingAuto) {
      msg = '사업자 인증 진행 중입니다…';
    } else if (bv.status == BizVerificationStatus.manualReview) {
      msg = '사업자 정보를 검토 중입니다. 완료되면 알려 드릴게요.';
    } else if (bv.status == BizVerificationStatus.rejected) {
      msg = '사업자 인증에 실패했습니다. 등록증을 다시 올려 주세요.';
    } else {
      msg = '사업자 인증이 완료되면 게시할 수 있어요.';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.06),
        border: Border(
          left: BorderSide(color: AppColors.accent, width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: GoogleFonts.notoSansKr(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    const labels = ['자료 첨부', '치과 정보', '공고 상세'];
    final idx = _editorStep == 'step1'
        ? 0
        : _editorStep == 'step2'
            ? 1
            : 2;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: List.generate(3, (i) {
        final active = i == idx;
        final stepId = i == 0 ? 'step1' : i == 1 ? 'step2' : 'step3';
        return InkWell(
          onTap: () => _setEditorStep(stepId),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.accent.withValues(alpha: 0.12)
                  : AppColors.white,
              border: Border.all(
                color: active ? AppColors.accent : AppColors.divider,
              ),
              borderRadius: BorderRadius.circular(AppPublisher.softRadius),
            ),
            child: Text(
              '${i + 1}. ${labels[i]}',
              style: GoogleFonts.notoSansKr(
                fontSize: 12,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStep1Body(ClinicProfile profile) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final form = JobPostForm(
      key: ValueKey('editor_s1_${widget.draftId}'),
      initialData: _data,
      draftId: widget.draftId,
      publisherWebStyle: true,
      publisherWebEditorStep: 'step1',
      extraDraftFields: _extraDraftFields,
      initialDraftUpdatedAt: _draftUpdatedAt,
      onDataChanged: _onDataChanged,
      onDraftIdChanged: (_) {},
      onSubmit: (_) async => _goToPublish(),
    );
    final license = _buildLicenseSide(profile);
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: form),
          const SizedBox(width: 20),
          Expanded(child: license),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        form,
        const SizedBox(height: 20),
        license,
      ],
    );
  }

  Widget _buildLicenseSide(ClinicProfile profile) {
    if (profile.isBusinessVerified) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.05),
          border: Border(
            left: BorderSide(color: AppColors.accent, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_outlined, color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  '사업자 인증 완료',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '등록증은 내부 검증용이며 외부에 공개되지 않습니다.',
              style: GoogleFonts.notoSansKr(
                fontSize: 12,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    return BizLicenseUploadSection(
      profileId: profile.id,
      onCompleted: () async {
        final updated = await ClinicProfileService.getProfile(profile.id);
        if (updated != null && mounted) {
          setState(() => _selectedProfile = updated);
        }
      },
    );
  }

  Widget _buildStepNav() {
    return Row(
      children: [
        if (_editorStep != 'step1')
          OutlinedButton(
            onPressed: _goPrevStep,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppPublisher.buttonRadius),
              ),
            ),
            child: Text(
              '이전',
              style: GoogleFonts.notoSansKr(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        const Spacer(),
        if (_editorStep != 'step3')
          SizedBox(
            height: AppPublisher.ctaHeight,
            child: ElevatedButton(
              onPressed: _goNextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppPublisher.buttonRadius),
                ),
              ),
              child: Text(
                '다음',
                style: GoogleFonts.notoSansKr(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
