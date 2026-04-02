import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import 'publisher_shared.dart';
import 'publisher_onboarding_progress.dart';
import 'publisher_onboarding_actions.dart';
import '../services/clinic_auth_service.dart';

class PublisherOnboardingPage extends StatelessWidget {
  const PublisherOnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PubScaffold(
      title: '게시자 인증 진행',
      subtitle: '3단계를 완료하면 공고를 작성할 수 있어요',
      showBack: false,
      webPublisherShell: true,
      child: StreamBuilder<ClinicStatus>(
        stream: ClinicAuthService.watchStatus(),
        builder: (context, snap) {
          final status = snap.data ?? const ClinicStatus();
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PublisherOnboardingProgressHeader(status: status),
                    const SizedBox(height: 28),

                    Text(
                      '진행 단계',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.72,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(height: 1, color: AppColors.divider),
                    const SizedBox(height: 4),

                    PublisherOnboardingStepRow(
                      step: 1,
                      title: '휴대폰 본인확인',
                      description: '인증을 통해 실제 담당자임을 확인해요.',
                      icon: Icons.phone_iphone_rounded,
                      isDone: status.phoneVerified,
                      onTap:
                          status.phoneVerified
                              ? null
                              : () => context.push('/publisher/verify-phone'),
                    ),
                    PublisherOnboardingStepRow(
                      step: 2,
                      title: '기본 정보 입력',
                      description: '이름, 직책, 치과명 등 기본 정보를 입력해주세요.',
                      icon: Icons.person_outline_rounded,
                      isDone: status.profileDone,
                      isLocked: !status.phoneVerified,
                      onTap:
                          (!status.phoneVerified || status.profileDone)
                              ? null
                              : () => context.push('/publisher/profile'),
                    ),
                    PublisherOnboardingStepRow(
                      step: 3,
                      title: '사업자 인증',
                      description: '사업자등록증을 제출해 치과 실재를 확인해요.',
                      icon: Icons.verified_outlined,
                      isDone: status.clinicVerified,
                      isPending: status.isPending,
                      isLocked: !status.profileDone,
                      onTap:
                          (!status.profileDone)
                              ? null
                              : status.isPending
                              ? () => context.push('/publisher/pending')
                              : status.clinicVerified
                              ? null
                              : () =>
                                  context.push('/publisher/verify-business'),
                    ),

                    if (status.approvalStatus == 'rejected') ...[
                      const SizedBox(height: 20),
                      PublisherOnboardingStatusBanner(
                        icon: Icons.cancel_outlined,
                        color: AppColors.error,
                        message: '사업자 인증이 반려되었습니다.\n서류를 재제출해주세요.',
                      ),
                    ] else if (status.approvalStatus == 'suspended') ...[
                      const SizedBox(height: 20),
                      PublisherOnboardingStatusBanner(
                        icon: Icons.block_rounded,
                        color: AppColors.error,
                        message: '계정이 정지 상태입니다.\n문의: support@chikabooks.com',
                      ),
                    ],

                    const SizedBox(height: 36),

                    if (status.isApprovedAndCanPost)
                      PublisherOnboardingPrimaryCta(
                        label: '공고 작성 시작하기',
                        background: AppColors.cardEmphasis,
                        onPressed: () => context.go('/post-job'),
                      )
                    else if (status.approvalStatus != 'suspended')
                      PublisherOnboardingNextStepButton(status: status),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
