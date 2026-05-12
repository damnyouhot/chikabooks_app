import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../models/campaign.dart';
import 'campaign_status_chip.dart';

/// 캠페인 한 건 카드 위젯 (대시보드 리스트 아이템).
///
/// 표기:
///   - 등급 / 상태 칩
///   - 공고 제목 (jobTitle 외부 prop으로 받음 — campaign 자체에 title 없음)
///   - 잔여 일수 + 진행 게이지
///   - 광고 시작/종료일
///   - 자동연장 ON 시 작은 indicator
///   - 우측: 액션 버튼(상세 열기) — onTap 으로만 위임, 외부에서 모달 열기.
class CampaignCard extends StatelessWidget {
  const CampaignCard({
    super.key,
    required this.campaign,
    required this.jobTitle,
    required this.onTap,
  });

  final Campaign campaign;
  final String jobTitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('yyyy.MM.dd');
    final start = campaign.adStartAt;
    final end = campaign.adEndAt;
    final remaining = campaign.remainingDays;
    final progress = campaign.progressRatio;
    final isAuto = campaign.autoRenew.enabled;

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppPublisher.inputPanelRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppPublisher.inputPanelRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius:
                BorderRadius.circular(AppPublisher.inputPanelRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1행: 등급/상태 칩 + 자동연장 indicator ──
              Row(
                children: [
                  CampaignTierChip(tierKey: campaign.tierKey),
                  const SizedBox(width: 6),
                  CampaignStatusChip(status: campaign.lifecycleStatus),
                  const Spacer(),
                  if (isAuto)
                    _AutoRenewBadge(
                      nextChargeAt: campaign.autoRenew.nextChargeAt,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // ── 2행: 공고 제목 ──
              Text(
                jobTitle.trim().isEmpty ? '(제목 없음)' : jobTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSansKr(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // ── 3행: 시작 ~ 종료일 ──
              Text(
                start != null && end != null
                    ? '${dateFmt.format(start.toLocal())}  →  ${dateFmt.format(end.toLocal())}'
                    : '게시 일정 정보 없음',
                style: GoogleFonts.notoSansKr(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // ── 4행: 진행 게이지 ──
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceMuted,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    campaign.lifecycleStatus.isTerminal
                        ? AppColors.disabledText
                        : AppColors.cardPrimary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // ── 5행: 잔여일 / 결제금액 ──
              Row(
                children: [
                  Text(
                    campaign.lifecycleStatus.isTerminal
                        ? '게시 종료'
                        : remaining > 0
                            ? '잔여 $remaining일'
                            : '오늘 만료',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: campaign.lifecycleStatus.isTerminal
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (campaign.amountPaid > 0)
                    Text(
                      '${NumberFormat('#,###').format(campaign.amountPaid)}원',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AutoRenewBadge extends StatelessWidget {
  const _AutoRenewBadge({this.nextChargeAt});

  final DateTime? nextChargeAt;

  @override
  Widget build(BuildContext context) {
    final txt = nextChargeAt != null
        ? '자동연장 · ${DateFormat('M/d').format(nextChargeAt!.toLocal())} 청구'
        : '자동연장';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.autorenew, size: 12, color: AppColors.success),
          const SizedBox(width: 4),
          Text(
            txt,
            style: GoogleFonts.notoSansKr(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}
