import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../models/campaign.dart';

/// 캠페인 상태 + 등급 라벨 공용 칩 위젯.
///
/// 디자인 원칙:
///   - 모든 색상은 [AppColors] semantic token 만 사용
///   - 라운드는 [AppRadius.full] (pill)
class CampaignStatusChip extends StatelessWidget {
  const CampaignStatusChip({
    super.key,
    required this.status,
  });

  final CampaignLifecycleStatus status;

  @override
  Widget build(BuildContext context) {
    final v = _resolve(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: v.bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        v.label,
        style: GoogleFonts.notoSansKr(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: v.fg,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  static _ChipStyle _resolve(CampaignLifecycleStatus s) {
    switch (s) {
      case CampaignLifecycleStatus.scheduled:
        return _ChipStyle(
          bg: AppColors.surfaceMuted,
          fg: AppColors.textSecondary,
          label: '예약',
        );
      case CampaignLifecycleStatus.active:
        return _ChipStyle(
          bg: AppColors.cardPrimary,
          fg: AppColors.onCardPrimary,
          label: '게시중',
        );
      case CampaignLifecycleStatus.paused:
        return _ChipStyle(
          bg: AppColors.warning.withValues(alpha: 0.18),
          fg: AppColors.warning,
          label: '일시정지',
        );
      case CampaignLifecycleStatus.ended:
        return _ChipStyle(
          bg: AppColors.disabledBg,
          fg: AppColors.textSecondary,
          label: '종료',
        );
      case CampaignLifecycleStatus.refunded:
        return _ChipStyle(
          bg: AppColors.destructive.withValues(alpha: 0.15),
          fg: AppColors.destructive,
          label: '환불',
        );
    }
  }
}

/// 등급(tier) 칩 — premium/standard/basic
class CampaignTierChip extends StatelessWidget {
  const CampaignTierChip({super.key, required this.tierKey});

  final String tierKey;

  @override
  Widget build(BuildContext context) {
    final v = _resolve(tierKey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: v.bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        v.label,
        style: GoogleFonts.notoSansKr(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: v.fg,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  static _ChipStyle _resolve(String key) {
    switch (key.toLowerCase()) {
      case 'premium':
        return _ChipStyle(
          bg: AppColors.cardEmphasis,
          fg: AppColors.onCardEmphasis,
          label: 'A · 프리미엄',
        );
      case 'standard':
        return _ChipStyle(
          bg: AppColors.cardPrimary,
          fg: AppColors.onCardPrimary,
          label: 'B · 스탠다드',
        );
      case 'basic':
      default:
        return _ChipStyle(
          bg: AppColors.surfaceMuted,
          fg: AppColors.textSecondary,
          label: 'C · 베이직',
        );
    }
  }
}

class _ChipStyle {
  const _ChipStyle({
    required this.bg,
    required this.fg,
    required this.label,
  });

  final Color bg;
  final Color fg;
  final String label;
}
