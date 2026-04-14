import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_badge.dart';
import '../../models/job.dart';
import 'job_cover_image.dart';

// ══════════════════════════════════════════════════════════════
// 채용 목록 카드/행 공용 위젯 — job_listings_screen.dart와 동일 로직
//
// 이 파일을 단일 소스로 유지하면 목록 화면과 게시자 상품 선택
// 프리뷰가 항상 동일한 렌더링(폰트·maxLines·줄넘김)을 보장한다.
// ══════════════════════════════════════════════════════════════

/// A·B 클래스 썸네일 크기 (C 목록 내 삽입 시 96의 60%)
const double kJobListingAbThumbSide = 58;

// ── 헬퍼 함수 ──────────────────────────────────────────────────

/// `(샘플)` 접두사 제거 (프리뷰에서 실제 공고처럼 표시할 때 사용)
String _stripSample(String text) {
  const prefix = '(샘플)';
  if (text.startsWith(prefix)) return text.substring(prefix.length).trimLeft();
  return text;
}

String jobListingEducationHint(String career) {
  final c = career.trim();
  if (c.contains('전문대졸')) return '전문대졸';
  if (c.contains('대졸')) return '대졸';
  if (c.contains('전문') && c.contains('학')) return '전문학사';
  return '학력 면접 협의';
}

String jobListingCareerShort(String career) {
  final c = career.trim();
  if (c.isEmpty || c == '미정') return '—';
  if (c.contains('경력 무관') || c.contains('경력무관')) return '경력 무관';
  if (c.contains('신입/경력')) return '경력 무관';
  if (c.contains('1년 이상')) return '1년 이상';
  if (c.contains('2년 이상')) return '2년 이상';
  if (c.contains('신입 가능') || c.contains('신입')) return '신입';
  if (c.length > 18) return '${c.substring(0, 15)}…';
  return c;
}

String jobListingDistrictStationLine(Job job) {
  final dong = job.district.split(' · ').first.trim();
  final t = job.transportation;
  final st = t?.subwayStationName;
  final wm = t?.walkingMinutes;
  if (dong.isEmpty) {
    final parts = job.address.split(' ');
    return parts.length >= 2 ? parts.take(2).join(' ') : job.address;
  }
  if (st != null && st.isNotEmpty && wm != null) {
    return '$dong, $st $wm분';
  }
  return dong;
}

String jobListingInsuranceLine(Job job) {
  for (final b in job.benefits) {
    if (b.contains('4대')) return b;
  }
  for (final t in job.tags) {
    if (t.contains('4대')) return t;
  }
  if (job.benefits.isNotEmpty) return job.benefits.first;
  return '복리 면접 협의';
}

// ── 공통 소형 칩 ───────────────────────────────────────────────

class JobListingSmallChip extends StatelessWidget {
  final String label;

  const JobListingSmallChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: AppColors.accent,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// A 클래스 — 2열 그리드 카드 (이미지 스와이프 + 매칭% 배지)
//            job_listings_screen._Level2Card 와 완전 동일
// ══════════════════════════════════════════════════════════════

class JobListingCardPremium extends StatefulWidget {
  final Job job;
  final bool hideSamplePrefix;

  const JobListingCardPremium({
    super.key,
    required this.job,
    this.hideSamplePrefix = false,
  });

  @override
  State<JobListingCardPremium> createState() => _JobListingCardPremiumState();
}

class _JobListingCardPremiumState extends State<JobListingCardPremium> {
  final _imgCtrl = PageController();
  int _imgPage = 0;

  @override
  void dispose() {
    _imgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final images = job.images;
    final hasMultiple = images.length > 1;
    final title = widget.hideSamplePrefix
        ? _stripSample(job.displayTitle)
        : job.displayTitle;
    final clinic = widget.hideSamplePrefix
        ? _stripSample(job.displayClinicName)
        : job.displayClinicName;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.appBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 이미지 + 인디케이터 + 매칭률 배지 ──────────────
          ClipRRect(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.md),
            ),
            child: SizedBox(
              height: 100,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  images.isNotEmpty
                      ? PageView.builder(
                          controller: _imgCtrl,
                          itemCount: images.length,
                          onPageChanged: (i) => setState(() => _imgPage = i),
                          itemBuilder: (_, i) => JobCoverImage(
                            source: images[i],
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        )
                      : Container(
                          color: AppColors.surfaceMuted,
                          child: const Center(
                            child: Icon(
                              Icons.business_outlined,
                              size: 22,
                              color: AppColors.textDisabled,
                            ),
                          ),
                        ),
                  if (hasMultiple)
                    Positioned(
                      bottom: 6,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(images.length, (i) {
                          final sel = i == _imgPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: sel ? 12 : 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppColors.white
                                  : AppColors.white.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                    ),
                  // 매칭률 배지 (우상단)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.50),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 9,
                            color: AppColors.prepBadgeGreen,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '매칭 ${job.matchScore}%',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── 제목 / 치과명 / 직무·학력 / 고용·경력 / 동·역 / 태그 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                const SizedBox(height: 2),
                Text(
                  clinic,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  '${job.type.trim()}, ${jobListingEducationHint(job.career)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 1),
                Text(
                  '${job.employmentType.trim()}, ${jobListingCareerShort(job.career)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 10,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        jobListingDistrictStationLine(job),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 3,
                  runSpacing: 2,
                  children: (job.tags.isNotEmpty ? job.tags : job.benefits)
                      .take(2)
                      .map((b) => JobListingSmallChip(label: b))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// B 클래스 — 추천 게시판형 행 (썸네일 96px)
//            job_listings_screen._Level3Row 와 완전 동일
// ══════════════════════════════════════════════════════════════

class JobListingRowRecommended extends StatelessWidget {
  final Job job;
  final VoidCallback? onTap;
  final bool hideSamplePrefix;

  const JobListingRowRecommended({
    super.key,
    required this.job,
    this.onTap,
    this.hideSamplePrefix = false,
  });

  @override
  Widget build(BuildContext context) {
    final title = hideSamplePrefix
        ? _stripSample(job.displayTitle)
        : job.displayTitle;
    final clinic = hideSamplePrefix
        ? _stripSample(job.displayClinicName)
        : job.displayClinicName;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: AppColors.appBg,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (job.jobLevel == 1) ...[
                    const Text(
                      '프리미엄',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    clinic,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    job.listRoleLine,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 11,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        job.district.isNotEmpty ? job.district : job.address,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  if (job.tags.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 3,
                      runSpacing: 0,
                      children: job.tags
                          .take(3)
                          .map((t) => JobListingSmallChip(label: t))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (job.images.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: JobCoverImage(
                  source: job.images.first,
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// C 클래스 — 전체 공고 텍스트형 행 (썸네일·해시태그 없음)
//            job_listings_screen._Level4Row 와 완전 동일
// ══════════════════════════════════════════════════════════════

class JobListingRowBasic extends StatelessWidget {
  final Job job;
  final VoidCallback? onTap;
  final bool hideSamplePrefix;

  const JobListingRowBasic({
    super.key,
    required this.job,
    this.onTap,
    this.hideSamplePrefix = false,
  });

  @override
  Widget build(BuildContext context) {
    final role = job.listRoleLine;
    final title = hideSamplePrefix
        ? _stripSample(job.displayTitle)
        : job.displayTitle;
    final clinic = hideSamplePrefix
        ? _stripSample(job.displayClinicName)
        : job.displayClinicName;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: AppColors.appBg,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (job.jobLevel == 1 || job.jobLevel == 2) ...[
                    Text(
                      job.jobLevel == 1 ? '프리미엄' : '추천',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: clinic,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (role.isNotEmpty)
                          TextSpan(
                            text: '  $role',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 11,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          job.district.isNotEmpty ? job.district : job.address,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (job.canApplyNow)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: AppBadge(
                  label: '즉시지원',
                  bgColor: AppColors.accent.withValues(alpha: 0.12),
                  textColor: AppColors.accent,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
