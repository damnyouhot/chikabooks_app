import 'package:flutter/material.dart';
import 'bond_colors.dart';

/// 공감 투표 섹션
class BondPollSection extends StatefulWidget {
  const BondPollSection({super.key});

  @override
  State<BondPollSection> createState() => _BondPollSectionState();
}

class _BondPollSectionState extends State<BondPollSection> {
  int? _selectedPollOption;

  @override
  Widget build(BuildContext context) {
    // 더미 투표 데이터
    const question = '요즘 가장 힘든 순간은?';
    final options = [
      '환자 컴플레인 받을 때',
      '야근이 길어질 때',
      '동료와 의견이 다를 때',
      '체력이 바닥날 때',
    ];
    // 더미 결과 (선택 후에만 표시) - 소수점 표시
    final results = [35.2, 24.8, 15.3, 24.7]; // int → double

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 섹션 타이틀 (Container 밖으로 이동)
          Row(
            children: [
              const Text(
                '공감 투표',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: BondColors.kText,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '다들 어떤지 궁금해서.',
                style: TextStyle(
                  fontSize: 11,
                  color: BondColors.kText.withOpacity(0.4),
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),

          // 투표 카드
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BondColors.cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 질문
                const Text(
                  question,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: BondColors.kText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // 선택지
                ...options.asMap().entries.map((entry) {
                  final i = entry.key;
                  final option = entry.value;
                  final isSelected = _selectedPollOption == i;
                  final hasVoted = _selectedPollOption != null;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: hasVoted
                      ? null
                      : () => setState(() => _selectedPollOption = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? BondColors.kAccent.withOpacity(0.12)
                          : BondColors.kBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? BondColors.kAccent.withOpacity(0.5)
                            : BondColors.kShadow2.withOpacity(0.5),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        // 라디오 아이콘
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? BondColors.kAccent
                                  : BondColors.kText.withOpacity(0.2),
                              width: isSelected ? 1.5 : 0.5,
                            ),
                            color: isSelected
                                ? BondColors.kAccent.withOpacity(0.3)
                                : Colors.transparent,
                          ),
                          child: isSelected
                              ? Center(
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: BondColors.kAccent,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: BondColors.kText,
                            ),
                          ),
                        ),
                        // 결과 (투표 후에만 표시) - 소수점 1자리
                        if (hasVoted)
                          Text(
                            '${results[i].toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: BondColors.kText.withOpacity(0.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            if (_selectedPollOption != null) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '파트너 그룹 내 익명 결과',
                  style: TextStyle(
                    fontSize: 11,
                    color: BondColors.kText.withOpacity(0.35),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 8),
            Center(
              child: Text(
                '지난 질문 보기',
                style: TextStyle(
                  fontSize: 11,
                  color: BondColors.kText.withOpacity(0.3),
                ),
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



