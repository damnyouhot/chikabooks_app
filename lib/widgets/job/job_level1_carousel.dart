import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/job.dart';
import '../../screen/jobs/job_detail_screen.dart';

// ── 디자인 팔레트 ──
const _kText = Color(0xFF5D6B6B);
const _kAccent = Color(0xFFF7CBCA);
const _kShadow = Color(0xFFD5E5E5);
const _kBg = Color(0xFFF5F0F2);
const _kMatch = Color(0xFF4DB6AC);

/// Level 1 프리미엄 캐러셀
///
/// - 최대 9개 풀에서 3개씩 표시, 4초마다 1칸씩 순환 (맨 아래 카드 교체)
/// - [isCompact]: Sticky 2 고정 모드일 때 카드 높이를 줄임
/// - [highlightAnimation]: 미니바 탭 시 강조 애니메이션 트리거용
class JobLevel1Carousel extends StatefulWidget {
  final List<Job> jobs;
  final bool isCompact;

  // Sticky 고정 시 사용하는 대략적인 높이 (SliverPadding 계산용)
  static const double normalHeight = 408.0;
  static const double compactHeight = 300.0;

  const JobLevel1Carousel({
    super.key,
    required this.jobs,
    this.isCompact = false,
  });

  @override
  State<JobLevel1Carousel> createState() => JobLevel1CarouselState();
}

/// 외부에서 [GlobalKey<JobLevel1CarouselState>]로 접근 가능한 공개 State
class JobLevel1CarouselState extends State<JobLevel1Carousel> {
  int _startIndex = 0;
  Timer? _timer;
  bool _highlighted = false;

  @override
  void initState() {
    super.initState();
    if (widget.jobs.length > 3) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _advance());
  }

  void _advance() {
    if (!mounted || widget.jobs.isEmpty) return;
    setState(() {
      _startIndex = (_startIndex + 1) % widget.jobs.length;
    });
  }

  /// 미니바 탭 시 외부에서 호출 가능한 강조 애니메이션
  void triggerHighlight() {
    if (!mounted) return;
    setState(() => _highlighted = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _highlighted = false);
    });
  }

  List<Job> get _visibleJobs {
    final pool = widget.jobs;
    if (pool.isEmpty) return [];
    if (pool.length <= 3) return pool;
    return List.generate(
      3,
      (i) => pool[(_startIndex + i) % pool.length],
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobs = _visibleJobs;
    if (jobs.isEmpty) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: _highlighted
            ? _kAccent.withOpacity(0.08)
            : Colors.transparent,
        border: _highlighted
            ? Border.all(color: _kAccent.withOpacity(0.3), width: 1)
            : null,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 섹션 헤더 (compact 모드에서는 숨김) ──
          if (!widget.isCompact)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _kAccent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '추천 · 프리미엄',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kText.withOpacity(0.8),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '거리 가까운 순',
                    style: TextStyle(
                      fontSize: 11,
                      color: _kText.withOpacity(0.4),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),
                  // 롤링 인디케이터 도트
                  _RollingIndicator(
                    total: widget.jobs.length > 9 ? 9 : widget.jobs.length,
                    currentStart: _startIndex,
                  ),
                ],
              ),
            ),

          // ── 카드 3개 (AnimatedSwitcher로 부드러운 전환) ──
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 550),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeIn,
                ),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                  )),
                  child: child,
                ),
              );
            },
            child: Column(
              key: ValueKey(_startIndex),
              children: jobs
                  .map(
                    (job) => _Level1Card(
                      job: job,
                      compact: widget.isCompact,
                    ),
                  )
                  .toList(),
            ),
          ),

          // ── compact 모드 하단 여백 ──
          if (widget.isCompact) const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── 롤링 도트 인디케이터 ─────────────────────────────────────────
class _RollingIndicator extends StatelessWidget {
  final int total;
  final int currentStart;

  const _RollingIndicator({
    required this.total,
    required this.currentStart,
  });

  @override
  Widget build(BuildContext context) {
    if (total <= 3) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total > 9 ? 9 : total, (i) {
        final isActive = i == currentStart % total ||
            i == (currentStart + 1) % total ||
            i == (currentStart + 2) % total;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isActive ? 14 : 5,
          height: 5,
          margin: const EdgeInsets.only(left: 3),
          decoration: BoxDecoration(
            color: isActive
                ? _kAccent.withOpacity(0.8)
                : _kShadow.withOpacity(0.6),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ── Level 1 카드 ─────────────────────────────────────────────────
class _Level1Card extends StatelessWidget {
  final Job job;
  final bool compact;

  const _Level1Card({required this.job, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final imageWidth = compact ? 88.0 : 108.0;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JobDetailScreen(jobId: job.id),
        ),
      ),
      child: Container(
        margin: EdgeInsets.fromLTRB(16, 0, 16, compact ? 6 : 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kShadow, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 좌: 이미지 (4:3 고정 비율) ──
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(13),
                bottomLeft: Radius.circular(13),
              ),
              child: SizedBox(
                width: imageWidth,
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: job.images.isNotEmpty
                      ? Image.network(
                          job.images.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _ImagePlaceholder(),
                        )
                      : _ImagePlaceholder(),
                ),
              ),
            ),

            // ── 우: 텍스트 영역 ──
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  10,
                  compact ? 8 : 11,
                  10,
                  compact ? 8 : 11,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1줄: 병원명 + 배지
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            job.clinicName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _kText,
                              letterSpacing: -0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _PremiumBadge(),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // 2줄: 위치 + 거리 + 역세권
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 11,
                          color: _kText.withOpacity(0.38),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            job.district.isNotEmpty
                                ? job.district
                                : job.address,
                            style: TextStyle(
                              fontSize: 11,
                              color: _kText.withOpacity(0.5),
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (job.isNearStation) ...[
                          const SizedBox(width: 4),
                          _StationBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),

                    // 3줄: 직무/경력
                    Text(
                      '${job.type} · ${job.career}',
                      style: TextStyle(
                        fontSize: 11,
                        color: _kText.withOpacity(0.55),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 5),

                    // 4줄: 태그
                    if (!compact)
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: job.benefits
                            .take(3)
                            .map((b) => _BenefitChip(label: b))
                            .toList(),
                      ),
                    if (!compact) const SizedBox(height: 5),

                    // 5줄: 커리어 매칭 점수 (Level 1 전용)
                    Row(
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          size: 12,
                          color: _kMatch.withOpacity(0.75),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '내 커리어와 ${job.matchScore}% 일치',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _kMatch,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
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
  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBg,
      child: Icon(
        Icons.business_outlined,
        size: 26,
        color: _kText.withOpacity(0.18),
      ),
    );
  }
}

// ── 공통 배지 위젯 ───────────────────────────────────────────────
class _PremiumBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _kAccent.withOpacity(0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _kAccent.withOpacity(0.4)),
      ),
      child: Text(
        '프리미엄',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: _kText.withOpacity(0.7),
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

class _StationBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFF81C784).withOpacity(0.5),
        ),
      ),
      child: const Text(
        '역세권',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Color(0xFF43A047),
          letterSpacing: -0.1,
        ),
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
        color: _kBg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _kShadow, width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: _kText.withOpacity(0.6),
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
