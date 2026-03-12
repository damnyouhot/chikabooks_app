import 'package:flutter/material.dart';
import '../../models/partner_group.dart';
import '../../core/theme/tab_theme.dart';

const _b = TabTheme.bond;

/// 파트너 요약 (감정 해석 문장 중심)
class BondPartnerSummary extends StatelessWidget {
  final List<GroupMemberMeta> members;
  final String? myUid;
  final Map<String, String>? memberNicknames;
  final Map<String, int>? weeklyPostCounts;
  final Map<String, int>? weeklyReactionCounts;

  const BondPartnerSummary({
    super.key,
    required this.members,
    this.myUid,
    this.memberNicknames,
    this.weeklyPostCounts,
    this.weeklyReactionCounts,
  });

  @override
  Widget build(BuildContext context) {
    final partners = members.where((m) => m.uid != myUid).toList();

    if (partners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _b.shadow2.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이번 주 함께하는 사람들',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _b.onBg,
            ),
          ),
          const SizedBox(height: 16),
          ...partners.map((partner) => _buildPartnerCard(partner)),
        ],
      ),
    );
  }

  Widget _buildPartnerCard(GroupMemberMeta partner) {
    final nickname = memberNicknames?[partner.uid] ?? '파트너';
    final postCount = weeklyPostCounts?[partner.uid] ?? 0;
    final reactionCount = weeklyReactionCounts?[partner.uid] ?? 0;
    final message = _generateEmotionalMessage(postCount, reactionCount);
    final activityText = _generateActivityText(postCount, reactionCount);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _b.shadow2,
            ),
            child: Center(
              child: Text(
                nickname.isNotEmpty ? nickname[0] : 'P',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _b.onBg,
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
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _b.onBg,
                      ),
                    ),
                    if (partner.mainConcernShown != null &&
                        partner.mainConcernShown!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '· ${partner.mainConcernShown}',
                        style: TextStyle(
                          fontSize: 12,
                          color: _b.onBg.withOpacity(0.4),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  activityText,
                  style: TextStyle(
                    fontSize: 13,
                    color: _b.onBg.withOpacity(0.7),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    color: _b.onBg.withOpacity(0.5),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _generateActivityText(int postCount, int reactionCount) {
    if (postCount == 0 && reactionCount == 0) return '이번 주는 조용히 지나갔어';
    if (postCount > 0 && reactionCount > 0) return '이번 주 ${postCount}번 다녀갔고, ${reactionCount}번 반응했어';
    if (postCount > 0) return '이번 주 ${postCount}번 다녀갔어';
    return '${reactionCount}번 조용히 반응했어';
  }

  String _generateEmotionalMessage(int postCount, int reactionCount) {
    final totalActivity = postCount + reactionCount;
    if (totalActivity == 0) return '조용함도 같이 있는 방식이야';
    if (totalActivity == 1) return '한 번의 흔적도 소중해';
    if (totalActivity <= 3) return '적당히 바쁜 주였나봐';
    if (totalActivity <= 5) return '꾸준히 곁에 있었어';
    if (postCount > 5) return '많이 바빴던 주 같아';
    return '이번 주 자주 마주쳤네';
  }
}
