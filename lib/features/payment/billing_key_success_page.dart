import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/web_site_footer.dart';
import '../../services/billing_key_service.dart';
import 'toss_billing_auth_service.dart';

/// Toss 빌링 인증 성공 redirect 콜백 페이지.
///
/// URL 파라미터: `authKey`, `customerKey`.
/// initState 에서 [BillingKeyService.registerBillingKey] 호출 → 성공 시
/// session 에 저장된 next 로 자동 복귀.
class BillingKeySuccessPage extends StatefulWidget {
  const BillingKeySuccessPage({
    super.key,
    required this.authKey,
    required this.customerKey,
  });

  final String authKey;
  final String customerKey;

  @override
  State<BillingKeySuccessPage> createState() => _BillingKeySuccessPageState();
}

class _BillingKeySuccessPageState extends State<BillingKeySuccessPage> {
  bool _busy = true;
  String? _errorMsg;
  RegisterBillingKeyResult? _result;
  String _nextPath = '/post-job/campaigns';

  @override
  void initState() {
    super.initState();
    _confirm();
  }

  Future<void> _confirm() async {
    final authKey = widget.authKey.trim();
    final customerKey = widget.customerKey.trim();
    final user = FirebaseAuth.instance.currentUser;

    final saved = TossBillingAuthService.readNextRedirect();
    if (saved != null && saved.startsWith('/') && !saved.startsWith('//')) {
      _nextPath = saved;
    }

    if (authKey.isEmpty || customerKey.isEmpty) {
      setState(() {
        _busy = false;
        _errorMsg = '카드 인증 응답이 올바르지 않습니다. 다시 시도해 주세요.';
      });
      return;
    }
    if (user == null) {
      setState(() {
        _busy = false;
        _errorMsg = '로그인 세션이 만료됐어요. 다시 로그인 후 시도해 주세요.';
      });
      return;
    }
    if (customerKey != user.uid) {
      // 서버가 거부할 거지만 클라에서 미리 안내
      setState(() {
        _busy = false;
        _errorMsg = '결제 식별자가 본인 계정과 일치하지 않습니다.';
      });
      return;
    }

    try {
      final r = await BillingKeyService.registerBillingKey(
        authKey: authKey,
        customerKey: customerKey,
        customerEmail: user.email ?? '',
        customerName: user.displayName ?? '',
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = r;
      });
      if (kIsWeb) {
        // history 의 query 가 남지 않도록 next 로 replace 이동.
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        context.go(_nextPath);
      }
    } catch (e) {
      debugPrint('⚠️ registerBillingKey failed: $e');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMsg = '카드 등록에 실패했어요. 다시 시도해 주세요.\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      bottomNavigationBar:
          const WebSiteFooter(backgroundColor: AppColors.white),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: _busy
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        '카드를 등록하고 있어요…',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                : _errorMsg != null
                    ? _ErrorView(
                        message: _errorMsg!,
                        onRetry: () => context.go(_nextPath),
                      )
                    : _SuccessView(
                        result: _result!,
                        nextPath: _nextPath,
                      ),
          ),
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.result, required this.nextPath});

  final RegisterBillingKeyResult result;
  final String nextPath;

  @override
  Widget build(BuildContext context) {
    final masked = result.cardNumberMasked.isEmpty
        ? '카드'
        : result.cardNumberMasked;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded,
              size: 32, color: Colors.green),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          '카드 등록이 완료됐어요',
          style: GoogleFonts.notoSansKr(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          result.cardCompany.isNotEmpty
              ? '${result.cardCompany} · $masked'
              : masked,
          style: GoogleFonts.notoSansKr(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: AppPublisher.ctaHeight,
          width: 200,
          child: ElevatedButton(
            onPressed: () => context.go(nextPath),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cardPrimary,
              foregroundColor: AppColors.onCardPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppPublisher.buttonRadius,
                ),
              ),
            ),
            child: Text(
              '대시보드로',
              style: GoogleFonts.notoSansKr(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.destructive.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.error_outline,
              size: 32, color: AppColors.destructive),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          '카드 등록에 실패했어요',
          style: GoogleFonts.notoSansKr(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSansKr(
            fontSize: 12,
            color: AppColors.textSecondary,
            height: 1.55,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          height: AppPublisher.ctaHeight,
          width: 200,
          child: ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceMuted,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
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
      ],
    );
  }
}
