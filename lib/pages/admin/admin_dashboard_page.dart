import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import 'tabs/admin_overview_tab.dart';
import 'tabs/admin_userflow_tab.dart';
import 'tabs/admin_feature_tab.dart';
import 'tabs/admin_behavior_tab.dart';
import 'tabs/admin_trends_tab.dart';
import 'tabs/admin_billing_tab.dart';
import 'tabs/admin_verify_tab.dart';

/// 관리자 전용 운영 대시보드
///
/// 5탭 구조:
///   - Overview     : 핵심 KPI + 연차 분포
///   - User Flow    : 가입 퍼널 + 전환율
///   - Feature      : 기능 클릭 TOP + 오류 리스트
///   - Behavior     : 행동 분석 (7개 지표, direct calculation)
///   - Trends       : 일별 추세 차트 (analytics_daily 기반)
///
/// 상단 기간 필터(오늘 / 최근 7일 / 최근 30일)가 모든 탭에 공통 적용됨
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  // ── 기간 필터 ──────────────────────────────────────────────────
  _Period _period = _Period.today;

  DateTime get _since {
    final now = DateTime.now();
    return switch (_period) {
      _Period.today => DateTime(now.year, now.month, now.day),
      _Period.week => now.subtract(const Duration(days: 7)),
      _Period.month => now.subtract(const Duration(days: 30)),
    };
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        backgroundColor: AppColors.appBg,
        appBar: AppBar(
          backgroundColor: AppColors.appBg,
          elevation: 0,
          title: const Text(
            '운영 대시보드',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          // ── 기간 선택 칩 ────────────────────────────────────────
          actions: [
            _PeriodChips(
              selected: _period,
              onChanged: (p) => setState(() => _period = p),
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(46),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(3),
                labelColor: AppColors.onAccent,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                dividerColor: Colors.transparent,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  const Tab(text: 'Overview'),
                  const Tab(text: 'User Flow'),
                  const Tab(text: 'Feature'),
                  const Tab(text: 'Behavior'),
                  const Tab(text: 'Trends'),
                  const Tab(text: 'Billing'),
                  const Tab(child: _VerifyTabLabel()),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            AdminOverviewTab(since: _since, period: _period.label),
            AdminUserFlowTab(since: _since),
            AdminFeatureTab(since: _since),
            AdminBehaviorTab(since: _since),
            const AdminTrendsTab(),
            const AdminBillingTab(),
            const AdminVerifyTab(),
          ],
        ),
      ),
    );
  }
}

class _VerifyTabLabel extends StatelessWidget {
  const _VerifyTabLabel();

  static const _verifyNotificationTypes = {
    'business_name_review',
    'business_verification_provisional',
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance
              .collection('adminNotifications')
              .where('status', isEqualTo: 'unread')
              .snapshots(),
      builder: (context, snap) {
        final count =
            (snap.data?.docs ?? const [])
                .where(
                  (doc) => _verifyNotificationTypes.contains(
                    doc.data()['type']?.toString(),
                  ),
                )
                .length;
        if (count == 0) return const Text('인증 검토');
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('인증 검토'),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── 기간 enum ─────────────────────────────────────────────────
enum _Period {
  today('오늘'),
  week('7일'),
  month('30일');

  final String label;
  const _Period(this.label);
}

// ─── 기간 선택 칩 위젯 ────────────────────────────────────────
class _PeriodChips extends StatelessWidget {
  final _Period selected;
  final ValueChanged<_Period> onChanged;

  const _PeriodChips({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children:
          _Period.values.map((p) {
            final isSelected = p == selected;
            return GestureDetector(
              onTap: () => onChanged(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accent : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  p.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        isSelected
                            ? AppColors.onAccent
                            : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }
}
