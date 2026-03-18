import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/admin_dashboard_models.dart';
import '../../../services/admin_dashboard_service.dart';
import '../widgets/admin_common_widgets.dart';

/// 기록하기 타임라인 탭
///
/// 1번 탭 '기록하기'에서 사용자가 작성한 notes를 트위터 타임라인처럼 최신순으로 표시
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
  List<NoteFeedItem> _notes = [];

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
      final notes = await AdminDashboardService.getRecentNotes(
        limit: 50,
        since: widget.since,
      );
      if (!mounted) return;
      setState(() {
        _notes = notes;
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
    if (_error != null) return AdminErrorState(
      message: _error!,
      onRetry: _load,
    );

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AdminSectionTitle('기록하기 피드 (${_notes.length}건)'),

          if (_notes.isEmpty)
            const AdminEmptyState(message: '기간 내 기록하기 내용이 없어요')
          else
            ..._notes.map((note) => _NoteCard(note: note)),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── 트위터 타임라인형 기록 카드 ─────────────────────────────────
class _NoteCard extends StatelessWidget {
  final NoteFeedItem note;
  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 헤더: UID 마스킹 + 시각 ────────────────────────────
          Row(
            children: [
              Text(
                '@${_maskUid(note.userId)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                _formatTime(note.createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textDisabled,
                ),
              ),
            ],
          ),

          // ── 본문 ──────────────────────────────────────────────────
          const SizedBox(height: 10),
          if (note.text.isNotEmpty)
            Text(
              note.text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),

          // ── 이미지 썸네일 ──────────────────────────────────────
          if (note.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 60,
              child: Row(
                children: [
                  ...note.imageUrls.take(3).map((url) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            url,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            cacheWidth: 120,
                            errorBuilder: (_, __, ___) => Container(
                              width: 60,
                              height: 60,
                              color: AppColors.disabledBg,
                              child: const Icon(Icons.broken_image_outlined,
                                  size: 18, color: AppColors.textDisabled),
                            ),
                          ),
                        ),
                      )),
                  if (note.imageUrls.length > 1)
                    Text(
                      '${note.imageUrls.length}장',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textDisabled,
                      ),
                    ),
                ],
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

  String _maskUid(String uid) {
    if (uid.isEmpty) return 'unknown';
    if (uid.length <= 8) return uid;
    return '${uid.substring(0, 8)}****';
  }
}
