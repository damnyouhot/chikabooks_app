import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';

/// 사이드바 메뉴 항목 정의.
class ApplicantNavItem {
  const ApplicantNavItem({
    required this.label,
    required this.icon,
    required this.path,
    this.requiresAuth = false,
    this.comingSoon = false,
    this.exactMatch = false,
  });

  final String label;
  final IconData icon;
  final String path;
  final bool requiresAuth;

  /// "준비 중" 배지 노출 (라우트는 있어도 미완성인 항목)
  final bool comingSoon;

  /// 정확 매칭만 활성으로 인정.
  ///
  /// 예: 대시보드(`/me`) 항목은 prefix 매칭으로 두면 `/me/applications` 등
  /// 자식 경로에서도 활성으로 표시되어 두 메뉴가 동시에 강조된다.
  /// `exactMatch: true` 로 두면 currentPath 가 path 와 완전히 같을 때만 활성.
  final bool exactMatch;

  bool isActive(String currentPath) {
    if (path == '/') return currentPath == '/';
    if (exactMatch) return currentPath == path;
    return currentPath == path || currentPath.startsWith('$path/');
  }
}

/// 사이드바 섹션 (제목 + 항목들)
class ApplicantNavSection {
  const ApplicantNavSection({required this.title, required this.items});
  final String title;
  final List<ApplicantNavItem> items;
}

/// Phase 1 기준 사이드바 구성.
///
/// 라우트가 아직 없는 항목은 [ApplicantNavItem.comingSoon] 으로 표시하여
/// 클릭 시 가벼운 안내만 띄운다.
const List<ApplicantNavSection> kApplicantNavSections = [
  ApplicantNavSection(
    title: '공고',
    items: [
      ApplicantNavItem(
        label: '전체 공고',
        icon: Icons.work_outline_rounded,
        path: '/',
      ),
      ApplicantNavItem(
        label: '내 지원 내역',
        icon: Icons.send_outlined,
        path: '/me/applications',
        requiresAuth: true,
      ),
      ApplicantNavItem(
        label: '찜한 공고',
        icon: Icons.bookmark_border_rounded,
        path: '/me/bookmarks',
        requiresAuth: true,
      ),
    ],
  ),
  ApplicantNavSection(
    title: '내 정보',
    items: [
      ApplicantNavItem(
        label: '대시보드',
        icon: Icons.dashboard_outlined,
        path: '/me',
        requiresAuth: true,
        exactMatch: true,
      ),
      ApplicantNavItem(
        label: '이력서',
        icon: Icons.description_outlined,
        path: '/me/resumes',
        requiresAuth: true,
      ),
      ApplicantNavItem(
        label: '커리어 카드',
        icon: Icons.badge_outlined,
        path: '/me/profile',
        requiresAuth: true,
      ),
      ApplicantNavItem(
        label: '메시지',
        icon: Icons.chat_bubble_outline_rounded,
        path: '/me/messages',
        requiresAuth: true,
      ),
      ApplicantNavItem(
        label: '계정 설정',
        icon: Icons.settings_outlined,
        path: '/me/account',
        requiresAuth: true,
      ),
    ],
  ),
  ApplicantNavSection(
    title: '같이 · 성장',
    items: [
      ApplicantNavItem(
        label: '오늘의 퀴즈',
        icon: Icons.quiz_outlined,
        path: '/quiz',
      ),
      ApplicantNavItem(
        label: '보험정보',
        icon: Icons.policy_outlined,
        path: '/policy',
      ),
      ApplicantNavItem(
        label: '내 서재',
        icon: Icons.menu_book_outlined,
        path: '/books',
      ),
      ApplicantNavItem(
        label: '공감투표',
        icon: Icons.how_to_vote_outlined,
        path: '/bond/polls',
        requiresAuth: true,
      ),
      ApplicantNavItem(
        // 모바일 '같이' 탭의 정식 명칭과 일치 (lib/pages/bond_page.dart 참고).
        label: '속닥속닥',
        icon: Icons.forum_outlined,
        path: '/bond/qna',
        requiresAuth: true,
      ),
    ],
  ),
];

/// 좌측 사이드바.
///
/// - 펼침: 폭 [AppApplicant.sideNavWidth] / 라벨 + 아이콘 함께 노출.
/// - 좁은 폭에서는 [ApplicantWebShell] 이 Drawer 로 감싸서 사용.
class ApplicantSideNav extends StatelessWidget {
  const ApplicantSideNav({
    super.key,
    this.onItemTap,
  });

  /// 항목 클릭 시 부모(셸)에서 추가로 처리할 콜백 (예: Drawer 닫기)
  final void Function(ApplicantNavItem item)? onItemTap;

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;

    return Container(
      width: AppApplicant.sideNavWidth,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(right: BorderSide(color: AppColors.divider)),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          for (final section in kApplicantNavSections) ...[
            _SectionTitle(title: section.title),
            ...section.items.map(
              (item) => _NavItemTile(
                item: item,
                active: item.isActive(currentPath),
                onTap: () {
                  if (item.comingSoon) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('"${item.label}"은(는) 준비 중이에요.'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    onItemTap?.call(item);
                    return;
                  }
                  context.go(item.path);
                  onItemTap?.call(item);
                },
              ),
            ),
            const SizedBox(height: AppApplicant.sideNavSectionGap),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(
        title,
        style: GoogleFonts.notoSansKr(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textDisabled,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _NavItemTile extends StatelessWidget {
  const _NavItemTile({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final ApplicantNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active
        ? AppColors.accent
        : (item.comingSoon ? AppColors.textDisabled : AppColors.textPrimary);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: active
            ? AppColors.accent.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: SizedBox(
            height: AppApplicant.sideNavItemHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(item.icon, size: 18, color: fg),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 13,
                        fontWeight:
                            active ? FontWeight.w800 : FontWeight.w600,
                        color: fg,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.comingSoon)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: Text(
                        '준비중',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
