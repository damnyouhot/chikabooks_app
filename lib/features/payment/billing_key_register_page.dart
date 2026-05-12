import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/web_site_footer.dart';
import '../../services/billing_key_service.dart';
import '../jobs/web/job_post_top_bar.dart';
import 'toss_billing_auth_service.dart';

/// 자동결제 카드(빌링키) 등록 화면.
///
/// 진입 경로:
///   `/post-job/payment/billing/register?next=<복귀 URL>&campaignId=<선택>`
///
/// 흐름:
///   1) 사용자가 [BillingKeyRegisterPage] 의 "카드 등록하기" 클릭.
///   2) 토스 SDK 가 customerKey=uid 로 카드 등록창 OPEN.
///   3) 성공 → 토스가 success URL 로 redirect → [BillingKeyRegisterSuccessPage] 가
///      `BillingKeyService.registerBillingKey` 호출하고 [next] 로 복귀.
///   4) 실패 → [BillingKeyRegisterFailPage] 가 사유 표시.
///
/// 이미 등록된 카드가 있으면 화면 하단에 표시 + "다른 카드로 변경" 옵션 제공.
class BillingKeyRegisterPage extends StatefulWidget {
  const BillingKeyRegisterPage({super.key, this.next});

  /// 등록 성공 후 돌아갈 경로 (예: `/post-job/campaigns`).
  /// null/비어있음 → 기본값 `/post-job/campaigns` 사용.
  final String? next;

  @override
  State<BillingKeyRegisterPage> createState() => _BillingKeyRegisterPageState();
}

class _BillingKeyRegisterPageState extends State<BillingKeyRegisterPage> {
  bool _busy = false;
  String? _errorMsg;

  String get _next =>
      (widget.next != null && widget.next!.isNotEmpty)
          ? widget.next!
          : '/post-job/campaigns';

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '';
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.appBg,
      bottomNavigationBar: const WebSiteFooter(backgroundColor: AppColors.white),
      body: Column(
        children: [
          JobPostTopBar(
            currentStep: const JobPostStep(title: '결제 카드 등록'),
            leading: TextButton.icon(
              onPressed: () => context.go(_next),
              icon: const Icon(Icons.chevron_left,
                  size: 18, color: AppColors.textSecondary),
              label: Text(
                '돌아가기',
                style: GoogleFonts.notoSansKr(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppSpacing.xxl),
                        _Header(),
                        const SizedBox(height: AppSpacing.xl),
                        StreamBuilder<BillingKeyMeta?>(
                          stream:
                              BillingKeyService.watchMyBillingMeta(),
                          builder: (context, snap) {
                            final meta = snap.data;
                            if (meta != null && meta.hasBillingKey) {
                              return _RegisteredCardCard(
                                meta: meta,
                                onDelete: _busy ? null : _handleDelete,
                                busy: _busy,
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _PolicyCard(),
                        if (_errorMsg != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          _ErrorBanner(message: _errorMsg!),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        SizedBox(
                          height: AppPublisher.ctaHeight,
                          child: ElevatedButton(
                            onPressed: (_busy || uid.isEmpty)
                                ? null
                                : () => _startBillingAuth(uid, email),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.cardPrimary,
                              foregroundColor: AppColors.onCardPrimary,
                              disabledBackgroundColor:
                                  AppColors.disabledBg,
                              disabledForegroundColor:
                                  AppColors.disabledText,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppPublisher.buttonRadius,
                                ),
                              ),
                            ),
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.onCardPrimary,
                                    ),
                                  )
                                : Text(
                                    '카드 등록하기',
                                    style: GoogleFonts.notoSansKr(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          '안전한 결제를 위해 토스페이먼츠 인증창에서 카드 정보를 입력합니다. '
                          '카드번호는 토스에 저장되며, 본 서비스에는 노출되지 않습니다.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.notoSansKr(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startBillingAuth(String uid, String email) async {
    if (!kIsWeb) {
      setState(() => _errorMsg = '웹에서만 카드 등록이 지원됩니다.');
      return;
    }
    setState(() {
      _busy = true;
      _errorMsg = null;
    });
    try {
      // 등록 후 복귀 경로 보존 (Toss redirect 후 success 페이지에서 읽음)
      TossBillingAuthService.setNextRedirect(_next);

      final user = FirebaseAuth.instance.currentUser;
      await TossBillingAuthService.requestBillingAuth(
        customerKey: uid,
        customerEmail: email.isNotEmpty ? email : '$uid@unknown.local',
        customerName: user?.displayName ?? '',
      );
      // 위 호출은 토스가 페이지를 redirect 하므로 이후 코드는 실행되지 않는다.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMsg = '카드 등록 창을 띄우지 못했어요. 잠시 후 다시 시도해 주세요.\n$e';
      });
    }
  }

  Future<void> _handleDelete() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          '카드 해지',
          style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w800),
        ),
        content: Text(
          '등록된 카드를 해지하면 자동연장이 켜진 모든 캠페인이 OFF 로 전환됩니다. '
          '계속하시겠어요?',
          style: GoogleFonts.notoSansKr(fontSize: 13, height: 1.55),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.destructive,
              foregroundColor: AppColors.white,
            ),
            child: const Text('해지'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _busy = true;
      _errorMsg = null;
    });
    try {
      final r = await BillingKeyService.deleteBillingKey();
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            r.autoRenewDisabledCount > 0
                ? '카드를 해지했습니다. 자동연장 ${r.autoRenewDisabledCount}건이 함께 OFF 됐습니다.'
                : '카드를 해지했습니다.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMsg = '카드 해지에 실패했어요.\n$e';
      });
    }
  }

}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.cardPrimary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.credit_card_outlined,
            size: 28,
            color: AppColors.cardPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          '자동결제 카드 등록',
          style: GoogleFonts.notoSansKr(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '자동연장이 켜진 캠페인은 게시 종료 직전 자동으로 청구됩니다.\n'
          '결제 카드를 한 번만 등록해 두세요.',
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSansKr(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class _RegisteredCardCard extends StatelessWidget {
  const _RegisteredCardCard({
    required this.meta,
    required this.onDelete,
    required this.busy,
  });

  final BillingKeyMeta meta;
  final VoidCallback? onDelete;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppPublisher.inputPanelRadius),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.cardPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              Icons.credit_card,
              size: 20,
              color: AppColors.cardPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '등록된 카드',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  meta.displayLabel,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onDelete,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.destructive,
            ),
            child: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    '해지',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = <String>[
      '카드는 안전한 토스페이먼츠 환경에서 등록되며, 카드 정보는 본 서비스에 저장되지 않습니다.',
      '자동연장이 켜진 캠페인은 게시 종료 직전 등록된 카드로 자동 청구됩니다.',
      '결제 실패 시 즉시 해당 캠페인의 자동연장이 OFF 로 전환되고 알림이 발송됩니다.',
      '언제든지 카드 해지가 가능하며, 해지 시 자동연장이 켜진 모든 캠페인이 OFF 됩니다.',
    ];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppPublisher.inputPanelRadius),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '약관 및 안내',
            style: GoogleFonts.notoSansKr(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final t in items)
            Padding(
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
                      t,
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
        color: AppColors.destructive.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.destructive.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
