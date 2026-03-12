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
      setState(() {
        _initStream();
      });
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
            // Neon 채운 스탬프 카드로 임팩트 강화
            decoration: BondColors.neonCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Neon 헤더 영역
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                  child: Row(
                    children: [
                      const Text(
                        '이번 주 우리 스탬프',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: BondColors.kOnNeon,  // Black on Neon
                        ),
                      ),
                      const Spacer(),
                      // 채운 칸 뱃지
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: BondColors.kOnNeon.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: BondColors.kOnNeon.withOpacity(0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          '${stamp.filledCount}/7',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: BondColors.kOnNeon,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 스탬프 원 7개 (흰 내부 배경)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(14),
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

  // 스탬프 설명은 상단 "같이" 탭 설명(info) 다이얼로그에 포함됩니다.
}

















