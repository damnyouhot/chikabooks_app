import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/hira_update.dart';
import '../services/hira_update_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/app_muted_card.dart';
import 'hira_update_card.dart';
import 'hira_update_compact_item.dart';

/// HIRA 수가/급여 변경 포인트 섹션
///
/// 디자인 원칙:
///   - boxShadow 없음 / Border 없음
///   - 빈 상태 카드: AppMutedCard
///   - 텍스트: AppColors.textPrimary / textSecondary / textDisabled
class HiraUpdateSection extends StatelessWidget {
  const HiraUpdateSection({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('🔍 HIRA: HiraUpdateSection building...');
    return StreamBuilder<List<HiraUpdate>>(
      stream: HiraUpdateService.watchAllUpdates(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final updates = snapshot.data ?? [];
        if (updates.isEmpty) {
          return _buildEmptyState();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 섹션 타이틀 ──
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xxl,
                AppSpacing.xl,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: AppSpacing.sm - 2),
                  Expanded(
                    child: Text(
                      '수가, 급여 변경 리스트(건강보험심사평가원)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: Text(
                '최근 3개월 간 ${updates.length}건의 변경사항',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textDisabled,
                ),
              ),
            ),

            // ── 상위 3건: 전체 카드 ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                children: updates
                    .take(3)
                    .map((update) => HiraUpdateCard(update: update))
                    .toList(),
              ),
            ),

            // ── 4건 이후: 간단 리스트 ──
            if (updates.length > 3) ...[
              const SizedBox(height: AppSpacing.lg),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Text(
                  '이전 항목',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDisabled,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Column(
                  children: updates
                      .skip(3)
                      .map((update) => HiraUpdateCompactItem(update: update))
                      .toList(),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      child: AppMutedCard(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          children: const [
            Icon(
              Icons.info_outline,
              size: 40,
              color: AppColors.textDisabled,
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              '최신 변경사항이 없습니다',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              '새로운 수가·급여 변경사항이 발표되면\n자동으로 업데이트됩니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textDisabled,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
