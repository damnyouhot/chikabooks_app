import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_style.dart';

// AppColors 직접 참조 (TabTheme 제거)

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
    const question = '요즘 가장 힘든 순간은?';
    final options = ['환자 컴플레인 받을 때', '야근이 길어질 때', '동료와 의견이 다를 때', '체력이 바닥날 때'];
    final results = [35.2, 24.8, 15.3, 24.7];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 섹션 타이틀
          Row(
            children: [
              Icon(
                Icons.how_to_vote_outlined,
                size: 16,
                color: AppColors.textPrimary.withOpacity(0.4),
              ),
              const SizedBox(width: 6),
              Text(
                '공감 투표',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '다들 어떤지 궁금해서.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textPrimary.withOpacity(0.4),
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),

          // 투표 카드 — Dark 배경
          Container(
            width: double.infinity,
            decoration: AppStyle.primaryCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 질문 영역
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Neon 꾸밈 뱃지
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.cardEmphasis,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '이번 주',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onCardEmphasis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          question,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onCardPrimary,  // White on Dark
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 선택지 목록
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Column(
                    children: options.asMap().entries.map((entry) {
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
                            duration: const Duration(milliseconds: 280),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.cardEmphasis
                                  : const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.cardEmphasis
                                    : Colors.white.withOpacity(0.08),
                                width: isSelected ? 0 : 0.5,
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
                                          ? AppColors.onCardEmphasis.withOpacity(0.6)
                                          : Colors.white.withOpacity(0.3),
                                      width: isSelected ? 1.5 : 0.8,
                                    ),
                                    color: isSelected
                                        ? AppColors.onCardEmphasis.withOpacity(0.15)
                                        : Colors.transparent,
                                  ),
                                  child: isSelected
                                      ? Center(
                                          child: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppColors.onCardEmphasis,
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
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: isSelected
                                          ? AppColors.onCardEmphasis
                                          : Colors.white.withOpacity(0.85),
                                    ),
                                  ),
                                ),
                                if (hasVoted) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '${results[i].toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? AppColors.onCardEmphasis.withOpacity(0.7)
                                          : Colors.white.withOpacity(0.45),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                if (_selectedPollOption != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Center(
                      child: Text(
                        '파트너 그룹 내 익명 결과',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.35),
                        ),
                      ),
                    ),
                  ),
                ],

                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Center(
                    child: Text(
                      '지난 질문 보기',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.3),
                      ),
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


