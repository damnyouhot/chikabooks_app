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
  /// true: 다른 카드 내부에 종속 (외부 padding/배경 없음)
  final bool embedded;

  const BondStampSection({
    super.key,
    required this.partnerGroupId,
    this.embedded = false,
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

        return widget.embedded
            ? _buildEmbeddedStamp(stamp, todayIdx)
            : _buildStandaloneStamp(stamp, todayIdx);
      },
    );
  }

  /// 독립 카드 스타일 (기존)
  Widget _buildStandaloneStamp(WeeklyStampState stamp, int todayIdx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.cardPrimary,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: _buildContent(stamp, todayIdx),
          ),
        );
  }

  /// 내부 종속 스타일 (BondSummarySection 카드 안)
  Widget _buildEmbeddedStamp(WeeklyStampState stamp, int todayIdx) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.onCardPrimary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: _buildContent(stamp, todayIdx),
    );
  }

  Widget _buildContent(WeeklyStampState stamp, int todayIdx) {
    return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, 14, AppSpacing.xl, 10),
                  child: Row(
                    children: [
                      Text(
                        '이번 주 스탬프',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: widget.embedded
                              ? AppColors.onCardPrimary.withOpacity(0.85)
                              : AppColors.onCardPrimary,
                        ),
                      ),
                      const Spacer(),
                      AppBadge(
                        label: '${stamp.filledCount}/7',
                        bgColor: AppColors.onCardPrimary.withOpacity(0.15),
                        textColor: AppColors.onCardPrimary,
                        isCircle: false,
                      ),
                    ],
                  ),
                ),
                // 스탬프 원 7개
                Container(
                  margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.white.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(AppRadius.md),
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
    );
  }
}
