import 'package:flutter/material.dart';
import '../../services/partner_service.dart';
import '../../core/theme/app_colors.dart';

// AppColors 직접 참조 (TabTheme 제거)

/// 소모임 나가기 바텀시트
class BondLeaveSheet extends StatefulWidget {
  final VoidCallback onLeft;

  const BondLeaveSheet({super.key, required this.onLeft});

  static Future<void> show(BuildContext context, {required VoidCallback onLeft}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BondLeaveSheet(onLeft: onLeft),
    );
  }

  @override
  State<BondLeaveSheet> createState() => _BondLeaveSheetState();
}

class _BondLeaveSheetState extends State<BondLeaveSheet> {
  int _step = 1;

  static const _reasons = [
    '휴식이 필요해요',
    '맞지 않는 것 같아요',
    '재매칭을 원해요',
    '기타',
  ];
  int? _selectedReasonIndex;
  final _otherController = TextEditingController();
  bool _confirmed = false;
  bool _loading = false;

  String get _selectedReason {
    if (_selectedReasonIndex == null) return '';
    if (_selectedReasonIndex == 3) return _otherController.text.trim();
    return _reasons[_selectedReasonIndex!];
  }

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  Future<void> _onLeave() async {
    setState(() => _loading = true);
    final result = await PartnerService.leaveGroup(reason: _selectedReason);
    if (!mounted) return;

    if (result.status == LeaveStatus.success) {
      Navigator.of(context).pop();
      widget.onLeft();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('소모임에서 나왔어요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? '처리 중 문제가 생겼어요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottomPad),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: _step == 1 ? _buildStep1() : _buildStep2(),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Icon(Icons.logout_rounded, size: 22, color: AppColors.textPrimary.withOpacity(0.7)),
            const SizedBox(width: 8),
            Text(
              '소모임 나가기',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '나가면 지금 소모임에서 더 이상 활동할 수 없어요.',
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary.withOpacity(0.8), height: 1.5),
              ),
              const SizedBox(height: 6),
              Text(
                '기존 게시물과 기록은 다른 멤버에게 계속 보일 수 있어요.',
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary.withOpacity(0.8), height: 1.5),
              ),
              const SizedBox(height: 6),
              Text(
                '나간 후에는 다시 "추천으로 찾기"를 통해 새 소모임에 참여할 수 있어요.',
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary.withOpacity(0.8), height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: AppColors.surfaceMuted.withOpacity(0.5)),
                ),
                child: Text(
                  '취소',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary.withOpacity(0.6),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => setState(() => _step = 2),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE57373),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  '나가기',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep2() {
    final canSubmit = _confirmed && _selectedReasonIndex != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '정말 나갈까요?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          '이유를 알려주시면 더 나은 경험을 만들게요.',
          style: TextStyle(fontSize: 12, color: AppColors.textPrimary.withOpacity(0.5)),
        ),
        const SizedBox(height: 16),

        ...List.generate(_reasons.length, (i) {
          final selected = _selectedReasonIndex == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedReasonIndex = i),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.accent.withOpacity(0.15)
                    : AppColors.surfaceMuted.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? AppColors.accent : AppColors.surfaceMuted.withOpacity(0.3),
                  width: selected ? 1.2 : 0.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 18,
                    color: selected ? AppColors.accent : AppColors.textPrimary.withOpacity(0.3),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _reasons[i],
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary.withOpacity(0.85),
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        if (_selectedReasonIndex == 3) ...[
          const SizedBox(height: 4),
          TextField(
            controller: _otherController,
            maxLength: 100,
            style: TextStyle(fontSize: 13, color: AppColors.textPrimary.withOpacity(0.9)),
            decoration: InputDecoration(
              hintText: '이유를 간단히 적어주세요',
              hintStyle: TextStyle(fontSize: 13, color: AppColors.textPrimary.withOpacity(0.3)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.surfaceMuted),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.surfaceMuted.withOpacity(0.5)),
              ),
            ),
          ),
        ],

        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => setState(() => _confirmed = !_confirmed),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: _confirmed,
                  onChanged: (v) => setState(() => _confirmed = v ?? false),
                  activeColor: const Color(0xFFE57373),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  side: BorderSide(color: AppColors.textPrimary.withOpacity(0.3)),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '위 내용을 확인했어요',
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary.withOpacity(0.7)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _loading ? null : () => setState(() => _step = 1),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: AppColors.surfaceMuted.withOpacity(0.5)),
                ),
                child: Text(
                  '돌아가기',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary.withOpacity(0.6),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: (canSubmit && !_loading) ? _onLeave : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE57373),
                  disabledBackgroundColor: Colors.grey[300],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        '나가기',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}



