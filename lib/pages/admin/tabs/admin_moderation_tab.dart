import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import '../../../core/widgets/app_modal_scaffold.dart';
import '../../../services/admin_moderation_service.dart';
import '../widgets/admin_common_widgets.dart';

/// 모더레이션 탭 — 신고 누적·자동 숨김 게시물 검토/조치
///
/// ── 사용자 시나리오 ────────────────────────────────────────
/// 1. 운영자가 매일 아침 진입
/// 2. 상단 필터칩 (자동 숨김만 / 신고 누적만 / 전체) 으로 큐 좁히기
/// 3. 카드 클릭 → 본문 + 신고자 리스트 모달
/// 4. 액션: 복구 / 영구 삭제 / 숨김 유지 (모두 감사 로그 자동 기록)
/// ────────────────────────────────────────────────────────────
class AdminModerationTab extends StatefulWidget {
  const AdminModerationTab({super.key});

  @override
  State<AdminModerationTab> createState() => _AdminModerationTabState();
}

class _AdminModerationTabState extends State<AdminModerationTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => false;

  ModerationFilter _filter = ModerationFilter.hiddenOnly;
  bool _loading = true;
  String? _error;
  List<ReportedPostSummary> _items = const [];
  List<String> _partialErrors = const [];
  DateTime? _lastSync;

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
      final result = await AdminModerationService.listReportedPosts(
        filter: _filter,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _partialErrors = result.partialErrors;
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

  void _setFilter(ModerationFilter f) {
    if (_filter == f) return;
    setState(() => _filter = f);
    _load();
  }

  Future<void> _openDetail(ReportedPostSummary item) async {
    final detail = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ModerationDetailDialog(item: item),
    );
    if (detail == true) {
      await _load();
    }
  }

  String _formatTime(DateTime dt) {
    return '${dt.month}/${dt.day} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading && _items.isEmpty) {
      return const AdminLoadingState();
    }
    if (_error != null) {
      return AdminErrorState(message: _error!, onRetry: _load);
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _FilterChips(selected: _filter, onChanged: _setFilter),
          const SizedBox(height: 12),

          if (_lastSync != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '마지막 동기화: ${_formatTime(_lastSync!)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textDisabled,
                ),
              ),
            ),

          if (_partialErrors.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '일부 소스만 불러왔어요: ${_partialErrors.join(", ")}',
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: AdminEmptyState(
                message: '검토할 항목이 없습니다.',
              ),
            )
          else
            for (final item in _items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ModerationCard(
                  item: item,
                  onTap: () => _openDetail(item),
                ),
              ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final ModerationFilter selected;
  final ValueChanged<ModerationFilter> onChanged;
  const _FilterChips({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const labels = <ModerationFilter, String>{
      ModerationFilter.hiddenOnly: '자동 숨김만',
      ModerationFilter.reportedOnly: '신고 누적만',
      ModerationFilter.all: '전체',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: labels.entries.map((e) {
          final isSelected = e.key == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color:
                      isSelected ? AppColors.accent : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  e.value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppColors.onAccent
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ModerationCard extends StatelessWidget {
  final ReportedPostSummary item;
  final VoidCallback onTap;
  const _ModerationCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hidden = item.isHidden;
    final dateText = _formatShort(
      item.lastReportedAt ?? item.hiddenAt ?? item.createdAt,
    );
    final reasonText = item.lastReportReason ?? '—';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hidden
                ? AppColors.error.withValues(alpha: 0.4)
                : AppColors.divider,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Badge(
                  text: item.documentType.displayName,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                _Badge(
                  text: '신고 ${item.reportCount}',
                  color: item.reportCount >= 3
                      ? AppColors.error
                      : AppColors.warning,
                ),
                if (hidden) ...[
                  const SizedBox(width: 6),
                  _Badge(text: '자동 숨김', color: AppColors.error),
                ],
                const Spacer(),
                Text(
                  dateText,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textDisabled,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.preview.isEmpty ? '(본문 없음)' : item.preview,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '최근 신고 사유: $reasonText  ·  작성자 ${_shortUid(item.authorUid)}',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textDisabled,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _shortUid(String uid) {
    if (uid.isEmpty) return '미상';
    if (uid.length <= 8) return uid;
    return uid.substring(0, 8);
  }

  static String _formatShort(DateTime? d) {
    if (d == null) return '—';
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 30) return '${diff.inDays}일 전';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _ModerationDetailDialog extends StatefulWidget {
  final ReportedPostSummary item;
  const _ModerationDetailDialog({required this.item});

  @override
  State<_ModerationDetailDialog> createState() =>
      _ModerationDetailDialogState();
}

class _ModerationDetailDialogState extends State<_ModerationDetailDialog> {
  bool _loading = true;
  ReportedPostDetail? _detail;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await AdminModerationService.getReportedItem(
        documentPath: widget.item.documentPath,
      );
      if (!mounted) return;
      setState(() {
        _detail = d;
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

  Future<void> _resolve(ResolveAction action) async {
    final destructive = action == ResolveAction.permanentDelete;
    final actionLabel = switch (action) {
      ResolveAction.restore => '숨김 해제',
      ResolveAction.permanentDelete => '영구 삭제',
      ResolveAction.keepHidden => '숨김 유지',
    };

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AppConfirmModal(
        title: '$actionLabel 하시겠어요?',
        message: destructive
            ? '게시물과 신고 기록이 영구 삭제되어 복구할 수 없습니다.\n'
                '대상: ${widget.item.documentPath}'
            : '게시물 상태를 변경합니다.\n대상: ${widget.item.documentPath}',
        confirmLabel: actionLabel,
        destructive: destructive,
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await AdminModerationService.resolveReportedPost(
        documentPath: widget.item.documentPath,
        action: action,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message.isEmpty ? '처리됨' : result.message)),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppModalDialog(
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      borderOpacity: 0.7,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.item.documentType.displayName,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.item.documentPath,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textDisabled,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                '불러오기 실패: $_error',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.error,
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.55,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _detail!.body.isEmpty ? '(본문 없음)' : _detail!.body,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_detail!.reports.isEmpty)
                      const Text(
                        '신고 기록 없음',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textDisabled,
                        ),
                      )
                    else ...[
                      Text(
                        '신고 ${_detail!.reports.length}건',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final r in _detail!.reports)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${r.reasonDisplay.isEmpty ? r.reason : r.reasonDisplay} · ${_shortUid(r.reporterUid)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (r.additionalInfo != null &&
                                    r.additionalInfo!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      r.additionalInfo!,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _resolve(ResolveAction.restore),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('숨김 해제'),
              ),
              OutlinedButton.icon(
                onPressed:
                    _busy ? null : () => _resolve(ResolveAction.keepHidden),
                icon: const Icon(Icons.visibility_off_outlined, size: 18),
                label: const Text('숨김 유지'),
              ),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _resolve(ResolveAction.permanentDelete),
                icon: const Icon(Icons.delete_forever_outlined, size: 18),
                label: const Text('영구 삭제'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                ),
              ),
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text('닫기'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _shortUid(String uid) {
    if (uid.isEmpty) return '미상';
    if (uid.length <= 8) return uid;
    return uid.substring(0, 8);
  }
}
