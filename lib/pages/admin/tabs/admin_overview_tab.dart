import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/admin_dashboard_models.dart';
import '../../../models/quiz_schedule.dart';
import '../../../services/admin_dashboard_service.dart';
import '../../../services/quiz_pool_service.dart';
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
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
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
  int _noteCount = 0;

  // 퀴즈 풀 데이터
  QuizMetaState? _quizMeta;
  bool _syncingQuizMeta = false;
  bool _reschedulingTodayQuiz = false;

  // 연차 분포
  List<CareerGroupCount> _careerGroups = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 앱 생명주기 감지 등록
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // 등록 해제
    super.dispose();
  }

  /// 앱이 백그라운드 → 포그라운드 복귀 시 자동 새로고침
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

  Future<void> _load() async {
    if (!mounted) return;

    debugPrint('🔄 [Overview] _load() 진입 — ${DateTime.now()}');

    setState(() {
      _loading = true;
      _error = null;
      _lastSync = DateTime.now(); // 진입 즉시 갱신 (화면에서 시각 변화 확인용)
    });

    try {
      final results = await Future.wait([
        AdminDashboardService.getTotalUserCount(),
        AdminDashboardService.getRecentSignups(since: widget.since),
        AdminDashboardService.getActiveUserCount(since: widget.since),
        AdminDashboardService.getLongAbsentCount(),
        AdminDashboardService.getRecentErrorCount(since: widget.since),
        AdminDashboardService.getNoteCount(since: widget.since),
        AdminDashboardService.getCareerGroupDistribution(),
        AdminDashboardService.getQuizMetaState(),
      ]);

      if (!mounted) {
        debugPrint('⚠️ [Overview] _load() 완료 but unmounted — 렌더 스킵');
        return;
      }

      setState(() {
        _totalUsers   = results[0] as int;
        _newUsers     = results[1] as int;
        _activeUsers  = results[2] as int;
        _longAbsent   = results[3] as int;
        _recentErrors = results[4] as int;
        _noteCount    = results[5] as int;
        _careerGroups = results[6] as List<CareerGroupCount>;
        _quizMeta     = results[7] as QuizMetaState?;
        _lastSync = DateTime.now();
        _loading = false;
      });

      debugPrint('✅ [Overview] _load() 완료 — _lastSync=$_lastSync');

    } catch (e, stack) {
      debugPrint('❌ [Overview] _load() 예외 발생!');
      debugPrint('❌ error: $e');
      debugPrint('❌ stack: $stack');

      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _lastSync = DateTime.now(); // 에러여도 시각은 갱신
        _loading = false;
      });
    }
  }

  Future<void> _syncQuizMetaFromSchedules() async {
    setState(() => _syncingQuizMeta = true);
    try {
      await AdminDashboardService.rebuildQuizMetaFromSchedules();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('퀴즈 메타가 스케줄과 동기화되었습니다.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('동기화 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _syncingQuizMeta = false);
    }
  }

  Future<void> _rescheduleTodayQuiz() async {
    final today = QuizPoolService.todayKey;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('오늘 퀴즈 스케줄 다시 만들기'),
        content: Text(
          '날짜 $today 의 quiz_schedule을 덮어씁니다.\n'
          '모든 사용자의 오늘 퀴즈가 새로 선정된 문항으로 바뀝니다. 진행할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('덮어쓰기'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _reschedulingTodayQuiz = true);
    try {
      final data = await AdminDashboardService.manualScheduleQuiz(
        targetDate: today,
        forceReplace: true,
      );
      if (!mounted) return;
      final success = data?['success'] == true;
      final msg = data?['message'] as String? ??
          (success ? '스케줄을 갱신했습니다.' : '스케줄 갱신에 실패했습니다.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: $e')),
      );
    } finally {
      if (mounted) setState(() => _reschedulingTodayQuiz = false);
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
                label: '기록하기 수',
                value: '$_noteCount건',
                sublabel: widget.period),
            DashboardKpi(label: '장기 미접속', value: '$_longAbsent명', sublabel: '14일+'),
          ]),

          const SizedBox(height: 8),

          // 오류 KPI — 강조 색상
          _ErrorKpiCard(count: _recentErrors, period: widget.period),

          const SizedBox(height: 20),

          // ── 퀴즈 풀 현황 ─────────────────────────────────────
          const AdminSectionTitle('퀴즈 풀 현황'),
          _QuizPoolCard(
            meta: _quizMeta,
            syncing: _syncingQuizMeta,
            onSyncFromSchedules: _syncQuizMetaFromSchedules,
            reschedulingToday: _reschedulingTodayQuiz,
            onRescheduleToday: _rescheduleTodayQuiz,
          ),

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
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
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

// ─── 퀴즈 풀 현황 카드 ─────────────────────────────────────────
class _QuizPoolCard extends StatelessWidget {
  final QuizMetaState? meta;
  final bool syncing;
  final VoidCallback onSyncFromSchedules;
  final bool reschedulingToday;
  final VoidCallback onRescheduleToday;

  const _QuizPoolCard({
    required this.meta,
    required this.syncing,
    required this.onSyncFromSchedules,
    required this.reschedulingToday,
    required this.onRescheduleToday,
  });

  @override
  Widget build(BuildContext context) {
    if (meta == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          '퀴즈 풀 데이터 없음',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      );
    }

    final total = meta!.totalActiveCount;
    // usedCount = 이번 사이클에서 배포된 문제 수 (CF의 usedQuizIds.length)
    final served = meta!.usedCount;
    final remaining = (total - served).clamp(0, total);
    final cycle = meta!.cycleCount;
    final daily = meta!.dailyCount;
    final daysLeft = daily > 0 ? (remaining / daily).ceil() : 0;

    final natTotal = meta!.totalNationalActiveCount;
    final clinTotal = meta!.totalClinicalActiveCount;
    final natUsed = meta!.usedNationalCount;
    final clinUsed = meta!.usedClinicalCount;
    final natRem = (natTotal - natUsed).clamp(0, natTotal);
    final clinRem = (clinTotal - clinUsed).clamp(0, clinTotal);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 진행률 바
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${cycle}사이클 진행 중',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '$served / $total',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? served / total : 0.0,
              minHeight: 8,
              backgroundColor: AppColors.surfaceMuted,
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
          const SizedBox(height: 14),
          // 3개 수치 행
          Row(
            children: [
              _QuizStat(label: '전체 문제', value: '$total문제'),
              _QuizDivider(),
              _QuizStat(label: '이번 사이클 배포', value: '$served문제'),
              _QuizDivider(),
              _QuizStat(label: '남은 문제', value: '$remaining문제\n(약 ${daysLeft}일치)'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '마지막 스케줄: ${meta!.lastScheduledDate}  ·  하루 $daily문제 배포',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textDisabled,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '「이번 사이클 배포」= 이번 사이클에서 한 번이라도 나간 고유 문항 수(usedQuizIds). '
            '국시/임상 수치는 활성 풀의 questionType 기준으로 CF가 갱신합니다. '
            '스케줄과 숫자가 어긋나면 아래를 눌러 맞춥니다.',
            style: TextStyle(
              fontSize: 10,
              height: 1.35,
              color: AppColors.textDisabled.withValues(alpha: 0.95),
            ),
          ),
          if (natTotal > 0 || clinTotal > 0) ...[
            const SizedBox(height: 12),
            Text(
              '국시 풀: 활성 $natTotal · 배포 $natUsed · 남음 $natRem',
              style: const TextStyle(
                fontSize: 11,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '임상 풀: 활성 $clinTotal · 배포 $clinUsed · 남음 $clinRem',
              style: const TextStyle(
                fontSize: 11,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                onPressed: syncing ? null : onSyncFromSchedules,
                icon: syncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync, size: 18),
                label: Text(syncing ? '동기화 중…' : '스케줄 기준으로 메타 동기화'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
              TextButton.icon(
                onPressed: (syncing || reschedulingToday)
                    ? null
                    : onRescheduleToday,
                icon: reschedulingToday
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.event_repeat, size: 18),
                label: Text(
                  reschedulingToday
                      ? '오늘 스케줄 재생성 중…'
                      : '오늘 스케줄 다시 만들기',
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuizStat extends StatelessWidget {
  final String label;
  final String value;
  const _QuizStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: AppColors.divider,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
