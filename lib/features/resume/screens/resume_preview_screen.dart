import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_muted_card.dart';
import '../../../models/resume.dart';
import '../widgets/resume_skill_presets.dart';
import '../../auth/web/web_account_menu_button.dart';

/// 이력서 미리보기 화면
///
/// 탭 2개: [지원용 미리보기] / [공개용(익명) 미리보기]
class ResumePreviewScreen extends StatefulWidget {
  final Resume resume;
  final int initialTab;
  const ResumePreviewScreen({super.key, required this.resume, this.initialTab = 0});

  @override
  State<ResumePreviewScreen> createState() => _ResumePreviewScreenState();
}

class _ResumePreviewScreenState extends State<ResumePreviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          widget.resume.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [if (kIsWeb) const WebAccountMenuButton()],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textDisabled,
          indicatorColor: AppColors.accent,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: '지원용 미리보기'),
            Tab(text: '익명 미리보기'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildFullPreview(widget.resume, anonymous: false),
          _buildFullPreview(widget.resume, anonymous: true),
        ],
      ),
    );
  }

  Widget _buildFullPreview(Resume r, {required bool anonymous}) {
    final profile = r.profile;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // ── 익명 모드 안내 배너 ──
        if (anonymous)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                const Icon(Icons.visibility_off, size: 18, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '병원이 지원 직후 처음 보게 될 화면이에요.\n개인 식별정보(이름, 연락처)는 마스킹됩니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.success.withOpacity(0.8),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // ── 프로필 사진 + 인적사항(기본정보) ──
        _buildProfileHeader(profile, anonymous: anonymous),

        // ── A. 학력 ──
        if (r.education.isNotEmpty)
          _PreviewSection(
            title: '학력',
            icon: Icons.school_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < r.education.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.divider.withValues(alpha: 0.55),
                      ),
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.education[i].school,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${r.education[i].major}'
                        '${r.education[i].gradYear != null ? ' · ${r.education[i].gradYear}년 졸업' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textDisabled,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

        // ── B. 경력 (한 카드 · 항목마다 구분선) ──
        if (r.experiences.isNotEmpty)
          _PreviewSection(
            title: '경력',
            icon: Icons.work_outline,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < r.experiences.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.divider.withValues(alpha: 0.55),
                      ),
                    ),
                  _ExperiencePreviewBlock(
                    experience: r.experiences[i],
                    anonymous: anonymous,
                    mask: _mask,
                  ),
                ],
              ],
            ),
          ),

        // ── C. 스킬 (임상 / 소프트·기타 / 코멘트) ──
        if (r.skills.isNotEmpty ||
            (profile?.clinicalSkillsComment.isNotEmpty == true) ||
            (profile?.softSkillsComment.isNotEmpty == true))
          _PreviewSection(
            title: '스킬',
            icon: Icons.auto_awesome_outlined,
            child: _buildSkillsPreviewBlock(r, profile),
          ),

        // ── E. 자기소개 ──
        if (profile?.summary.isNotEmpty == true)
          _PreviewSection(
            title: '자기소개',
            icon: Icons.edit_note,
            child: Text(
              profile!.summary,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.65,
              ),
            ),
          ),

        // ── F. 면허/자격 ──
        if (r.licenses.isNotEmpty)
          _PreviewSection(
            title: '면허 / 자격',
            icon: Icons.verified_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: r.licenses
                  .map((l) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              l.has ? Icons.check_circle : Icons.circle_outlined,
                              size: 16,
                              color: l.has ? AppColors.success : AppColors.textDisabled,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l.type,
                              style: TextStyle(
                                fontSize: 13,
                                color: l.has
                                    ? AppColors.textPrimary
                                    : AppColors.textDisabled,
                                fontWeight:
                                    l.has ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),

        // ── G. 보수교육 ──
        if (r.trainings.isNotEmpty)
          _PreviewSection(
            title: '보수교육 / 세미나',
            icon: Icons.menu_book_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: r.trainings
                  .map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${t.title} · ${t.org}'
                          '${t.hours != null ? ' (${t.hours}시간)' : ''}'
                          '${t.year != null ? ' · ${t.year}' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),

        // ── H. 첨부파일 ──
        if (r.attachments.isNotEmpty)
          _PreviewSection(
            title: '첨부파일',
            icon: Icons.attach_file,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: r.attachments
                  .map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.insert_drive_file_outlined,
                              size: 16,
                              color: AppColors.accent.withOpacity(0.5),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${a.title} (${a.type})',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),

        const SizedBox(height: 40),
      ],
    );
  }

  /// 스킬 미리보기: 작성 화면과 동일하게 임상 / 소프트·기타 구분
  Widget _buildSkillsPreviewBlock(Resume r, ResumeProfile? profile) {
    final clinical = <ResumeSkill>[];
    final soft = <ResumeSkill>[];
    final other = <ResumeSkill>[];
    for (final s in r.skills) {
      if (ResumeSkillPresets.isClinicalSkillId(s.id, s.name)) {
        clinical.add(s);
      } else if (ResumeSkillPresets.isSoftSkillId(s.id, s.name)) {
        soft.add(s);
      } else {
        other.add(s);
      }
    }
    final cc = profile?.clinicalSkillsComment ?? '';
    final sc = profile?.softSkillsComment ?? '';

    final hasClinicalBlock = clinical.isNotEmpty || cc.isNotEmpty;
    final hasSoftBlock =
        soft.isNotEmpty || other.isNotEmpty || sc.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasClinicalBlock) ...[
          _skillPreviewSubheading('임상 스킬'),
          if (clinical.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              children: clinical.map((s) => _previewSkillChip(s)).toList(),
            ),
          ],
          if (cc.isNotEmpty) ...[
            SizedBox(height: clinical.isNotEmpty ? 12 : 0),
            _skillCommentCard('코멘트', cc),
          ],
        ],
        if (hasClinicalBlock && hasSoftBlock) ...[
          const SizedBox(height: 14),
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.divider.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 14),
        ],
        if (hasSoftBlock) ...[
          _skillPreviewSubheading('소프트 스킬'),
          if (soft.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              children: soft.map((s) => _previewSkillChip(s)).toList(),
            ),
          ],
          if (other.isNotEmpty) ...[
            SizedBox(height: soft.isNotEmpty ? 10 : 8),
            Text(
              '직접 추가',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textDisabled,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              children: other.map((s) => _previewSkillChip(s)).toList(),
            ),
          ],
          if (sc.isNotEmpty) ...[
            SizedBox(height: (soft.isNotEmpty || other.isNotEmpty) ? 12 : 0),
            _skillCommentCard('코멘트', sc),
          ],
        ],
      ],
    );
  }

  Widget _previewSkillChip(ResumeSkill s) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: AppColors.accent.withValues(alpha: 0.15),
        radius: 10,
        child: Text(
          '${s.level}',
          style: const TextStyle(
            fontSize: 9,
            color: AppColors.accent,
          ),
        ),
      ),
      label: Text(s.name, style: const TextStyle(fontSize: 12)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 2),
    );
  }

  Widget _skillPreviewSubheading(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _skillCommentCard(String label, String body) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AppColors.divider.withValues(alpha: 0.65),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {double labelWidth = 58}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textDisabled,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(ResumeProfile? profile, {required bool anonymous}) {
    final photoUrl = anonymous ? null : profile?.selectedPhotoUrl;

    return AppMutedCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      radius: AppRadius.md,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 대표 사진 (3:4) — 인적사항 가독성을 위해 충분히 크게
          Container(
            width: 132,
            height: 176,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: AppColors.divider,
            ),
            child: photoUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _defaultAvatar(),
                    ),
                  )
                : _defaultAvatar(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(
                  '이름',
                  anonymous ? _mask(profile?.name ?? '') : (profile?.name ?? '-'),
                ),
                _infoRow(
                  '연락처',
                  anonymous ? '***-****-****' : (profile?.phone ?? '-'),
                ),
                _infoRow(
                  '이메일',
                  anonymous ? '****@****.com' : (profile?.email ?? '-'),
                ),
                _infoRow('지역', profile?.region ?? '-'),
                _infoRow(
                  '근무형태',
                  profile?.workTypes.isNotEmpty == true
                      ? profile!.workTypes.join(', ')
                      : '-',
                ),
                if (profile?.headline.isNotEmpty == true)
                  _infoRow('한줄소개', profile!.headline),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultAvatar() {
    return Center(
      child: Icon(
        Icons.person,
        size: 48,
        color: AppColors.textDisabled.withOpacity(0.5),
      ),
    );
  }

  /// 마스킹 유틸 (이름: 첫 글자만 보여줌)
  String _mask(String text) {
    if (text.isEmpty) return '-';
    if (text.length <= 1) return '*';
    return '${text[0]}${'*' * (text.length - 1)}';
  }
}

/// 경력 한 건 — 병원명(지역)은 지역 비어 있으면 괄호 생략
class _ExperiencePreviewBlock extends StatelessWidget {
  const _ExperiencePreviewBlock({
    required this.experience,
    required this.anonymous,
    required this.mask,
  });

  final ResumeExperience experience;
  final bool anonymous;
  final String Function(String) mask;

  @override
  Widget build(BuildContext context) {
    final e = experience;
    final clinic = anonymous ? mask(e.clinicName) : e.clinicName;
    final region = e.region.trim();
    final titleLine =
        region.isEmpty ? clinic : '$clinic ($region)';

    final period = '${e.start} ~ ${e.end}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                titleLine,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.35,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              period,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textDisabled,
              ),
            ),
          ],
        ),
        if (e.tasks.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: e.tasks
                .map(
                  (t) => Chip(
                    label: Text(t, style: const TextStyle(fontSize: 10)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                )
                .toList(),
          ),
        ],
        if (e.achievementsText?.isNotEmpty == true) ...[
          const SizedBox(height: 6),
          Text(
            '성과: ${e.achievementsText}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 섹션 카드 래퍼
// ═══════════════════════════════════════════════════════════
class _PreviewSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _PreviewSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AppMutedCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      radius: AppRadius.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.accent.withOpacity(0.6)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
