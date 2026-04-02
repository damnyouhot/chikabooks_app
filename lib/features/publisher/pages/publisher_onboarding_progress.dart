import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import 'publisher_shared.dart';
import '../services/clinic_auth_service.dart';

/// 상단 요약 — 직사각형 그림자 블록
class PublisherOnboardingProgressHeader extends StatelessWidget {
  final ClinicStatus status;
  const PublisherOnboardingProgressHeader({super.key, required this.status});

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
        color: AppColors.white,
        borderRadius: BorderRadius.zero,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  status.isApprovedAndCanPost
                      ? '인증 완료! 공고를 작성할 수 있어요.'
                      : '인증을 완료해 공고를 게시하세요.',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.18,
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$_doneCount / 3',
                style: GoogleFonts.notoSansKr(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.18,
                  color:
                      status.isApprovedAndCanPost
                          ? AppColors.cardEmphasis
                          : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRect(
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: AppColors.divider.withOpacity(0.6),
              valueColor: AlwaysStoppedAnimation<Color>(
                status.isApprovedAndCanPost
                    ? AppColors.cardEmphasis
                    : AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 단계 한 줄 — 상단 라인만으로 구역
class PublisherOnboardingStepRow extends StatelessWidget {
  final int step;
  final String title;
  final String description;
  final IconData icon;
  final bool isDone;
  final bool isPending;
  final bool isLocked;
  final VoidCallback? onTap;

  const PublisherOnboardingStepRow({
    super.key,
    required this.step,
    required this.title,
    required this.description,
    required this.icon,
    this.isDone = false,
    this.isPending = false,
    this.isLocked = false,
    this.onTap,
  });

  String get _stepLabel => step.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final interactive = onTap != null && !isLocked;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: interactive ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 1, color: AppColors.divider),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      _stepLabel,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.18,
                        color:
                            isDone
                                ? AppColors.cardEmphasis
                                : isLocked
                                ? AppColors.textDisabled
                                : AppColors.accent,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              icon,
                              size: 18,
                              color:
                                  isLocked
                                      ? AppColors.textDisabled
                                      : isDone
                                      ? AppColors.cardEmphasis
                                      : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                style: GoogleFonts.notoSansKr(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.18,
                                  color:
                                      isLocked
                                          ? AppColors.textDisabled
                                          : kPubText,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            if (isDone)
                              Text(
                                '완료',
                                style: GoogleFonts.notoSansKr(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.12,
                                  color: AppColors.cardEmphasis,
                                ),
                              )
                            else if (isPending)
                              Text(
                                '검토 중',
                                style: GoogleFonts.notoSansKr(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.12,
                                  color: AppColors.accent,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: GoogleFonts.notoSansKr(
                            fontSize: 12,
                            letterSpacing: -0.12,
                            height: 1.45,
                            color: AppColors.textSecondary.withOpacity(
                              isLocked ? 0.45 : 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (interactive)
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.accent.withOpacity(0.65),
                      size: 22,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
