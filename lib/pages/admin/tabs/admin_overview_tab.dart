import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/admin_dashboard_models.dart';
import '../../../services/admin_dashboard_service.dart';
import '../widgets/admin_common_widgets.dart';

class AdminOverviewTab extends StatefulWidget {
  final DateTime since;
  final String period; // 표시용 라벨 (예: '7일')

  const AdminOverviewTab({
    super.key,
    required this.since,
    required this.period,
  });

  @override
  State<AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends State<AdminOverviewTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => false; // 기간 변경 시 항상 재로드

  bool _loading = true;
  String? _error;
  DateTime? _lastSync;

  // KPI 데이터
  int _totalUsers = 0;
  int _newUsers = 0;
  int _activeUsers = 0;
  int _longAbsent = 0;
  int _recentErrors = 0;
  int _emotionCount = 0;
  double? _avgEmotionScore;

  // 연차 분포
  List<CareerGroupCount> _careerGroups = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AdminOverviewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.since != widget.since) _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        AdminDashboardService.getTotalUserCount(),
        AdminDashboardService.getRecentSignups(since: widget.since),
        AdminDashboardService.getActiveUserCount(since: widget.since),
        AdminDashboardService.getLongAbsentCount(),
        AdminDashboardService.getRecentErrorCount(since: widget.since),
        AdminDashboardService.getEmotionCount(since: widget.since),
        AdminDashboardService.getAverageEmotionScore(since: widget.since),
        AdminDashboardService.getCareerGroupDistribution(),
      ]);
      if (!mounted) return;
      setState(() {
        _totalUsers      = results[0] as int;
        _newUsers        = results[1] as int;
        _activeUsers     = results[2] as int;
        _longAbsent      = results[3] as int;
        _recentErrors    = results[4] as int;
        _emotionCount    = results[5] as int;
        _avgEmotionScore = results[6] as double?;
        _careerGroups    = results[7] as List<CareerGroupCount>;
        _lastSync = DateTime.now();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
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
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textDisabled),
              ),
            ),

          // ── KPI 카드 그리드 ──────────────────────────────────
          AdminSectionTitle('핵심 지표 (${widget.period})'),
          _KpiGrid(kpis: [
            DashboardKpi(label: '총 사용자', value: '$_totalUsers명'),
            DashboardKpi(
                label: '기간 신규 가입',
                value: '+$_newUsers명',
                sublabel: widget.period),
            DashboardKpi(
                label: '활성 유저',
                value: '$_activeUsers명',
                sublabel: widget.period),
            DashboardKpi(
                label: '감정기록 수',
                value: '$_emotionCount건',
                sublabel: widget.period),
            DashboardKpi(
                label: '감정 평균 점수',
                value: _avgEmotionScore != null
                    ? _avgEmotionScore!.toStringAsFixed(1)
                    : '-',
                sublabel: widget.period),
            DashboardKpi(label: '장기 미접속', value: '$_longAbsent명', sublabel: '14일+'),
          ]),

          const SizedBox(height: 8),

          // 오류 KPI — 강조 색상
          _ErrorKpiCard(count: _recentErrors, period: widget.period),

          const SizedBox(height: 20),

          // ── 연차별 분포 ──────────────────────────────────────
          const AdminSectionTitle('연차별 사용자 분포'),
          _CareerGroupChart(
              groups: _careerGroups, totalUsers: _totalUsers),

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
  final String period;
  const _ErrorKpiCard({required this.count, required this.period});

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
                  color:
                      isAlert ? AppColors.error : AppColors.textPrimary,
                ),
              ),
              Text(
                '$period 오류 발생',
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
  const _CareerGroupChart(
      {required this.groups, required this.totalUsers});

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
                width: 68,
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
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 72,
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
