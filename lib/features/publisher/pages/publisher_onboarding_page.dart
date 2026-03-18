import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import 'publisher_shared.dart';
import '../services/clinic_auth_service.dart';

class PublisherOnboardingPage extends StatelessWidget {
  const PublisherOnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PubScaffold(
      title: '게시자 인증 진행',
      subtitle: '3단계를 완료하면 공고를 작성할 수 있어요',
      showBack: false,
      child: StreamBuilder<ClinicStatus>(
        stream: ClinicAuthService.watchStatus(),
        builder: (context, snap) {
          final status = snap.data ?? const ClinicStatus();
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── 전체 진행률 바 ─────────────────
                    _ProgressHeader(status: status),
                    const SizedBox(height: 24),

                    // ── 단계 카드 ──────────────────────
                    _StepCard(
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
                    const SizedBox(height: 12),
                    _StepCard(
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
                    const SizedBox(height: 12),
                    _StepCard(
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

                    // ── 거절/정지 안내 ─────────────────
                    if (status.approvalStatus == 'rejected') ...[
                      const SizedBox(height: 16),
                      _StatusBanner(
                        icon: Icons.cancel_outlined,
                        color: AppColors.error,
                        message: '사업자 인증이 반려되었습니다.\n서류를 재제출해주세요.',
                      ),
                    ] else if (status.approvalStatus == 'suspended') ...[
                      const SizedBox(height: 16),
                      _StatusBanner(
                        icon: Icons.block_rounded,
                        color: AppColors.error,
                        message: '계정이 정지 상태입니다.\n문의: support@chikabooks.com',
                      ),
                    ],

                    const SizedBox(height: 32),

                    // ── CTA ───────────────────────────
                    if (status.isApprovedAndCanPost)
                      PubPrimaryButton(
                        label: '공고 작성 시작하기',
                        onPressed: () => context.go('/post-job'),
                      )
                    else if (status.approvalStatus != 'suspended')
                      _NextStepButton(status: status),
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

// ── 전체 진행률 헤더 ───────────────────────────────────────
class _ProgressHeader extends StatelessWidget {
  final ClinicStatus status;
  const _ProgressHeader({required this.status});

  int get _doneCount =>
      [
        status.phoneVerified,
        status.profileDone,
        status.clinicVerified,
      ].where((e) => e).length;

  @override
  Widget build(BuildContext context) {
    final progress = _doneCount / 3;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kPubCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  status.isApprovedAndCanPost
                      ? '인증 완료! 공고를 작성할 수 있어요.'
                      : '인증을 완료해 공고를 게시하세요.',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kPubText,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color:
                      status.isApprovedAndCanPost
                          ? kPubBlue.withOpacity(0.1)
                          : kPubBorder.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_doneCount / 3',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color:
                        status.isApprovedAndCanPost
                            ? kPubBlue
                            : kPubText.withOpacity(0.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: kPubBorder.withOpacity(0.4),
              valueColor: const AlwaysStoppedAnimation<Color>(kPubBlue),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 단계 카드 ────────────────────────────────────────────
class _StepCard extends StatelessWidget {
  final int step;
  final String title;
  final String description;
  final IconData icon;
  final bool isDone;
  final bool isPending;
  final bool isLocked;
  final VoidCallback? onTap;

  const _StepCard({
    required this.step,
    required this.title,
    required this.description,
    required this.icon,
    this.isDone = false,
    this.isPending = false,
    this.isLocked = false,
    this.onTap,
  });

  Color get _cardColor {
    if (isDone) return AppColors.accent.withOpacity(0.06);
    if (isPending) return AppColors.warning.withOpacity(0.08);
    if (isLocked) return AppColors.surfaceMuted;
    return kPubCard;
  }

  Color get _iconBg {
    if (isDone) return kPubBlue.withOpacity(0.15);
    if (isPending) return AppColors.warning.withOpacity(0.3);
    if (isLocked) return kPubBorder.withOpacity(0.4);
    return kPubBlue.withOpacity(0.08);
  }

  Color get _iconColor {
    if (isDone) return kPubBlue;
    if (isPending) return AppColors.warning;
    if (isLocked) return kPubText.withOpacity(0.3);
    return kPubBlue.withOpacity(0.7);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isDone
                    ? kPubBlue.withOpacity(0.2)
                    : isPending
                    ? AppColors.warning.withOpacity(0.5)
                    : kPubBorder.withOpacity(0.5),
          ),
          boxShadow: [
            BoxShadow(
            color: AppColors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 아이콘 영역
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  isDone
                      ? const Icon(
                        Icons.check_rounded,
                        color: kPubBlue,
                        size: 24,
                      )
                      : Icon(icon, color: _iconColor, size: 24),
            ),
            const SizedBox(width: 14),

            // 텍스트 영역
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'STEP $step',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color:
                              isDone
                                  ? kPubBlue
                                  : isLocked
                                  ? kPubText.withOpacity(0.3)
                                  : kPubBlue.withOpacity(0.6),
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (isDone) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: kPubBlue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '완료',
                            style: TextStyle(
                              fontSize: 9,
                              color: kPubBlue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ] else if (isPending) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '검토 중',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.warning,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isLocked ? kPubText.withOpacity(0.3) : kPubText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: kPubText.withOpacity(isLocked ? 0.25 : 0.5),
                    ),
                  ),
                ],
              ),
            ),

            // 화살표
            if (!isDone && !isLocked)
              Icon(
                Icons.chevron_right_rounded,
                color: kPubBlue.withOpacity(0.5),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

// ── 다음 단계 진행 버튼 ────────────────────────────────────
class _NextStepButton extends StatelessWidget {
  final ClinicStatus status;
  const _NextStepButton({required this.status});

  String get _label {
    if (!status.phoneVerified) return '1단계 시작 – 휴대폰 인증';
    if (!status.profileDone) return '2단계 시작 – 기본 정보 입력';
    if (status.isPending) return '3단계 확인 – 검토 대기 중';
    return '3단계 시작 – 사업자 인증';
  }

  @override
  Widget build(BuildContext context) {
    final isPending = status.isPending;
    return ElevatedButton(
      onPressed:
          isPending
              ? () => context.push('/publisher/pending')
              : () => context.push(status.nextRoute),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPending ? AppColors.warning : kPubBlue,
        foregroundColor: AppColors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        _label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── 상태 안내 배너 (거절/정지) ─────────────────────────────
class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _StatusBanner({
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: kPubText.withOpacity(0.8),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


