import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_muted_card.dart';

/// 📍 내 주변 신규 구인 카드
class JobsInfoCard extends StatelessWidget {
  final Map<String, dynamic>? data;
  final VoidCallback? onTap;

  const JobsInfoCard({super.key, this.data, this.onTap});

  @override
  Widget build(BuildContext context) {
    final count       = data?['count'] ?? 0;
    final clinicName  = data?['clinicName'] ?? '';
    final otherCount  = count > 1 ? count - 1 : 0;

    return AppMutedCard(
      radius: AppRadius.sm,
      padding: const EdgeInsets.all(AppSpacing.sm),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타이틀
          const Row(
            children: [
              Text('📍', style: TextStyle(fontSize: 13)),
              SizedBox(width: 3),
              Text(
                '내 주변 신규 구인',
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
            data == null
                ? '로딩 중...'
                : count == 0
                    ? '새로운 구인 공고가 없어요'
                    : '오늘 새로 올라온 $count건',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          if (count > 0 && clinicName.isNotEmpty)
            Text(
              otherCount > 0 ? '$clinicName 외 $otherCount건' : clinicName,
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }
}
