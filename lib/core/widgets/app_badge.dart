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
/// badgeLevel에 따라 배경/텍스트 색이 자동으로 설정됩니다.
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

  static const _activeColor   = Color(0xFFE57373); // 🔴 시행 중
  static const _soonColor     = Color(0xFFFFB74D); // 🟠 30일 이내
  static const _upcomingColor = Color(0xFFFDD835); // 🟡 90일 이내
  static const _noticeColor   = Color(0xFFBDBDBD); // ⚪ 사전공지

  @override
  Widget build(BuildContext context) {
    final Color baseColor;
    switch (badgeLevel) {
      case 'ACTIVE':
        baseColor = _activeColor;
        break;
      case 'SOON':
        baseColor = _soonColor;
        break;
      case 'UPCOMING':
        baseColor = _upcomingColor;
        break;
      default:
        baseColor = _noticeColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        // 의미 컬러 배경 (투명도 적용 — 이 경우는 의미상 필요)
        color: baseColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: baseColor,
        ),
      ),
    );
  }
}

