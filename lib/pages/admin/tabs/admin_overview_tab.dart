import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/admin_dashboard_models.dart';
import '../../../services/admin_dashboard_service.dart';
import '../widgets/admin_common_widgets.dart';

/// 운영 대시보드 Overview — 핵심 KPI 요약(읽기 전용)
///
/// 콘텐츠 운영 액션(공감투표/퀴즈/오늘단어/오늘문제)은 별도 [Content Ops] 탭에서
/// 다룹니다. 이 탭은 운영자가 아침에 「오늘 숫자만 빠르게 스캔」하는 용도입니다.
///
/// ── 부분 실패 허용 ────────────────────────────────────────────
/// KPI 7종을 [Future.wait]로 동시에 가져오지만, 각 메서드는 실패 시 null 을
/// 반환합니다. 화면은 실패한 카드만 `—` 로 표시하고 다른 카드는 정상 노출합니다.
/// 모든 KPI 가 실패한 경우에만 전체 에러 상태로 전환됩니다.
/// ──────────────────────────────────────────────────────────────
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
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => false;

  bool _loading = true;
  bool _allFailed = false;
  DateTime? _lastSync;

  /// 각 KPI 는 null = 페치 실패(또는 미로드). UI 에서는 `—` 로 표시되어
  /// 진짜 0과 구분됩니다.
  int? _totalUsers;
  int? _newUsers;
  int? _activeUsers;
  int? _longAbsent;
  int? _recentErrors;
  int? _noteCount;
  int? _goalCount;

  List<CareerGroupCount>? _careerGroups;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _load();
    }
  }

  @override
  void didUpdateWidget(AdminOverviewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.since != widget.since) _load();
  }

  /// 각 KPI 를 nullable 로 감싸 부분 실패를 허용한다.
  /// 모든 KPI 가 동시에 실패하는 경우에만 [_allFailed] 로 화면 전체를 오류 처리.
  Future<int?> _safe(Future<int> Function() fn) async {
    try {
      return await fn();
    } catch (_) {
      return null;
    }
  }

  Future<List<CareerGroupCount>?> _safeCareer() async {
    try {
      return await AdminDashboardService.getCareerGroupDistribution();
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _allFailed = false;
    });

    final results = await Future.wait([
      _safe(AdminDashboardService.getTotalUserCount),
      _safe(() => AdminDashboardService.getRecentSignups(since: widget.since)),
      _safe(
        () => AdminDashboardService.getActiveUserCount(since: widget.since),
      ),
      _safe(AdminDashboardService.getLongAbsentCount),
      _safe(
        () => AdminDashboardService.getRecentErrorCount(since: widget.since),
      ),
      _safe(() => AdminDashboardService.getNoteCount(since: widget.since)),
      _safe(() => AdminDashboardService.getGoalCount(since: widget.since)),
      _safeCareer(),
    ]);

    if (!mounted) return;

    final total = results[0] as int?;
    final signups = results[1] as int?;
    final actives = results[2] as int?;
    final absent = results[3] as int?;
    final errors = results[4] as int?;
    final notes = results[5] as int?;
    final goals = results[6] as int?;
    final careerList = results[7] as List<CareerGroupCount>?;

    final everyKpiFailed =
        total == null &&
        signups == null &&
        actives == null &&
        absent == null &&
        errors == null &&
        notes == null &&
        goals == null &&
        careerList == null;

    setState(() {
      _totalUsers = total;
      _newUsers = signups;
      _activeUsers = actives;
      _longAbsent = absent;
      _recentErrors = errors;
      _noteCount = notes;
      _goalCount = goals;
      _careerGroups = careerList;
      _lastSync = DateTime.now();
      _loading = false;
      _allFailed = everyKpiFailed;
    });
  }

  String _fmtUser(int? v) => v == null ? '—' : '$v명';
  String _fmtNote(int? v) => v == null ? '—' : '$v건';
  String _fmtSign(int? v) => v == null ? '—' : '+$v명';

  String _formatTime(DateTime dt) {
    return '${dt.month}/${dt.day} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const AdminLoadingState();
    if (_allFailed) return AdminErrorState(onRetry: _load);

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_lastSync != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '마지막 동기화: ${_formatTime(_lastSync!)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textDisabled,
                ),
              ),
            ),

          AdminSectionTitle('핵심 지표 (${widget.period})'),
          _KpiGrid(
            kpis: [
              DashboardKpi(label: '총 사용자', value: _fmtUser(_totalUsers)),
              DashboardKpi(
                label: '기간 신규 가입',
                value: _fmtSign(_newUsers),
                sublabel: widget.period,
              ),
              DashboardKpi(
                label: '활성 유저',
                value: _fmtUser(_activeUsers),
                sublabel: widget.period,
              ),
              DashboardKpi(
                label: '기록하기 수',
                value: _fmtNote(_noteCount),
                sublabel: widget.period,
              ),
              DashboardKpi(
                label: '목표 생성',
                value: _fmtNote(_goalCount),
                sublabel: widget.period,
              ),
              DashboardKpi(
                label: '장기 미접속',
                value: _fmtUser(_longAbsent),
                sublabel: '14일+',
              ),
            ],
          ),

          const SizedBox(height: 8),

          _ErrorKpiCard(count: _recentErrors, period: widget.period),

          const SizedBox(height: 20),

          const AdminSectionTitle('연차별 사용자 분포'),
          _CareerGroupChart(
            groups: _careerGroups,
            totalUsers: _totalUsers,
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

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
      itemBuilder:
          (_, i) => AdminKpiCard(
            label: kpis[i].label,
            value: kpis[i].value,
            sublabel: kpis[i].sublabel,
          ),
    );
  }
}

/// 오류 KPI — `null` 이면 "측정 실패" 로 표기해 진짜 0과 구분.
class _ErrorKpiCard extends StatelessWidget {
  final int? count;
  final String period;
  const _ErrorKpiCard({required this.count, required this.period});

  @override
  Widget build(BuildContext context) {
    final failed = count == null;
    final isAlert = !failed && count! > 0;
    final valueText = failed ? '—' : '${count!}건';
    final subText = failed ? '$period 오류 측정 실패' : '$period 오류 발생';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color:
            isAlert
                ? AppColors.error.withValues(alpha: 0.08)
                : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border:
            isAlert
                ? Border.all(color: AppColors.error.withValues(alpha: 0.3))
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
                valueText,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isAlert ? AppColors.error : AppColors.textPrimary,
                ),
              ),
              Text(
                subText,
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

/// 연차 분포 — groups 가 null 이면 측정 실패, 빈 리스트면 데이터 없음.
class _CareerGroupChart extends StatelessWidget {
  final List<CareerGroupCount>? groups;
  final int? totalUsers;
  const _CareerGroupChart({required this.groups, required this.totalUsers});

  @override
  Widget build(BuildContext context) {
    if (groups == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          '연차 분포를 불러오지 못했어요. 당겨서 새로고침하세요.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      );
    }
    if (groups!.isEmpty) return const AdminEmptyState();
    final maxCount = groups!.fold(0, (m, g) => g.count > m ? g.count : m);
    final tot = totalUsers ?? 0;

    return Column(
      children:
          groups!.map((g) {
            final ratio = maxCount > 0 ? g.count / maxCount : 0.0;
            final pct =
                tot > 0
                    ? (g.count / tot * 100).toStringAsFixed(1)
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
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.accent,
                        ),
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
