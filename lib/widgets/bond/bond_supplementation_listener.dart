import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_muted_card.dart';

/// 주중 보충 상태 실시간 표시
class BondSupplementationListener extends StatefulWidget {
  final String? groupId;
  final Function()? onMemberJoined;

  const BondSupplementationListener({
    super.key,
    this.groupId,
    this.onMemberJoined,
  });

  @override
  State<BondSupplementationListener> createState() =>
      _BondSupplementationListenerState();
}

class _BondSupplementationListenerState
    extends State<BondSupplementationListener> {
  int _previousMemberCount = 0;

  @override
  void initState() {
    super.initState();
    _previousMemberCount = 0;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groupId == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('partnerGroups')
          .doc(widget.groupId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) return const SizedBox.shrink();

        final needsSupplementation = data['needsSupplementation'] ?? false;
        final memberUids = List<String>.from(data['memberUids'] ?? []);
        final currentMemberCount = memberUids.length;

        if (_previousMemberCount > 0 &&
            currentMemberCount > _previousMemberCount) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && widget.onMemberJoined != null) {
              widget.onMemberJoined!();
            }
          });
        }
        _previousMemberCount = currentMemberCount;

        if (needsSupplementation && currentMemberCount < 3) {
          return _buildWaitingCard(currentMemberCount);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildWaitingCard(int currentCount) {
    return AppMutedCard(
      radius: AppRadius.md,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.warning),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '새 파트너를 기다리는 중',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentCount == 1 ? '곧 2명이 함께할 거예요' : '곧 3명이 완성될 거예요',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
