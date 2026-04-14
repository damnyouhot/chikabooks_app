import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_muted_card.dart';
import '../../models/job.dart';
import '../../screen/jobs/job_detail_screen.dart';
import 'job_cover_image.dart';

/// Level 1 프리미엄 캐러셀 (수평 PageView — 무한루프, 항상 정방향)
///
/// - 4초마다 자동으로 다음 공고로 슬라이드 (항상 좌→우 방향)
/// - 마지막 공고 다음에 첫 번째로 자연스럽게 연결됨 (역주행 없음)
/// - 유저가 직접 좌우 스와이프로도 이동 가능
///
/// [stickyHeight]: Stack 오버레이로 사용할 고정 높이
class JobLevel1Carousel extends StatefulWidget {
  final List<Job> jobs;

  /// 지도 화면 등: 카드 탭 시 [JobDetailScreen]만 열지 않고 카메라 이동 등을 함께 처리할 때 사용.
  /// null이면 기본 동작(상세 화면 푸시만).
  final void Function(BuildContext context, Job job)? onJobTap;

  /// 섹션헤더(40) + PageView카드(116) + 하단여백(8) = 164px
  static const double stickyHeight = 164.0;

  /// 무한루프의 가상 시작 인덱스 — 충분히 큰 배수로 잡아 앞뒤로 자유롭게 스와이프 가능
  static const int _loopOffset = 10000;

  const JobLevel1Carousel({
    super.key,
    required this.jobs,
    this.onJobTap,
  });

  @override
  State<JobLevel1Carousel> createState() => JobLevel1CarouselState();
}

/// 외부에서 [GlobalKey<JobLevel1CarouselState>]로 접근 가능한 공개 State
class JobLevel1CarouselState extends State<JobLevel1Carousel> {
  late PageController _pageCtrl;
  Timer? _timer;
  int _virtualPage = JobLevel1Carousel._loopOffset; // 현재 가상 인덱스

  int get _realIndex {
    if (widget.jobs.isEmpty) return 0;
    return _virtualPage % widget.jobs.length;
  }

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(initialPage: _virtualPage);
    if (widget.jobs.length > 1) _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _advance());
  }

  void _resetTimer() {
    if (widget.jobs.length > 1) _startTimer();
  }

  /// 항상 +1 방향으로 이동 → 역주행 없음
  void _advance() {
    if (!mounted || widget.jobs.isEmpty || !_pageCtrl.hasClients) return;
    _pageCtrl.animateToPage(
      _virtualPage + 1,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  /// 외부(지도 화면 등)에서 GlobalKey로 특정 실제 인덱스로 이동
  void scrollToPage(int realIndex) {
    if (!mounted || !_pageCtrl.hasClients || widget.jobs.isEmpty) return;
    // 현재 가상 페이지 기준으로 가장 가까운 방향으로 이동
    final currentReal = _virtualPage % widget.jobs.length;
    int diff = realIndex - currentReal;
    if (diff < 0) diff += widget.jobs.length;
    _pageCtrl.animateToPage(
      _virtualPage + diff,
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
              // 페이지 인디케이터 (실제 번호)
              if (widget.jobs.length > 1)
                Text(
                  '${_realIndex + 1} / ${widget.jobs.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textDisabled,
                    letterSpacing: -0.2,
                  ),
                ),
            ],
          ),
        ),

        // ── 수평 PageView (무한 itemCount → 역주행 없음) ─────────────
        SizedBox(
          height: 116,
          child: PageView.builder(
            controller: _pageCtrl,
            onPageChanged: (i) {
              setState(() => _virtualPage = i);
              _resetTimer();
            },
            itemBuilder: (_, i) {
              final job = widget.jobs[i % widget.jobs.length];
              return _Level1Card(
                job: job,
                onJobTap: widget.onJobTap,
              );
            },
            // itemCount 미지정 → 무한 스크롤
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
  final void Function(BuildContext context, Job job)? onJobTap;

  const _Level1Card({
    required this.job,
    this.onJobTap,
  });

  void _handleTap(BuildContext context) {
    final custom = onJobTap;
    if (custom != null) {
      custom(context, job);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JobDetailScreen(jobId: job.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const imageWidth = 108.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: AppMutedCard(
        padding: EdgeInsets.zero,
        radius: AppRadius.lg,
        onTap: () => _handleTap(context),
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
                      ? JobCoverImage(
                          source: job.images.first,
                          fit: BoxFit.cover,
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
                    // 1줄: 공고 제목 + 매칭 점수 (우측 정렬)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            job.displayTitle,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              size: 11,
                              color: AppColors.prepBadgeGreen,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '매칭 ${job.matchScore}%',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.prepBadgeGreen,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // 2줄: 치과이름, 위치 (검은색)
                    Text(
                      job.district.isNotEmpty
                          ? '${job.displayClinicName}  ${job.district}'
                          : job.displayClinicName,
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

                    // 3줄: 직무 · 고용형태 · 경력 (검은색)
                    Text(
                      job.listRoleLine.isEmpty ? '—' : job.listRoleLine,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),

                    // 4줄: 해시태그 (accent 배경 칩)
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: (job.tags.isNotEmpty ? job.tags : job.benefits)
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
        color: AppColors.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.accent,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
