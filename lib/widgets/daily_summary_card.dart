import 'package:flutter/material.dart';
import '../services/daily_summary_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/app_primary_button.dart';

/// 저녁 7시 요약 카드
class DailySummaryCard extends StatelessWidget {
  final String groupId;

  const DailySummaryCard({
    super.key,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context) {
    // 저녁 7시 이후에만 표시
    if (!DailySummaryService.shouldShowSummary()) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<DailySummary?>(
      future: DailySummaryService.getTodaySummary(groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final summary = snapshot.data;
        if (summary == null) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.accent.withOpacity(0.15),
                AppColors.accent.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: AppColors.accent.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Row(
                children: [
                  // 시계 아이콘
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.access_time,
                      color: AppColors.accent,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  const Text(
                    '🌙 오늘의 요약',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                    ),
                  ),

                  const Spacer(),

                  Text(
                    '19:00',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 메인 메시지
              Text(
                summary.summaryMessage,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 12),

              // 활동 요약
              _buildActivitySummary(summary.activityCounts),

              const SizedBox(height: 16),

              // CTA 버튼
              AppPrimaryButton(
                label: summary.ctaMessage,
                onPressed: () {
                  // TODO: 한 문장 작성 화면으로 이동
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivitySummary(Map<String, int> activityCounts) {
    if (activityCounts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '오늘 활동',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...activityCounts.entries.map((entry) {
            final isMe = entry.key == 'me'; // TODO: 실제 uid 비교
            final name = isMe ? '나' : entry.key;
            final count = entry.value;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 4,
                  decoration: BoxDecoration(
                    color: count > 0 
                        ? AppColors.accent 
                        : AppColors.textDisabled,
                    shape: BoxShape.circle,
                  ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$name: ${count > 0 ? "$count회" : "아직 없음"}',
                    style: TextStyle(
                      fontSize: 12,
                      color: count > 0 
                          ? AppColors.textPrimary 
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}



















