import 'package:flutter/material.dart';
import '../../models/partner_group.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_primary_card.dart';

/// 파트너 요약 섹션 (통합 버전)
/// - 접힌 상태: 아바타 + 1줄 요약
/// - 확장 상태: 파트너별 감정 해석
class BondSummarySection extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final bool enableToggle;
  final List<GroupMemberMeta>? members;
  final String? myUid;
  final Map<String, String>? memberNicknames;
  final Map<String, int>? weeklyPostCounts;
  final Map<String, int>? weeklyReactionCounts;
  final Widget? topRightOverlay;

  const BondSummarySection({
    super.key,
    required this.isExpanded,
    required this.onToggleExpand,
    this.enableToggle = true,
    this.members,
    this.myUid,
    this.memberNicknames,
    this.weeklyPostCounts,
    this.weeklyReactionCounts,
    this.topRightOverlay,
  });

  @override
  Widget build(BuildContext context) {
    if (members == null || members!.isEmpty) return const SizedBox.shrink();

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: AppPrimaryCard(
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Blue 헤더 배너
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg + 2,
                    AppSpacing.lg + 2,
                    topRightOverlay != null ? 80 : AppSpacing.lg + 2,
                    14,
                  ),
                  child: Row(
                    children: [
                      _buildPartnerAvatars(),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '동행 파트너',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onCardPrimary,
                          ),
                        ),
                      ),
                      if (enableToggle)
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: AppColors.onCardPrimary.withOpacity(0.7),
                        ),
                    ],
                  ),
                ),

                // 1줄 요약 (접힘 상태에서만)
                if (enableToggle && !isExpanded) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg + 2, 0, AppSpacing.lg + 2, AppSpacing.lg),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.onCardPrimary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Text(
                        _getOneLinerSummary(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.onCardPrimary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                ],

                // 확장 시: 내부 카드
                if (isExpanded) ...[
                  Container(
                    margin: const EdgeInsets.fromLTRB(
                      AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: _buildExpandedPartnerDetails(),
                  ),
                ],
              ],
            ),
            if (topRightOverlay != null)
              Positioned(
                top: 0,
                right: 0,
                child: IgnorePointer(child: topRightOverlay!),
              ),
          ],
        ),
      ),
    );

    if (!enableToggle) return card;
    return GestureDetector(onTap: onToggleExpand, child: card);
  }

  Widget _buildPartnerAvatars() {
    final displayMembers = members!.take(3).toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: displayMembers.asMap().entries.map((e) {
        final i      = e.key;
        final member = e.value;
        final isMe   = member.uid == myUid;
        final nickname = memberNicknames?[member.uid] ?? '파트너';

        return Transform.translate(
          offset: Offset(-6.0 * i, 0),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMe
                  ? AppColors.cardEmphasis
                  : AppColors.onCardPrimary.withOpacity(0.25),
              border: Border.all(
                color: AppColors.onCardPrimary.withOpacity(0.6),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                nickname.isNotEmpty ? nickname[0] : (isMe ? '나' : 'P'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isMe
                      ? AppColors.onCardEmphasis
                      : AppColors.onCardPrimary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _getOneLinerSummary() {
    final partners = members!.where((m) => m.uid != myUid).toList();
    if (partners.isEmpty) return '이번 주는 나만의 시간';

    int totalActivity = 0;
    for (final partner in partners) {
      totalActivity += (weeklyPostCounts?[partner.uid] ?? 0) +
          (weeklyReactionCounts?[partner.uid] ?? 0);
    }

    if (totalActivity == 0) return '조용히 이어지고 있어요';
    if (totalActivity <= 3) return '이번 주 함께 버티고 있어요';
    return '이번 주 ${totalActivity}번 교감을 나눴어요';
  }

  Widget _buildExpandedPartnerDetails() {
    final partners = members!.where((m) => m.uid != myUid).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '이번 주 함께하는 사람들',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...partners.map((partner) => _buildPartnerCard(partner)),
      ],
    );
  }

  Widget _buildPartnerCard(GroupMemberMeta partner) {
    final nickname      = memberNicknames?[partner.uid] ?? '파트너';
    final postCount     = weeklyPostCounts?[partner.uid] ?? 0;
    final reactionCount = weeklyReactionCounts?[partner.uid] ?? 0;
    final statusMsg     = _generateStatusMessage(postCount, reactionCount);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceMuted,
            ),
            child: Center(
              child: Text(
                nickname.isNotEmpty ? nickname[0] : 'P',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      nickname,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (partner.mainConcernShown != null &&
                        partner.mainConcernShown!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '· ${partner.mainConcernShown}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textDisabled,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  statusMsg,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _generateStatusMessage(int postCount, int reactionCount) {
    final totalActivity = postCount + reactionCount;
    if (totalActivity == 0) return '조용히 이어지고 있어요';
    if (totalActivity <= 2) return '이번 주 함께 버티고 있어요';
    return '이번 주 ${totalActivity}번 대화를 나눴어요';
  }
}
