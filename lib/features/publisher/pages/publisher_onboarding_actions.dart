import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import 'publisher_shared.dart';
import '../services/clinic_auth_service.dart';

class PublisherOnboardingPrimaryCta extends StatelessWidget {
  final String label;
  final Color background;
  final VoidCallback onPressed;

  const PublisherOnboardingPrimaryCta({
    super.key,
    required this.label,
    required this.background,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: AppColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        child: Text(
          label,
          style: GoogleFonts.notoSansKr(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.18,
            color: AppColors.white,
          ),
        ),
      ),
    );
  }
}

class PublisherOnboardingNextStepButton extends StatelessWidget {
  final ClinicStatus status;
  const PublisherOnboardingNextStepButton({super.key, required this.status});

  String get _label {
    if (!status.phoneVerified) return '1단계 시작 – 휴대폰 인증';
    if (!status.profileDone) return '2단계 시작 – 기본 정보 입력';
    if (status.isPending) return '3단계 확인 – 검토 대기 중';
    return '3단계 시작 – 사업자 인증';
  }

  @override
  Widget build(BuildContext context) {
    final isPending = status.isPending;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed:
            isPending
                ? () => context.push('/publisher/pending')
                : () => context.push(status.nextRoute),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isPending ? AppColors.accent : AppColors.cardEmphasis,
          foregroundColor: AppColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        child: Text(
          _label,
          style: GoogleFonts.notoSansKr(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.18,
          ),
        ),
      ),
    );
  }
}

class PublisherOnboardingStatusBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const PublisherOnboardingStatusBanner({
    super.key,
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.zero,
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.notoSansKr(
                fontSize: 13,
                letterSpacing: -0.12,
                color: kPubText.withOpacity(0.85),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
