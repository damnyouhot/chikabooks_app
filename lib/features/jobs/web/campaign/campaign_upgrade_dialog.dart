import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_modal_scaffold.dart';
import '../../../../models/campaign.dart';
import '../../../../services/campaign_action_service.dart';
import '../../../../services/order_service.dart';
import '../../../payment/toss_payment_service.dart';

/// 캠페인 등급 변경 다이얼로그.
///
/// - 현재 등급보다 상위 등급(예: basic → standard / standard → premium) 만 허용.
/// - 차액 = (newPrice − currentPrice) × (남은일수 / newCatalog.exposureDays)
///   계산은 서버 [createUpgradeOrder] 가 수행. 클라이언트는 옵션만 전송.
/// - 차액이 0원이면 confirmPayment 만 호출, >0 이면 Toss 결제 위젯 호출.
class CampaignUpgradeDialog extends StatefulWidget {
  const CampaignUpgradeDialog({
    super.key,
    required this.campaign,
    required this.jobTitle,
  });

  final Campaign campaign;
  final String jobTitle;

  static Future<bool?> show(
    BuildContext context, {
    required Campaign campaign,
    required String jobTitle,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => CampaignUpgradeDialog(
        campaign: campaign,
        jobTitle: jobTitle,
      ),
    );
  }

  @override
  State<CampaignUpgradeDialog> createState() => _CampaignUpgradeDialogState();
}

class _CampaignUpgradeDialogState extends State<CampaignUpgradeDialog> {
  /// 표시 순서 — 낮은 → 높은 등급
  static const _allTiers = <String>['basic', 'standard', 'premium'];

  String? _selected;
  bool _busy = false;
  String? _errorMsg;
  Map<String, _TierMeta> _meta = const {};
  bool _loadingMeta = true;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  /// productCatalog/{tierKey} 의 이름·가격을 한 번 읽어 보여준다.
  /// (UI 미리보기용 — 실제 결제 금액은 서버가 산정.)
  Future<void> _loadCatalog() async {
    try {
      final fs = FirebaseFirestore.instance;
      final docs = await Future.wait(
        _allTiers.map((t) => fs.collection('productCatalog').doc(t).get()),
      );
      final result = <String, _TierMeta>{};
      for (var i = 0; i < _allTiers.length; i++) {
        final t = _allTiers[i];
        final d = docs[i].data() ?? const <String, dynamic>{};
        final priceId = (d['activePriceId'] as String?) ?? '';
        int amount = 0;
        int exposureDays = (d['exposureDays'] as num?)?.toInt() ?? 0;
        if (priceId.isNotEmpty) {
          final p = await fs
              .collection('productCatalog')
              .doc(t)
              .collection('prices')
              .doc(priceId)
              .get();
          amount = (p.data()?['amount'] as num?)?.toInt() ?? 0;
        }
        result[t] = _TierMeta(
          name: (d['name'] as String?) ?? _fallbackName(t),
          amount: amount,
          exposureDays: exposureDays,
        );
      }
      if (!mounted) return;
      setState(() {
        _meta = result;
        _loadingMeta = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMeta = false);
    }
  }

  String _fallbackName(String t) {
    switch (t) {
      case 'premium':
        return 'A · 프리미엄';
      case 'standard':
        return 'B · 스탠다드';
      case 'basic':
      default:
        return 'C · 베이직';
    }
  }

  int _rankOf(String t) {
    switch (t) {
      case 'premium':
        return 3;
      case 'standard':
        return 2;
      case 'basic':
      default:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTier = widget.campaign.tierKey.toLowerCase();
    final currentRank = _rankOf(currentTier);
    final upgradable = _allTiers.where((t) => _rankOf(t) > currentRank).toList();

    return AppModalDialog(
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '광고 등급 변경',
            style: GoogleFonts.notoSansKr(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '현재 등급: ${_meta[currentTier]?.name ?? _fallbackName(currentTier)}',
            style: GoogleFonts.notoSansKr(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (upgradable.isEmpty)
            _Notice(
              text: '이미 가장 높은 등급입니다. 더 이상 상위 등급으로 변경할 수 없습니다.',
              color: AppColors.textSecondary,
            )
          else if (_loadingMeta)
            const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            Text(
              '변경할 등급',
              style: GoogleFonts.notoSansKr(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Column(
              children: upgradable
                  .map(
                    (t) => Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _TierOption(
                        tierKey: t,
                        name: _meta[t]?.name ?? _fallbackName(t),
                        amount: _meta[t]?.amount ?? 0,
                        exposureDays: _meta[t]?.exposureDays ?? 0,
                        selected: _selected == t,
                        onTap: _busy
                            ? null
                            : () => setState(() => _selected = t),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '결제 금액은 남은 일수에 비례한 차액으로 자동 산정됩니다.',
              style: GoogleFonts.notoSansKr(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
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
                      _busy || _selected == null || upgradable.isEmpty
                          ? null
                          : _proceed,
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
                          _selected == null ? '등급 선택' : '차액 결제',
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
    final newTier = _selected;
    if (newTier == null) return;
    setState(() {
      _busy = true;
      _errorMsg = null;
    });
    try {
      final result = await CampaignActionService.createUpgradeOrder(
        campaignId: widget.campaign.id,
        newTierKey: newTier,
      );

      final orderId = (result['orderId'] ?? '').toString();
      final amount = (result['amount'] as num?)?.toInt() ?? 0;
      final requiresPayment = result['requiresPayment'] == true;

      if (orderId.isEmpty) {
        throw Exception('주문 정보가 비어 있습니다.');
      }
      if (!mounted) return;

      if (!requiresPayment || amount <= 0) {
        // 차액 0원 — confirmPayment 만 호출 후 종료
        await OrderService.confirmPayment(orderId: orderId);
        if (mounted) Navigator.of(context).pop(true);
        return;
      }

      final email =
          FirebaseAuth.instance.currentUser?.email ?? 'noreply@hygienelab.kr';
      await TossPaymentService.requestPayment(
        orderId: orderId,
        orderName: '[등급 변경] ${_meta[newTier]?.name ?? newTier}',
        amount: amount,
        customerEmail: email,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMsg = '등급 변경 주문 생성에 실패했습니다.\n$e';
      });
    }
  }
}

class _TierMeta {
  const _TierMeta({
    required this.name,
    required this.amount,
    required this.exposureDays,
  });
  final String name;
  final int amount;
  final int exposureDays;
}

class _TierOption extends StatelessWidget {
  const _TierOption({
    required this.tierKey,
    required this.name,
    required this.amount,
    required this.exposureDays,
    required this.selected,
    required this.onTap,
  });

  final String tierKey;
  final String name;
  final int amount;
  final int exposureDays;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.cardPrimary : AppColors.white,
      borderRadius: BorderRadius.circular(AppPublisher.buttonRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppPublisher.buttonRadius),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? AppColors.cardPrimary : AppColors.divider,
            ),
            borderRadius:
                BorderRadius.circular(AppPublisher.buttonRadius),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: selected
                            ? AppColors.onCardPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      exposureDays > 0
                          ? '노출 $exposureDays일'
                          : '노출 기간 정보 없음',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 12,
                        color: selected
                            ? AppColors.onCardPrimary.withValues(alpha: 0.85)
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                amount > 0
                    ? '${NumberFormat('#,###').format(amount)}원'
                    : '-',
                style: GoogleFonts.notoSansKr(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? AppColors.onCardPrimary
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        text,
        style: GoogleFonts.notoSansKr(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
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
