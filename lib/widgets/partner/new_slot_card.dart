import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/slot_status.dart';
import '../../models/slot_message.dart';
import '../../services/partner_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_muted_card.dart';
import '../../core/widgets/app_primary_button.dart';

/// 새로운 슬롯 카드 (서버 시간 기준)
///
/// 슬롯 오픈: 12:30~12:59, 19:00~19:29 (KST)
/// 1명만 한마디 작성, 나머지는 리액션만 가능
class NewSlotCard extends StatefulWidget {
  final String groupId;

  const NewSlotCard({super.key, required this.groupId});

  @override
  State<NewSlotCard> createState() => _NewSlotCardState();
}

class _NewSlotCardState extends State<NewSlotCard> {
  SlotStatus? _slotStatus;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSlotStatus();
  }

  Future<void> _loadSlotStatus() async {
    final status = await PartnerService.getSlotStatus(widget.groupId);
    if (mounted) {
      setState(() {
        _slotStatus = status;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppMutedCard(
      radius: AppRadius.xl,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              const Icon(Icons.chat_bubble_outline,
                  color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              const Text(
                '오늘의 말',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (_slotStatus != null && _slotStatus!.slotKey != null)
                Text(
                  _slotStatus!.timeLabel,
                  style: const TextStyle(fontSize: 12, color: AppColors.textDisabled),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 로딩 중
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                  child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )),
            )
          // 슬롯 상태에 따라 UI 표시
          else if (_slotStatus != null)
            _buildSlotContent()
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  '슬롯 상태를 불러올 수 없어요',
                  style: TextStyle(fontSize: 13, color: AppColors.textDisabled),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSlotContent() {
    final status = _slotStatus!;

    // 슬롯이 닫혀 있음
    if (!status.isOpen) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Column(
            children: [
              Text(
                '다음 오픈: ${_formatNextOpen(status.nextOpensAt)}',
                style: const TextStyle(fontSize: 13, color: AppColors.textDisabled),
              ),
            ],
          ),
        ),
      );
    }

    // 슬롯이 열려 있음
    if (status.slotId == null) return const SizedBox.shrink();

    return StreamBuilder<SlotMessage?>(
      stream: PartnerService.streamSlotMessage(widget.groupId, status.slotId!),
      builder: (context, snap) {
        if (!snap.hasData || snap.data == null) {
          // 아직 아무도 작성 안 함
          return _buildOpenSlotUI(status);
        }

        final message = snap.data!;
        return _buildMessageUI(message, status);
      },
    );
  }

  /// 슬롯 오픈 중 (아무도 작성 안 함)
  Widget _buildOpenSlotUI(SlotStatus status) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            const Text(
              '지금 말할 수 있어요',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 8),
            AppPrimaryButton(
              label: '한마디 쓰기 ✍️',
              onPressed: () => _showWriteDialog(status),
              radius: AppRadius.full,
            ),
          ],
        ),
      ),
    );
  }

  /// 메시지가 있는 경우
  Widget _buildMessageUI(SlotMessage message, SlotStatus status) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final isMyMessage = message.authorUid == myUid;

    return Column(
      children: [
        // 말풍선
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Text(
            message.message,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
        const SizedBox(height: 10),

        // 리액션 버튼 (본인이 작성한 메시지가 아닌 경우만)
        if (!isMyMessage)
          _ReactionRow(
            groupId: widget.groupId,
            slotId: message.id,
            myReaction: message.reactions[myUid],
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '내가 남긴 한마디',
              style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
            ),
          ),
      ],
    );
  }

  /// 한마디 작성 다이얼로그
  void _showWriteDialog(SlotStatus status) {
    final textCtrl = TextEditingController();
    bool submitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('한마디 쓰기'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textCtrl,
                maxLength: 60,
                decoration: const InputDecoration(
                  hintText: '60자 이내로 한마디',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: submitting || textCtrl.text.trim().isEmpty
                  ? null
                  : () async {
                      setDialogState(() => submitting = true);
                      final ok = await PartnerService.submitSlotMessage(
                        groupId: widget.groupId,
                        message: textCtrl.text.trim(),
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        if (ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('한마디 남겼어요 ✨')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('이미 누가 말했거나 시간이 지났어요')),
                          );
                        }
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('남기기'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNextOpen(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }
}

/// 리액션 선택 행
class _ReactionRow extends StatefulWidget {
  final String groupId;
  final String slotId;
  final SlotReaction? myReaction;

  const _ReactionRow({
    required this.groupId,
    required this.slotId,
    this.myReaction,
  });

  @override
  State<_ReactionRow> createState() => _ReactionRowState();
}

class _ReactionRowState extends State<_ReactionRow> {
  String? _selectedPhraseId;

  @override
  void initState() {
    super.initState();
    _selectedPhraseId = widget.myReaction?.phraseId;
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: PartnerService.reactionOptions.entries.map((e) {
        final key = e.key;
        final option = e.value;
        final selected = _selectedPhraseId == key;
        return GestureDetector(
          onTap: () async {
            final ok = await PartnerService.submitSlotReaction(
              groupId: widget.groupId,
              slotId: widget.slotId,
              emoji: option.emoji,
              phraseId: key,
              phraseText: option.label,
            );
            if (ok && mounted) {
              setState(() => _selectedPhraseId = key);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('리액션 남겼어요 💛')),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.accent.withOpacity(0.12)
                  : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: selected
                  ? Border.all(color: AppColors.accent, width: 1.5)
                  : null,
            ),
            child: Text(
              '${option.emoji} ${option.label}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
