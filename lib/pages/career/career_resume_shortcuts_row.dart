import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_muted_card.dart';
import '../../features/resume/screens/my_applications_screen.dart';
import '../../features/resume/screens/resume_home_screen.dart';

/// 채용 탭 스크롤 상단 등 — 내 이력서 / 지원 내역 바로가기 (가로 반반)
class CareerResumeShortcutsRow extends StatelessWidget {
  const CareerResumeShortcutsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _CareerShortcutCard(
              icon: Icons.description_outlined,
              label: '내 이력서',
              description: '이력서 작성 및 지원',
              showOcrPrepBadge: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ResumeHomeScreen()),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _CareerShortcutCard(
              icon: Icons.work_outline,
              label: '지원 내역',
              description: '지원 공고 현황 확인',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MyApplicationsScreen(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CareerShortcutCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;
  final bool showOcrPrepBadge;

  const _CareerShortcutCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
    this.showOcrPrepBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppMutedCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: AppColors.accent, size: 18),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (showOcrPrepBadge) ...[
                const SizedBox(width: 6),
                const PrepInProgressBadge(),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
