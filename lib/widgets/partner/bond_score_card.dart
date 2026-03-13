import 'package:flutter/material.dart';
import '../../services/bond_score_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_muted_card.dart';
import '../../core/widgets/app_badge.dart';

/// 결 점수 카드 (숫자 + 짧은 라벨만, 차트/막대 금지)
class BondScoreCard extends StatelessWidget {
  final double score;

  const BondScoreCard({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final label = BondScoreService.scoreLabel(score);
    final scoreStr = score.toStringAsFixed(1);
    final labelColor = _labelColor(score);

    return AppMutedCard(
      radius: AppRadius.xl,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome,
              color: AppColors.warning, size: 20),
          const SizedBox(width: 10),
          const Text(
            '결',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Text(
            scoreStr,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 8),
          AppBadge(
            label: label,
            bgColor: labelColor.withOpacity(0.15),
            textColor: labelColor,
          ),
        ],
      ),
    );
  }

  Color _labelColor(double score) {
    if (score >= 70) return AppColors.error;
    if (score >= 60) return AppColors.accent;
    if (score >= 50) return AppColors.success;
    if (score >= 40) return AppColors.warning;
    return AppColors.textDisabled;
  }
}
