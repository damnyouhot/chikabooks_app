import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/daily_slot.dart';
import '../../services/partner_service.dart';

/// 오늘의 말(슬롯) 카드
///
/// 시간대에 따라 현재 슬롯을 표시하고,
/// claim / 작성(60자) / 리액션 UI를 제공합니다.
class SlotCard extends StatefulWidget {
  final String groupId;

  const SlotCard({super.key, required this.groupId});

  @override
  State<SlotCard> createState() => _SlotCardState();
}

class _SlotCardState extends State<SlotCard> {
  final _textCtrl = TextEditingController();
  bool _claiming = false;
  bool _posting = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slotKey = PartnerService.currentSlotKey();
    final dateKey = PartnerService.todayDateKey();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCE93D8).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              const Icon(Icons.chat_bubble_outline,
                  color: Color(0xFFCE93D8), size: 20),
              const SizedBox(width: 8),
              const Text(
                '오늘의 말',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF424242),
                ),
              ),
              const Spacer(),
              if (slotKey != null)
                Text(
                  slotKey == '1230' ? '12:30 슬롯' : '19:00 슬롯',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 슬롯이 없는 시간대
          if (slotKey == null)
            _buildWaiting()
          else
            // 실시간 슬롯 스트림
            StreamBuilder<DailySlot>(
              stream: PartnerService.streamSlot(
                  widget.groupId, dateKey, slotKey),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                        child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )),
                  );
                }
                final slot = snap.data!;
                return _buildSlotContent(slot);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildWaiting() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          PartnerService.nextSlotGuide(),
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
      ),
    );
  }

  Widget _buildSlotContent(DailySlot slot) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    // ① 아무도 claim 안 함 → "내가 말할래" 버튼
    if (slot.isOpen) {
      return _buildClaimButton(slot);
    }

    // ② claim만 (글 없음) → "누군가 쓰는 중…"
    if (slot.isClaimed && (slot.text == null || slot.text!.isEmpty)) {
      if (slot.claimedByUid == myUid) {
        return _buildWriteUI(slot);
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            '누군가 쓰는 중…',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ),
      );
    }

    // ③ 글이 있음 → 말풍선 + 리액션
    return _buildPostedUI(slot);
  }

  Widget _buildClaimButton(DailySlot slot) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ElevatedButton(
          onPressed: _claiming
              ? null
              : () async {
                  setState(() => _claiming = true);
                  final success = await PartnerService.claimSlot(
                    widget.groupId,
                    slot.dateKey,
                    slot.slotKey,
                  );
                  if (mounted) {
                    setState(() => _claiming = false);
                    if (!success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('이미 누가 말했어요')),
                      );
                    }
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFCE93D8),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          ),
          child: _claiming
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('내가 말할래 ✍️',
                  style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _buildWriteUI(DailySlot slot) {
    return Column(
      children: [
        TextField(
          controller: _textCtrl,
          maxLength: 60,
          decoration: InputDecoration(
            hintText: '60자 이내로 한마디',
            counterText: '${_textCtrl.text.length}/60',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _posting || _textCtrl.text.trim().isEmpty
                ? null
                : () async {
                    setState(() => _posting = true);
                    final ok = await PartnerService.postSlot(
                      groupId: widget.groupId,
                      dateKey: slot.dateKey,
                      slotKey: slot.slotKey,
                      text: _textCtrl.text,
                    );
                    if (mounted) {
                      setState(() => _posting = false);
                      if (ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('한마디 남겼어요 ✨')),
                        );
                      }
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A5ACD),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _posting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('남기기'),
          ),
        ),
      ],
    );
  }

  Widget _buildPostedUI(DailySlot slot) {
    return Column(
      children: [
        // 말풍선
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E5F5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (slot.toneEmoji != null && slot.toneEmoji!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(slot.toneEmoji!,
                      style: const TextStyle(fontSize: 20)),
                ),
              Text(
                slot.text ?? '',
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 리액션 버튼들
        _ReactionRow(slotDocId: slot.id),
      ],
    );
  }
}

/// 리액션 선택 행
class _ReactionRow extends StatefulWidget {
  final String slotDocId;

  const _ReactionRow({required this.slotDocId});

  @override
  State<_ReactionRow> createState() => _ReactionRowState();
}

class _ReactionRowState extends State<_ReactionRow> {
  String? _myReaction;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadMyReaction();
  }

  Future<void> _loadMyReaction() async {
    final key = await PartnerService.getMySlotReaction(widget.slotDocId);
    if (mounted) setState(() { _myReaction = key; _loaded = true; });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: PartnerService.reactionOptions.entries.map((e) {
        final key = e.key;
        final option = e.value;
        final selected = _myReaction == key;
        return GestureDetector(
          onTap: () async {
            await PartnerService.setSlotReaction(widget.slotDocId, key);
            if (mounted) setState(() => _myReaction = key);
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFFE8DAFF)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: selected
                  ? Border.all(color: const Color(0xFF6A5ACD), width: 1.5)
                  : null,
            ),
            child: Text(
              '${option.emoji} ${option.label}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected
                    ? const Color(0xFF6A5ACD)
                    : Colors.grey[600],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}



