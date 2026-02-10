import 'package:flutter/material.dart';
import '../services/activity_log_service.dart';
import '../services/partner_service.dart';

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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6A5ACD).withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 헤더 (탭하면 펼침)
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.people_outline,
                      color: Color(0xFF6A5ACD), size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    '파트너 소식',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6A5ACD),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // 새 소식 dot
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF8A80),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey[400],
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Column(
                children: _items
                    .map((item) => _buildItemRow(item))
                    .toList(),
              ),
            ),
            // 확인 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _markRead,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[500],
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
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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

