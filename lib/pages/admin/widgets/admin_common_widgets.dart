import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

// ══════════════════════════════════════════════════════════════
// KPI 카드 — 숫자 + 라벨 한 쌍
// ══════════════════════════════════════════════════════════════
class AdminKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sublabel;
  final Color? valueColor;
  final IconData? icon;

  const AdminKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.sublabel,
    this.valueColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: AppColors.textDisabled),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
          if (sublabel != null) ...[
            const SizedBox(height: 2),
            Text(
              sublabel!,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textDisabled,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 섹션 타이틀
// ══════════════════════════════════════════════════════════════
class AdminSectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const AdminSectionTitle(
    this.title, {
    super.key,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                action!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.accent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 빈 데이터 상태
// ══════════════════════════════════════════════════════════════
class AdminEmptyState extends StatelessWidget {
  final String message;
  const AdminEmptyState({super.key, this.message = '데이터가 없어요'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 36, color: AppColors.textDisabled),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textDisabled,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 로딩 상태
// ══════════════════════════════════════════════════════════════
class AdminLoadingState extends StatelessWidget {
  const AdminLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 오류 상태 + 재시도
// ══════════════════════════════════════════════════════════════
class AdminErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AdminErrorState({
    super.key,
    this.message = '데이터를 불러오지 못했어요',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36, color: AppColors.error),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('재시도'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 오류 항목 타일
// ══════════════════════════════════════════════════════════════
class AdminErrorTile extends StatelessWidget {
  final String message;
  final String? page;
  final String? feature;
  final DateTime timestamp;

  const AdminErrorTile({
    super.key,
    required this.message,
    required this.timestamp,
    this.page,
    this.feature,
  });

  @override
  Widget build(BuildContext context) {
    final time =
        '${timestamp.month}/${timestamp.day} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, size: 14, color: AppColors.error),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              if (page != null)
                _badge('📄 $page'),
              if (feature != null)
                _badge('🔧 $feature'),
              _badge('🕐 $time'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String text) => Text(
    text,
    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
  );
}

