import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// 도전하기 탭 빠른 액션 행
///
/// [지도/목록] 세그먼트 전환 + 공고 등록 + 내 지원/스크랩
/// 원칙: Shadow 없음 / Border 없음
class QuickActionRow extends StatelessWidget {
  final bool isMapView;
  final VoidCallback onViewToggle;
  final VoidCallback onCreateJob;
  final VoidCallback onMyApplications;

  const QuickActionRow({
    super.key,
    required this.isMapView,
    required this.onViewToggle,
    required this.onCreateJob,
    required this.onMyApplications,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          // 지도/목록 세그먼트 → surfaceMuted 컨테이너, 선택 시 white fill
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: _SegmentButton(
                      label: '지도',
                      icon: Icons.map_outlined,
                      isSelected: isMapView,
                      onPressed: () {
                        if (!isMapView) onViewToggle();
                      },
                    ),
                  ),
                  Expanded(
                    child: _SegmentButton(
                      label: '목록',
                      icon: Icons.list_alt,
                      isSelected: !isMapView,
                      onPressed: () {
                        if (isMapView) onViewToggle();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // 공고 등록 — 주요 액션 → accent
          _ActionButton(
            icon: Icons.add_circle_outline,
            label: '공고등록',
            onPressed: onCreateJob,
            isPrimary: true,
          ),
          const SizedBox(width: AppSpacing.sm),

          // 내 활동 — 보조 액션 → surfaceMuted
          _ActionButton(
            icon: Icons.folder_outlined,
            label: '내활동',
            onPressed: onMyApplications,
            isPrimary: false,
          ),
        ],
      ),
    );
  }
}

// ── 세그먼트 버튼 ────────────────────────────────────────────

class _SegmentButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

  const _SegmentButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          // 선택 시 Blue fill (시스템 일관성: segmentSelected)
          color: isSelected ? AppColors.segmentSelected : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? AppColors.onSegmentSelected
                  : AppColors.onSegmentUnselected,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? AppColors.onSegmentSelected
                    : AppColors.onSegmentUnselected,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 액션 버튼 ────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        // 주요 → accent(Blue) / 보조 → surfaceMuted (Border 없음)
        backgroundColor:
            isPrimary ? AppColors.accent : AppColors.surfaceMuted,
        foregroundColor:
            isPrimary ? AppColors.onAccent : AppColors.textSecondary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 10,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
