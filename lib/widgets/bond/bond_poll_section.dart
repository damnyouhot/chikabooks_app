import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_muted_card.dart';
import '../../core/widgets/app_badge.dart';

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
    final options  = [
      '환자 컴플레인 받을 때',
      '야근이 길어질 때',
      '동료와 의견이 다를 때',
      '체력이 바닥날 때',
    ];
    final results = [35.2, 24.8, 15.3, 24.7];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 섹션 타이틀
          Row(
            children: [
              const Icon(
                Icons.how_to_vote_outlined,
                size: 16,
                color: AppColors.textDisabled,
              ),
              const SizedBox(width: 6),
              const Text(
                '공감 투표',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                '다들 어떤지 궁금해서.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textDisabled,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),

          // 투표 카드 — AppMutedCard (정보 카드)
          AppMutedCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 질문 영역
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.lg),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppBadge(
                        label: '이번 주',
                        bgColor: AppColors.pollBadgeBg,
                        textColor: AppColors.pollBadgeText,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          question,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
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
                      final i        = entry.key;
                      final option   = entry.value;
                      final isSelected = _selectedPollOption == i;
                      final hasVoted   = _selectedPollOption != null;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: GestureDetector(
                          onTap: hasVoted
                              ? null
                              : () => setState(() => _selectedPollOption = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 280),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.pollOptionSelectedBg
                                  : AppColors.pollOptionBg.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? AppColors.pollOptionSelectedText.withValues(alpha: 0.15)
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.pollOptionSelectedText.withValues(alpha: 0.6)
                                          : AppColors.textDisabled.withValues(alpha: 0.5),
                                      width: isSelected ? 1.5 : 0.8,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Center(
                                          child: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppColors.pollOptionSelectedText,
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
                                          ? AppColors.pollOptionSelectedText
                                          : AppColors.pollOptionText,
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
                                          ? AppColors.pollOptionSelectedText
                                              .withValues(alpha: 0.7)
                                          : AppColors.textSecondary,
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

                if (_selectedPollOption != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Center(
                      child: Text(
                        '파트너 그룹 내 익명 결과',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: Center(
                    child: Text(
                      '지난 질문 보기',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textDisabled,
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
