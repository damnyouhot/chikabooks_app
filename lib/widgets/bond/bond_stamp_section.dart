import 'package:flutter/material.dart';
import '../../models/weekly_stamp.dart';
import '../../services/weekly_stamp_service.dart';
import 'bond_colors.dart';
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
      _initStream();
    }
  }

  void _initStream() {
    if (widget.partnerGroupId != null && widget.partnerGroupId!.isNotEmpty) {
      setState(() {
        _stream = WeeklyStampService.watchThisWeek(widget.partnerGroupId!);
      });
    } else {
      _stream = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 파트너 그룹이 없으면 숨김
    if (widget.partnerGroupId == null || widget.partnerGroupId!.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<WeeklyStampState>(
      stream: _stream,
      builder: (context, snap) {
        final stamp = snap.data ?? WeeklyStampState.empty(
          WeeklyStampService.currentWeekKey(),
        );
        final todayIdx = WeeklyStampService.todayDayOfWeek();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BondColors.cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 타이틀 + 안내 아이콘
                Row(
                  children: [
                    const Text(
                      '이번 주 우리 스탬프',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: BondColors.kText,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 7개 스탬프 원 (월~일)
                Row(
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

                const SizedBox(height: 14),

                // 요약 텍스트
                Center(
                  child: Text(
                    '이번 주 ${stamp.filledCount}/7 칸 채웠어요',
                    style: TextStyle(
                      fontSize: 12,
                      color: BondColors.kText.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 스탬프 설명은 상단 "같이" 탭 설명(info) 다이얼로그에 포함됩니다.
}

















