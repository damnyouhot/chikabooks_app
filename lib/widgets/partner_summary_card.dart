import 'package:flutter/material.dart';
import '../services/activity_log_service.dart';
import '../services/partner_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';

/// CaringPage 파트너 소식 접이식 카드
///
/// 활성 그룹이 있고 unread 활동이 있을 때만 표시.
/// 사람별(actorUid)로 아이콘 요약만 보여줌 (과시/숫자 최소).
class PartnerSummaryCard extends StatefulWidget {
  final String groupId;

  const PartnerSummaryCard({super.key, required this.groupId});

  @override
  State<PartnerSummaryCard> createState() => _PartnerSummaryCardState();
}

class _PartnerSummaryCardState extends State<PartnerSummaryCard> {
  List<PartnerSummaryItem> _items = [];
  bool _loading = true;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final members =
          await PartnerService.getGroupMembers(widget.groupId);
      final items = await ActivityLogService.buildSummaryItems(
          widget.groupId, members);
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _markRead() async {
    await ActivityLogService.markAsRead(widget.groupId);
    if (mounted) setState(() => _items = []);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          // 헤더 (탭하면 펼침)
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.people_outline,
                      color: AppColors.accent, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    '파트너 소식',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // 새 소식 dot
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.textDisabled,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // 펼침 영역
          if (_expanded) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 4),
              child: Column(
                children: _items
                    .map((item) => _buildItemRow(item))
                    .toList(),
              ),
            ),
            // 확인 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 4, AppSpacing.lg, 12),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _markRead,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textDisabled,
                  ),
                  child: const Text('확인했어',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemRow(PartnerSummaryItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // 뱃지
          Text(
            item.memberMeta.displayLabel,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const Spacer(),
          // 아이콘 요약
          Text(
            item.iconSummary,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
