import 'package:flutter/material.dart';
import '../../models/partner_group.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_muted_card.dart';
import '../../core/widgets/app_badge.dart';

/// 파트너 그룹 멤버 카드
class BondMemberCard extends StatelessWidget {
  final GroupMemberMeta member;
  final bool isMe;
  final bool isSupplemented;
  final bool isContinuePair;

  const BondMemberCard({
    super.key,
    required this.member,
    this.isMe = false,
    this.isSupplemented = false,
    this.isContinuePair = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppMutedCard(
      radius: AppRadius.xl,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          member.careerBucket.isNotEmpty
                              ? member.careerBucket
                              : '연차 미표시',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (isMe)
                          AppBadge(
                            label: '나',
                            bgColor: AppColors.accent.withOpacity(0.10),
                            textColor: AppColors.accent,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      member.region.isNotEmpty
                          ? '📍 ${member.region}'
                          : '📍 지역 미표시',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSupplemented)
                AppBadge(
                  label: '🍃 보충',
                  bgColor: AppColors.success.withOpacity(0.10),
                  textColor: AppColors.success,
                ),
              if (isContinuePair && !isSupplemented)
                AppBadge(
                  label: '💛 이어가기',
                  bgColor: AppColors.warning.withOpacity(0.10),
                  textColor: AppColors.warning,
                ),
            ],
          ),
          if (member.mainConcerns.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: member.mainConcerns.take(2).map((tag) => AppBadge(
                label: '#$tag',
                bgColor: AppColors.surfaceMuted,
                textColor: AppColors.textSecondary,
              )).toList(),
            ),
          ] else if (member.mainConcernShown != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                AppBadge(
                  label: '#${member.mainConcernShown!}',
                  bgColor: AppColors.surfaceMuted,
                  textColor: AppColors.textSecondary,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.accent,
      ),
      child: Center(
        child: Text(
          member.region.isNotEmpty ? member.region[0] : '?',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.onAccent,
          ),
        ),
      ),
    );
  }
}

/// 그룹 멤버 목록 섹션
class BondMemberListSection extends StatelessWidget {
  final String? myUid;
  final List<GroupMemberMeta> members;
  final List<String>? previousPair;
  final bool needsSupplementation;

  const BondMemberListSection({
    super.key,
    this.myUid,
    required this.members,
    this.previousPair,
    this.needsSupplementation = false,
  });

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              const Text(
                '이번 주 파트너',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${members.length}명',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
        ...members.map((member) {
          final isMe           = member.uid == myUid;
          final isContinuePair = previousPair?.contains(member.uid) ?? false;
          final isSupplemented = member.isSupplemented;
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.sm,
            ),
            child: BondMemberCard(
              member: member,
              isMe: isMe,
              isSupplemented: isSupplemented,
              isContinuePair: isContinuePair,
            ),
          );
        }),
        if (needsSupplementation && members.length < 3)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Row(
                children: [
                  Icon(Icons.schedule, size: 18, color: AppColors.textSecondary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '곧 한 명 더 함께할 거예요',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}
