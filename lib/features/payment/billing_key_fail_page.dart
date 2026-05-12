import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/web_site_footer.dart';
import 'toss_billing_auth_service.dart';

/// Toss 빌링 인증 실패 redirect 페이지.
class BillingKeyFailPage extends StatelessWidget {
  const BillingKeyFailPage({
    super.key,
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  @override
  Widget build(BuildContext context) {
    final friendly = _friendlyMessage(code, message);
    final next =
        TossBillingAuthService.readNextRedirect() ?? '/post-job/campaigns';
    return Scaffold(
      backgroundColor: AppColors.appBg,
      bottomNavigationBar:
          const WebSiteFooter(backgroundColor: AppColors.white),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color:
                        AppColors.destructive.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.error_outline,
                      size: 32, color: AppColors.destructive),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '카드 등록이 취소되었거나 실패했어요',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  friendly,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.55,
                  ),
                ),
                if (code.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '오류 코드: $code',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 11,
                      color: AppColors.textDisabled,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: AppPublisher.ctaHeight,
                      child: TextButton(
                        onPressed: () => context.go(next),
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.surfaceMuted,
                          foregroundColor: AppColors.textPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppPublisher.buttonRadius,
                            ),
                          ),
                        ),
                        child: Text(
                          '돌아가기',
                          style: GoogleFonts.notoSansKr(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    SizedBox(
                      height: AppPublisher.ctaHeight,
                      child: ElevatedButton(
                        onPressed: () => context.go(
                          '/post-job/payment/billing/register'
                          '?next=${Uri.encodeComponent(next)}',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.cardPrimary,
                          foregroundColor: AppColors.onCardPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppPublisher.buttonRadius,
                            ),
                          ),
                        ),
                        child: Text(
                          '다시 시도',
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
          ),
        ),
      ),
    );
  }

  String _friendlyMessage(String code, String message) {
    if (code == 'USER_CANCEL' || code == 'PAY_PROCESS_CANCELED') {
      return '카드 등록을 취소했어요. 자동연장 사용을 원하시면 다시 등록해 주세요.';
    }
    if (code == 'SDK_NOT_LOADED') {
      return '결제 모듈을 불러오지 못했어요. 페이지를 새로고침하고 다시 시도해 주세요.';
    }
    if (message.isNotEmpty) return message;
    return '카드 등록 중 알 수 없는 오류가 발생했어요. 잠시 후 다시 시도해 주세요.';
  }
}
