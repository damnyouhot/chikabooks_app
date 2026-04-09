import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_muted_button.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../models/resume.dart';
import '../../../services/resume_service.dart';
import '../../../services/resume_draft_service.dart';
import '../../../services/resume_prefill_service.dart';
import '../widgets/section_profile.dart';
import '../widgets/section_experiences.dart';
import '../widgets/section_skills.dart';
import '../widgets/section_education.dart';
import '../widgets/section_summary.dart';
import '../widgets/resume_inline_underline_field.dart';
import '../../auth/web/web_account_menu_button.dart';
import 'resume_preview_screen.dart';

/// 이력서 편집 화면
///
/// 상단에 섹션별 진행바가 있고, 각 섹션을 탭하면 해당 폼으로 스크롤.
/// 모든 변경은 자동 임시저장(Firestore update on blur/next).
class ResumeEditScreen extends StatefulWidget {
  final String resumeId;
  const ResumeEditScreen({super.key, required this.resumeId});

  @override
  State<ResumeEditScreen> createState() => _ResumeEditScreenState();
}

class _ResumeEditScreenState extends State<ResumeEditScreen> {
  Resume? _resume;
  bool _loading = true;
  int _currentSection = 0;
  bool _saving = false;
  bool _dirty = false; // 변경 사항 있음 표시
  String? _draftId; // 현재 임시저장 ID
  Timer? _autoSaveTimer;

  final _titleCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  // 섹션 정의: 기본정보 → 학력 → 경력 → 스킬 → 자기소개
  static const _sections = [
    _SectionDef(icon: Icons.person_outline, label: '기본정보'),
    _SectionDef(icon: Icons.school_outlined, label: '학력'),
    _SectionDef(icon: Icons.work_outline, label: '경력'),
    _SectionDef(icon: Icons.auto_awesome_outlined, label: '스킬'),
    _SectionDef(icon: Icons.edit_note, label: '자기소개'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
    // 자동 저장 타이머 (30초마다)
    _autoSaveTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _autoSaveDraft(),
    );
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    // 종료 전 마지막 자동 저장
    if (_dirty && _resume != null) {
      _autoSaveDraft();
    }
    _titleCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    Resume? r = await ResumeService.fetchResume(widget.resumeId);
    var prefillApplied = false;
    if (r != null) {
      final merged = await ResumePrefillService.mergeCareerSourcesIfNeeded(r);
      r = merged.$1;
      prefillApplied = merged.$2;
    }
    if (mounted) {
      setState(() {
        _resume = r;
        _loading = false;
        _titleCtrl.text = r?.title ?? Resume.kDefaultResumeTitle;
        if (prefillApplied) _dirty = true;
      });
      if (prefillApplied) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('가입·커리어 카드에 적어 둔 내용을 이력서에 자동으로 넣었어요. 저장하면 반영돼요.'),
              duration: Duration(seconds: 3),
            ),
          );
        });
      }
    }
    // 기존 드래프트가 있는지 확인
    final existing = await ResumeDraftService.findDraftForResume(
      widget.resumeId,
    );
    if (existing != null && mounted) {
      setState(() => _draftId = existing.id);
    }
  }

  /// 자동 임시저장 (변경 사항이 있을 때만)
  Future<void> _autoSaveDraft() async {
    if (!_dirty || _resume == null) return;

    try {
      final savedId = await ResumeDraftService.saveDraft(
        draftId: _draftId,
        title: _resume!.title,
        resumeId: widget.resumeId,
        data: _resume!.toMap(),
      );
      if (savedId != null && mounted) {
        _draftId = savedId;
        _dirty = false;
        debugPrint('✅ 자동 임시저장 완료');
      }
    } catch (e) {
      debugPrint('⚠️ 자동 임시저장 실패: $e');
    }
  }

  /// 이력서 전체 저장 (확정)
  Future<void> _save() async {
    if (_resume == null) return;
    debugPrint('💾 [ResumeEdit] _save() 진입 — resumeId: ${widget.resumeId}');
    setState(() => _saving = true);
    final success = await ResumeService.updateResume(_resume!);
    debugPrint('💾 [ResumeEdit] updateResume 결과: $success');

    // 확정 저장 후 드래프트 삭제
    if (_draftId != null) {
      await ResumeDraftService.deleteDraft(_draftId!);
      _draftId = null;
    }
    _dirty = false;

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '저장되었어요.' : '저장에 실패했어요. 다시 시도해주세요.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 제목 변경 콜백
  void _onTitleChanged(String title) {
    if (_resume == null) return;
    _resume = Resume(
      id: _resume!.id,
      ownerUid: _resume!.ownerUid,
      title: title,
      createdAt: _resume!.createdAt,
      updatedAt: _resume!.updatedAt,
      visibility: _resume!.visibility,
      profile: _resume!.profile,
      licenses: _resume!.licenses,
      experiences: _resume!.experiences,
      skills: _resume!.skills,
      education: _resume!.education,
      trainings: _resume!.trainings,
      attachments: _resume!.attachments,
    );
  }

  /// 섹션 데이터 업데이트 콜백 (각 섹션 위젯에서 호출)
  void _updateResume(Resume updated) {
    setState(() {
      _resume = updated;
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.appBg,
        appBar: AppBar(title: const Text('이력서 편집')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_resume == null) {
      return Scaffold(
        backgroundColor: AppColors.appBg,
        appBar: AppBar(title: const Text('이력서 편집')),
        body: const Center(child: Text('이력서를 찾을 수 없어요.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // ── 섹션 진행바 ──
          _buildSectionBar(),

          // ── 현재 섹션 폼 ──
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final targetWidth =
                    constraints.maxWidth > 680 ? 680.0 : constraints.maxWidth;
                return Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: targetWidth,
                    height: constraints.maxHeight,
                    child: _buildCurrentSection(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.white,
      elevation: 0,
      title: GestureDetector(
        onTap: () => _showTitleDialog(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _resume!.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.edit, size: 14, color: AppColors.textDisabled),
          ],
        ),
      ),
      centerTitle: false,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      actions: [
        if (kIsWeb) const WebAccountMenuButton(),
        // 저장 버튼 (모든 섹션에서 항상 표시)
        TextButton(
          onPressed: _saving ? null : _save,
          child:
              _saving
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text(
                    '저장',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ResumePreviewScreen(resume: _resume!),
              ),
            );
          },
          child: const Text(
            '미리보기',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionBar() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.only(bottom: 8),
      child: SingleChildScrollView(
        controller: _scrollCtrl,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: List.generate(_sections.length, (i) {
            final s = _sections[i];
            final selected = i == _currentSection;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                avatar: Icon(
                  s.icon,
                  size: 16,
                  color: selected ? AppColors.onAccent : AppColors.textDisabled,
                ),
                label: Text(
                  s.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color:
                        selected ? AppColors.onAccent : AppColors.textSecondary,
                  ),
                ),
                selected: selected,
                selectedColor: AppColors.accent,
                backgroundColor: AppColors.white,
                side: BorderSide(
                  color: selected ? AppColors.accent : AppColors.divider,
                ),
                onSelected: (_) => setState(() => _currentSection = i),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCurrentSection() {
    final r = _resume!;
    switch (_currentSection) {
      case 0:
        return SectionProfile(
          profile: r.profile,
          onChanged: (p) => _updateResume(_copyWith(profile: p)),
        );
      case 1:
        return SectionEducation(
          education: r.education,
          onChanged: (e) => _updateResume(_copyWith(education: e)),
        );
      case 2:
        return SectionExperiences(
          experiences: r.experiences,
          onChanged: (e) => _updateResume(_copyWith(experiences: e)),
        );
      case 3:
        return SectionSkills(
          skills: r.skills,
          clinicalSkillsComment: r.profile?.clinicalSkillsComment ?? '',
          softSkillsComment: r.profile?.softSkillsComment ?? '',
          onSkillsChanged: (s) => _updateResume(_copyWith(skills: s)),
          onCommentsChanged: (clinical, soft) {
            final p = r.profile ?? const ResumeProfile();
            _updateResume(
              _copyWith(
                profile: p.copyWith(
                  clinicalSkillsComment: clinical,
                  softSkillsComment: soft,
                ),
              ),
            );
          },
        );
      case 4:
        return SectionSummary(
          resume: r,
          onSummaryChanged: (s) {
            final p = r.profile ?? const ResumeProfile();
            _updateResume(_copyWith(profile: p.copyWith(summary: s)));
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Resume _copyWith({
    ResumeProfile? profile,
    List<ResumeExperience>? experiences,
    List<ResumeSkill>? skills,
    List<ResumeEducation>? education,
  }) {
    final r = _resume!;
    return Resume(
      id: r.id,
      ownerUid: r.ownerUid,
      title: r.title,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
      visibility: r.visibility,
      profile: profile ?? r.profile,
      licenses: r.licenses,
      experiences: experiences ?? r.experiences,
      skills: skills ?? r.skills,
      education: education ?? r.education,
      trainings: r.trainings,
      attachments: r.attachments,
    );
  }

  Widget _buildBottomBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontal = screenWidth > 680 ? (screenWidth - 680) / 2 : 0.0;
    final side = horizontal > AppSpacing.xl ? horizontal : AppSpacing.xl;
    return Container(
      color: AppColors.white,
      padding: EdgeInsets.fromLTRB(
        side,
        AppSpacing.md,
        side,
        AppSpacing.md + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          // 이전
          if (_currentSection > 0)
            Expanded(
              child: AppMutedButton(
                onTap:
                    () => setState(() => _currentSection = _currentSection - 1),
                label: '이전',
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          if (_currentSection > 0) const SizedBox(width: 10),

          // 다음 / 저장
          Expanded(
            flex: 2,
            child: AppPrimaryButton(
              onPressed:
                  _saving
                      ? null
                      : _currentSection < _sections.length - 1
                      ? () => setState(() => _currentSection++)
                      : _save,
              label: _currentSection < _sections.length - 1 ? '다음' : '저장하기',
              isLoading: _saving,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _showTitleDialog() {
    _titleCtrl.text = _resume!.title;
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('이력서 제목'),
            content: ResumeInlineUnderlineField(
              label: '제목',
              hint: '예: 하이진랩에서 작성한 이력서, 교정 지원용',
              controller: _titleCtrl,
              autofocus: true,
              bottomPadding: 0,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () {
                  final t = _titleCtrl.text.trim();
                  if (t.isNotEmpty) {
                    _onTitleChanged(t);
                    ResumeService.updateTitle(widget.resumeId, t);
                    setState(() {});
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('확인'),
              ),
            ],
          ),
    );
  }
}

class _SectionDef {
  final IconData icon;
  final String label;
  const _SectionDef({required this.icon, required this.label});
}
