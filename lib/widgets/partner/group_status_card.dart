import 'package:flutter/material.dart';
import '../../models/partner_group.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_muted_card.dart';
import '../../core/widgets/app_badge.dart';

/// "이번 주 파트너" 상태 카드
class GroupStatusCard extends StatelessWidget {
  final PartnerGroup group;
  final List<GroupMemberMeta> members;

  const GroupStatusCard({
    super.key,
    required this.group,
    required this.members,
  });

  @override
  Widget build(BuildContext context) {
    final daysLeft = group.daysLeft;

    return AppMutedCard(
      radius: AppRadius.xl,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              const Icon(Icons.people_outline,
                  color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              const Text(
                '이번 주 파트너',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              AppBadge(
                label: daysLeft == 0 ? '오늘 종료' : 'D-$daysLeft',
                bgColor: daysLeft <= 1
                    ? AppColors.error.withOpacity(0.10)
                    : AppColors.accent.withOpacity(0.10),
                textColor: daysLeft <= 1
                    ? AppColors.error
                    : AppColors.accent,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 멤버 라벨 (닉네임/사진 없이 뱃지만)
          ...members.map((m) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      m.displayLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
