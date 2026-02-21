import 'package:flutter/material.dart';
import '../../models/partner_group.dart';
import 'bond_colors.dart';

/// 결 점수 + 파트너 아바타 요약 섹션
class BondSummarySection extends StatelessWidget {
  final double bondScore;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final List<GroupMemberMeta>? members; // 실제 멤버 데이터
  final String? myUid; // 내 UID

  const BondSummarySection({
    super.key,
    required this.bondScore,
    required this.isExpanded,
    required this.onToggleExpand,
    this.members,
    this.myUid,
  });

  @override
  Widget build(BuildContext context) {
    // 멤버가 없으면 렌더링하지 않음
    if (members == null || members!.isEmpty) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onToggleExpand,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BondColors.cardDecoration(),
        child: Column(
          children: [
            // 결 점수 + 파트너 아바타
            Row(
              children: [
                // 결 점수 링
                _buildBondRing(),
                const SizedBox(width: 16),
                // 결 점수 텍스트
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '결',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w300,
                          color: BondColors.kText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '함께 쌓아가는 교감',
                        style: TextStyle(
                          fontSize: 12,
                          color: BondColors.kText.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                // 파트너 아바타 3명
                _buildPartnerAvatars(),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: BondColors.kText.withOpacity(0.5),
                ),
              ],
            ),

            // 확장 시 파트너 상세
            if (isExpanded) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 0.5,
                color: BondColors.kShadow2.withOpacity(0.6),
              ),
              const SizedBox(height: 16),
              _buildExpandedPartnerDetails(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBondRing() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: BondColors.kAccent.withOpacity(0.6),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: BondColors.kAccent.withOpacity(0.15),
          ),
        child: Center(
          child: Text(
            bondScore.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: BondColors.kText,
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildPartnerAvatars() {
    // 실제 멤버 데이터 사용
    final displayMembers = members!.take(3).toList();
    
    return Row(
      children: displayMembers.asMap().entries.map((e) {
        final i = e.key;
        final member = e.value;
        final isMe = member.uid == myUid;
        
        return Transform.translate(
          offset: Offset(-8.0 * i, 0),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMe ? BondColors.kAccent.withOpacity(0.3) : BondColors.kShadow2,
              border: Border.all(color: BondColors.kCardBg, width: 1.5),
            ),
            child: Center(
              child: Text(
                isMe ? '나' : 'P${i + 1}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: BondColors.kText.withOpacity(0.6),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExpandedPartnerDetails() {
    // 실제 멤버 데이터 사용
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '파트너 상세',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: BondColors.kText,
          ),
        ),
        const SizedBox(height: 12),
        ...members!.map((member) {
          final isMe = member.uid == myUid;
          final displayName = isMe ? '나' : '파트너';
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isMe 
                        ? BondColors.kAccent.withOpacity(0.2) 
                        : BondColors.kShadow2,
                  ),
                  child: Center(
                    child: Text(
                      isMe ? '나' : 'P',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: BondColors.kText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: BondColors.kText,
                        ),
                      ),
                      Text(
                        '${member.careerGroup} · ${member.region}',
                        style: TextStyle(
                          fontSize: 12,
                          color: BondColors.kText.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}



