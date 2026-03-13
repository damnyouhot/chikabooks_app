import 'package:flutter/material.dart';
import '../../models/weekly_stamp.dart';
import '../../services/weekly_stamp_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_badge.dart';
import 'bond_stamp_circle.dart';

/// 이번 주 우리 스탬프 섹션
class BondStampSection extends StatefulWidget {
  final String? partnerGroupId;

  const BondStampSection({
    super.key,
    required this.partnerGroupId,
  });

  @override
  State<BondStampSection> createState() => _BondStampSectionState();
}

class _BondStampSectionState extends State<BondStampSection> {
  Stream<WeeklyStampState>? _stream;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  @override
  void didUpdateWidget(BondStampSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.partnerGroupId != widget.partnerGroupId) {
      setState(() => _initStream());
    }
  }

  void _initStream() {
    if (widget.partnerGroupId != null && widget.partnerGroupId!.isNotEmpty) {
      _stream = WeeklyStampService.watchThisWeek(widget.partnerGroupId!);
    } else {
      _stream = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.partnerGroupId == null || widget.partnerGroupId!.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<WeeklyStampState>(
      stream: _stream,
      builder: (context, snap) {
        final stamp = snap.data ??
            WeeklyStampState.empty(WeeklyStampService.currentWeekKey());
        final todayIdx = WeeklyStampService.todayDayOfWeek();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.cardEmphasis,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Neon 헤더
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, 18, AppSpacing.xl, 14),
                  child: Row(
                    children: [
                      const Text(
                        '이번 주 우리 스탬프',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onCardEmphasis,
                        ),
                      ),
                      const Spacer(),
                      AppBadge(
                        label: '${stamp.filledCount}/7',
                        bgColor: AppColors.onCardEmphasis.withOpacity(0.15),
                        textColor: AppColors.onCardEmphasis,
                        isCircle: false,
                      ),
                    ],
                  ),
                ),
                // 스탬프 원 7개
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.white.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(7, (i) {
                      final isFilled = stamp.isFilled(i);
                      final isToday = i == todayIdx;
                      return BondStampCircle(
                        dayLabel: const ['월', '화', '수', '목', '금', '토', '일'][i],
                        isFilled: isFilled,
                        isToday: isToday,
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
