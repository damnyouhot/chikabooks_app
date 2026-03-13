import 'package:flutter/material.dart';
import 'dart:async';
import '../../models/policy_update.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_muted_card.dart';

/// 🏥 급여 변경 임박 카드 (3초 간격 자동 로테이션)
class SalaryUpdateCard extends StatefulWidget {
  final List<PolicyUpdate>? updates;
  final VoidCallback? onTap;

  const SalaryUpdateCard({super.key, this.updates, this.onTap});

  @override
  State<SalaryUpdateCard> createState() => _SalaryUpdateCardState();
}

class _SalaryUpdateCardState extends State<SalaryUpdateCard> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.updates != null && widget.updates!.length > 1) {
      _startAutoRotation();
    }
  }

  void _startAutoRotation() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && widget.updates != null && widget.updates!.isNotEmpty) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % widget.updates!.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final updates = widget.updates;

    // 로딩·빈 상태 공통 헤더
    Widget header({required String bodyText}) {
      return AppMutedCard(
        radius: AppRadius.sm,
        padding: const EdgeInsets.all(AppSpacing.sm),
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Text('🏥', style: TextStyle(fontSize: 13)),
                SizedBox(width: 3),
                Text(
                  '임박 제도 변경',
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
              bodyText,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (updates == null) return header(bodyText: '로딩 중...');
    if (updates.isEmpty) return header(bodyText: '예정된 제도 변경 없음');

    final update = updates[_currentIndex];

    return AppMutedCard(
      radius: AppRadius.sm,
      padding: const EdgeInsets.all(AppSpacing.sm),
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🏥', style: TextStyle(fontSize: 13)),
              SizedBox(width: 3),
              Text(
                '임박 제도 변경',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 슬라이드 애니메이션 (위로 밀려나기)
          ClipRect(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                );
              },
              child: Column(
                key: ValueKey(_currentIndex),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    update.title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '시행일: ${update.effectiveDate?.month ?? '?'}월 ${update.effectiveDate?.day ?? '?'}일 (${update.ddayString})',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
