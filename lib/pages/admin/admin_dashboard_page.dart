import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'tabs/admin_overview_tab.dart';
import 'tabs/admin_userflow_tab.dart';
import 'tabs/admin_feature_tab.dart';

/// 관리자 전용 운영 대시보드
///
/// 3탭 구조:
///   - Overview     : 핵심 KPI + 연차 분포
///   - User Flow    : 가입 퍼널 + 전환율
///   - Feature      : 기능 클릭 TOP + 오류 리스트
///
/// 진입 경로: 설정 → 운영 대시보드 (isAdmin == true 계정만 노출)
/// 라우트 가드: /admin 경로는 app_router에서 isAdmin 검증 후 허용
class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
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
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'User Flow'),
                  Tab(text: 'Feature'),
                ],
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            AdminOverviewTab(),
            AdminUserFlowTab(),
            AdminFeatureTab(),
          ],
        ),
      ),
    );
  }
}
