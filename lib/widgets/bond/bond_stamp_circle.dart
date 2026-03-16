import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

// AppColors 직접 참조 (TabTheme 제거)

/// 스탬프 원 위젯 (pop 애니메이션 포함)
class BondStampCircle extends StatefulWidget {
  final String dayLabel;
  final bool isFilled;
  final bool isToday;

  const BondStampCircle({
    super.key,
    required this.dayLabel,
    required this.isFilled,
    required this.isToday,
  });

  @override
  State<BondStampCircle> createState() => _BondStampCircleState();
}

class _BondStampCircleState extends State<BondStampCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _popCtrl;
  late Animation<double> _popAnim;
  bool _wasFilledBefore = false;

  @override
  void initState() {
    super.initState();
    _wasFilledBefore = widget.isFilled;
    _popCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _popAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 0.95), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _popCtrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant BondStampCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_wasFilledBefore && widget.isFilled) {
      _popCtrl.forward(from: 0);
      HapticFeedback.mediumImpact();
    }
    _wasFilledBefore = widget.isFilled;
  }

  @override
  void dispose() {
    _popCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _popAnim,
      builder: (context, child) {
        return Transform.scale(
          scale: _popAnim.value,
          child: child,
        );
      },
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.isFilled
              ? AppColors.cardPrimary
              : widget.isToday
                  ? AppColors.accent.withOpacity(0.15)
                  : AppColors.surfaceMuted,
          border: Border.all(
            color: widget.isToday
                ? AppColors.accent
                : widget.isFilled
                    ? AppColors.cardPrimary
                    : AppColors.disabledBg,
            width: widget.isToday ? 2.0 : 0.8,
          ),
        ),
        child: Center(
          child: Text(
            widget.dayLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: widget.isFilled
                  ? AppColors.onCardPrimary
                  : widget.isToday
                      ? AppColors.accent
                      : AppColors.textDisabled,
            ),
          ),
        ),
      ),
    );
  }
}



