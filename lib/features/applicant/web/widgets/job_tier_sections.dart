import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../models/job.dart';
import 'job_image.dart';

/// 공고 보드 섹션 헤더 (제목 + 부제 + 액션)
class JobBoardSectionHeader extends StatelessWidget {
  const JobBoardSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.badge,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final String? badge;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppApplicant.sectionHeaderGap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (badge != null) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.cardEmphasis,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Text(
                badge!,
                style: GoogleFonts.notoSansKr(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onCardEmphasis,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 프리미엄(레벨 1) 카드 그리드.
///
/// `RecommendedJobGrid` 와 동일한 `LayoutBuilder + Wrap` 패턴으로 통일해
/// 모든 환경(웹 release/canvaskit/skwasm 포함)에서 layout 측정 안정성을
/// 보장한다.
///
/// 이전에는 가로 스크롤 캐러셀(`SingleChildScrollView` + `IntrinsicHeight` +
/// `Row` + `Material/Ink(boxShadow)`) 였으나, 해당 조합이 web release 에서
/// intrinsic height 측정을 잘못 부풀려 카드 영역이 거대한 회색 빈 박스로
/// 그려지는 사례가 보고됐다. 그리드 패턴은 children intrinsic 측정에
/// 의존하지 않으므로 동일 증상이 재발하지 않는다.
class PremiumJobCarousel extends StatelessWidget {
  const PremiumJobCarousel({
    super.key,
    required this.jobs,
    required this.onJobTap,
  });

  final List<Job> jobs;
  final void Function(Job job) onJobTap;

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppApplicant.premiumCardGap;
        const minCardWidth = AppApplicant.premiumMinCardWidth;
        // 본문 폭에 따라 1~3 열로 자동 분할. jobs 갯수보다 큰 cols 는 의미 없음.
        final cols = (constraints.maxWidth / (minCardWidth + gap))
            .floor()
            .clamp(1, jobs.length < 3 ? jobs.length : 3);
        final cardWidth =
            (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final job in jobs)
              SizedBox(
                width: cardWidth,
                child: _PremiumCard(
                  job: job,
                  onTap: () => onJobTap(job),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.job, required this.onTap});
  final Job job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = job.images.isNotEmpty
        ? job.images.first
        : (job.promotionalImageUrls.isNotEmpty
            ? job.promotionalImageUrls.first
            : null);

    // 카드 width 는 부모([PremiumJobCarousel]의 [LayoutBuilder] + [Wrap])에서
    // 본문 폭에 비례해 결정한다. 이미지 영역은 카드 width 기준 16:9 비율을
    // 유지하기 위해 [AspectRatio] 를 사용 — IntrinsicHeight 부모가 없으므로
    // AspectRatio 가 안정적으로 동작한다.
    return Material(
      color: AppColors.white,
      borderRadius:
          BorderRadius.circular(AppApplicant.premiumCardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(AppApplicant.premiumCardRadius),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(AppApplicant.premiumCardRadius),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: AppColors.divider.withValues(alpha: 0.4),
                blurRadius: AppApplicant.cardShadowBlur,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 이미지 ──
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppApplicant.premiumCardRadius),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: image != null
                      ? JobThumbImage(src: image)
                      : JobThumbImage.placeholder(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _PremiumBadge(),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            job.displayClinicName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.notoSansKr(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      job.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_districtOrAddress(job)} · ${job.salaryDisplayLine}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _PremiumBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.cardEmphasis,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        'PREMIUM',
        style: GoogleFonts.notoSansKr(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: AppColors.onCardEmphasis,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// 추천(레벨 2) 그리드 — 폭에 따라 1~3열 자동 조정
class RecommendedJobGrid extends StatelessWidget {
  const RecommendedJobGrid({
    super.key,
    required this.jobs,
    required this.onJobTap,
  });

  final List<Job> jobs;
  final void Function(Job job) onJobTap;

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // 최소 카드 폭 기준으로 칸 수 자동 계산
        final cols = (constraints.maxWidth /
                (AppApplicant.recommendedMinCardWidth +
                    AppApplicant.recommendedCardGap))
            .floor()
            .clamp(1, 3);
        final cardWidth = (constraints.maxWidth -
                AppApplicant.recommendedCardGap * (cols - 1)) /
            cols;
        return Wrap(
          spacing: AppApplicant.recommendedCardGap,
          runSpacing: AppApplicant.recommendedCardGap,
          children: [
            for (final job in jobs)
              SizedBox(
                width: cardWidth,
                child: _RecommendedCard(
                  job: job,
                  onTap: () => onJobTap(job),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RecommendedCard extends StatelessWidget {
  const _RecommendedCard({required this.job, required this.onTap});
  final Job job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius:
          BorderRadius.circular(AppApplicant.recommendedCardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(AppApplicant.recommendedCardRadius),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(AppApplicant.recommendedCardRadius),
            border: Border.all(color: AppColors.divider),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: Text(
                        '추천',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatPostedAt(job.postedAt),
                      style: GoogleFonts.notoSansKr(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDisabled,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  job.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  job.displayClinicName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _districtOrAddress(job),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(
                      Icons.payments_outlined,
                      size: 15,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        job.salaryDisplayLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansKr(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                if (job.listRoleLine.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    job.listRoleLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 일반(레벨 3) 리스트 — 행 형태, 텍스트 위주
class StandardJobList extends StatelessWidget {
  const StandardJobList({
    super.key,
    required this.jobs,
    required this.onJobTap,
  });

  final List<Job> jobs;
  final void Function(Job job) onJobTap;

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 60),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppColors.textDisabled,
            ),
            const SizedBox(height: 12),
            Text(
              '조건에 맞는 공고가 없어요.',
              style: GoogleFonts.notoSansKr(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < jobs.length; i++) ...[
          _StandardRow(job: jobs[i], onTap: () => onJobTap(jobs[i])),
          if (i < jobs.length - 1)
            const Divider(height: 1, color: AppColors.divider),
        ],
      ],
    );
  }
}

class _StandardRow extends StatelessWidget {
  const _StandardRow({required this.job, required this.onTap});
  final Job job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        job.displayClinicName,
                        if (job.listRoleLine.isNotEmpty) job.listRoleLine,
                      ].join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  _districtOrAddress(job),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  job.salaryDisplayLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 70,
                child: Text(
                  _formatPostedAt(job.postedAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDisabled,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _districtOrAddress(Job job) {
  final d = job.district.trim();
  if (d.isNotEmpty) return d;
  final a = job.address.trim();
  if (a.isEmpty) return '지역 미지정';
  // 시·구·동 정도만 짧게 노출
  final parts = a.split(' ').where((s) => s.isNotEmpty).toList();
  if (parts.length <= 2) return a;
  return parts.take(2).join(' ');
}

String _formatPostedAt(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inMinutes < 1) return '방금';
  if (diff.inHours < 1) return '${diff.inMinutes}분 전';
  if (diff.inDays < 1) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  return DateFormat('M/d').format(date);
}
