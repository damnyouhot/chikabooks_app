import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/admin_dashboard_models.dart';
import '../../../services/admin_dashboard_service.dart';
import '../widgets/admin_common_widgets.dart';

/// 감정 기록 타임라인 탭
///
/// emotionLogs 컬렉션을 최신순으로 보여주는 피드 형태 화면
class AdminEmotionFeedTab extends StatefulWidget {
  final DateTime since;
  const AdminEmotionFeedTab({super.key, required this.since});

  @override
  State<AdminEmotionFeedTab> createState() => _AdminEmotionFeedTabState();
}

class _AdminEmotionFeedTabState extends State<AdminEmotionFeedTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => false;

  bool _loading = true;
  String? _error;
  List<EmotionLogItem> _logs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AdminEmotionFeedTab oldWidget) {
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
      final logs = await AdminDashboardService.getRecentEmotionLogs(
        limit: 50,
        since: widget.since,
      );
      if (!mounted) return;
      setState(() {
        _logs = logs;
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
          AdminSectionTitle('감정 기록 피드 (${_logs.length}건)'),

          if (_logs.isEmpty)
            const AdminEmptyState(message: '기간 내 감정 기록이 없어요')
          else
            ..._logs.map((log) => _EmotionLogCard(log: log)),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── 감정 기록 카드 ───────────────────────────────────────────
class _EmotionLogCard extends StatelessWidget {
  final EmotionLogItem log;
  const _EmotionLogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 헤더: 시각 + 연차 + 점수 ─────────────────────────
          Row(
            children: [
              // 점수 배지
              _ScoreBadge(score: log.score),
              const SizedBox(width: 10),
              // 연차 (있으면)
              if (log.careerGroupSnapshot != null) ...[
                Text(
                  log.careerGroupSnapshot!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              // 시각
              Text(
                _formatTime(log.timestamp),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textDisabled,
                ),
              ),
            ],
          ),

          // ── 텍스트 (있으면) ──────────────────────────────────
          if (log.text != null && log.text!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              log.text!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // ── 태그 (있으면) ────────────────────────────────────
          if (log.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: log.tags
                  .map((tag) => _TagChip(tag: tag))
                  .toList(),
            ),
          ],

          // ── 유저 ID (마스킹) ─────────────────────────────────
          if (log.userId.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'UID: ${_maskUid(log.userId)}',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textDisabled,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.month}/${dt.day} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  /// UID 앞 8자 + '****' 마스킹
  String _maskUid(String uid) {
    if (uid.length <= 8) return uid;
    return '${uid.substring(0, 8)}****';
  }
}

// ─── 점수 배지 ────────────────────────────────────────────────
class _ScoreBadge extends StatelessWidget {
  final int? score;
  const _ScoreBadge({this.score});

  @override
  Widget build(BuildContext context) {
    if (score == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.disabledBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          '점수 없음',
          style: TextStyle(fontSize: 11, color: AppColors.textDisabled),
        ),
      );
    }

    // 점수 1~5 기준 색상
    final color = switch (score!) {
      1 => const Color(0xFFE53935),
      2 => const Color(0xFFFF8A65),
      3 => const Color(0xFFFFCC00),
      4 => const Color(0xFF66BB6A),
      _ => AppColors.accent,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '점수 $score',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

// ─── 태그 칩 ─────────────────────────────────────────────────
class _TagChip extends StatelessWidget {
  final String tag;
  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '#$tag',
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

