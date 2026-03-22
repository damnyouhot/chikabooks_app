import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/admin_behavior_service.dart';
import '../widgets/admin_common_widgets.dart';

/// 행동 분석(Behavior) 탭
///
/// activityLogs bulk read 1회 → 7개 지표 동시 계산
class AdminBehaviorTab extends StatefulWidget {
  final DateTime since;
  const AdminBehaviorTab({super.key, required this.since});

  @override
  State<AdminBehaviorTab> createState() => _AdminBehaviorTabState();
}

class _AdminBehaviorTabState extends State<AdminBehaviorTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => false;

  bool _loading = true;
  String? _error;
  BehaviorAnalysis? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AdminBehaviorTab oldWidget) {
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
      final data = await AdminBehaviorService.analyze(since: widget.since);
      if (!mounted) return;
      setState(() {
        _data = data;
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
    if (_error != null) {
      return AdminErrorState(message: _error!, onRetry: _load);
    }
    final d = _data!;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 1. 기능 실행률 ──
          const AdminSectionTitle('1. 기능 실행률'),
          const SizedBox(height: 4),
          ...d.featureUsage.map((m) => _MetricTile(metric: m)),
          const SizedBox(height: 20),

          // ── 2. 탭 → 행동 전환율 ──
          const AdminSectionTitle('2. 탭 → 행동 전환율'),
          const SizedBox(height: 4),
          ...d.conversions.map((m) => _MetricTile(metric: m)),
          const SizedBox(height: 20),

          // ── 3. 행동 깊이 ──
          const AdminSectionTitle('3. 행동 깊이'),
          const SizedBox(height: 4),
          ...d.depth.map((m) => _MetricTile(metric: m)),
          const SizedBox(height: 20),

          // ── 4. 반복 사용 ──
          const AdminSectionTitle('4. 반복 사용'),
          const SizedBox(height: 4),
          ...d.repeat.map((m) => _MetricTile(metric: m)),
          const SizedBox(height: 20),

          // ── 5. 유저 타입 분포 ──
          const AdminSectionTitle('5. 유저 타입 분포'),
          const SizedBox(height: 4),
          ...d.segments.map((m) => _MetricTile(metric: m)),
          const SizedBox(height: 20),

          // ── 6. 첫 클릭 위치 ──
          const AdminSectionTitle('6. 첫 클릭 위치'),
          const SizedBox(height: 4),
          ...d.firstActions.map((m) => _MetricTile(metric: m)),
          const SizedBox(height: 20),

          // ── 7. 재방문 (D3/D7) ──
          const AdminSectionTitle('7. 재방문 (Retention Lite)'),
          const SizedBox(height: 4),
          _MetricTile(
            metric: MetricCard.safe(
              label: 'D3 재방문 (2일+)',
              count: d.retention.d3Count,
              total: d.retention.total,
              basis: '전체 로그인 사용자',
            ),
          ),
          _MetricTile(
            metric: MetricCard.safe(
              label: 'D7 재방문 (3일+)',
              count: d.retention.d7Count,
              total: d.retention.total,
              basis: '전체 로그인 사용자',
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 지표 카드 위젯 — [절대값] + [비율] + [기준]
// ═══════════════════════════════════════════════════════════════
class _MetricTile extends StatelessWidget {
  final MetricCard metric;
  const _MetricTile({required this.metric});

  @override
  Widget build(BuildContext context) {
    final pct = metric.percent;
    final barWidth = metric.rate.clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 라벨 + 수치
          Row(
            children: [
              Expanded(
                child: Text(
                  metric.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${metric.count}명 / ${metric.total}명 ($pct)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 프로그레스 바
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: barWidth,
              minHeight: 6,
              backgroundColor: AppColors.disabledBg,
              valueColor: AlwaysStoppedAnimation<Color>(
                _barColor(metric.rate),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // 기준 설명
          Text(
            '기준: ${metric.basis}',
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textDisabled,
            ),
          ),
          if (metric.detail != null) ...[
            const SizedBox(height: 4),
            Text(
              metric.detail!,
              style: const TextStyle(
                fontSize: 10,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _barColor(double rate) {
    if (rate >= 0.7) return const Color(0xFF66BB6A);
    if (rate >= 0.4) return AppColors.accent;
    if (rate >= 0.2) return const Color(0xFFFFCC00);
    return const Color(0xFFE53935);
  }
}
