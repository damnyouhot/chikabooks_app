import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/admin_dashboard_models.dart';
import '../../../services/admin_dashboard_service.dart';
import '../widgets/admin_common_widgets.dart';

class AdminOverviewTab extends StatefulWidget {
  const AdminOverviewTab({super.key});

  @override
  State<AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends State<AdminOverviewTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _loading = true;
  String? _error;
  DateTime? _lastSync;

  // KPI 데이터
  int _totalUsers = 0;
  int _newUsers7d = 0;
  int _activeUsers7d = 0;
  int _longAbsent = 0;
  int _recentErrors = 0;

  // 연차 분포
  List<CareerGroupCount> _careerGroups = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        AdminDashboardService.getTotalUserCount(),
        AdminDashboardService.getRecentSignups(7),
        AdminDashboardService.getActiveUserCount(7),
        AdminDashboardService.getLongAbsentCount(14),
        AdminDashboardService.getRecentErrorCount(),
        AdminDashboardService.getCareerGroupDistribution(),
      ]);
      if (!mounted) return;
      setState(() {
        _totalUsers    = results[0] as int;
        _newUsers7d    = results[1] as int;
        _activeUsers7d = results[2] as int;
        _longAbsent    = results[3] as int;
        _recentErrors  = results[4] as int;
        _careerGroups  = results[5] as List<CareerGroupCount>;
        _lastSync = DateTime.now();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const AdminLoadingState();
    if (_error != null) return AdminErrorState(onRetry: _load);

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 마지막 동기화 시각
          if (_lastSync != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '마지막 동기화: ${_formatTime(_lastSync!)}',
                style: const TextStyle(fontSize: 11, color: AppColors.textDisabled),
              ),
            ),

          // ── KPI 카드 그리드 ────────────────────────────────────
          const AdminSectionTitle('핵심 지표'),
          _KpiGrid(kpis: [
            DashboardKpi(label: '총 사용자', value: '$_totalUsers명'),
            DashboardKpi(label: '최근 7일 신규', value: '+$_newUsers7d명', sublabel: '7일 기준'),
            DashboardKpi(label: '활성 사용자', value: '$_activeUsers7d명', sublabel: '최근 7일'),
            DashboardKpi(label: '장기 미접속', value: '$_longAbsent명', sublabel: '14일 이상'),
          ]),

          const SizedBox(height: 8),

          // 오류 KPI — 강조 색상
          _ErrorKpiCard(count: _recentErrors),

          const SizedBox(height: 20),

          // ── 연차별 분포 ────────────────────────────────────────
          const AdminSectionTitle('연차별 사용자 분포'),
          _CareerGroupChart(groups: _careerGroups, totalUsers: _totalUsers),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.month}/${dt.day} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─── KPI 2열 그리드 ────────────────────────────────────────────
class _KpiGrid extends StatelessWidget {
  final List<DashboardKpi> kpis;
  const _KpiGrid({required this.kpis});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.7,
      ),
      itemCount: kpis.length,
      itemBuilder: (_, i) => AdminKpiCard(
        label: kpis[i].label,
        value: kpis[i].value,
        sublabel: kpis[i].sublabel,
      ),
    );
  }
}

// ─── 오류 KPI 카드 (강조) ──────────────────────────────────────
class _ErrorKpiCard extends StatelessWidget {
  final int count;
  const _ErrorKpiCard({required this.count});

  @override
  Widget build(BuildContext context) {
    final isAlert = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isAlert
            ? AppColors.error.withOpacity(0.08)
            : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: isAlert
            ? Border.all(color: AppColors.error.withOpacity(0.3))
            : null,
      ),
      child: Row(
        children: [
          Icon(
            Icons.bug_report_outlined,
            color: isAlert ? AppColors.error : AppColors.textDisabled,
            size: 28,
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count건',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isAlert ? AppColors.error : AppColors.textPrimary,
                ),
              ),
              Text(
                '최근 24시간 오류',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (isAlert) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Text(
                '확인 필요',
                style: TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 연차별 분포 차트 (바 형태) ────────────────────────────────
class _CareerGroupChart extends StatelessWidget {
  final List<CareerGroupCount> groups;
  final int totalUsers;
  const _CareerGroupChart({required this.groups, required this.totalUsers});

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const AdminEmptyState();
    final maxCount = groups.fold(0, (m, g) => g.count > m ? g.count : m);

    return Column(
      children: groups.map((g) {
        final ratio = maxCount > 0 ? g.count / maxCount : 0.0;
        final pct = totalUsers > 0
            ? (g.count / totalUsers * 100).toStringAsFixed(1)
            : '0.0';
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 60,
                child: Text(
                  g.label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio.toDouble(),
                    minHeight: 14,
                    backgroundColor: AppColors.surfaceMuted,
                    valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                child: Text(
                  '${g.count}명 ($pct%)',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

