import 'package:flutter/material.dart';
import '../../services/career_profile_service.dart';
import '../../features/resume/screens/resume_home_screen.dart';
import '../../features/resume/screens/my_applications_screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_muted_card.dart';
import '../../core/widgets/app_segmented_control.dart';
import '../../core/widgets/app_badge.dart';
import 'career_shared.dart';
import 'career_identity_section.dart';
import 'career_skill_section.dart';
import 'career_network_section.dart';
import 'career_stage_section.dart';

/// 커리어 탭 소탭바 (AppSegmentedControl 전용 헤더)
///
/// 타이틀·인포·설정은 [job_page.dart]의 [_JobPageTitleBar]가 처리하며,
/// 이 위젯은 소탭('공고 보기' / '커리어 카드')만 렌더링합니다.
class CareerTabHeader extends StatelessWidget {
  const CareerTabHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSegmentedControl(
      controller: DefaultTabController.of(context),
      labels: const ['공고 보기', '커리어 카드'],
      wipIndices: const {0},
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xs,
      ),
    );
  }
}

// ── 커리어 탭 메인 뷰 ──────────────────────────────────────────
class CareerTab extends StatelessWidget {
  const CareerTab({super.key});

  @override
  Widget build(BuildContext context) {
    return _buildBody(context);
  }

  Widget _buildBody(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: CareerProfileService.watchMyCareerProfile(),
      builder: (context, profileSnap) {
        if (profileSnap.connectionState == ConnectionState.waiting) {
          return _buildLoadingShell();
        }
        if (profileSnap.hasError) {
          return _buildErrorShell('프로필 데이터를 불러오지 못했어요.');
        }

        final profile = profileSnap.data;
        final identity = profile?['identity'] as Map<String, dynamic>?;
        final skillsMap =
            (profile?['skills'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
            ) ??
            {};

        final enabledSkills =
            CareerProfileService.skillMaster
                .where((m) => skillsMap[m['id']]?['enabled'] == true)
                .toList();
        final previewSkills = enabledSkills.take(4).toList();
        final hasMore = enabledSkills.length > 4;

        return StreamBuilder<List<DentalNetworkEntry>>(
          stream: CareerProfileService.watchNetworkEntries(),
          builder: (context, networkSnap) {
            final entries = networkSnap.data ?? [];
            final autoMonths = entries.fold(0, (sum, e) => sum + e.months);

            final useOverride =
                identity?['useTotalCareerMonthsOverride'] == true;
            final overrideMonths =
                identity?['totalCareerMonthsOverride'] as int?;
            final totalCareerMonths =
                (useOverride && overrideMonths != null)
                    ? overrideMonths
                    : autoMonths;

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              children: [
                // ══════════════════════════════════════════
                // 1. 최상위 커리어 카드 (Blue — AppPrimaryCard)
                // ══════════════════════════════════════════
                _TopCareerCard(
                  identity: identity,
                  totalCareerMonths: totalCareerMonths,
                  autoMonths: autoMonths,
                ),
                const SizedBox(height: AppSpacing.lg),

                // ══════════════════════════════════════════
                // 2. 내 이력서 + 지원 내역 (가로 반반, Gray)
                // ══════════════════════════════════════════
                _ShortcutRow(),
                const SizedBox(height: AppSpacing.lg),

                // ══════════════════════════════════════════
                // 3. 나의 스킬 카드 (Gray)
                // ══════════════════════════════════════════
                _SkillSection(
                  enabledSkills: enabledSkills,
                  previewSkills: previewSkills,
                  hasMore: hasMore,
                  skillsMap: skillsMap,
                ),
                const SizedBox(height: AppSpacing.lg),

                // ══════════════════════════════════════════
                // 4. 커리어 단계 카드 + 치과 네트워크 통합 (Gray)
                // ══════════════════════════════════════════
                _StageAndNetworkCard(
                  totalCareerMonths: totalCareerMonths,
                  totalClinics: entries.length,
                  entries: entries,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingShell() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: const [
        CareerLoadingCard(height: 140),
        SizedBox(height: 14),
        CareerLoadingCard(height: 80),
        SizedBox(height: 14),
        CareerLoadingCard(height: 110),
        SizedBox(height: 14),
        CareerLoadingCard(height: 130),
      ],
    );
  }

  Widget _buildErrorShell(String message) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [CareerErrorCard(message: message)],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 1. 최상위 커리어 카드 — Blue(Primary) 배경
//    기존 CareerIdentityEmptyCard / CareerIdentityFilledCard 래핑
// ══════════════════════════════════════════════════════════════
class _TopCareerCard extends StatelessWidget {
  final Map<String, dynamic>? identity;
  final int totalCareerMonths;
  final int autoMonths;

  const _TopCareerCard({
    required this.identity,
    required this.totalCareerMonths,
    required this.autoMonths,
  });

  @override
  Widget build(BuildContext context) {
    // CareerCard(= AppPrimaryCard)를 그대로 활용하고 헤더 타이틀만 추가
    return CareerCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 섹션 라벨 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0,
            ),
            child: Text(
              '커리어 카드',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.onCardPrimary.withOpacity(0.55),
                letterSpacing: 0.5,
              ),
            ),
          ),
          // ── 기존 Identity 카드 내용 ──
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: identity == null
                ? _IdentityEmptyInner()
                : _IdentityFilledInner(
                    identity: identity!,
                    totalCareerMonths: totalCareerMonths,
                    autoMonths: autoMonths,
                  ),
          ),
        ],
      ),
    );
  }
}

/// 커리어 카드 빈 상태 내부 (Blue 배경 위에서 렌더)
class _IdentityEmptyInner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '내 커리어 카드',
              style: TextStyle(
                fontSize: 16,            // 기존 16 유지 (동일)
                fontWeight: FontWeight.w800,
                color: AppColors.onCardPrimary,
              ),
            ),
            const Spacer(),
            AppBadge(
              label: '채우기',
              bgColor: AppColors.onCardPrimary.withOpacity(0.2),
              textColor: AppColors.onCardPrimary,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '아직 비어 있어요',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.onCardPrimary.withOpacity(0.65),
          ),
        ),
        const SizedBox(height: 14),
        _PlaceholderRow(label: '현재 치과'),
        const SizedBox(height: 10),
        _PlaceholderRow(label: '총 경력'),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => CareerIdentitySheet.show(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cardEmphasis,
              foregroundColor: AppColors.onCardEmphasis,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: const Text(
              '지금 채우기',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaceholderRow extends StatelessWidget {
  final String label;
  const _PlaceholderRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.onCardPrimary.withOpacity(0.75),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.onCardPrimary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
        ),
      ],
    );
  }
}

/// 커리어 카드 채워진 상태 내부 (Blue 배경 위에서 렌더)
class _IdentityFilledInner extends StatelessWidget {
  final Map<String, dynamic> identity;
  final int totalCareerMonths;
  final int autoMonths;

  const _IdentityFilledInner({
    required this.identity,
    required this.totalCareerMonths,
    required this.autoMonths,
  });

  @override
  Widget build(BuildContext context) {
    final clinicName = (identity['clinicName'] as String?)?.trim() ?? '';
    final status = (identity['status'] as String?) ?? 'employed';
    final tags =
        (identity['specialtyTags'] as List?)?.cast<String>() ?? const [];
    final useOverride = identity['useTotalCareerMonthsOverride'] == true;

    final startTs = identity['currentStartDate'];
    String? currentDuration;
    if (status == 'employed' && startTs != null) {
      try {
        final start = (startTs as dynamic).toDate() as DateTime;
        final now = DateTime.now();
        final m = (now.year - start.year) * 12 + (now.month - start.month);
        currentDuration = formatCareerMonths(m < 1 ? 1 : m);
      } catch (_) {}
    }

    final titleLine = switch (status) {
      'leave' =>
        clinicName.isEmpty ? '잠시 쉬는 중' : '$clinicName · 잠시 쉬는 중',
      'unemployed' => '다음 치과를 기다리는 중',
      _ =>
        clinicName.isEmpty
            ? '(미입력)'
            : currentDuration != null
            ? '$clinicName · $currentDuration째'
            : clinicName,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 타이틀 행: titleLine + 유저분류 배지 + 수정 아이콘 ──
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                titleLine,
                style: const TextStyle(
                  fontSize: 16,            // 14 → 16 (다른 카드 타이틀과 통일)
                  fontWeight: FontWeight.w900,
                  color: AppColors.onCardPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // '치과위생사' 분류 배지 (기존 위 줄에서 이동)
            AppBadge(
              label: '치과위생사',
              bgColor: AppColors.onCardPrimary.withOpacity(0.15),
              textColor: AppColors.onCardPrimary,
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () => CareerIdentitySheet.show(context),
              icon: Icon(
                Icons.edit_outlined,
                color: AppColors.onCardPrimary.withOpacity(0.6),
                size: 18,
              ),
              tooltip: '수정',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              '총 경력: ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.onCardPrimary.withOpacity(0.6),
              ),
            ),
            Text(
              totalCareerMonths == 0
                  ? '미입력'
                  : formatCareerMonths(totalCareerMonths),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.onCardPrimary,
              ),
            ),
            if (useOverride) ...[
              const SizedBox(width: 4),
              AppBadge(
                label: '직접입력',
                bgColor: AppColors.onCardPrimary.withOpacity(0.2),
                textColor: AppColors.onCardPrimary.withOpacity(0.8),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '전문 분야',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.onCardPrimary.withOpacity(0.75),
          ),
        ),
        const SizedBox(height: 8),
        if (tags.isEmpty)
          Text(
            '아직 없어요',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.onCardPrimary.withOpacity(0.65),
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in tags)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.onCardPrimary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    t,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onCardPrimary,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 2. 이력서 + 지원내역 바로가기 — 가로 반반, Gray(Muted) 배경
// ══════════════════════════════════════════════════════════════
class _ShortcutRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _ShortcutCard(
            icon: Icons.description_outlined,
            label: '내 이력서',
            description: '이력서 작성 및 지원',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ResumeHomeScreen()),
            ),
          )),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _ShortcutCard(
            icon: Icons.work_outline,
            label: '지원 내역',
            description: '지원 공고 현황 확인',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyApplicationsScreen()),
            ),
          )),
        ],
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  const _ShortcutCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppMutedCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: AppColors.accent, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 3. 스킬 카드 섹션 — Gray(Muted) 배경
// ══════════════════════════════════════════════════════════════
class _SkillSection extends StatelessWidget {
  final List<Map<String, dynamic>> enabledSkills;
  final List<Map<String, dynamic>> previewSkills;
  final bool hasMore;
  final Map<String, Map<String, dynamic>> skillsMap;

  const _SkillSection({
    required this.enabledSkills,
    required this.previewSkills,
    required this.hasMore,
    required this.skillsMap,
  });

  @override
  Widget build(BuildContext context) {
    return AppMutedCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 헤더 ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const CareerSectionTitle('나의 스킬 카드'),
              const Spacer(),
              GestureDetector(
                onTap: () => CareerSkillEditSheet.show(context),
                child: AppBadge(
                  label: '관리',
                  bgColor: AppColors.emphasisBadgeBg,
                  textColor: AppColors.emphasisBadgeText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── 내용 ──
          if (enabledSkills.isEmpty)
            SizedBox(
              width: double.infinity,
              child: _SkillEmptyState(onTap: () => CareerSkillEditSheet.show(context)),
            )
          else ...[
            ...previewSkills.map((m) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CareerSkillCard(
                  info: CareerSkillInfo(
                    id: m['id'] as String,
                    title: m['title'] as String,
                    icon: iconFromSkillName(m['icon'] as String),
                  ),
                ),
              );
            }),
            if (hasMore)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => CareerSkillEditSheet.show(context),
                  child: Text(
                    '더보기 (${enabledSkills.length - 4}개)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// 스킬 빈 상태 (Muted 배경 위)
class _SkillEmptyState extends StatelessWidget {
  final VoidCallback onTap;
  const _SkillEmptyState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Icon(
          Icons.auto_awesome_outlined,
          size: 32,
          color: AppColors.textDisabled,
        ),
        const SizedBox(height: 10),
        const Text(
          '아직 스킬 카드가 없어요',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        const Text(
          '"관리"를 눌러 내 스킬을 추가해 보세요',
          style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
        ),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.onAccent,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl,
              vertical: AppSpacing.sm + 2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            elevation: 0,
          ),
          child: const Text(
            '스킬 추가하기',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 4. 커리어 단계 + 치과 네트워크 통합 카드 — Gray(Muted) 배경
// ══════════════════════════════════════════════════════════════
class _StageAndNetworkCard extends StatelessWidget {
  final int totalCareerMonths;
  final int totalClinics;
  final List<DentalNetworkEntry> entries;

  const _StageAndNetworkCard({
    required this.totalCareerMonths,
    required this.totalClinics,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    return AppMutedCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CareerSectionTitle('커리어 단계'),
          const SizedBox(height: 12),
          _StageContent(
            totalCareerMonths: totalCareerMonths,
            totalClinics: totalClinics,
          ),
          const SizedBox(height: AppSpacing.xl),
          // ── 구분선 ──
          const Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: AppSpacing.lg),
          // ── 치과 네트워크 ──
          _NetworkSection(entries: entries),
        ],
      ),
    );
  }
}

class _StageContent extends StatelessWidget {
  final int totalCareerMonths;
  final int totalClinics;

  const _StageContent({
    required this.totalCareerMonths,
    required this.totalClinics,
  });

  @override
  Widget build(BuildContext context) {
    return CareerStageCard(
      totalCareerMonths: totalCareerMonths,
      totalClinics: totalClinics,
    );
  }
}

/// 치과 네트워크 섹션 (Muted 배경 위에서 렌더)
class _NetworkSection extends StatefulWidget {
  final List<DentalNetworkEntry> entries;
  const _NetworkSection({required this.entries});

  @override
  State<_NetworkSection> createState() => _NetworkSectionState();
}

class _NetworkSectionState extends State<_NetworkSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    final totalClinics = entries.length;
    final totalMonths = entries.fold(0, (sum, e) => sum + e.months);
    final maxMonths = entries.isEmpty
        ? 1
        : entries.map((e) => e.months).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 헤더 ──
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Expanded(
                  child: CareerSectionTitle('나의 치과 네트워크'),
                ),
                IconButton(
                  onPressed: () => DentalNetworkEditSheet.show(context),
                  icon: const Icon(Icons.add, size: 18),
                  color: AppColors.textSecondary,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                  tooltip: '추가',
                ),
                const SizedBox(width: 2),
                Text(
                  _expanded ? '접기' : '펼치기',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        // ── 요약 텍스트 ──
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              totalClinics == 0
                  ? '아직 이력이 없어요  ·  탭해서 추가하기'
                  : '총 $totalClinics곳 · 총 ${formatCareerMonths(totalMonths)}',
              style: TextStyle(
                fontSize: 12,
                color: totalClinics == 0
                    ? AppColors.accent
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
        // ── 펼치기 내용 ──
        AnimatedCrossFade(
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
          firstChild: const SizedBox(height: 0),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: entries.isEmpty
                ? _NetworkEmptyHint(
                    onAdd: () => DentalNetworkEditSheet.show(context),
                  )
                : Column(
                    children: entries
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _NetworkTimelineItem(
                              entry: e,
                              maxMonths: maxMonths,
                              onEdit: () => DentalNetworkEditSheet.show(
                                context,
                                editing: e,
                              ),
                              onDelete: () => _confirmDelete(context, e),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    DentalNetworkEntry entry,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제하시겠어요?'),
        content: Text('"${entry.clinicName}" 이력을 삭제합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              '삭제',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await CareerProfileService.deleteNetworkEntry(entry.id);
    }
  }
}

class _NetworkEmptyHint extends StatelessWidget {
  final VoidCallback onAdd;
  const _NetworkEmptyHint({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '아직 이력이 없어요.\n첫 근무지를 추가하면 타임라인이 만들어져요.',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: onAdd,
            child: const Text('추가하기'),
          ),
        ],
      ),
    );
  }
}

class _NetworkTimelineItem extends StatelessWidget {
  final DentalNetworkEntry entry;
  final int maxMonths;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NetworkTimelineItem({
    required this.entry,
    required this.maxMonths,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final kMaxBarH = (screenH * 0.13).clamp(80.0, 130.0);
    final kMinBarH = (screenH * 0.035).clamp(22.0, 36.0);
    final barHeight =
        kMinBarH + (kMaxBarH - kMinBarH) * (entry.months / maxMonths);

    return Container(
      decoration: BoxDecoration(
        color: entry.isCurrent
            ? AppColors.accent.withOpacity(0.08)
            : AppColors.appBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: entry.isCurrent
              ? AppColors.accent.withOpacity(0.18)
              : AppColors.divider,
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 7,
            height: barHeight,
            margin: const EdgeInsets.only(top: 2, right: 12),
            decoration: BoxDecoration(
              color: entry.isCurrent
                  ? AppColors.accent
                  : AppColors.textDisabled,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.periodLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.clinicName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatCareerMonths(entry.months),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (entry.tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: entry.tags
                        .map(
                          (t) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.textDisabled.withOpacity(0.12),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                            ),
                            child: Text(
                              t,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                color: AppColors.textSecondary,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                padding: EdgeInsets.zero,
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 16),
                color: AppColors.error,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
