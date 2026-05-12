import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_modal_scaffold.dart';
import '../../../../models/campaign.dart';
import '../../../../services/campaign_action_service.dart';
import '../../../payment/toss_payment_service.dart';

/// 캠페인 연장 결제 다이얼로그.
///
/// 흐름:
///   1) 사용자에게 7 / 14 / 30일 옵션을 보여준다.
///   2) `CampaignActionService.createExtendOrder` 호출 → 서버가 가격을 산정해 반환.
///   3) `requiresPayment` 가 true 면 [TossPaymentService.requestPayment] 호출.
///      success URL 로 돌아오면 [PaymentSuccessPage] 가 confirmPayment 를 실행.
///   4) `requiresPayment=false` (0원) 면 confirmPayment 직접 호출.
///
/// 연장 단가는 서버에서 `(price.amount × addDays / catalog.exposureDays)` 로 산출.
class CampaignExtendDialog extends StatefulWidget {
  const CampaignExtendDialog({
    super.key,
    required this.campaign,
    required this.jobTitle,
  });

  final Campaign campaign;
  final String jobTitle;

  @override
  State<CampaignExtendDialog> createState() => _CampaignExtendDialogState();

  /// 헬퍼 — `showDialog` 와 함께 호출.
  static Future<bool?> show(
    BuildContext context, {
    required Campaign campaign,
    required String jobTitle,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => CampaignExtendDialog(
        campaign: campaign,
        jobTitle: jobTitle,
      ),
    );
  }
}

class _CampaignExtendDialogState extends State<CampaignExtendDialog> {
  static const _options = <int>[7, 14, 30];

  int _selectedDays = 14;
  bool _busy = false;
  String? _errorMsg;

  @override
  Widget build(BuildContext context) {
    return AppModalDialog(
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '광고 연장 결제',
            style: GoogleFonts.notoSansKr(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.jobTitle.trim().isEmpty ? '(제목 없음)' : widget.jobTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.notoSansKr(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _CurrentEndInfo(campaign: widget.campaign),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '추가 게시 기간',
            style: GoogleFonts.notoSansKr(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _options
                .map(
                  (d) => _DayOption(
                    days: d,
                    selected: _selectedDays == d,
                    onTap: _busy
                        ? null
                        : () => setState(() => _selectedDays = d),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '결제 금액은 다음 단계에서 등급별 단가에 비례해 자동 산정됩니다. '
            '(추가 일수 ÷ 등급 노출일수 × 등급 가격)',
            style: GoogleFonts.notoSansKr(
              fontSize: 12,
              height: 1.5,
              color: AppColors.textSecondary,
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
                    minimumSize: const Size.fromHeight(AppPublisher.ctaHeight),
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
                  onPressed: _busy ? null : _proceed,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.onCardPrimary,
                    backgroundColor: AppColors.cardPrimary,
                    minimumSize: const Size.fromHeight(AppPublisher.ctaHeight),
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
                          '$_selectedDays일 결제하기',
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

  Future<void> _proceed() async {
    setState(() {
      _busy = true;
      _errorMsg = null;
    });
    try {
      final result = await CampaignActionService.createExtendOrder(
        campaignId: widget.campaign.id,
        addDays: _selectedDays,
      );

      final orderId = (result['orderId'] ?? '').toString();
      final amount = (result['amount'] as num?)?.toInt() ?? 0;
      final requiresPayment = result['requiresPayment'] == true;

      if (orderId.isEmpty) {
        throw Exception('주문 정보가 비어 있습니다.');
      }
      if (!mounted) return;

      if (!requiresPayment || amount <= 0) {
        // 0원 (이론상 불가) — confirmPayment 만 호출하면 끝
        // 다만 본 흐름에서는 사용자 경험상 결제 화면을 거치도록 유지하지 않고 종료.
        Navigator.of(context).pop(true);
        return;
      }

      // 결제 위젯 호출 — successUrl 로 돌아와 PaymentSuccessPage 가 confirmPayment 실행.
      final email =
          FirebaseAuth.instance.currentUser?.email ?? 'noreply@hygienelab.kr';
      await TossPaymentService.requestPayment(
        orderId: orderId,
        orderName: '[광고 연장] $_selectedDays일',
        amount: amount,
        customerEmail: email,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMsg = '연장 주문 생성에 실패했습니다.\n$e';
      });
    }
  }
}

class _CurrentEndInfo extends StatelessWidget {
  const _CurrentEndInfo({required this.campaign});

  final Campaign campaign;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy.MM.dd');
    final end = campaign.adEndAt;
    final remain = campaign.remainingDays;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.event_available,
              size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              end == null
                  ? '게시 종료일 정보 없음'
                  : '현재 종료일 ${fmt.format(end.toLocal())} · 잔여 $remain일',
              style: GoogleFonts.notoSansKr(
                fontSize: 12,
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

class _DayOption extends StatelessWidget {
  const _DayOption({
    required this.days,
    required this.selected,
    required this.onTap,
  });

  final int days;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.cardPrimary : AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppPublisher.buttonRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppPublisher.buttonRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            '+$days일',
            style: GoogleFonts.notoSansKr(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color:
                  selected ? AppColors.onCardPrimary : AppColors.textPrimary,
            ),
          ),
        ),
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

