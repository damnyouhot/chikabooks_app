import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// ══════════════════════════════════════════════════════════════
/// AppBadge — 소형 뱃지 (상태, 번호, 태그)
///
/// 사용 위치:
///   - 퀴즈 카드 Q1/Q2 번호 뱃지 (isCircle: true)
///   - ebook 목록 "무료" 뱃지
///   - HIRA 카드 "시행 중", "30일 이내" 등 상태 뱃지 (AppStatusBadge)
///
/// 원칙:
///   - boxShadow 없음 / Border 없음
///   - 기본 배경: AppColors.surfaceMuted
///   - 기본 텍스트: AppColors.textSecondary
///   - bgColor/textColor를 지정해 의미 컬러 사용 가능
/// ══════════════════════════════════════════════════════════════
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.bgColor,
    this.textColor,
    this.isCircle = false,
    this.size,
  });

  final String label;

  /// 뱃지 배경색. 기본: AppColors.surfaceMuted
  final Color? bgColor;

  /// 뱃지 텍스트 색. 기본: AppColors.textSecondary
  final Color? textColor;

  /// true면 원형 (Q1 등 번호 뱃지), false면 pill/rounded
  final bool isCircle;

  /// 원형 뱃지 크기 (isCircle: true일 때만 적용). 기본: 28
  final double? size;

  @override
  Widget build(BuildContext context) {
    final bg   = bgColor   ?? AppColors.surfaceMuted;
    final text = textColor ?? AppColors.textSecondary;

    if (isCircle) {
      final s = size ?? 28.0;
      return Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: text,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs - 1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }
}

/// ══════════════════════════════════════════════════════════════
/// AppStatusBadge — HIRA 카드용 상태 뱃지 (시행 중 / 30일 이내 / 90일 이내 / 사전공지)
///
/// 앱 포인트 2색 기반:
///   긴급(ACTIVE/SOON)  → cardEmphasis (Lobster Red) + onCardEmphasis 텍스트
///   예정(UPCOMING/NOTICE) → cardPrimary (Steel Marine) + onCardPrimary 텍스트
/// ══════════════════════════════════════════════════════════════
class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    super.key,
    required this.badgeLevel,
    required this.badgeText,
  });

  /// 'ACTIVE' | 'SOON' | 'UPCOMING' | 'NOTICE'
  final String badgeLevel;
  final String badgeText;

  @override
  Widget build(BuildContext context) {
    // 긴급: cardEmphasis (Lobster Red) — 시행 중·30일 이내
    // 예정: cardPrimary (Steel Marine) — 90일 이내·사전공지
    final bool isUrgent = badgeLevel == 'ACTIVE' || badgeLevel == 'SOON';
    final Color bg   = isUrgent ? AppColors.cardEmphasis : AppColors.cardPrimary;
    final Color text = isUrgent ? AppColors.onCardEmphasis : AppColors.onCardPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }
}

/// '준비중' — 어두운 녹색([AppColors.prepBadgeGreen]) 배경 + 크림 화이트 텍스트 ([AppColors.appBg])
///
/// 사용: 나 탭 Jobs 카드, 커리어 소탭(채용 · 지원) 등
class PrepInProgressBadge extends StatelessWidget {
  const PrepInProgressBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.prepBadgeGreen,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        '준비중',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: AppColors.appBg,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
