import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_muted_card.dart';
import '../../models/job.dart';
import '../../screen/jobs/job_detail_screen.dart';

/// Level 1 프리미엄 캐러셀 (수평 PageView)
///
/// - 4초마다 자동으로 다음 공고로 슬라이드
/// - 유저가 직접 좌우 스와이프로도 이동 가능
/// - 스와이프 시 자동 타이머 리셋
///
/// [stickyHeight]: SliverPersistentHeader 에서 사용하는 고정 높이
class JobLevel1Carousel extends StatefulWidget {
  final List<Job> jobs;

  /// 섹션헤더(40) + PageView카드(96) + 하단여백(8) = 144px
  static const double stickyHeight = 144.0;

  const JobLevel1Carousel({
    super.key,
    required this.jobs,
  });

  @override
  State<JobLevel1Carousel> createState() => JobLevel1CarouselState();
}

/// 외부에서 [GlobalKey<JobLevel1CarouselState>]로 접근 가능한 공개 State
class JobLevel1CarouselState extends State<JobLevel1Carousel> {
  late final PageController _pageCtrl;
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    if (widget.jobs.length > 1) _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _advance());
  }

  // 타이머 리셋 (스와이프 후 호출)
  void _resetTimer() {
    _timer?.cancel();
    if (widget.jobs.length > 1) _startTimer();
  }

  void _advance() {
    if (!mounted || widget.jobs.isEmpty) return;
    final next = (_currentPage + 1) % widget.jobs.length;
    _pageCtrl.animateToPage(
      next,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  /// 외부(지도 화면 등)에서 GlobalKey로 특정 페이지로 이동
  void scrollToPage(int index) {
    if (!mounted || !_pageCtrl.hasClients) return;
    _pageCtrl.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.jobs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      children: [
        // ── 섹션 헤더 ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '추천 · 프리미엄',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              // 페이지 인디케이터 (현재/전체)
              if (widget.jobs.length > 1)
                Text(
                  '${_currentPage + 1} / ${widget.jobs.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textDisabled,
                    letterSpacing: -0.2,
                  ),
                ),
            ],
          ),
        ),

        // ── 수평 PageView (스와이프 + 자동 슬라이드) ─────────────
        SizedBox(
          height: 96,
          child: PageView.builder(
            controller: _pageCtrl,
            onPageChanged: (i) {
              setState(() => _currentPage = i);
              _resetTimer(); // 스와이프 시 타이머 리셋
            },
            itemCount: widget.jobs.length,
            itemBuilder: (_, i) => _Level1Card(job: widget.jobs[i]),
          ),
        ),

        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Level 1 카드 ─────────────────────────────────────────────────
class _Level1Card extends StatelessWidget {
  final Job job;

  const _Level1Card({required this.job});

  @override
  Widget build(BuildContext context) {
    const imageWidth = 108.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: AppMutedCard(
        padding: EdgeInsets.zero,
        radius: AppRadius.lg,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => JobDetailScreen(jobId: job.id),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 좌: 이미지 (4:3 고정 비율) ──
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                bottomLeft: Radius.circular(AppRadius.lg),
              ),
              child: SizedBox(
                width: imageWidth,
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: job.images.isNotEmpty
                      ? Image.network(
                          job.images.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const _ImagePlaceholder(),
                        )
                      : const _ImagePlaceholder(),
                ),
              ),
            ),

            // ── 우: 텍스트 영역 ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 11, 10, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1줄: 병원명 + 위치 + 매칭 점수 (우측)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: job.clinicName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                if (job.district.isNotEmpty)
                                  TextSpan(
                                    text: '  ${job.district}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                      color: AppColors.textDisabled,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // 매칭 점수 (우측 정렬)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              size: 11,
                              color: AppColors.success.withValues(alpha: 0.75),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '매칭 ${job.matchScore}%',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // 2줄: 직무 · 고용 · 경력
                    Text(
                      job.listRoleLine.isEmpty ? '—' : job.listRoleLine,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 5),

                    // 3줄: 복지 태그
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: job.benefits
                          .take(3)
                          .map((b) => _BenefitChip(label: b))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 이미지 플레이스홀더 ──────────────────────────────────────────
class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surfaceMuted,
      child: Icon(
        Icons.business_outlined,
        size: 26,
        color: AppColors.textDisabled,
      ),
    );
  }
}

class _BenefitChip extends StatelessWidget {
  final String label;

  const _BenefitChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.textSecondary,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
