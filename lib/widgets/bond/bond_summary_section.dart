import 'package:flutter/material.dart';
import '../../models/partner_group.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_style.dart';

// 같이 탭 팔레트 단축 참조
// AppColors 직접 참조 (TabTheme 제거)

/// 파트너 요약 섹션 (통합 버전)
/// - 접힌 상태: 아바타 + 1줄 요약
/// - 확장 상태: 파트너별 감정 해석 (MemberList + PartnerSummary 흡수)
class BondSummarySection extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final bool enableToggle;
  final List<GroupMemberMeta>? members;
  final String? myUid;
  final Map<String, String>? memberNicknames;
  final Map<String, int>? weeklyPostCounts; // 주간 활동 데이터
  final Map<String, int>? weeklyReactionCounts;
  final Widget? topRightOverlay; // 예: 결 점수 게이지

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
    // 멤버가 없으면 렌더링하지 않음
    if (members == null || members!.isEmpty) {
      return const SizedBox.shrink();
    }

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      // Blue 채운 카드로 임팩트 강화
      decoration: AppStyle.primaryCardDecoration(),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Blue 헤더 배너
              Padding(
                padding: EdgeInsets.fromLTRB(18, 18, topRightOverlay != null ? 80 : 18, 14),
                child: Row(
                  children: [
                    _buildPartnerAvatars(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '동행 파트너',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onAccent,  // White on Blue
                        ),
                      ),
                    ),
                    if (enableToggle)
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: AppColors.onAccent.withOpacity(0.7),
                      ),
                  ],
                ),
              ),

              // 1줄 요약 (접힘 상태에서만)
              if (enableToggle && !isExpanded) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _getOneLinerSummary(),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.onAccent,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ],

              // 확장 시: White 배경의 내부 카드
              if (isExpanded) ...[
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
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
    );

    if (!enableToggle) return card;
    return GestureDetector(onTap: onToggleExpand, child: card);
  }

  Widget _buildPartnerAvatars() {
    final displayMembers = members!.take(3).toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children:
          displayMembers.asMap().entries.map((e) {
            final i = e.key;
            final member = e.value;
            final isMe = member.uid == myUid;
            final nickname = memberNicknames?[member.uid] ?? '파트너';

            return Transform.translate(
              offset: Offset(-6.0 * i, 0),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isMe
                      ? AppColors.cardEmphasis             // Neon 내 아바타
                      : Colors.white.withOpacity(0.35),
                  border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    nickname.isNotEmpty ? nickname[0] : (isMe ? '나' : 'P'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isMe ? AppColors.onCardEmphasis : AppColors.onAccent,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  /// 1줄 요약 생성
  String _getOneLinerSummary() {
    final partners = members!.where((m) => m.uid != myUid).toList();

    if (partners.isEmpty) {
      return '이번 주는 나만의 시간';
    }

    // 전체 활동량 계산
    int totalActivity = 0;
    for (final partner in partners) {
      final posts = weeklyPostCounts?[partner.uid] ?? 0;
      final reactions = weeklyReactionCounts?[partner.uid] ?? 0;
      totalActivity += posts + reactions;
    }

    if (totalActivity == 0) {
      return '조용히 이어지고 있어요';
    } else if (totalActivity <= 3) {
      return '이번 주 함께 버티고 있어요';
    } else {
      return '이번 주 ${totalActivity}번 교감을 나눴어요';
    }
  }

  /// 확장 상태: 파트너별 감정 해석
  Widget _buildExpandedPartnerDetails() {
    // 나를 제외한 파트너들
    final partners = members!.where((m) => m.uid != myUid).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
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
    final nickname = memberNicknames?[partner.uid] ?? '파트너';
    final postCount = weeklyPostCounts?[partner.uid] ?? 0;
    final reactionCount = weeklyReactionCounts?[partner.uid] ?? 0;

    final statusMessage = _generateStatusMessage(postCount, reactionCount);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 아바타
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceMuted,
            ),
            child: Center(
              child: Text(
                nickname.isNotEmpty ? nickname[0] : 'P',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 내용
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 닉네임 + 관심사
                Row(
                  children: [
                    Text(
                      nickname,
                      style: TextStyle(
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
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary.withOpacity(0.4),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  statusMessage,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary.withOpacity(0.65),
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

  /// 파트너 상태 메시지 생성 (단일 문구)
  String _generateStatusMessage(int postCount, int reactionCount) {
    final totalActivity = postCount + reactionCount;

    if (totalActivity == 0) {
      return '조용히 이어지고 있어요';
    } else if (totalActivity <= 2) {
      return '이번 주 함께 버티고 있어요';
    } else {
      return '이번 주 ${totalActivity}번 대화를 나눴어요';
    }
  }
}


