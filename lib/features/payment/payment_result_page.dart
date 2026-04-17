import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/web_site_footer.dart';
import '../../services/order_service.dart';

/// 토스페이먼츠 결제 성공 후 리다이렉트 되는 페이지
///
/// URL 파라미터: paymentKey, orderId, amount
class PaymentSuccessPage extends StatefulWidget {
  final String paymentKey;
  final String orderId;
  final String amount;

  const PaymentSuccessPage({
    super.key,
    required this.paymentKey,
    required this.orderId,
    required this.amount,
  });

  @override
  State<PaymentSuccessPage> createState() => _PaymentSuccessPageState();
}

class _PaymentSuccessPageState extends State<PaymentSuccessPage> {
  bool _isConfirming = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _confirm();
  }

  Future<void> _confirm() async {
    try {
      final result = await OrderService.confirmPayment(
        orderId: widget.orderId,
        paymentKey: widget.paymentKey,
      );
      if (mounted && result.success) {
        context.go('/post-job/success/${result.jobId}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConfirming = false;
          _errorMsg = '결제 확인 중 오류가 발생했어요.\n고객센터로 문의해 주세요.\n($e)';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      bottomNavigationBar: const WebSiteFooter(backgroundColor: AppColors.white),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isConfirming) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  '결제를 확인하고 있어요…',
                  style: GoogleFonts.notoSansKr(fontSize: 16, color: AppColors.textSecondary),
                ),
              ] else if (_errorMsg != null) ...[
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  _errorMsg!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSansKr(fontSize: 14, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/post-job/input'),
                  child: const Text('공고 목록으로'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 토스페이먼츠 결제 실패 후 리다이렉트 되는 페이지
///
/// URL 파라미터: code, message, orderId
class PaymentFailPage extends StatelessWidget {
  final String code;
  final String message;
  final String orderId;

  const PaymentFailPage({
    super.key,
    required this.code,
    required this.message,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      bottomNavigationBar: const WebSiteFooter(backgroundColor: AppColors.white),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cancel_outlined, size: 56, color: Colors.red),
              const SizedBox(height: 20),
              Text(
                '결제에 실패했어요',
                style: GoogleFonts.notoSansKr(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message.isNotEmpty ? message : '알 수 없는 오류가 발생했어요.',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansKr(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                '오류 코드: $code',
                style: GoogleFonts.notoSansKr(fontSize: 12, color: AppColors.textDisabled),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => context.go('/post-job/input'),
                child: const Text('다시 시도하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
