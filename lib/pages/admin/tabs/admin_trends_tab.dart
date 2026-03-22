import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/analytics_daily_model.dart';
import '../../../services/admin_analytics_daily_service.dart';
import '../widgets/admin_common_widgets.dart';

/// 추세(Trends) 탭
///
/// analytics_daily 기반 차트 5종 표시.
/// 기간: 30 / 60 / 90일 선택 가능.
/// 백필 버튼으로 누락 날짜 생성 가능.
class AdminTrendsTab extends StatefulWidget {
  const AdminTrendsTab({super.key});

  @override
  State<AdminTrendsTab> createState() => _AdminTrendsTabState();
}

class _AdminTrendsTabState extends State<AdminTrendsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int _days = 30;
  bool _loading = true;
  bool _backfilling = false;
  String? _error;
  List<DailySummary> _data = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final start = now.subtract(Duration(days: _days));
      final data = await AdminAnalyticsDailyService.fetchRange(
        start: start,
        end: now,
      );
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

  Future<void> _backfill() async {
    setState(() => _backfilling = true);
    try {
      final now = DateTime.now();
      final start = now.subtract(Duration(days: _days));
      final created = await AdminAnalyticsDailyService.backfill(
        start: start,
        end: now.subtract(const Duration(days: 1)),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$created일 집계 생성 완료')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('백필 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _backfilling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 기간 선택 + 백필 ──
          Row(
            children: [
              ...[30, 60, 90].map((d) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _DayChip(
                      label: '${d}일',
                      selected: _days == d,
                      onTap: () {
                        setState(() => _days = d);
                        _load();
                      },
                    ),
                  )),
              const Spacer(),
              TextButton.icon(
                onPressed: _backfilling ? null : _backfill,
                icon: _backfilling
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.build_outlined, size: 14),
                label: Text(
                  _backfilling ? '생성 중...' : '백필',
                  style: const TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_loading)
            const AdminLoadingState()
          else if (_error != null)
            AdminErrorState(message: _error!, onRetry: _load)
          else if (_data.isEmpty)
            const AdminEmptyState(message: '집계 데이터가 없어요. 백필을 실행해보세요.')
          else ...[
            // 데이터 수 안내
            Text(
              '${_data.length}일 / ${_days}일 데이터',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textDisabled),
            ),
            const SizedBox(height: 16),

            // ── 1. 일별 활성 유저 수 ──
            const AdminSectionTitle('1. 일별 활성 유저 수'),
            _TrendChart(
              data: _data,
              getValue: (d) => d.activeUsers.toDouble(),
              color: AppColors.accent,
            ),
            const SizedBox(height: 24),

            // ── 2. 탭 사용 추이 ──
            const AdminSectionTitle('2. 탭 사용 추이'),
            _MultiLineChart(
              data: _data,
              series: {
                '나 탭': (d) =>
                    (d.tabViews['view_home'] ?? 0).toDouble(),
                '성장 탭': (d) =>
                    (d.tabViews['view_growth'] ?? 0).toDouble(),
                '구직 탭': (d) =>
                    (d.tabViews['view_job'] ?? 0).toDouble(),
                '교감 탭': (d) =>
                    (d.tabViews['view_bond'] ?? 0).toDouble(),
              },
              colors: const [
                Color(0xFF66BB6A),
                AppColors.accent,
                Color(0xFFFFCC00),
                Color(0xFF42A5F5),
              ],
            ),
            const SizedBox(height: 24),

            // ── 3. 기능 사용 추이 ──
            const AdminSectionTitle('3. 기능 사용 추이'),
            _MultiLineChart(
              data: _data,
              series: {
                '감정 기록': (d) =>
                    (d.featureUsage['emotion_save_success'] ?? 0).toDouble(),
                '캐릭터': (d) =>
                    (d.featureUsage['tap_character'] ?? 0).toDouble(),
                '밥주기': (d) =>
                    (d.featureUsage['caring_feed_success'] ?? 0).toDouble(),
                '공고 클릭': (d) =>
                    (d.featureUsage['view_job_detail'] ?? 0).toDouble(),
                '퀴즈': (d) =>
                    (d.featureUsage['quiz_completed'] ?? 0).toDouble(),
              },
              colors: const [
                Color(0xFFEF5350),
                Color(0xFF66BB6A),
                Color(0xFFFF9800),
                Color(0xFFFFCC00),
                AppColors.accent,
              ],
            ),
            const SizedBox(height: 24),

            // ── 4. 유저 타입 분포 추이 ──
            const AdminSectionTitle('4. 유저 타입 분포 추이'),
            _MultiLineChart(
              data: _data,
              series: {
                '성장 관심형': (d) =>
                    (d.segments['growth'] ?? 0).toDouble(),
                '감정형': (d) =>
                    (d.segments['emotion'] ?? 0).toDouble(),
                '커리어형': (d) =>
                    (d.segments['career'] ?? 0).toDouble(),
                '교감형': (d) =>
                    (d.segments['bond'] ?? 0).toDouble(),
                '유령': (d) =>
                    (d.segments['ghost'] ?? 0).toDouble(),
              },
              colors: const [
                AppColors.accent,
                Color(0xFFEF5350),
                Color(0xFFFFCC00),
                Color(0xFF42A5F5),
                Color(0xFFBDBDBD),
              ],
            ),
            const SizedBox(height: 24),

            // ── 5. 행동 깊이 분포 추이 ──
            const AdminSectionTitle('5. 행동 깊이 추이'),
            _MultiLineChart(
              data: _data,
              series: {
                '로그인만': (d) =>
                    (d.depthBuckets['loginOnly'] ?? 0).toDouble(),
                '1회': (d) =>
                    (d.depthBuckets['oneAction'] ?? 0).toDouble(),
                '2~4회': (d) =>
                    (d.depthBuckets['twoToFour'] ?? 0).toDouble(),
                '5회+': (d) =>
                    (d.depthBuckets['fivePlus'] ?? 0).toDouble(),
              },
              colors: const [
                Color(0xFFBDBDBD),
                Color(0xFFFFCC00),
                AppColors.accent,
                Color(0xFF66BB6A),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 단일 라인 차트
// ═══════════════════════════════════════════════════════════════
class _TrendChart extends StatelessWidget {
  final List<DailySummary> data;
  final double Function(DailySummary) getValue;
  final Color color;

  const _TrendChart({
    required this.data,
    required this.getValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final spots = <FlSpot>[];
    for (var i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), getValue(data[i])));
    }

    return Container(
      height: 180,
      padding: const EdgeInsets.only(right: 16, top: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: _calcInterval(spots),
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.divider,
              strokeWidth: 0.5,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textDisabled),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: _xInterval,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox();
                  final dk = data[idx].dateKey;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${dk.substring(5, 7)}/${dk.substring(8)}',
                      style: const TextStyle(
                          fontSize: 9, color: AppColors.textDisabled),
                    ),
                  );
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: color,
              barWidth: 2,
              dotData: FlDotData(
                show: data.length <= 31,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 2,
                  color: color,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: color.withOpacity(0.08),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) {
                final idx = s.spotIndex;
                final dk = idx < data.length ? data[idx].dateKey : '';
                return LineTooltipItem(
                  '$dk\n${s.y.toInt()}',
                  const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  double get _xInterval {
    if (data.length <= 7) return 1;
    if (data.length <= 31) return 5;
    if (data.length <= 60) return 10;
    return 15;
  }

  double _calcInterval(List<FlSpot> spots) {
    if (spots.isEmpty) return 1;
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    if (maxY <= 5) return 1;
    if (maxY <= 20) return 5;
    if (maxY <= 50) return 10;
    return (maxY / 5).ceilToDouble();
  }
}

// ═══════════════════════════════════════════════════════════════
// 다중 라인 차트 (범례 포함)
// ═══════════════════════════════════════════════════════════════
class _MultiLineChart extends StatelessWidget {
  final List<DailySummary> data;
  final Map<String, double Function(DailySummary)> series;
  final List<Color> colors;

  const _MultiLineChart({
    required this.data,
    required this.series,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final entries = series.entries.toList();
    final lineBars = <LineChartBarData>[];
    double maxY = 0;

    for (var si = 0; si < entries.length; si++) {
      final getter = entries[si].value;
      final color = colors[si % colors.length];
      final spots = <FlSpot>[];
      for (var i = 0; i < data.length; i++) {
        final v = getter(data[i]);
        spots.add(FlSpot(i.toDouble(), v));
        if (v > maxY) maxY = v;
      }
      lineBars.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        preventCurveOverShooting: true,
        color: color,
        barWidth: 2,
        dotData: const FlDotData(show: false),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 범례
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: List.generate(entries.length, (i) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colors[i % colors.length],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  entries[i].key,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            );
          }),
        ),
        const SizedBox(height: 8),
        Container(
          height: 180,
          padding: const EdgeInsets.only(right: 16, top: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(14),
          ),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: _calcInterval(maxY),
                getDrawingHorizontalLine: (_) => FlLine(
                  color: AppColors.divider,
                  strokeWidth: 0.5,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (v, _) => Text(
                      v.toInt().toString(),
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textDisabled),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: _xInterval,
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= data.length) {
                        return const SizedBox();
                      }
                      final dk = data[idx].dateKey;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${dk.substring(5, 7)}/${dk.substring(8)}',
                          style: const TextStyle(
                              fontSize: 9, color: AppColors.textDisabled),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: lineBars,
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots.map((s) {
                    final si = s.barIndex;
                    final label =
                        si < entries.length ? entries[si].key : '';
                    return LineTooltipItem(
                      '$label: ${s.y.toInt()}',
                      TextStyle(
                        fontSize: 11,
                        color: colors[si % colors.length],
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  double get _xInterval {
    if (data.length <= 7) return 1;
    if (data.length <= 31) return 5;
    if (data.length <= 60) return 10;
    return 15;
  }

  double _calcInterval(double maxY) {
    if (maxY <= 5) return 1;
    if (maxY <= 20) return 5;
    if (maxY <= 50) return 10;
    return (maxY / 5).ceilToDouble();
  }
}

// ═══════════════════════════════════════════════════════════════
// 기간 선택 칩
// ═══════════════════════════════════════════════════════════════
class _DayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.onAccent : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
