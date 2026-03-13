import 'package:flutter/material.dart';
import '../../services/career_profile_service.dart';
import '../../features/resume/screens/resume_home_screen.dart';
import '../../features/resume/screens/my_applications_screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_primary_card.dart';
import '../../core/widgets/app_segmented_control.dart';
import '../../core/widgets/app_badge.dart';
import 'career_shared.dart';
import 'career_identity_section.dart';
import 'career_skill_section.dart';
import 'career_network_section.dart';
import 'career_stage_section.dart';

/// 커리어 탭 소탭바 (AppSegmentedControl 전용 헤더)
///
/// 타이틀·인포·설정은 JobListingsScreen 내 스크롤 영역으로 이동했으므로
/// 이 위젯은 소탭('공고 보기' / '커리어 카드')만 렌더링합니다.
class CareerTabHeader extends StatelessWidget {
  const CareerTabHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSegmentedControl(
      controller: DefaultTabController.of(context),
      labels: const ['공고 보기', '커리어 카드'],
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
    return Column(
      children: [
        // 소탭바: 공고 보기 ↔ 커리어 카드 전환
        const CareerTabHeader(),
        Expanded(
          child: _buildBody(context),
        ),
      ],
    );
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
                identity == null
                    ? const CareerIdentityEmptyCard()
                    : CareerIdentityFilledCard(
                        identity: identity,
                        totalCareerMonths: totalCareerMonths,
                        autoMonths: autoMonths,
                      ),
                const SizedBox(height: AppSpacing.xl),
                // ── 스킬 카드 섹션 헤더 ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const CareerSectionTitle('나의 스킬 카드'),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => CareerSkillEditSheet.show(context),
                      child: AppBadge(
                        label: '관리',
                        bgColor: AppColors.accent.withOpacity(0.12),
                        textColor: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (enabledSkills.isEmpty)
                  CareerSkillEmptyState(
                    onTap: () => CareerSkillEditSheet.show(context),
                  )
                else ...[
                  ...previewSkills.map((m) {
                    final state = skillsMap[m['id']] ?? {};
                    final level = (state['level'] as int?) ?? 1;
                    final recommended = state['recommendedLevel'] as int?;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CareerSkillCard(
                        info: CareerSkillInfo(
                          id: m['id'] as String,
                          title: m['title'] as String,
                          icon: iconFromSkillName(m['icon'] as String),
                          level: level,
                          recommended: recommended,
                        ),
                        skillsMap: skillsMap,
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
                            color: AppColors.textSecondary, // 이전 kCText.withOpacity(0.7)
                          ),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: AppSpacing.xl),
                const CareerSectionTitle('커리어 단계'),
                const SizedBox(height: 10),
                CareerStageCard(
                  totalCareerMonths: totalCareerMonths,
                  totalClinics: entries.length,
                  skillsLv4Count:
                      skillsMap.values
                          .where(
                            (s) =>
                                s['enabled'] == true &&
                                ((s['level'] as int?) ?? 1) >= 4,
                          )
                          .length,
                ),
                const SizedBox(height: AppSpacing.xl),
                const _ResumeShortcutCard(),
                const SizedBox(height: AppSpacing.md),
                const _ApplicationsShortcutCard(),
                const SizedBox(height: 14),
                const CareerNetworkCard(),
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
        CareerLoadingCard(height: 110),
        SizedBox(height: 14),
        CareerLoadingCard(height: 130),
        SizedBox(height: 14),
        CareerLoadingCard(height: 80),
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

// ═══════════════════════════════════════════════════════════
// 이력서 바로가기 카드
// ═══════════════════════════════════════════════════════════
class _ResumeShortcutCard extends StatelessWidget {
  const _ResumeShortcutCard();

  @override
  Widget build(BuildContext context) {
    return AppPrimaryCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ResumeHomeScreen()),
      ),
      child: Row(
        children: [
          Builder(
            builder: (ctx) {
              final iconBox =
                  (MediaQuery.of(ctx).size.width * 0.095).clamp(34.0, 48.0);
              return Container(
                width: iconBox,
                height: iconBox,
                decoration: BoxDecoration(
                  // Blue 카드 내부 아이콘박스 — onCardPrimary(White) 반투명 허용
                  color: AppColors.onCardPrimary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.description_outlined,
                  color: AppColors.onCardPrimary,
                  size: iconBox * 0.55,
                ),
              );
            },
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '내 이력서',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onCardPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '이력서를 작성하고 공고에 빠르게 지원해요',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.onCardPrimary.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: AppColors.onCardPrimary.withOpacity(0.7),
            size: 20,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 내 지원 내역 바로가기 카드
// ═══════════════════════════════════════════════════════════
class _ApplicationsShortcutCard extends StatelessWidget {
  const _ApplicationsShortcutCard();

  @override
  Widget build(BuildContext context) {
    return AppPrimaryCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyApplicationsScreen()),
      ),
      child: Row(
        children: [
          Builder(
            builder: (ctx) {
              final iconBox =
                  (MediaQuery.of(ctx).size.width * 0.095).clamp(34.0, 48.0);
              return Container(
                width: iconBox,
                height: iconBox,
                decoration: BoxDecoration(
                  color: AppColors.onCardPrimary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.work_outline,
                  color: AppColors.onCardPrimary,
                  size: iconBox * 0.55,
                ),
              );
            },
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '내 지원 내역',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onCardPrimary, // onAccent → onCardPrimary 통일
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '지원한 공고의 진행 상태를 확인해요',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.onCardPrimary.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: AppColors.onCardPrimary.withOpacity(0.7),
            size: 20,
          ),
        ],
      ),
    );
  }
}
