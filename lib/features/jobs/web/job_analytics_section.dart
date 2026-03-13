import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../core/theme/app_colors.dart';
import '../../../models/job_stats_daily.dart';
import '../../../services/job_stats_service.dart';
import 'web_typography.dart';

/// 공고 분석 탭 – 조회수 추이 그래프 + 공고 비교표
///
/// 설계서 2.4.3 기준:
/// - 일별 조회수 라인 차트 (최근 7/30일)
/// - 지원수 막대 표시
/// - 공고 간 비교표 (조회수, 유니크, 지원수, 전환율, 7일 증감)
class JobAnalyticsSection extends StatefulWidget {
  const JobAnalyticsSection({super.key});

  @override
  State<JobAnalyticsSection> createState() => _JobAnalyticsSectionState();
}

class _JobAnalyticsSectionState extends State<JobAnalyticsSection> {
  List<_JobInfo> _jobs = [];
  _JobInfo? _selectedJob;
  List<JobStatsDaily> _dailyStats = [];
  Map<String, int> _totalStats = {};
  bool _loading = true;
  int _periodDays = 7; // 7 or 30

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('jobs')
          .where('createdBy', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();

      final jobs = snap.docs.map((d) {
        final data = d.data();
        return _JobInfo(
          id: d.id,
          title: data['title'] as String? ?? '(제목 없음)',
          clinicName: data['clinicName'] as String? ?? '',
          status: data['status'] as String? ?? 'pending',
        );
      }).toList();

      setState(() {
        _jobs = jobs;
        _loading = false;
      });

      if (jobs.isNotEmpty) {
        _selectJob(jobs.first);
      }
    } catch (e) {
      debugPrint('⚠️ loadJobs error: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _selectJob(_JobInfo job) async {
    setState(() {
      _selectedJob = job;
      _loading = true;
    });

    final daily = await JobStatsService.fetchDailyStats(
      job.id,
      days: _periodDays,
    );
    final total = await JobStatsService.fetchTotalStats(job.id);

    if (mounted) {
      setState(() {
        _dailyStats = daily;
        _totalStats = total;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return _buildLoginRequired();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // ── 공고 선택 드롭다운 ──
            _buildJobSelector(),
            const SizedBox(height: 20),

            // ── 요약 카드 ──
            _buildSummaryCards(),
            const SizedBox(height: 24),

            // ── 기간 선택 + 차트 ──
            _buildPeriodSelector(),
            const SizedBox(height: 12),
            _buildChart(),
            const SizedBox(height: 32),

            // ── 비교표 ──
            _buildComparisonHeader(),
            const SizedBox(height: 12),
            _buildComparisonTable(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 위젯 빌더들
  // ═══════════════════════════════════════════════════════════

  Widget _buildLoginRequired() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.analytics_outlined, size: 56,
              color: AppColors.textDisabled),
          const SizedBox(height: 16),
          Text(
            '로그인 후 공고 분석을 확인할 수 있어요.',
            style: WebTypo.body(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildJobSelector() {
    if (_jobs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(
          '등록된 공고가 없습니다. 공고를 먼저 등록해주세요.',
          style: WebTypo.body(color: AppColors.textSecondary),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedJob?.id,
          hint: Text('공고를 선택하세요',
              style: WebTypo.body(color: AppColors.textDisabled)),
          items: _jobs.map((j) {
            return DropdownMenuItem(
              value: j.id,
              child: Row(
                children: [
                  _statusDot(j.status),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      j.title,
                      style: WebTypo.body(color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (j.clinicName.isNotEmpty)
                    Text(
                      j.clinicName,
                      style: WebTypo.caption(
                          color: AppColors.textDisabled, size: 12),
                    ),
                ],
              ),
            );
          }).toList(),
          onChanged: (id) {
            if (id == null) return;
            _selectJob(_jobs.firstWhere((j) => j.id == id));
          },
        ),
      ),
    );
  }

  Widget _statusDot(String status) {
    Color c;
    switch (status) {
      case 'active':
        c = AppColors.success;
        break;
      case 'closed':
        c = AppColors.textDisabled;
        break;
      default:
        c = AppColors.accent;
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c),
    );
  }

  Widget _buildSummaryCards() {
    final views = _totalStats['views'] ?? 0;
    final unique = _totalStats['uniqueViews'] ?? 0;
    final applies = _totalStats['applies'] ?? 0;
    final conversion =
        views > 0 ? (applies / views * 100).toStringAsFixed(1) : '0.0';

    return Row(
      children: [
        _SummaryCard(
          label: '총 조회수',
          value: NumberFormat('#,###').format(views),
          icon: Icons.visibility_outlined,
          color: AppColors.accent,
        ),
        const SizedBox(width: 12),
        _SummaryCard(
          label: '유니크 조회',
          value: NumberFormat('#,###').format(unique),
          icon: Icons.person_outline,
          color: AppColors.warning,
        ),
        const SizedBox(width: 12),
        _SummaryCard(
          label: '지원 수',
          value: NumberFormat('#,###').format(applies),
          icon: Icons.send_outlined,
          color: AppColors.success,
        ),
        const SizedBox(width: 12),
        _SummaryCard(
          label: '전환율',
          value: '$conversion%',
          icon: Icons.trending_up,
          color: AppColors.error,
        ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      children: [
        Text(
          '조회수 추이',
          style: WebTypo.sectionTitle(color: AppColors.textPrimary),
        ),
        const Spacer(),
        _periodChip('7일', 7),
        const SizedBox(width: 8),
        _periodChip('30일', 30),
      ],
    );
  }

  Widget _periodChip(String label, int days) {
    final selected = _periodDays == days;
    return InkWell(
      onTap: () {
        setState(() => _periodDays = days);
        if (_selectedJob != null) _selectJob(_selectedJob!);
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withOpacity(0.1) : AppColors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? AppColors.accent.withOpacity(0.3) : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.notoSansKr(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.accent : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// 간단 막대 차트 (외부 패키지 없이 CustomPaint)
  Widget _buildChart() {
    if (_loading) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    if (_dailyStats.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        alignment: Alignment.center,
        child: Text(
          '아직 데이터가 없습니다.',
          style: WebTypo.body(color: AppColors.textDisabled),
        ),
      );
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: CustomPaint(
        size: const Size(double.infinity, 188),
        painter: _BarChartPainter(
          stats: _dailyStats,
          barColor: AppColors.accent,
          applyColor: AppColors.success,
        ),
      ),
    );
  }

  Widget _buildComparisonHeader() {
    return Text(
      '공고 비교표',
      style: WebTypo.sectionTitle(color: AppColors.textPrimary),
    );
  }

  Widget _buildComparisonTable() {
    if (_jobs.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: JobStatsService.fetchComparisonStats(
        _jobs.map((j) => j.id).toList(),
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final rows = snap.data ?? [];

        return Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                AppColors.accent.withOpacity(0.04),
              ),
              headingTextStyle: GoogleFonts.notoSansKr(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              dataTextStyle: GoogleFonts.notoSansKr(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              columns: const [
                DataColumn(label: Text('공고')),
                DataColumn(label: Text('조회수'), numeric: true),
                DataColumn(label: Text('유니크'), numeric: true),
                DataColumn(label: Text('지원수'), numeric: true),
                DataColumn(label: Text('전환율'), numeric: true),
                DataColumn(label: Text('7일 증감'), numeric: true),
              ],
              rows: rows.map((r) {
                final jobId = r['jobId'] as String;
                final jobInfo =
                    _jobs.where((j) => j.id == jobId).firstOrNull;
                final title = jobInfo?.title ?? jobId;
                final change = (r['recentChange'] as double?) ?? 0.0;

                return DataRow(cells: [
                  DataCell(
                    SizedBox(
                      width: 180,
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(Text('${r['views'] ?? 0}')),
                  DataCell(Text('${r['uniqueViews'] ?? 0}')),
                  DataCell(Text('${r['applies'] ?? 0}')),
                  DataCell(
                    Text('${(r['conversion'] as double?)?.toStringAsFixed(1) ?? '0.0'}%'),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          change >= 0
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 14,
                          color: change >= 0 ? AppColors.success : AppColors.error,
                        ),
                        Text(
                          '${change.abs().toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: change >= 0 ? AppColors.success : AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 데이터 클래스
// ═══════════════════════════════════════════════════════════

class _JobInfo {
  final String id;
  final String title;
  final String clinicName;
  final String status;
  const _JobInfo({
    required this.id,
    required this.title,
    required this.clinicName,
    required this.status,
  });
}

// ═══════════════════════════════════════════════════════════
// 요약 카드
// ═══════════════════════════════════════════════════════════

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: WebTypo.number(color: AppColors.textPrimary, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 간단 막대 차트 (외부 패키지 없이)
// ═══════════════════════════════════════════════════════════

class _BarChartPainter extends CustomPainter {
  final List<JobStatsDaily> stats;
  final Color barColor;
  final Color applyColor;

  _BarChartPainter({
    required this.stats,
    required this.barColor,
    required this.applyColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (stats.isEmpty) return;

    final maxViews =
        stats.map((s) => s.views).reduce((a, b) => a > b ? a : b);
    final maxVal = maxViews > 0 ? maxViews.toDouble() : 1.0;
    final barWidth = (size.width - 40) / stats.length;
    final chartHeight = size.height - 24;

    // 그리드 라인
    final gridPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 4; i++) {
      final y = chartHeight - (chartHeight / 4 * i);
      canvas.drawLine(
        Offset(30, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    // 막대
    for (int i = 0; i < stats.length; i++) {
      final s = stats[i];
      final x = 30 + barWidth * i + barWidth * 0.15;
      final bw = barWidth * 0.7;

      // 조회수 막대 (파란)
      final viewHeight = (s.views / maxVal) * chartHeight;
      final viewPaint = Paint()..color = barColor.withOpacity(0.6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, chartHeight - viewHeight, bw * 0.55, viewHeight),
          const Radius.circular(2),
        ),
        viewPaint,
      );

      // 지원수 막대 (초록)
      if (s.applies > 0) {
        final applyHeight = (s.applies / maxVal) * chartHeight;
        final applyPaint = Paint()..color = applyColor.withOpacity(0.7);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              x + bw * 0.55 + 2,
              chartHeight - applyHeight,
              bw * 0.45,
              applyHeight,
            ),
            const Radius.circular(2),
          ),
          applyPaint,
        );
      }

      // 날짜 라벨 (간소화)
      if (i % (stats.length > 14 ? 5 : 1) == 0 &&
          s.dateKey.length == 8) {
        final label = '${s.dateKey.substring(4, 6)}/${s.dateKey.substring(6)}';
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(fontSize: 9, color: Color(0xFF999999)),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + bw / 2 - tp.width / 2, chartHeight + 6));
      }
    }

    // Y축 라벨
    for (int i = 0; i <= 4; i++) {
      final val = (maxVal / 4 * i).round();
      final tp = TextPainter(
        text: TextSpan(
          text: '$val',
          style: const TextStyle(fontSize: 9, color: Color(0xFF999999)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final y = chartHeight - (chartHeight / 4 * i) - tp.height / 2;
      tp.paint(canvas, Offset(0, y));
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) =>
      old.stats != stats;
}
