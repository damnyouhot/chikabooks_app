import 'package:flutter/material.dart';
import 'bond_colors.dart';

/// 결 점수 + 파트너 아바타 요약 섹션
class BondSummarySection extends StatelessWidget {
  final double bondScore;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  const BondSummarySection({
    super.key,
    required this.bondScore,
    required this.isExpanded,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
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
                      Text(
                        '결 ${bondScore.toInt()}',
                        style: const TextStyle(
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
              '${bondScore.toInt()}',
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
    // 더미 파트너 (실제 연결 시 교체)
    final partners = ['P1', 'P2', 'P3'];
    return Row(
      children: partners.asMap().entries.map((e) {
        final i = e.key;
        return Transform.translate(
          offset: Offset(-8.0 * i, 0),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: BondColors.kShadow2,
              border: Border.all(color: BondColors.kCardBg, width: 1.5),
            ),
            child: Center(
              child: Text(
                e.value,
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
    // 더미 파트너 (실제 연결 시 교체)
    final partners = [
      {'name': '민지', 'activity': '3', 'goals': '5/7'},
      {'name': '지은', 'activity': '1', 'goals': '2/5'},
      {'name': '현수', 'activity': '0', 'goals': '아직 없음'},
    ];

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
        ...partners.map((p) {
          final name = p['name'] as String;
          final activity = p['activity'] as String;
          final goals = p['goals'] as String;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: BondColors.kShadow2,
                  ),
                  child: Center(
                    child: Text(
                      name[0],
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
                        '${name}님',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: BondColors.kText,
                        ),
                      ),
                      Text(
                        '활동 ${activity}회 · 목표 $goals',
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

