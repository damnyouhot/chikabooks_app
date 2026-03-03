import 'package:flutter/material.dart';
import 'bond_colors.dart';

/// 다음 월요일 09:00 KST 까지 남은 시간을 사람이 읽기 좋은 문자열로 반환
String _nextMatchingMessage() {
  final now = DateTime.now();
  // 다음 월요일 09:00 계산
  int daysUntilMonday = (DateTime.monday - now.weekday) % 7;
  if (daysUntilMonday == 0 && (now.hour > 9 || (now.hour == 9 && now.minute > 0))) {
    daysUntilMonday = 7; // 이미 이번 월요일 9시를 지났으면 다음 주
  }
  if (daysUntilMonday == 0) daysUntilMonday = 7; // 월요일 09:00 이전도 이번 주 매칭
  // 하지만 정확히 월요일 09:00 전이면 오늘 매칭
  final nextMonday = DateTime(now.year, now.month, now.day + daysUntilMonday, 9, 0);
  // 실제 남은 시간이 오늘이 월요일이고 9시 전이면 daysUntilMonday=0 처리
  final todayIsMonday = now.weekday == DateTime.monday;
  final before9am = now.hour < 9;
  if (todayIsMonday && before9am) {
    final diff = DateTime(now.year, now.month, now.day, 9, 0).difference(now);
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    if (hours > 0) return '다음 매칭까지 약 $hours시간 $mins분 남았습니다';
    return '다음 매칭까지 약 $mins분 남았습니다';
  }

  final diff = nextMonday.difference(now);
  final days = diff.inDays;
  final hours = diff.inHours % 24;
  if (days > 0) return '다음 매칭까지 약 $days일 $hours시간 남았습니다';
  return '다음 매칭까지 약 $hours시간 남았습니다';
}

/// 결 점수 원형 게이지 (다른 카드에서도 재사용)
class BondScoreGauge extends StatelessWidget {
  final double bondScore;
  const BondScoreGauge({super.key, required this.bondScore});

  @override
  Widget build(BuildContext context) {
    final progress = (bondScore / 100).clamp(0.0, 1.0);
    final scoreText = bondScore.toStringAsFixed(1);

    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
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
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 4.0,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(
                BondColors.kAccent,
              ),
            ),
          ),
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
}

/// [파트너 없음] 상태 카드
/// - 상단 타이틀(이번 주 동행 기록) 제거
/// - 우측 결 점수 게이지 유지
/// - 하단 "한 주가 끝나면..." 안내 유지
class BondNoPartnerCard extends StatelessWidget {
  final double bondScore;
  const BondNoPartnerCard({super.key, required this.bondScore});

  @override
  Widget build(BuildContext context) {
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '아직 동료와 만나지 않았어요.',
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
                ),
              ),
              const SizedBox(width: 12),
              BondScoreGauge(bondScore: bondScore),
            ],
          ),
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
                  _nextMatchingMessage(),
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
}

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
              BondScoreGauge(bondScore: bondScore),
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
                  _nextMatchingMessage(),
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
  // (BondScoreGauge로 대체됨)

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
