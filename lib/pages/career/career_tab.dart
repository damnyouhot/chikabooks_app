import 'package:flutter/material.dart';
import '../../services/career_profile_service.dart';
import '../../features/resume/screens/resume_home_screen.dart';
import '../../features/resume/screens/my_applications_screen.dart';
import '../settings/settings_page.dart';
import 'career_shared.dart';
import 'career_identity_section.dart';
import 'career_skill_section.dart';
import 'career_network_section.dart';
import 'career_stage_section.dart';

// ── 커리어 탭 헤더 (탭바 포함) ────────────────────────────────
class CareerTabHeader extends StatelessWidget {
  const CareerTabHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = DefaultTabController.of(context);

    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        final isCareer = ctrl.index == 1;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 아이콘 바 (1~3탭과 동일한 구조) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.info_outline,
                      color: kCText.withOpacity(0.5),
                      size: 18,
                    ),
                    onPressed: () => _showInfoDialog(context),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.settings_outlined,
                      color: kCText.withOpacity(0.4),
                      size: 20,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
            // ── 타이틀 + 수정 버튼 ──
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 12),
              child: Row(
                children: [
                  const Text(
                    '커리어',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: kCText,
                    ),
                  ),
                  const Spacer(),
                  if (isCareer)
                    TextButton.icon(
                      onPressed: () => _showQuickEditSheet(context),
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: kCText.withOpacity(0.7),
                      ),
                      label: Text(
                        '수정',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kCText.withOpacity(0.8),
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            // ── 서브타이틀 ──
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 16),
              child: Text(
                isCareer ? '이 화면은 나만 볼 수 있어요.' : '지도와 목록으로 공고를 확인해요.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: kCText.withOpacity(0.65),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // ── 소탭바 (성장하기 탭바와 동일한 필 스타일) ──
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(
                color: kCShadow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDD3D8), width: 0.5),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDDD3D8).withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(3),
                dividerColor: Colors.transparent,
                labelColor: kCText,
                unselectedLabelColor: kCText.withOpacity(0.4),
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                tabs: const [Tab(text: '공고 보기'), Tab(text: '커리어 카드')],
              ),
            ),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text(
              '커리어 탭에 대해서',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            content: const SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '커리어 탭은 나만 볼 수 있는\n나만의 직업 기록 공간이에요.',
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '📋 커리어 카드',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '현재 재직 중인 치과, 직무 상태,\n전문 분야 태그와 총 경력을 한눈에 정리해요.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Color(0xFF666666),
                    ),
                  ),
                  SizedBox(height: 14),
                  Text(
                    '🧩 나의 스킬 카드',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '스케일링, 보철, 교정 등 내가 보유한 기술의\n현재 수준을 기록하고 체크 질문으로 측정할 수 있어요.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Color(0xFF666666),
                    ),
                  ),
                  SizedBox(height: 14),
                  Text(
                    '🏥 치과 네트워크',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '내가 거쳐온 치과들을 타임라인으로 기록해요.\n근무 기간, 획득 스킬, 태그를 함께 남길 수 있어요.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Color(0xFF666666),
                    ),
                  ),
                  SizedBox(height: 14),
                  Text(
                    '📈 커리어 단계',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '경력과 스킬을 바탕으로 나의 커리어 단계를 확인하고\n다음 단계까지 필요한 조건을 체크리스트로 볼 수 있어요.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Color(0xFF666666),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '모든 내용은 나만 볼 수 있으며\n언제든 자유롭게 수정할 수 있어요.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Color(0xFF888888),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('닫기'),
              ),
            ],
          ),
    );
  }

  void _showQuickEditSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 8, 8, 6),
                child: Text(
                  '무엇을 수정할까요?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kCText,
                  ),
                ),
              ),
              CareerEditSheetTile(
                icon: Icons.badge_outlined,
                title: '커리어 카드 수정',
                onTap: () {
                  Navigator.of(context).pop();
                  CareerIdentitySheet.show(context);
                },
              ),
              CareerEditSheetTile(
                icon: Icons.auto_awesome_outlined,
                title: '스킬 카드 수정',
                onTap: () {
                  Navigator.of(context).pop();
                  CareerSkillEditSheet.show(context);
                },
              ),
              CareerEditSheetTile(
                icon: Icons.timeline,
                title: '치과 네트워크 수정',
                onTap: () {
                  Navigator.of(context).pop();
                  DentalNetworkEditSheet.show(context);
                },
              ),
              CareerEditSheetTile(
                icon: Icons.stairs_outlined,
                title: '커리어 단계 안내',
                onTap: () {
                  Navigator.of(context).pop();
                  showCareerStageGuideSheet(context);
                },
              ),
              const Divider(height: 12),
              CareerEditSheetTile(
                icon: Icons.description_outlined,
                title: '내 이력서 관리',
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ResumeHomeScreen(),
                    ),
                  );
                },
              ),
              CareerEditSheetTile(
                icon: Icons.work_outline,
                title: '내 지원 내역',
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MyApplicationsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }
}

// ── 커리어 탭 메인 뷰 ──────────────────────────────────────────
class CareerTab extends StatelessWidget {
  const CareerTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: CareerProfileService.watchMyCareerProfile(),
      builder: (context, profileSnap) {
        // ── 최초 로딩 중 ──
        if (profileSnap.connectionState == ConnectionState.waiting) {
          return _buildLoadingShell();
        }
        // ── 에러 ──
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
            // 네트워크 로딩 중엔 entries를 빈 배열로 처리 (전체 로딩 방지)
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                identity == null
                    ? const CareerIdentityEmptyCard()
                    : CareerIdentityFilledCard(
                      identity: identity,
                      totalCareerMonths: totalCareerMonths,
                      autoMonths: autoMonths,
                    ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const CareerSectionTitle('나의 스킬 카드'),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => CareerSkillEditSheet.show(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: kCShadow.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '관리',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: kCText.withOpacity(0.7),
                          ),
                        ),
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
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: kCText.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 20),
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
                const SizedBox(height: 20),
                // ── 이력서 바로가기 ──
                _ResumeShortcutCard(),
                const SizedBox(height: 12),
                // ── 지원 내역 바로가기 ──
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
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ResumeHomeScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF4A90D9).withOpacity(0.07),
              const Color(0xFF4A90D9).withOpacity(0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF4A90D9).withOpacity(0.12),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF4A90D9).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.description_outlined,
                color: Color(0xFF4A90D9),
                size: 22,
              ),
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
                      color: kCText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '이력서를 작성하고 공고에 빠르게 지원해요',
                    style: TextStyle(
                      fontSize: 12,
                      color: kCText.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: kCText.withOpacity(0.3),
              size: 20,
            ),
          ],
        ),
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
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyApplicationsScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF4CAF50).withOpacity(0.07),
              const Color(0xFF4CAF50).withOpacity(0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF4CAF50).withOpacity(0.12),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.work_outline,
                color: Color(0xFF4CAF50),
                size: 22,
              ),
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
                      color: kCText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '지원한 공고의 진행 상태를 확인해요',
                    style: TextStyle(
                      fontSize: 12,
                      color: kCText.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: kCText.withOpacity(0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
