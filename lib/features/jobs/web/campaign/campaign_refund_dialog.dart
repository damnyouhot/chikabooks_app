import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_modal_scaffold.dart';
import '../../../../models/campaign.dart';
import '../../../../services/campaign_action_service.dart';

/// 환불 신청 다이얼로그.
///
/// - 본인 캠페인 환불은 정책 윈도우(`policySnapshot.refundWindowDays`) 내에서만.
/// - 클라이언트는 사유만 입력하고, 윈도우 검증은 서버 [cancelAndRefund] 가 수행.
/// - v1 정책: 전액 환불(부분환불 미지원).
class CampaignRefundDialog extends StatefulWidget {
  const CampaignRefundDialog({super.key, required this.campaign});

  final Campaign campaign;

  static Future<bool?> show(
    BuildContext context, {
    required Campaign campaign,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => CampaignRefundDialog(campaign: campaign),
    );
  }

  @override
  State<CampaignRefundDialog> createState() => _CampaignRefundDialogState();
}

class _CampaignRefundDialogState extends State<CampaignRefundDialog> {
  final _reasonCtrl = TextEditingController();
  bool _busy = false;
  String? _errorMsg;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.campaign.policySnapshot;
    return AppModalDialog(
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '광고 환불 신청',
            style: GoogleFonts.notoSansKr(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.destructive.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '환불 시 즉시 광고 노출이 중단되고 공고가 마감됩니다.',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.destructive,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '환불 가능 기간: 결제일로부터 ${p.refundWindowDays}일 이내. '
                  '결제 금액 ${NumberFormat('#,###').format(widget.campaign.amountPaid)}원이 카드사로 환원됩니다.',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 11,
                    color: AppColors.destructive,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '환불 사유',
            style: GoogleFonts.notoSansKr(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _reasonCtrl,
            enabled: !_busy,
            minLines: 2,
            maxLines: 4,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: '환불을 신청하시는 이유를 알려주세요. (최대 200자)',
              hintStyle: GoogleFonts.notoSansKr(
                fontSize: 12,
                color: AppColors.textDisabled,
              ),
              filled: true,
              fillColor: AppColors.surfaceMuted,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide.none,
              ),
            ),
            style: GoogleFonts.notoSansKr(fontSize: 13),
          ),
          if (_errorMsg != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _ErrorBanner(message: _errorMsg!),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed:
                      _busy ? null : () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    backgroundColor: AppColors.surfaceMuted,
                    minimumSize:
                        const Size.fromHeight(AppPublisher.ctaHeight),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppPublisher.buttonRadius,
                      ),
                    ),
                  ),
                  child: Text(
                    '취소',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextButton(
                  onPressed: _busy ? null : _submit,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.onCardEmphasis,
                    backgroundColor: AppColors.cardEmphasis,
                    minimumSize:
                        const Size.fromHeight(AppPublisher.ctaHeight),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppPublisher.buttonRadius,
                      ),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onCardEmphasis,
                          ),
                        )
                      : Text(
                          '환불 신청',
                          style: GoogleFonts.notoSansKr(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _errorMsg = null;
    });
    try {
      await CampaignActionService.cancelAndRefund(
        campaignId: widget.campaign.id,
        reason: _reasonCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMsg = '환불 처리에 실패했습니다. ($e)';
      });
    }
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.destructive.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              size: 16, color: AppColors.destructive),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.notoSansKr(
                fontSize: 12,
                color: AppColors.destructive,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
