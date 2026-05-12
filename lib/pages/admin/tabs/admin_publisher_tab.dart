import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/admin_dashboard_service.dart';
import '../widgets/admin_common_widgets.dart';

/// 공고자(Publisher) · 주문 · 공고권 KPI 모니터링 탭
///
/// 그동안 [AdminDashboardService] 에 만들어만 두고 어떤 탭에서도 호출하지 않았던
/// 8개 메서드(`getTotalPublisherCount` 등)를 한 곳에 묶어 노출한 화면입니다.
///
/// ── 부분 실패 허용 ────────────────────────────────────────────
/// 각 KPI 는 nullable 로 보관됩니다. null = 측정 실패(권한/네트워크 오류), UI 는
/// "—" 로 표시해 진짜 0 과 구분합니다. 전체 KPI 가 동시에 실패한 경우에만
/// 화면을 오류 상태로 전환합니다.
/// ──────────────────────────────────────────────────────────────
class AdminPublisherTab extends StatefulWidget {
  final DateTime since;
  const AdminPublisherTab({super.key, required this.since});

  @override
  State<AdminPublisherTab> createState() => _AdminPublisherTabState();
}

class _AdminPublisherTabState extends State<AdminPublisherTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => false;

  bool _loading = true;
  bool _allFailed = false;
  DateTime? _lastSync;

  int? _totalPublishers;
  int? _newPublishers;
  int? _activePublishers;
  int? _identityVerified;
  int? _recentPaidOrders;
  Map<String, int>? _approval;
  Map<String, int>? _orderStatus;
  Map<String, int>? _voucherStatus;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AdminPublisherTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.since != widget.since) _load();
  }

  Future<int?> _safe(Future<int> Function() fn) async {
    try {
      return await fn();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, int>?> _safeMap(
    Future<Map<String, int>> Function() fn,
  ) async {
    try {
      return await fn();
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
      _safe(AdminDashboardService.getTotalPublisherCount),
      _safe(
        () => AdminDashboardService.getRecentPublisherSignups(
          since: widget.since,
        ),
      ),
      _safe(AdminDashboardService.getActivePublisherCount),
      _safe(AdminDashboardService.getIdentityVerifiedPublisherCount),
      _safe(
        () => AdminDashboardService.getRecentPaidOrderCount(
          since: widget.since,
        ),
      ),
      _safeMap(AdminDashboardService.getPublisherApprovalCounts),
      _safeMap(AdminDashboardService.getOrderStatusCounts),
      _safeMap(AdminDashboardService.getVoucherStatusCounts),
    ]);

    if (!mounted) return;

    final total = results[0] as int?;
    final newP = results[1] as int?;
    final active = results[2] as int?;
    final idVerified = results[3] as int?;
    final recentPaid = results[4] as int?;
    final approval = results[5] as Map<String, int>?;
    final orderStatus = results[6] as Map<String, int>?;
    final voucherStatus = results[7] as Map<String, int>?;

    final everyFailed =
        total == null &&
        newP == null &&
        active == null &&
        idVerified == null &&
        recentPaid == null &&
        approval == null &&
        orderStatus == null &&
        voucherStatus == null;

    setState(() {
      _totalPublishers = total;
      _newPublishers = newP;
      _activePublishers = active;
      _identityVerified = idVerified;
      _recentPaidOrders = recentPaid;
      _approval = approval;
      _orderStatus = orderStatus;
      _voucherStatus = voucherStatus;
      _lastSync = DateTime.now();
      _loading = false;
      _allFailed = everyFailed;
    });
  }

  String _fmt(int? v, {String suffix = '건'}) =>
      v == null ? '—' : '$v$suffix';

  String _fmtPeriod(int? v) => v == null ? '—' : '+$v건';

  String _formatTime(DateTime dt) =>
      '${dt.month}/${dt.day} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';

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

          const AdminSectionTitle('공고자 KPI'),
          _PublisherKpiGrid(
            tiles: [
              _KpiTile(label: '총 공고자', value: _fmt(_totalPublishers, suffix: '명')),
              _KpiTile(
                label: '기간 신규 가입',
                value: _fmtPeriod(_newPublishers),
                sublabel: _periodLabel,
              ),
              _KpiTile(
                label: '공고 작성 가능',
                value: _fmt(_activePublishers, suffix: '명'),
                sublabel: 'approved + canPost',
              ),
              _KpiTile(
                label: '본인인증 완료',
                value: _fmt(_identityVerified, suffix: '명'),
              ),
            ],
          ),

          const SizedBox(height: 20),

          const AdminSectionTitle('승인 상태 분포'),
          _StatusBarList(
            data: _approval,
            order: const [
              ('pending', '대기'),
              ('approved', '승인'),
              ('rejected', '거절'),
              ('suspended', '정지'),
            ],
            barColors: const {
              'pending': AppColors.warning,
              'approved': AppColors.success,
              'rejected': AppColors.error,
              'suspended': AppColors.textDisabled,
            },
            emptyHint: '승인 상태 데이터를 불러오지 못했어요.',
          ),

          const SizedBox(height: 20),

          const AdminSectionTitle('주문 / 결제'),
          _StatusBarList(
            data: _orderStatus,
            order: const [
              ('created', '생성'),
              ('paid', '결제 완료'),
              ('failed', '실패'),
              ('refunded', '환불'),
            ],
            barColors: const {
              'created': AppColors.textSecondary,
              'paid': AppColors.success,
              'failed': AppColors.error,
              'refunded': AppColors.warning,
            },
            emptyHint: '주문 상태 데이터를 불러오지 못했어요.',
          ),
          const SizedBox(height: 8),
          _MiniStat(
            label: '$_periodLabel 결제 완료 건수',
            value: _fmt(_recentPaidOrders),
          ),

          const SizedBox(height: 20),

          const AdminSectionTitle('공고권(Voucher) 상태'),
          _StatusBarList(
            data: _voucherStatus,
            order: const [
              ('active', '발급/활성'),
              ('used', '사용'),
              ('expired', '만료'),
            ],
            barColors: const {
              'active': AppColors.accent,
              'used': AppColors.success,
              'expired': AppColors.textDisabled,
            },
            emptyHint: '공고권 상태 데이터를 불러오지 못했어요.',
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String get _periodLabel {
    final now = DateTime.now();
    final diff = now.difference(widget.since).inDays;
    if (diff <= 0) return '오늘';
    if (diff <= 1) return '오늘';
    if (diff <= 7) return '7일';
    if (diff <= 30) return '30일';
    return '$diff일';
  }
}

class _KpiTile {
  final String label;
  final String value;
  final String? sublabel;
  const _KpiTile({required this.label, required this.value, this.sublabel});
}

class _PublisherKpiGrid extends StatelessWidget {
  final List<_KpiTile> tiles;
  const _PublisherKpiGrid({required this.tiles});

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
      itemCount: tiles.length,
      itemBuilder: (_, i) {
        final t = tiles[i];
        return AdminKpiCard(
          label: t.label,
          value: t.value,
          sublabel: t.sublabel,
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// status → count 분포를 가로 막대로 시각화.
class _StatusBarList extends StatelessWidget {
  final Map<String, int>? data;
  final List<(String, String)> order;
  final Map<String, Color> barColors;
  final String emptyHint;

  const _StatusBarList({
    required this.data,
    required this.order,
    required this.barColors,
    required this.emptyHint,
  });

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          emptyHint,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      );
    }

    final values = order.map((p) => data![p.$1] ?? 0).toList();
    final maxV = values.fold(0, (m, v) => v > m ? v : m);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(order.length, (i) {
        final key = order[i].$1;
        final label = order[i].$2;
        final v = values[i];
        final ratio = maxV > 0 ? v / maxV : 0.0;
        final color = barColors[key] ?? AppColors.accent;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  label,
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
                    minHeight: 12,
                    backgroundColor: AppColors.surfaceMuted,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                child: Text(
                  '$v건',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
