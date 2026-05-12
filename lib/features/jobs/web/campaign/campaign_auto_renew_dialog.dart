import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_modal_scaffold.dart';
import '../../../../models/campaign.dart';
import '../../../../services/billing_key_service.dart';
import '../../../../services/campaign_action_service.dart';

/// 자동연장 ON 동의 다이얼로그.
///
/// 정책:
///   - ON 시 동의 버전(`v1`) 을 함께 전송 — 서버는 캠페인의
///     `autoRenew.consentVersion` 에 스냅샷을 박는다.
///   - OFF 는 별도 확인창 없이 바로 setAutoRenew(false).
///
/// 디자인:
///   - 동의 약관(체크박스) 1건. 미체크 시 ON 버튼 비활성.
class CampaignAutoRenewDialog extends StatefulWidget {
  const CampaignAutoRenewDialog({
    super.key,
    required this.campaign,
  });

  final Campaign campaign;

  static Future<bool?> show(
    BuildContext context, {
    required Campaign campaign,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => CampaignAutoRenewDialog(campaign: campaign),
    );
  }

  @override
  State<CampaignAutoRenewDialog> createState() =>
      _CampaignAutoRenewDialogState();
}

class _CampaignAutoRenewDialogState extends State<CampaignAutoRenewDialog> {
  static const _consentVersion = 'auto_renew_v1';

  bool _agreed = false;
  bool _busy = false;
  String? _errorMsg;

  /// 빌링키(자동결제 카드) 등록 여부 — initState 에서 1회 조회.
  /// null 이면 아직 모름(로딩) 상태로 취급.
  bool? _hasBillingKey;

  @override
  void initState() {
    super.initState();
    _resolveBillingKey();
  }

  Future<void> _resolveBillingKey() async {
    try {
      final ok = await BillingKeyService.hasBillingKey();
      if (!mounted) return;
      setState(() => _hasBillingKey = ok);
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasBillingKey = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final discount =
        (widget.campaign.autoRenew.discountRateSnapshot * 100).round();
    final policySnapshot = widget.campaign.policySnapshot;
    return AppModalDialog(
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '자동연장 활성화',
            style: GoogleFonts.notoSansKr(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Bullet(
            text: '게시 종료 ${policySnapshot.autoRenewLeadDays}일 전, 등록된 카드로 자동 청구됩니다.',
          ),
          _Bullet(
            text: discount > 0
                ? '자동연장 시 정가의 $discount% 할인이 적용됩니다.'
                : '자동연장 할인은 등급에 따라 적용될 수 있습니다.',
          ),
          const _Bullet(
            text: '결제에 실패하면 즉시 비활성화되며 알림으로 안내됩니다.',
          ),
          const _Bullet(
            text: '언제든 OFF 로 전환할 수 있고, 이미 결제된 기간은 환원되지 않습니다.',
          ),
          const SizedBox(height: AppSpacing.md),
          if (_hasBillingKey == false)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _BillingKeyMissingBanner(
                onRegister: _busy
                    ? null
                    : () {
                        Navigator.of(context).pop(false);
                        context.go(
                          '/post-job/payment/billing/register'
                          '?next=${Uri.encodeComponent("/post-job/campaigns")}',
                        );
                      },
              ),
            ),
          InkWell(
            onTap: _busy ? null : () => setState(() => _agreed = !_agreed),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(
                    _agreed
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    size: 20,
                    color: _agreed
                        ? AppColors.cardPrimary
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '위 내용을 확인했고, 카드 자동결제에 동의합니다.',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_errorMsg != null) ...[
            const SizedBox(height: AppSpacing.md),
            _ErrorBanner(message: _errorMsg!),
          ],
          const SizedBox(height: AppSpacing.lg),
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
                  onPressed:
                      _busy || !_agreed || _hasBillingKey == false
                          ? null
                          : _enable,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.onCardPrimary,
                    backgroundColor: AppColors.cardPrimary,
                    disabledBackgroundColor: AppColors.disabledBg,
                    disabledForegroundColor: AppColors.disabledText,
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
                            color: AppColors.onCardPrimary,
                          ),
                        )
                      : Text(
                          '자동연장 ON',
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

  Future<void> _enable() async {
    setState(() {
      _busy = true;
      _errorMsg = null;
    });
    try {
      await CampaignActionService.setAutoRenew(
        campaignId: widget.campaign.id,
        enabled: true,
        consentVersion: _consentVersion,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMsg = '자동연장 설정에 실패했습니다.\n$e';
      });
    }
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.notoSansKr(
                fontSize: 12,
                height: 1.55,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillingKeyMissingBanner extends StatelessWidget {
  const _BillingKeyMissingBanner({required this.onRegister});
  final VoidCallback? onRegister;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.credit_card_off_outlined,
              size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '자동연장에 사용할 카드가 등록되지 않았어요',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '카드를 먼저 등록한 뒤 자동연장을 켜 주세요.',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 11,
                    height: 1.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onRegister,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.cardPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 32),
            ),
            child: Text(
              '등록하기',
              style: GoogleFonts.notoSansKr(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
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
