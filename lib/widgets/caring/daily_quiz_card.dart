import 'package:flutter/material.dart';
import '../../models/daily_quiz.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_muted_card.dart';
import '../../core/widgets/app_primary_button.dart';

/// 🧠 오늘의 1문제 카드
class DailyQuizCard extends StatelessWidget {
  final DailyQuiz? quiz;
  final VoidCallback? onStart;

  const DailyQuizCard({super.key, this.quiz, this.onStart});

  @override
  Widget build(BuildContext context) {
    final hasQuiz = quiz != null && quiz!.question.isNotEmpty;
    return AppMutedCard(
      radius: AppRadius.sm,
      padding: const EdgeInsets.all(AppSpacing.sm),
      onTap: hasQuiz ? onStart : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🧠', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 3),
              const Text(
                '오늘의 1문제',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            quiz == null
                ? '로딩 중...'
                : quiz!.question.isEmpty
                    ? '오늘의 퀴즈가 준비되지 않았어요'
                    : quiz!.question,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          AppPrimaryButton(
            label: '바로 풀기',
            onPressed: onStart ?? () {},
            isEnabled: hasQuiz,
            fontSize: 10,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            radius: AppRadius.xs,
          ),
        ],
      ),
    );
  }
}
