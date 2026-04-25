import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart' show AppRadius, AppSpacing;
import '../../jobs/web/web_typography.dart';
import '../providers/me_providers.dart';
import '../services/me_overview_service.dart';
import '../services/me_session.dart';
import '../widgets/me_page_shell.dart';

/// /me — 한눈에 보기 (Overview)
///
/// Sprint 1 범위:
///   - KPI 4종 (조회/유니크/지원/전환율, 누적 합산)
///   - To-Do 패널 (검수중 / 만료임박 / 신규지원자 / 인증필요)
///   - 잔여 공고권/충전 잔액 카드 (정책 모드별 분기, Sprint 3에서 실데이터 연결)
///   - 사업자 인증 배지
///   - 광고 성과 대시보드 티저
class MeOverviewPage extends ConsumerWidget {
  const MeOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchId = ref.watch(meActiveBranchProvider);
    final asyncSnap = ref.watch(meOverviewProvider(branchId));
    final mode = ref.watch(meBillingModeProvider);

    return MePageShell(
      title: '한눈에 보기',
      activeMenuId: 'overview',
      child: asyncSnap.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 80),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(32),
          child: Text('한눈에 보기 데이터를 불러오지 못했습니다: $error',
              style: WebTypo.caption(color: AppColors.error, size: 12)),
        ),
        data: (s) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _GreetingBar(snapshot: s),
            const SizedBox(height: AppSpacing.lg),
            _KpiRow(snapshot: s),
            const SizedBox(height: AppSpacing.xxl),
            _SectionTitle('지금 확인이 필요한 일'),
            const SizedBox(height: AppSpacing.md),
            _TodoPanel(snapshot: s),
            const SizedBox(height: AppSpacing.xxl),
            _SectionTitle('잔여 ${mode.label}'),
            const SizedBox(height: AppSpacing.md),
            _BillingSummaryCard(mode: mode),
            const SizedBox(height: AppSpacing.xxl),
            const _DashboardTeaser(),
          ],
        ),
      ),
    );
  }
}

// ── 인사 + 인증 배지 ────────────────────────────────────
class _GreetingBar extends StatelessWidget {
  const _GreetingBar({required this.snapshot});

  final MeOverviewSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final allVerified = snapshot.branchCount > 0 &&
        snapshot.branchCount == snapshot.verifiedBranchCount;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘도 좋은 인재를 찾아 드릴게요.',
                  style: WebTypo.sectionTitle(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  '지점 ${snapshot.branchCount}곳 · 게시중 ${snapshot.activeJobs}건 · 검수중 ${snapshot.pendingJobs}건',
                  style: WebTypo.caption(
                      color: AppColors.textSecondary, size: 12),
                ),
              ],
            ),
          ),
          if (allVerified)
            _MiniBadge(
              icon: Icons.verified,
              label: '사업자 인증 완료',
              color: AppColors.accent,
            )
          else
            InkWell(
              onTap: () => context.go('/me/verify'),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: _MiniBadge(
                icon: Icons.warning_amber_outlined,
                label: '인증 필요',
                color: AppColors.warning,
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge(
      {required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── KPI 카드 4종 ────────────────────────────────────────
class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.snapshot});

  final MeOverviewSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    return LayoutBuilder(
      builder: (context, c) {
        // 폭이 좁으면 2열로, 충분하면 4열로
        final cols = c.maxWidth < 640 ? 2 : 4;
        final cards = <Widget>[
          _KpiCard(
            label: '총 조회수',
            value: fmt.format(snapshot.totalViews30d),
            icon: Icons.visibility_outlined,
            color: AppColors.accent,
          ),
          _KpiCard(
            label: '유니크 방문',
            value: fmt.format(snapshot.totalUniqueViews30d),
            icon: Icons.person_outline,
            color: AppColors.warning,
          ),
          _KpiCard(
            label: '지원자 수',
            value: fmt.format(snapshot.totalApplies30d),
            icon: Icons.send_outlined,
            color: AppColors.success,
          ),
          _KpiCard(
            label: '전환율',
            value: '${snapshot.conversionRate30d.toStringAsFixed(1)}%',
            icon: Icons.trending_up,
            color: AppColors.cardEmphasis,
          ),
        ];
        return GridView.count(
          crossAxisCount: cols,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: cols == 2 ? 2.4 : 1.55,
          children: cards,
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: WebTypo.caption(
                      color: AppColors.textSecondary, size: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Text(
              value,
              style: WebTypo.number(color: AppColors.textPrimary, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

// ── To-Do 패널 ──────────────────────────────────────────
class _TodoPanel extends StatelessWidget {
  const _TodoPanel({required this.snapshot});

  final MeOverviewSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final items = <_TodoItem>[
      if (snapshot.recentApplicants24h > 0)
        _TodoItem(
          severity: _Severity.high,
          icon: Icons.fiber_new_outlined,
          title: '신규 지원자 ${snapshot.recentApplicants24h}명',
          desc: '24시간 이내 도착 — 빠르게 확인하면 합격률이 올라가요.',
          actionLabel: '인재풀 열기',
          onAction: () => context.go('/me/applicants'),
        ),
      if (snapshot.expiringJobs > 0)
        _TodoItem(
          severity: _Severity.medium,
          icon: Icons.schedule,
          title: '마감 임박 공고 ${snapshot.expiringJobs}건',
          desc: '3일 이내 마감 예정 — 채용이 끝나지 않았다면 마감일을 연장하세요.',
          actionLabel: '공고 관리로',
          onAction: () => context.go('/post-job'),
        ),
      if (snapshot.pendingJobs > 0)
        _TodoItem(
          severity: _Severity.info,
          icon: Icons.hourglass_top,
          title: '검수 대기 ${snapshot.pendingJobs}건',
          desc: '평균 1~2 영업일 안에 검수가 완료돼요.',
        ),
      if (snapshot.branchCount == 0 ||
          snapshot.verifiedBranchCount < snapshot.branchCount)
        _TodoItem(
          severity: _Severity.medium,
          icon: Icons.verified_outlined,
          title: '사업자 인증 미완료',
          desc: '인증을 완료하면 공고 노출 우선순위가 올라가고 신뢰 배지가 표시돼요.',
          actionLabel: '인증하러 가기',
          onAction: () => context.go('/me/verify'),
        ),
    ];

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline,
                color: AppColors.success.withOpacity(0.8)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '오늘 처리할 일이 없어요. 새 공고 등록은 어떨까요?',
                style: WebTypo.body(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/post-job/input'),
              child: const Text('공고 등록'),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 0.6, color: AppColors.divider),
            _TodoTile(item: items[i]),
          ],
        ],
      ),
    );
  }
}

enum _Severity { high, medium, info }

class _TodoItem {
  final _Severity severity;
  final IconData icon;
  final String title;
  final String desc;
  final String? actionLabel;
  final VoidCallback? onAction;

  _TodoItem({
    required this.severity,
    required this.icon,
    required this.title,
    required this.desc,
    this.actionLabel,
    this.onAction,
  });

  Color get color {
    switch (severity) {
      case _Severity.high:
        return AppColors.error;
      case _Severity.medium:
        return AppColors.warning;
      case _Severity.info:
        return AppColors.accent;
    }
  }
}

class _TodoTile extends StatelessWidget {
  const _TodoTile({required this.item});

  final _TodoItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6, right: 12, left: 4),
            decoration: BoxDecoration(
              color: item.color,
              shape: BoxShape.circle,
            ),
          ),
          Icon(item.icon, size: 18, color: item.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.desc,
                  style: WebTypo.caption(
                      color: AppColors.textSecondary, size: 12),
                ),
              ],
            ),
          ),
          if (item.actionLabel != null && item.onAction != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: item.onAction,
              child: Text(item.actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 잔여 공고권/충전 카드 (placeholder) ────────────────
///
/// `both` 모드에서는 공고권 카드 + 충전 잔액 카드를 두 줄로 노출한다.
/// 단일 모드에서는 해당 카드 하나만 노출.
class _BillingSummaryCard extends StatelessWidget {
  const _BillingSummaryCard({required this.mode});

  final BillingMode mode;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      if (mode != BillingMode.credit)
        const _BillingMiniCard(
          icon: Icons.confirmation_number_outlined,
          title: '잔여 공고권 — 곧 표시 예정',
          subtitle: '구매 후 12개월 내 사용 (운영자 admin에서 조정 가능)',
        ),
      if (mode != BillingMode.voucher)
        const _BillingMiniCard(
          icon: Icons.account_balance_wallet_outlined,
          title: '충전 잔액 — 곧 표시 예정',
          subtitle: '마지막 사용일로부터 24개월 보관 (운영자 admin에서 조정 가능)',
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          cards[i],
        ],
      ],
    );
  }
}

class _BillingMiniCard extends StatelessWidget {
  const _BillingMiniCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: AppColors.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: WebTypo.sectionTitle(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: WebTypo.caption(
                      color: AppColors.textSecondary, size: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => context.go('/me/billing'),
            child: const Text('자세히'),
          ),
        ],
      ),
    );
  }
}

// ── 광고 성과 대시보드 티저 ─────────────────────────────
class _DashboardTeaser extends StatelessWidget {
  const _DashboardTeaser();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.cardPrimary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.onCardPrimary.withOpacity(0.18),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.insights, color: AppColors.onCardPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '곧 만나요 — 광고 성과 대시보드',
                  style:
                      WebTypo.sectionTitle(color: AppColors.onCardPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  '동일 직무·지역 평균과 비교, 5단 깔때기 분석, AI 코칭 카드까지\n'
                  '타사에 없던 인사이트를 곧 제공해요.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.onCardPrimary.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 공통 섹션 타이틀 ────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: WebTypo.sectionTitle(color: AppColors.textPrimary));
  }
}
