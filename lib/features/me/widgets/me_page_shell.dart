import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart' show AppPublisher, AppRadius, AppSpacing;
import '../../../core/widgets/web_site_footer.dart';
import '../../auth/web/web_account_menu_button.dart';
import '../../jobs/web/web_typography.dart';
import 'me_branch_switcher.dart';

/// /me 셸 — 상단 헤더 + 좌(콘텐츠) / 우(사이드 메뉴) + 하단 푸터
///
/// 기존 [JobPostWebPage] 의 좌-프리뷰/우-폼 패턴을 그대로 차용하되,
/// 사용자 결정에 따라 **콘텐츠는 좌측**, **메뉴(네비)는 우측**에 둔다.
///
/// 모바일/좁은 화면은 메뉴를 상단 가로 스크롤 칩으로 폴백한다.
class MePageShell extends StatefulWidget {
  const MePageShell({
    super.key,
    required this.title,
    required this.activeMenuId,
    required this.child,
    this.hideBranchSwitcher = false,
  });

  /// 콘텐츠 영역 상단에 표시할 페이지 제목 (예: '한눈에 보기')
  final String title;

  /// 우측 사이드 메뉴에서 활성으로 표시할 항목 id ([_MeMenuItem] 참조)
  final String activeMenuId;

  /// 좌측 콘텐츠 영역에 들어갈 위젯
  final Widget child;

  /// 헤더의 [MeBranchSwitcher] 표시 여부.
  ///
  /// "보기 기준(지점 필터)" 이 의미가 없는 페이지는 true 로 해서 사용자 혼란을 막는다.
  final bool hideBranchSwitcher;

  static const double sideMenuWidth = 260;
  static const double maxContentWidth = 860;

  /// 우측 사이드 메뉴 표시 가능 여부 판단 기준 폭
  static const double wideBreakpoint = 1080;

  @override
  State<MePageShell> createState() => _MePageShellState();
}

/// 처음부터 다시 짠 layout (Option 1).
///
/// 구조:
///   Scaffold
///   └ Column (vertical)
///       ├ Header                      (intrinsic height)
///       ├ NarrowMenuStrip             (narrow only)
///       ├ Expanded
///       │   └ Row                     (wide only; narrow 은 본문만)
///       │       ├ Expanded ← 본문 (SingleChildScrollView)
///       │       └ SizedBox(width:260) ← 사이드 메뉴
///       └ Footer                      (intrinsic height)
///
/// 핵심:
///   - Stack/Positioned 사용 X — paint order 협상 회피
///   - wide 에서 Row 안의 Expanded(본문) + SizedBox(메뉴) 만 사용
///     → SizedBox 가 fixed width 라 Expanded 가 항상 정확히 (parentW - 260)
///       을 받음
///   - 본문 안에서만 Center + ConstrainedBox(maxWidth:860) 로 가운데 정렬
class _MePageShellState extends State<MePageShell> {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= MePageShell.wideBreakpoint;

    return Theme(
      data: WebTypo.themeData(Theme.of(context)),
      child: Scaffold(
        backgroundColor: AppColors.appBg,
        body: Column(
          children: [
            _Header(hideBranchSwitcher: widget.hideBranchSwitcher),
            if (!isWide) _NarrowMenuStrip(activeMenuId: widget.activeMenuId),
            Expanded(
              child: isWide
                  ? LayoutBuilder(
                      builder: (ctx, constraints) {
                        final totalW = constraints.maxWidth;
                        final menuW = MePageShell.sideMenuWidth;
                        final contentW = (totalW - menuW).clamp(0.0, totalW);
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            SizedBox(
                              width: contentW,
                              child: _ContentArea(
                                title: widget.title,
                                child: widget.child,
                              ),
                            ),
                            SizedBox(
                              width: menuW,
                              child: DecoratedBox(
                                decoration: const BoxDecoration(
                                  color: AppColors.white,
                                  border: Border(
                                    left: BorderSide(
                                        color: AppColors.divider, width: 0.8),
                                  ),
                                ),
                                child: _SideMenu(
                                    activeMenuId: widget.activeMenuId),
                              ),
                            ),
                          ],
                        );
                      },
                    )
                  : _ContentArea(
                      title: widget.title,
                      child: widget.child,
                    ),
            ),
            const WebSiteFooter(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 28),
            ),
          ],
        ),
      ),
    );
  }
}

/// 본문 영역 — narrow / wide 공통 사용.
///
/// 부모는 항상 horizontal/vertical 모두 tight 한 constraints 를 줌
/// (narrow: Expanded 가 Column 안에서, wide: Row 안의 Expanded 안에서).
/// 따라서 SingleChildScrollView 로 vertical 만 풀고, Center + ConstrainedBox
/// 로 가운데 정렬 + 최대 폭 제한.
class _ContentArea extends StatelessWidget {
  const _ContentArea({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: MePageShell.maxContentWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: WebTypo.heading(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.lg),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

// ── 상단 헤더 ───────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({this.hideBranchSwitcher = false});

  final bool hideBranchSwitcher;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 18),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(AppPublisher.softRadius),
            ),
            child: const Icon(
              Icons.local_hospital_outlined,
              size: 20,
              color: AppColors.white,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '하이진랩 · 내 정보',
            style: WebTypo.heading(color: AppColors.textPrimary),
          ),
          const SizedBox(width: 16),
          // 활성 지점 셀렉터 — 의미 없는 페이지에서는 숨김
          if (!hideBranchSwitcher)
            const Flexible(child: MeBranchSwitcher())
          else
            const SizedBox.shrink(),
          const Spacer(),
          TextButton.icon(
            onPressed: () => context.go('/post-job/input'),
            icon: const Icon(Icons.edit_note, size: 16),
            label: const Text('공고 등록으로'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
          if (kIsWeb) ...[
            const SizedBox(width: 4),
            const WebAccountMenuButton(),
          ],
        ],
      ),
    );
  }
}

// ── 우측 사이드 메뉴 (1080px 이상) ────────────────────────
class _SideMenu extends StatelessWidget {
  const _SideMenu({required this.activeMenuId});

  final String activeMenuId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        for (final item in _MeMenuItem.all) ...[
          _SideMenuTile(
            item: item,
            active: item.id == activeMenuId,
          ),
          const SizedBox(height: 4),
        ],
        const SizedBox(height: 16),
        const Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: 16),
        _UpcomingDashboardCard(),
      ],
    );
  }
}

class _SideMenuTile extends StatelessWidget {
  const _SideMenuTile({required this.item, required this.active});

  final _MeMenuItem item;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.accent : AppColors.textSecondary;
    final bg = active ? AppColors.accent.withOpacity(0.08) : Colors.transparent;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => context.go(item.route),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(item.icon, size: 18, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 좁은 화면용 상단 가로 메뉴 ──────────────────────────
class _NarrowMenuStrip extends StatelessWidget {
  const _NarrowMenuStrip({required this.activeMenuId});

  final String activeMenuId;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final item in _MeMenuItem.all)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _NarrowMenuChip(
                  item: item,
                  active: item.id == activeMenuId,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NarrowMenuChip extends StatelessWidget {
  const _NarrowMenuChip({required this.item, required this.active});

  final _MeMenuItem item;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon,
              size: 14,
              color: active ? AppColors.accent : AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(item.label),
        ],
      ),
      selected: active,
      onSelected: (_) => context.go(item.route),
      selectedColor: AppColors.accent.withOpacity(0.12),
      backgroundColor: AppColors.appBg,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
        color: active ? AppColors.accent : AppColors.textSecondary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color:
              active ? AppColors.accent.withOpacity(0.4) : AppColors.divider,
        ),
      ),
    );
  }
}

// ── 사이드 메뉴 하단: 광고 대시보드 티저 ──────────────
class _UpcomingDashboardCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardPrimary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, size: 16, color: AppColors.onCardPrimary),
              const SizedBox(width: 6),
              Text(
                '곧 출시',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onCardPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '광고 성과 대시보드',
            style: WebTypo.sectionTitle(color: AppColors.onCardPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            '시장 평균과 비교, 5단 깔때기, AI 코칭까지\n타사에 없던 인사이트를 준비하고 있어요.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: AppColors.onCardPrimary.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 메뉴 정의 ───────────────────────────────────────────
class _MeMenuItem {
  final String id;
  final String label;
  final IconData icon;
  final String route;

  const _MeMenuItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.route,
  });

  /// 사이드바·상단 칩에 노출되는 순서대로 정의
  static const all = <_MeMenuItem>[
    _MeMenuItem(
      id: 'overview',
      label: '한눈에 보기',
      icon: Icons.dashboard_outlined,
      route: '/me',
    ),
    _MeMenuItem(
      id: 'clinic',
      label: '병원 정보',
      icon: Icons.local_hospital_outlined,
      route: '/me/clinic',
    ),
    _MeMenuItem(
      id: 'billing',
      label: '공고권 / 충전',
      icon: Icons.confirmation_number_outlined,
      route: '/me/billing',
    ),
    _MeMenuItem(
      id: 'orders',
      label: '결제·세금계산서',
      icon: Icons.receipt_long_outlined,
      route: '/me/orders',
    ),
    _MeMenuItem(
      id: 'applicants',
      label: '인재풀',
      icon: Icons.groups_outlined,
      route: '/me/applicants',
    ),
    _MeMenuItem(
      id: 'notifications',
      label: '알림 설정',
      icon: Icons.notifications_outlined,
      route: '/me/notifications',
    ),
    _MeMenuItem(
      id: 'account',
      label: '계정 설정',
      icon: Icons.settings_outlined,
      route: '/me/account',
    ),
  ];
}
