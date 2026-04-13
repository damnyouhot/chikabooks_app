import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_primary_card.dart';

// ── 헬퍼 함수 ──────────────────────────────────────────────────
/// 치과 히스토리가 비었을 때 — 요약·펼침 힌트 문구 공통 (두 줄)
const String kDentalHistoryEmptyHint =
    '아직 이력이 없어요\n직접 추가 또는 이력서 업로드 시 자동 입력돼요';

String formatCareerMonths(int months) {
  if (months <= 0) return '1개월 미만';
  final years = months ~/ 12;
  final m = months % 12;
  if (years == 0) return '$m개월';
  if (m == 0) return '$years년';
  return '$years년 $m개월';
}

IconData iconFromSkillName(String name) {
  switch (name) {
    case 'cleaning_services': return Icons.cleaning_services_outlined;
    case 'handyman':          return Icons.handyman_outlined;
    case 'architecture':      return Icons.architecture_outlined;
    case 'chat_bubble':       return Icons.chat_bubble_outline;
    case 'receipt_long':      return Icons.receipt_long_outlined;
    case 'build':             return Icons.build_outlined;
    case 'child_care':        return Icons.child_care_outlined;
    case 'sanitizer':         return Icons.sanitizer_outlined;
    case 'phone':             return Icons.phone_outlined;
    case 'radio':             return Icons.radio_outlined;
    case 'denture_imp':       return Icons.precision_manufacturing_outlined;
    default:                  return Icons.star_outline;
  }
}

// ── 공통 위젯 ───────────────────────────────────────────────────

/// Blue(Primary) 카드 — AppPrimaryCard 위임 래퍼
/// 커리어 탭 내 카드들이 CareerCard를 참조하는 경우 호환 유지용
class CareerCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const CareerCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  @override
  Widget build(BuildContext context) {
    return AppPrimaryCard(padding: padding, child: child);
  }
}

class CareerSectionTitle extends StatelessWidget {
  final String text;
  const CareerSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class CareerDatePickerTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const CareerDatePickerTile({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppPrimaryCard(
      radius: AppRadius.md,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg - 2,
        vertical: 13,
      ),
      onTap: onTap,
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 16,
            color: AppColors.onCardPrimary,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.onCardPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 로딩 카드 (Shimmer 스타일) ────────────────────────────────
class CareerLoadingCard extends StatefulWidget {
  final double height;
  const CareerLoadingCard({super.key, this.height = 120});

  @override
  State<CareerLoadingCard> createState() => _CareerLoadingCardState();
}

class _CareerLoadingCardState extends State<CareerLoadingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final opacity = 0.4 + _anim.value * 0.3;
        return AppPrimaryCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(
            height: widget.height - AppSpacing.lg * 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBar(width: 100, height: 14, opacity: opacity),
                const SizedBox(height: 10),
                _ShimmerBar(
                  width: double.infinity,
                  height: 12,
                  opacity: opacity,
                ),
                const SizedBox(height: 6),
                _ShimmerBar(width: 200, height: 12, opacity: opacity),
                const Spacer(),
                _ShimmerBar(
                  width: double.infinity,
                  height: 38,
                  opacity: opacity,
                  radius: AppRadius.md,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ShimmerBar extends StatelessWidget {
  final double width;
  final double height;
  final double opacity;
  final double radius;
  const _ShimmerBar({
    required this.width,
    required this.height,
    required this.opacity,
    this.radius = AppRadius.sm,
  });

  @override
  Widget build(BuildContext context) {
    // shimmer 애니메이션 목적 — onCardPrimary(White) 반투명 사용은 예외 허용
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.onCardPrimary.withOpacity(opacity),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ── 에러 카드 ─────────────────────────────────────────────────
class CareerErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const CareerErrorCard({
    super.key,
    this.message = '데이터를 불러오지 못했어요.',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return CareerCard(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xxl,
        horizontal: AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.wifi_off_outlined,
            size: 32,
            color: AppColors.onCardPrimary, // White on Blue — fade 불필요
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.onCardPrimary,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: const Text(
                '다시 시도',
                style: TextStyle(fontSize: 13, color: AppColors.onCardPrimary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CareerEditSheetTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const CareerEditSheetTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      leading: Icon(icon, color: AppColors.textSecondary),   // 이전 withOpacity(0.75)
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textDisabled,                        // 이전 withOpacity(0.45)
      ),
    );
  }
}
