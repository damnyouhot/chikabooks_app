import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/admin_dashboard_models.dart';
import '../../../services/admin_dashboard_service.dart';
import '../widgets/admin_common_widgets.dart';

class AdminUserFlowTab extends StatefulWidget {
  final DateTime since;
  const AdminUserFlowTab({super.key, required this.since});

  @override
  State<AdminUserFlowTab> createState() => _AdminUserFlowTabState();
}

class _AdminUserFlowTabState extends State<AdminUserFlowTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => false;

  bool _loading = true;
  String? _error;
  List<FunnelStep> _steps = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AdminUserFlowTab oldWidget) {
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
      final steps =
          await AdminDashboardService.getFunnelSteps(since: widget.since);
      if (!mounted) return;
      setState(() {
        _steps = steps;
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
          // 설명 배너
          _InfoBanner(
            text:
                '순차 온보딩 퍼널입니다. 각 단계 인원은 **이전 단계를 통과한 유저만** 포함됩니다(교집합). '
                '②~⑤ 이벤트는 계정당 1회만 기록됩니다.',
          ),
          const SizedBox(height: 16),

          // 온보딩 퍼널
          const AdminSectionTitle('온보딩 퍼널'),
          if (_steps.isEmpty)
            const AdminEmptyState(message: '퍼널 데이터가 아직 없어요')
          else
            _FunnelChart(steps: _steps),

          const SizedBox(height: 24),

          // 퍼널 해석 가이드
          _FunnelGuide(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── 안내 배너 ────────────────────────────────────────────────
class _InfoBanner extends StatelessWidget {
  final String text;
  const _InfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 퍼널 차트 ────────────────────────────────────────────────
class _FunnelChart extends StatelessWidget {
  final List<FunnelStep> steps;
  const _FunnelChart({required this.steps});

  @override
  Widget build(BuildContext context) {
    final maxCount = steps.fold(0, (m, s) => s.count > m ? s.count : m);

    return Column(
      children: List.generate(steps.length, (i) {
        final step = steps[i];
        final ratio = maxCount > 0 ? step.count / maxCount : 0.0;
        final isFirst = i == 0;
        final isLast = i == steps.length - 1;

        return Column(
          children: [
            _FunnelRow(
              step: step,
              ratio: ratio.toDouble(),
              stepNumber: i + 1,
              isFirst: isFirst,
            ),
            if (!isLast)
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: _DropArrow(rate: step.conversionRate),
              ),
          ],
        );
      }),
    );
  }
}

class _FunnelRow extends StatelessWidget {
  final FunnelStep step;
  final double ratio;
  final int stepNumber;
  final bool isFirst;

  const _FunnelRow({
    required this.step,
    required this.ratio,
    required this.stepNumber,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 단계 번호
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isFirst ? AppColors.accent : AppColors.disabledBg,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$stepNumber',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isFirst ? AppColors.onAccent : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  step.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${step.count}명',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 진행 바
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: AppColors.disabledBg,
              valueColor: AlwaysStoppedAnimation(
                isFirst ? AppColors.accent : AppColors.accent.withOpacity(0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropArrow extends StatelessWidget {
  final double? rate; // 전환율 (0.0~1.0)
  const _DropArrow({this.rate});

  @override
  Widget build(BuildContext context) {
    final pct = rate != null ? '${(rate! * 100).toStringAsFixed(0)}%' : '-';
    final isGood = rate != null && rate! >= 0.5;

    return Row(
      children: [
        const SizedBox(width: 6),
        const Icon(Icons.arrow_downward, size: 16, color: AppColors.textDisabled),
        const SizedBox(width: 4),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isGood
                ? AppColors.accent.withOpacity(0.12)
                : AppColors.error.withOpacity(0.10),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            '전환율 $pct',
            style: TextStyle(
              fontSize: 11,
              color: isGood ? AppColors.accent : AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 해석 가이드 ──────────────────────────────────────────────
class _FunnelGuide extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            '해석 가이드',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          _GuideItem(
            icon: Icons.arrow_downward,
            text: '순차 퍼널: N단계 인원 = (N−1단계를 통과한 사람) ∩ (N단계 이벤트가 있는 사람)',
          ),
          _GuideItem(
            icon: Icons.arrow_downward,
            text: '전환율이 낮은 단계 = 사용자가 막히는 지점',
          ),
          _GuideItem(
            icon: Icons.warning_amber_outlined,
            text: '50% 미만이면 개선 우선순위 검토 권장',
          ),
          _GuideItem(
            icon: Icons.refresh,
            text: '아래로 당겨서 최신 데이터로 새로고침',
          ),
        ],
      ),
    );
  }
}

class _GuideItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _GuideItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.textDisabled),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

