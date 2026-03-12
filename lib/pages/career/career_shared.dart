import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_style.dart';

// ── 커리어 탭 디자인 팔레트: AppColors 참조 ──
// 색상 변경 → app_colors.dart Primitive만 수정하면 자동 반영
const kCText   = AppColors.textPrimary;   // Black
const kCBg     = AppColors.appBg;         // Soft gray
const kCAccent = AppColors.accent;        // Blue (버튼/카드 채움)
const kCShadow = AppColors.accent;        // Blue 계열 (border 역할이었으나 제거)
const kCCardBg = AppColors.surfaceMuted;  // Muted surface 카드 배경
const kCMuted  = AppColors.textSecondary; // 진한 회색 (비활성)

// ── 헬퍼 함수 ──────────────────────────────────────────────────
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
    case 'cleaning_services':
      return Icons.cleaning_services_outlined;
    case 'handyman':
      return Icons.handyman_outlined;
    case 'architecture':
      return Icons.architecture_outlined;
    case 'chat_bubble':
      return Icons.chat_bubble_outline;
    case 'receipt_long':
      return Icons.receipt_long_outlined;
    case 'build':
      return Icons.build_outlined;
    case 'child_care':
      return Icons.child_care_outlined;
    case 'sanitizer':
      return Icons.sanitizer_outlined;
    case 'phone':
      return Icons.phone_outlined;
    case 'radio':
      return Icons.radio_outlined;
    default:
      return Icons.star_outline;
  }
}

// ── 공통 위젯 ───────────────────────────────────────────────────
class CareerCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const CareerCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: AppStyle.primaryCardDecoration(radius: 16),
      child: child,
    );
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
        // 앱 배경(#F7F8FA) 위에 직접 렌더링되므로 Black 텍스트 사용
        // (카드 내부 제목은 각 섹션에서 onCardPrimary=White 직접 지정)
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: AppStyle.primaryCardDecoration(radius: 12),
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
        return Container(
          height: widget.height,
          padding: const EdgeInsets.all(16),
          decoration: AppStyle.primaryCardDecoration(radius: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ShimmerBar(width: 100, height: 14, opacity: opacity),
              const SizedBox(height: 10),
              _ShimmerBar(width: double.infinity, height: 12, opacity: opacity),
              const SizedBox(height: 6),
              _ShimmerBar(width: 200, height: 12, opacity: opacity),
              const Spacer(),
              _ShimmerBar(
                width: double.infinity,
                height: 38,
                opacity: opacity,
                radius: 12,
              ),
            ],
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
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
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
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wifi_off_outlined,
            size: 32,
            color: AppColors.onCardPrimary.withOpacity(0.6),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: Icon(icon, color: AppColors.textPrimary.withOpacity(0.75)),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: AppColors.textPrimary.withOpacity(0.45)),
    );
  }
}
