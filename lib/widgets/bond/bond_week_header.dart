import 'package:flutter/material.dart';
import 'bond_colors.dart';

/// 주간 페이지 통합 헤더
///
/// - 타이틀: "이번 주 동행 기록" + 원형 게이지 (우측 상단)
/// - 기간: "2월 4주차 · 16~22일"
/// - 매칭 상태별 안내 문구
/// - 하단 안내: "한 주가 끝나면 조용히 다음 페이지로 넘어갑니다"
class BondWeekHeader extends StatelessWidget {
  final double bondScore;
  final int weeklyIncrease; // 사용하지 않음 (호환성 유지)
  final String? partnerGroupId;
  final VoidCallback? onSettingsTap;

  const BondWeekHeader({
    super.key,
    required this.bondScore,
    required this.weeklyIncrease,
    this.partnerGroupId,
    this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final weekInfo = _getWeekInfo();
    final hasPartner = partnerGroupId != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BondColors.kShadow2.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ━━━ 상단: 타이틀 + 원형 게이지 ━━━
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '이번 주 동행 기록',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: BondColors.kText,
                          ),
                        ),
                        if (onSettingsTap != null) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: onSettingsTap,
                            child: Icon(
                              Icons.settings_outlined,
                              size: 16,
                              color: BondColors.kText.withOpacity(0.3),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      weekInfo,
                      style: TextStyle(
                        fontSize: 13,
                        color: BondColors.kText.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // 원형 게이지
              _buildCircularGauge(),
            ],
          ),
          const SizedBox(height: 16),

          // ━━━ 중간: 매칭 상태별 안내 문구 ━━━
          _buildStatusMessage(hasPartner),

          // ━━━ 하단: 시스템 안내 ━━━
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: BondColors.kText.withOpacity(0.4),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '한 주가 끝나면 조용히 다음 페이지로 넘어갑니다',
                  style: TextStyle(
                    fontSize: 11,
                    color: BondColors.kText.withOpacity(0.5),
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 원형 게이지 (결 점수 시각화)
  Widget _buildCircularGauge() {
    final progress = (bondScore / 100).clamp(0.0, 1.0);
    final scoreText = bondScore.toStringAsFixed(1);

    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 배경 원
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 4.0,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                BondColors.kShadow2.withOpacity(0.25),
              ),
            ),
          ),
          // 진행 원
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 4.0,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(BondColors.kAccent),
            ),
          ),
          // 중앙: "결 점수" + 숫자
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '결 점수',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w500,
                  color: BondColors.kText.withOpacity(0.6),
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                scoreText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: BondColors.kText,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 매칭 상태별 안내 문구
  Widget _buildStatusMessage(bool hasPartner) {
    if (hasPartner) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이번 주, 파트너와 함께 버티는 시간입니다',
            style: TextStyle(
              fontSize: 13,
              color: BondColors.kText.withOpacity(0.75),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '7일 동안 조용히 이어집니다',
            style: TextStyle(
              fontSize: 13,
              color: BondColors.kText.withOpacity(0.75),
              height: 1.4,
            ),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '아직 매칭이 시작되지 않았어요',
            style: TextStyle(
              fontSize: 13,
              color: BondColors.kText.withOpacity(0.75),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '함께 걸을 사람을 찾아보세요',
            style: TextStyle(
              fontSize: 13,
              color: BondColors.kText.withOpacity(0.75),
              height: 1.4,
            ),
          ),
        ],
      );
    }
  }

  /// 주차 정보 계산
  /// 예: "2월 4주차 · 16~22일"
  String _getWeekInfo() {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    final month = kst.month;

    // 이번 달의 몇 주차인지 계산
    final firstDayOfMonth = DateTime(kst.year, kst.month, 1);
    final daysDiff = kst.difference(firstDayOfMonth).inDays;
    final weekOfMonth = (daysDiff / 7).floor() + 1;

    // 월요일 계산
    final weekday = kst.weekday; // 1=월, 7=일
    final monday = kst.subtract(Duration(days: weekday - 1));
    final sunday = monday.add(const Duration(days: 6));

    return '$month월 ${weekOfMonth}주차 · ${monday.day}~${sunday.day}일';
  }
}
