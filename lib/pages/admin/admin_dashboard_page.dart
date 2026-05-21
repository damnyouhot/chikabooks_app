import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/theme/app_colors.dart';
import '../../services/admin_billing_service.dart';
import 'tabs/admin_behavior_tab.dart';
import 'tabs/admin_billing_tab.dart';
import 'tabs/admin_content_ops_tab.dart';
import 'tabs/admin_feature_tab.dart';
import 'tabs/admin_moderation_tab.dart';
import 'tabs/admin_overview_tab.dart';
import 'tabs/admin_publisher_tab.dart';
import 'tabs/admin_timeline_tab.dart';
import 'tabs/admin_trends_tab.dart';
import 'tabs/admin_user_tab.dart';
import 'tabs/admin_userflow_tab.dart';
import 'tabs/admin_verify_tab.dart';

/// 관리자 전용 운영 대시보드
///
/// ── 탭 구성 (운영 우선 → 분석 순) ─────────────────────────────
///   1. Overview      : 핵심 KPI (읽기 전용)
///   2. 타임라인      : 전체 유저 기록·목표 통합 피드 (운영 모니터링)
///   3. Content Ops   : 공감투표 · 퀴즈 · 오늘 단어 · 오늘 문제 슬롯
///   4. Publisher     : 공고자 / 주문 / 공고권 KPI
///   5. Moderation    : 신고 누적·자동 숨김 게시물 검토 (P1.A)
///   6. Users         : 사용자 검색·상세·플래그 토글 (P1.B)
///   7. Billing       : 충전 · 세금계산서 · 현금영수증 큐 (미처리 배지)
///   8. 인증 검토     : 사업자 인증 / 상호 확인 큐 (미처리 배지)
///   9. User Flow     : 온보딩 퍼널
///   10. Feature      : 기능 반응 + 오류 모니터
///   11. Behavior     : 7개 행동 지표
///   12. Trends       : 일별 추세 차트
///
/// 상단 기간 필터(오늘/7일/30일)는 Overview · 타임라인 · Publisher · UserFlow ·
/// Feature · Behavior 6개 탭에 적용됩니다. Trends 는 자체 기간 칩을,
/// Content Ops / Moderation / Users / Billing / Verify 는 기간 개념이 없습니다.
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
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
      length: 12,
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
                tabs: const [
                  Tab(text: '요약'),
                  Tab(text: '타임라인'),
                  Tab(text: '콘텐츠'),
                  Tab(text: '공고'),
                  Tab(text: '신고'),
                  Tab(text: '사용자'),
                  Tab(child: _BillingTabLabel()),
                  Tab(child: _VerifyTabLabel()),
                  Tab(text: '가입'),
                  Tab(text: '기능'),
                  Tab(text: '행동'),
                  Tab(text: '추세'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            AdminOverviewTab(since: _since, period: _period.label),
            AdminTimelineTab(since: _since),
            const AdminContentOpsTab(),
            AdminPublisherTab(since: _since),
            const AdminModerationTab(),
            const AdminUserTab(),
            const AdminBillingTab(),
            const AdminVerifyTab(),
            AdminUserFlowTab(since: _since),
            AdminFeatureTab(since: _since),
            AdminBehaviorTab(since: _since),
            const AdminTrendsTab(),
          ],
        ),
      ),
    );
  }
}

// ─── 인증 검토 탭 라벨 (미처리 카운트 배지) ──────────────────
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
        return _TabLabelWithBadge(text: '인증 검토', count: count);
      },
    );
  }
}

/// Billing 탭 — 충전·세금계산서·현금영수증 큐 합계를 라벨에 배지로 표시.
///
/// `AdminBillingService.watchCounts()` 가 세 큐의 미처리 건수를 한 번에 반환하므로
/// 합산하여 운영자에게 「현재 처리할 게 몇 건 있는지」를 탭 전환 없이 노출한다.
class _BillingTabLabel extends StatelessWidget {
  const _BillingTabLabel();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<({int payment, int tax, int cash})>(
      stream: AdminBillingService.watchCounts(),
      builder: (context, snap) {
        final c = snap.data;
        final count = c == null ? 0 : (c.payment + c.tax + c.cash);
        return _TabLabelWithBadge(text: '결제', count: count);
      },
    );
  }
}

/// 미처리 카운트가 있을 때 라벨 오른쪽에 빨간 배지를 표시하는 공통 위젯.
class _TabLabelWithBadge extends StatelessWidget {
  final String text;
  final int count;
  const _TabLabelWithBadge({required this.text, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return Text(text);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
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
  }
}

enum _Period {
  today('오늘'),
  week('7일'),
  month('30일');

  final String label;
  const _Period(this.label);
}

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
