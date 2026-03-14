import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_primary_card.dart';
import '../../core/widgets/glass_card.dart';

/// 다음 월요일 09:00 KST 까지 남은 시간을 사람이 읽기 좋은 문자열로 반환
String _nextMatchingMessage() {
  final now = DateTime.now();
  int daysUntilMonday = (DateTime.monday - now.weekday) % 7;
  if (daysUntilMonday == 0 &&
      (now.hour > 9 || (now.hour == 9 && now.minute > 0))) {
    daysUntilMonday = 7;
  }
  if (daysUntilMonday == 0) daysUntilMonday = 7;
  final nextMonday = DateTime(now.year, now.month, now.day + daysUntilMonday, 9, 0);
  final todayIsMonday = now.weekday == DateTime.monday;
  final before9am = now.hour < 9;
  if (todayIsMonday && before9am) {
    final diff = DateTime(now.year, now.month, now.day, 9, 0).difference(now);
    final hours = diff.inHours;
    final mins  = diff.inMinutes % 60;
    if (hours > 0) return '다음 매칭까지 약 $hours시간 $mins분 남았습니다';
    return '다음 매칭까지 약 $mins분 남았습니다';
  }
  final diff  = nextMonday.difference(now);
  final days  = diff.inDays;
  final hours = diff.inHours % 24;
  if (days > 0) return '다음 매칭까지 약 $days일 $hours시간 남았습니다';
  return '다음 매칭까지 약 $hours시간 남았습니다';
}

/// 결 점수 원형 게이지
class BondScoreGauge extends StatelessWidget {
  final double bondScore;
  final bool glassMode;
  const BondScoreGauge({
    super.key,
    required this.bondScore,
    this.glassMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final progress   = (bondScore / 100).clamp(0.0, 1.0);
    final scoreText  = bondScore.toStringAsFixed(1);
    final labelColor = glassMode
        ? AppColors.white.withOpacity(0.7)
        : AppColors.textSecondary;
    final scoreColor = glassMode ? AppColors.white : AppColors.textPrimary;
    final trackColor = glassMode
        ? AppColors.white.withOpacity(0.2)
        : AppColors.disabledBg;

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
              valueColor: AlwaysStoppedAnimation<Color>(trackColor),
            ),
          ),
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 4.0,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                glassMode ? AppColors.white : AppColors.cardEmphasis,
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
                  color: labelColor,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                scoreText,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: scoreColor,
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
class BondNoPartnerCard extends StatelessWidget {
  final double bondScore;
  final bool glassMode;
  const BondNoPartnerCard({
    super.key,
    required this.bondScore,
    this.glassMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary = glassMode ? AppColors.white.withOpacity(0.75) : AppColors.onCardPrimary.withOpacity(0.85);
    final textDisabled  = glassMode ? AppColors.white.withOpacity(0.5)  : AppColors.onCardPrimary.withOpacity(0.6);

    final content = Column(
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
                    style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '함께 걸을 사람을 찾아보세요',
                    style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            BondScoreGauge(bondScore: bondScore, glassMode: glassMode),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: textDisabled),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _nextMatchingMessage(),
                style: TextStyle(fontSize: 11, color: textDisabled, height: 1.3),
              ),
            ),
          ],
        ),
      ],
    );

    if (glassMode) {
      return GlassCard(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: content,
      );
    }

    return AppPrimaryCard(
      radius: AppRadius.xl,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: content,
    );
  }
}

/// 주간 페이지 통합 헤더
class BondWeekHeader extends StatelessWidget {
  final double bondScore;
  final int weeklyIncrease;
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
    final weekInfo  = _getWeekInfo();
    final hasPartner = partnerGroupId != null;

    return AppPrimaryCard(
      radius: AppRadius.xl,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      padding: const EdgeInsets.all(AppSpacing.xl),
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
                    Row(
                      children: [
                        const Text(
                          '이번 주 동행 기록',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onCardPrimary,
                          ),
                        ),
                        if (onSettingsTap != null) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: onSettingsTap,
                            child: Icon(
                              Icons.settings_outlined,
                              size: 16,
                              color: AppColors.onCardPrimary.withOpacity(0.6),
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
                        color: AppColors.onCardPrimary.withOpacity(0.75),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              BondScoreGauge(bondScore: bondScore),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildStatusMessage(hasPartner),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: AppColors.onCardPrimary.withOpacity(0.5),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _nextMatchingMessage(),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.onCardPrimary.withOpacity(0.6),
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

  Widget _buildStatusMessage(bool hasPartner) {
    final msg1 = hasPartner
        ? '이번 주, 파트너와 함께 버티는 시간입니다'
        : '아직 매칭이 시작되지 않았어요';
    final msg2 = hasPartner
        ? '7일 동안 조용히 이어집니다'
        : '함께 걸을 사람을 찾아보세요';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          msg1,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.onCardPrimary.withOpacity(0.85),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          msg2,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.onCardPrimary.withOpacity(0.85),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  String _getWeekInfo() {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    final month = kst.month;
    final firstDayOfMonth = DateTime(kst.year, kst.month, 1);
    final daysDiff    = kst.difference(firstDayOfMonth).inDays;
    final weekOfMonth = (daysDiff / 7).floor() + 1;
    final weekday     = kst.weekday;
    final monday      = kst.subtract(Duration(days: weekday - 1));
    final sunday      = monday.add(const Duration(days: 6));
    return '$month월 ${weekOfMonth}주차 · ${monday.day}~${sunday.day}일';
  }
}
