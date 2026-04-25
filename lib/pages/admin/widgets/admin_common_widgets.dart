import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

// ══════════════════════════════════════════════════════════════
// 표본 한계 안내 배너
//
// activityLogs / appErrors 의 최근 N건만 읽어 클라이언트에서 집계하는
// 화면(Feature·Behavior·오류 페이지 TOP)에서, 읽어들인 표본이 limit 에
// 닿았을 때 "선택한 기간이 다 반영되지 않았을 수 있음"을 명시한다.
//
// 운영자가 30일 칩을 골라도 실제로는 최근 일부만 보고 있는 상황을
// 모르고 의사결정하는 것을 방지하기 위함.
// ══════════════════════════════════════════════════════════════
class AdminSampleNotice extends StatelessWidget {
  final int sampleSize;
  final int limit;
  final String periodLabel;

  const AdminSampleNotice({
    super.key,
    required this.sampleSize,
    required this.limit,
    this.periodLabel = '선택한 기간',
  });

  bool get _truncated => limit > 0 && sampleSize >= limit;

  @override
  Widget build(BuildContext context) {
    if (!_truncated) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '표본 한계: 최근 $limit건만 읽어 집계했어요. '
              '$periodLabel 전체가 다 반영되지 않았을 수 있어요. '
              '기간을 짧게 보거나, 더 정확한 추세는 Trends 탭(일별 집계)을 참고하세요.',
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
  final bool isFatal;
  final String? appVersion;
  final String? careerGroup;
  final String? region;

  const AdminErrorTile({
    super.key,
    required this.message,
    required this.timestamp,
    this.page,
    this.feature,
    this.isFatal = false,
    this.appVersion,
    this.careerGroup,
    this.region,
  });

  @override
  Widget build(BuildContext context) {
    final time =
        '${timestamp.month}/${timestamp.day} '
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFatal
            ? AppColors.error.withOpacity(0.06)
            : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isFatal
              ? AppColors.error.withOpacity(0.35)
              : AppColors.error.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isFatal
                    ? Icons.dangerous_outlined
                    : Icons.error_outline,
                size: 14,
                color: AppColors.error,
              ),
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
              if (isFatal)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'FATAL',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 2,
            children: [
              if (page != null) _badge('📄 $page'),
              if (feature != null) _badge('🔧 $feature'),
              if (careerGroup != null) _badge('👤 $careerGroup'),
              if (region != null) _badge('📍 $region'),
              if (appVersion != null) _badge('v$appVersion'),
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

