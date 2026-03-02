import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../data/mock_jobs.dart';
import '../../models/job.dart';
import '../../notifiers/job_filter_notifier.dart';
import '../../services/career_profile_service.dart';
import '../../services/job_match_service.dart';
import '../../services/job_service.dart';
import '../../widgets/job/job_search_bar.dart';
import '../../widgets/job/job_level1_carousel.dart';
import '../../widgets/job/filter_bottom_sheet.dart';
import '../jobs/job_detail_screen.dart';

// ── 디자인 팔레트 ──
const _kText = Color(0xFF5D6B6B);
const _kAccent = Color(0xFFF7CBCA);
const _kShadow = Color(0xFFD5E5E5);
const _kBg = Color(0xFFF5F0F2);

/// 공고보기 소탭 - 목록 모드
///
/// ## Sliver 구조
/// - Sticky 1 (항상 고정): 검색 바 + 커리어 요약 + 필터
/// - Level 1 (일반 스크롤): 프리미엄 캐러셀 (자동 롤링, 4초 주기)
/// - Level 2 (일반 스크롤): 추천 2열 바둑판
/// - Level 3 (일반 스크롤): 게시판형 리스트 + 12개마다 미니바
///
/// ## Sticky 2 동작
/// Level 3 헤더가 검색 바 아래에 닿는 순간 Level 1 캐러셀이
/// Stack 오버레이로 고정(Sticky 2)되고, Level 3 리스트 상단에
/// 동일한 높이의 패딩이 추가되어 콘텐츠가 가려지지 않음.
class JobListingsScreen extends StatefulWidget {
  final LatLng? userLocation;
  final VoidCallback onMapToggle;

  const JobListingsScreen({
    super.key,
    this.userLocation,
    required this.onMapToggle,
  });

  @override
  State<JobListingsScreen> createState() => _JobListingsScreenState();
}

class _JobListingsScreenState extends State<JobListingsScreen> {
  final _scrollController = ScrollController();

  // Sticky 2 상태
  final _level3Key = GlobalKey();
  bool _showStickyCarousel = false;
  double _level3Threshold = double.infinity;
  bool _thresholdReady = false;

  // Sticky 2 캐러셀 강조 트리거용 GlobalKey
  final _stickyCarouselKey = GlobalKey<JobLevel1CarouselState>();

  // 검색
  String _searchQuery = '';

  // ── 커리어 프로파일 (Stage 5) ────────────────────────────────────
  String _careerSummary = '';
  Map<String, dynamic>? _careerProfile;
  int _totalCareerMonths = 0;
  StreamSubscription<Map<String, dynamic>?>? _careerSub;

  // ── Level 3 페이지네이션 상태 ────────────────────────────────────
  List<Job> _level3Jobs = [];
  bool _level3Loading = false;
  bool _level3HasMore = true;
  DocumentSnapshot? _level3LastDoc;
  bool _useMockData = false;

  // 필터 변경 감지용
  JobFilterNotifier? _filterNotifier;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measureThreshold();
      // 필터 리스너 등록 + 초기 로드
      _filterNotifier = context.read<JobFilterNotifier>();
      _filterNotifier!.addListener(_onFilterChanged);
      _loadLevel3(reset: true);
      // 커리어 프로파일 구독
      _careerSub = CareerProfileService.watchMyCareerProfile().listen(
        (profile) {
          if (!mounted) return;
          final months = JobMatchService.extractTotalCareerMonths(profile);
          setState(() {
            _careerProfile = profile;
            _totalCareerMonths = months;
            _careerSummary = JobMatchService.buildCareerSummary(
              profile: profile,
              totalCareerMonths: months,
            );
          });
        },
      );
    });
  }

  @override
  void dispose() {
    _careerSub?.cancel();
    _filterNotifier?.removeListener(_onFilterChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onFilterChanged() => _loadLevel3(reset: true);

  // Level 3 헤더의 스크롤 임계값 계산
  void _measureThreshold() {
    final ctx = _level3Key.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;

    // viewport 기준 현재 Y 위치 → 스크롤 content 좌표 변환
    final viewportY = box.localToGlobal(Offset.zero).dy;
    final contentY = viewportY + _scrollController.offset;

    // Level 3 헤더 상단이 Sticky 1 아래(76px)에 닿는 스크롤 offset
    _level3Threshold = contentY - JobSearchBarDelegate.height;
    _thresholdReady = true;
  }

  void _onScroll() {
    if (!_thresholdReady) {
      _measureThreshold();
    } else {
      final shouldStick = _scrollController.offset >= _level3Threshold;
      if (shouldStick != _showStickyCarousel) {
        setState(() => _showStickyCarousel = shouldStick);
      }
    }

    // 무한 스크롤: 하단 400px 이내 진입 시 다음 페이지 로드
    if (!_level3Loading && _level3HasMore && !_useMockData) {
      final pos = _scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - 400) {
        _loadLevel3();
      }
    }
  }

  // ── Level 3 페이지 로드 ────────────────────────────────────────
  Future<void> _loadLevel3({bool reset = false}) async {
    if (_level3Loading) return;
    if (!reset && !_level3HasMore) return;

    if (reset) {
      setState(() {
        _level3Jobs = [];
        _level3LastDoc = null;
        _level3HasMore = true;
        _useMockData = false;
      });
    }

    setState(() => _level3Loading = true);

    try {
      final svc = context.read<JobService>();
      final result = await svc.fetchJobsPaged(
        pageSize: 15,
        startAfter: _level3LastDoc,
      );

      if (!mounted) return;

      if (result.jobs.isEmpty && _level3Jobs.isEmpty) {
        // Firestore 비어있으면 Mock 데이터로 폴백
        setState(() {
          _level3Jobs = generateMockLevel3Jobs(count: 30);
          _level3HasMore = false;
          _useMockData = true;
          _level3Loading = false;
        });
      } else {
        setState(() {
          _level3Jobs.addAll(result.jobs);
          _level3LastDoc = result.lastDoc;
          _level3HasMore = result.hasMore;
          _level3Loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      if (_level3Jobs.isEmpty) {
        setState(() {
          _level3Jobs = generateMockLevel3Jobs(count: 30);
          _level3HasMore = false;
          _useMockData = true;
          _level3Loading = false;
        });
      } else {
        setState(() => _level3Loading = false);
      }
    }
  }

  int _activeFilterCount(JobFilterNotifier f) => f.activeCount;

  @override
  Widget build(BuildContext context) {
    final jobFilter = context.watch<JobFilterNotifier>();

    // Level 2 dedup: Level 1에 이미 노출된 공고 제외
    final level1Ids = mockLevel1Jobs.map((j) => j.id).toSet();
    final deduped2 =
        mockLevel2Jobs.where((j) => !level1Ids.contains(j.id)).toList();

    return Stack(
      children: [
        // ── 메인 스크롤 뷰 ─────────────────────────────────────
        CustomScrollView(
          controller: _scrollController,
          slivers: [
            // ── Sticky 1: 검색 바 (항상 고정) ──────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: JobSearchBarDelegate(
                searchQuery: _searchQuery,
                careerSummary: _careerSummary,
                activeFilterCount: _activeFilterCount(jobFilter),
                onSearchChanged: (q) => setState(() => _searchQuery = q),
                onFilterPressed: () =>
                    FilterBottomSheet.show(context, jobFilter),
                onMapToggle: widget.onMapToggle,
              ),
            ),

            // ── Level 1: 프리미엄 캐러셀 (일반 스크롤) ─────────
            SliverToBoxAdapter(
              child: JobLevel1Carousel(jobs: mockLevel1Jobs),
            ),

            // ── Level 2: 추천 2열 그리드 (Level 1 중복 제거) ───
            SliverToBoxAdapter(
              child: _Level2Section(jobs: deduped2),
            ),

            // ── Level 3 헤더 (GlobalKey 부착) ───────────────────
            SliverToBoxAdapter(
              child: _Level3Header(sectionKey: _level3Key),
            ),

            // ── Level 3 리스트
            // _showStickyCarousel 시 compactHeight만큼 상단 패딩 추가
            SliverPadding(
              padding: EdgeInsets.only(
                top: _showStickyCarousel
                    ? JobLevel1Carousel.compactHeight
                    : 0,
              ),
              sliver: _buildLevel3Sliver(jobFilter),
            ),

            // 로딩 인디케이터 (다음 페이지 로드 중)
            if (_level3Loading && _level3Jobs.isNotEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
          ],
        ),

        // ── Sticky 2: Level 1 캐러셀 오버레이 (Level 3 진입 시) ─
        if (_showStickyCarousel)
          Positioned(
            top: JobSearchBarDelegate.height,
            left: 0,
            right: 0,
            child: Material(
              elevation: 3,
              shadowColor: Colors.black.withOpacity(0.1),
              color: Colors.white,
              child: JobLevel1Carousel(
                key: _stickyCarouselKey,
                jobs: mockLevel1Jobs,
                isCompact: true,
              ),
            ),
          ),
      ],
    );
  }

  // ── Level 3 리스트 Sliver (상태 기반) ───────────────────────────
  Widget _buildLevel3Sliver(JobFilterNotifier jobFilter) {
    // 초기 로딩 (첫 페이지 로드 중)
    if (_level3Loading && _level3Jobs.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // 클라이언트 필터 적용
    List<Job> jobs = List.of(_level3Jobs);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      jobs = jobs.where((j) {
        return j.clinicName.toLowerCase().contains(q) ||
            j.address.toLowerCase().contains(q) ||
            j.district.toLowerCase().contains(q);
      }).toList();
    }

    if (jobFilter.positionFilter != '전체') {
      jobs = jobs.where((j) => j.type == jobFilter.positionFilter).toList();
    }

    // 근무형태 필터
    if (jobFilter.employmentType != '전체') {
      jobs = jobs
          .where((j) => j.type.contains(jobFilter.employmentType))
          .toList();
    }

    // 정렬
    switch (jobFilter.sortBy) {
      case '매칭높은순':
        jobs.sort((a, b) {
          final sa = JobMatchService.computeScore(
            job: a,
            profile: _careerProfile,
            totalCareerMonths: _totalCareerMonths,
          );
          final sb = JobMatchService.computeScore(
            job: b,
            profile: _careerProfile,
            totalCareerMonths: _totalCareerMonths,
          );
          return sb.compareTo(sa);
        });
      case '마감임박순':
        jobs.sort((a, b) {
          if (a.closingDate == null) return 1;
          if (b.closingDate == null) return -1;
          return a.closingDate!.compareTo(b.closingDate!);
        });
      case '급여높은순':
        jobs.sort(
          (a, b) => b.salaryRange.last.compareTo(a.salaryRange.last),
        );
      case '거리순':
        if (widget.userLocation != null) {
          final svc = context.read<JobService>();
          jobs.sort((a, b) {
            final da = svc.calculateDistance(
              widget.userLocation!,
              LatLng(a.lat, a.lng),
            );
            final db = svc.calculateDistance(
              widget.userLocation!,
              LatLng(b.lat, b.lng),
            );
            return da.compareTo(db);
          });
        }
      default: // 최신순
        jobs.sort((a, b) => b.postedAt.compareTo(a.postedAt));
    }

    if (jobs.isEmpty) {
      return const SliverToBoxAdapter(child: _Level3EmptyState());
    }

    return SliverToBoxAdapter(
      child: Column(
        children: [
          for (int i = 0; i < jobs.length; i++) ...[
            _Level3Row(
              job: jobs[i],
              onTap: () => _navigateToDetail(jobs[i]),
            ),
            if (i < jobs.length - 1)
              Divider(
                height: 0.5,
                thickness: 0.5,
                indent: 16,
                endIndent: 16,
                color: _kShadow.withOpacity(0.5),
              ),
            // 12개마다 미니바 삽입
            if ((i + 1) % 12 == 0 && i < jobs.length - 1)
              _MiniBar(
                onTap: () {
                  _scrollController.animateTo(
                    _level3Threshold,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                  );
                  // Sticky 캐러셀 강조 애니메이션
                  Future.delayed(const Duration(milliseconds: 420), () {
                    _stickyCarouselKey.currentState?.triggerHighlight();
                  });
                },
              ),
          ],
        ],
      ),
    );
  }

  void _navigateToDetail(Job job) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: job.id)),
    );
  }
}

// ── Level 2: 추천 바둑판 ──────────────────────────────────────────
class _Level2Section extends StatelessWidget {
  final List<Job> jobs;

  const _Level2Section({required this.jobs});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 섹션 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF90CAF9),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '추천 공고',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kText.withOpacity(0.8),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '커리어 카드 기반',
                  style: TextStyle(
                    fontSize: 11,
                    color: _kText.withOpacity(0.4),
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),

          // 2열 그리드
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.88,
              ),
              itemCount: jobs.length,
              itemBuilder: (_, i) => _Level2Card(job: jobs[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Level2Card extends StatelessWidget {
  final Job job;

  const _Level2Card({required this.job});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JobDetailScreen(jobId: job.id),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kShadow, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: 이미지 (4:3 비율)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: job.images.isNotEmpty
                    ? Image.network(job.images.first, fit: BoxFit.cover)
                    : Container(
                        color: _kBg,
                        child: Stack(
                          children: [
                            Center(
                              child: Icon(
                                Icons.business_outlined,
                                size: 22,
                                color: _kText.withOpacity(0.15),
                              ),
                            ),
                            Positioned(
                              top: 6,
                              left: 6,
                              child: _RecommendBadge(),
                            ),
                          ],
                        ),
                      ),
              ),
            ),

            // 하단: 텍스트
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.clinicName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _kText,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_shortDistrict(job)} · ${job.type} · ${job.career}',
                      style: TextStyle(
                        fontSize: 10,
                        color: _kText.withOpacity(0.5),
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 3,
                      children: job.benefits
                          .take(2)
                          .map((b) => _SmallChip(label: b))
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

  String _shortDistrict(Job job) {
    if (job.district.isNotEmpty) {
      return job.district.split(' · ').first;
    }
    final parts = job.address.split(' ');
    return parts.length >= 2 ? parts.take(2).join(' ') : job.address;
  }
}

// ── Level 3 헤더 ──────────────────────────────────────────────────
class _Level3Header extends StatelessWidget {
  final GlobalKey? sectionKey;

  const _Level3Header({this.sectionKey});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: sectionKey,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: _kShadow.withOpacity(0.5), width: 0.5),
          bottom: BorderSide(color: _kShadow.withOpacity(0.5), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: _kShadow,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '전체 공고',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kText.withOpacity(0.8),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '최신 등록 순',
            style: TextStyle(
              fontSize: 11,
              color: _kText.withOpacity(0.4),
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Level 3 행 (게시판형) ──────────────────────────────────────────
class _Level3Row extends StatelessWidget {
  final Job job;
  final VoidCallback onTap;

  const _Level3Row({required this.job, required this.onTap});

  String get _dDayText {
    if (job.closingDate == null) return '상시';
    final diff = job.closingDate!.difference(DateTime.now()).inDays;
    if (diff < 0) return '마감';
    if (diff == 0) return 'D-day';
    return 'D-$diff';
  }

  bool get _isUrgent {
    final t = _dDayText;
    return t == 'D-day' || t == 'D-1' || t == 'D-2';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 좌: 제목 + 병원명 + 직무 + 위치
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 프리미엄/추천 라벨 (Level 1·2 공고가 Level 3에도 노출될 때)
                  if (job.jobLevel == 1 || job.jobLevel == 2) ...[
                    Text(
                      job.jobLevel == 1 ? '프리미엄' : '추천',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: job.jobLevel == 1
                            ? const Color(0xFFF48FB1)
                            : const Color(0xFF90CAF9),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    job.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kText,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    job.clinicName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _kText.withOpacity(0.65),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${job.type} · ${job.career}',
                    style: TextStyle(
                      fontSize: 11,
                      color: _kText.withOpacity(0.45),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  // 위치 + 역세권
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 11,
                        color: _kText.withOpacity(0.32),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        job.district.isNotEmpty
                            ? job.district
                            : job.address,
                        style: TextStyle(
                          fontSize: 10,
                          color: _kText.withOpacity(0.4),
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (job.isNearStation) ...[
                        const SizedBox(width: 5),
                        _StationChip(),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // 우: D-day + 즉시지원
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _dDayText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _isUrgent
                        ? const Color(0xFFE57373)
                        : _kText.withOpacity(0.42),
                    letterSpacing: -0.2,
                  ),
                ),
                if (job.canApplyNow) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _kAccent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(6),
                      border:
                          Border.all(color: _kAccent.withOpacity(0.45)),
                    ),
                    child: Text(
                      '즉시지원',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _kText.withOpacity(0.7),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── 미니바 ──────────────────────────────────────────────────────────
class _MiniBar extends StatelessWidget {
  final VoidCallback onTap;

  const _MiniBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      color: _kAccent.withOpacity(0.07),
      child: Row(
        children: [
          Icon(
            Icons.stars_rounded,
            size: 15,
            color: _kAccent.withOpacity(0.9),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '추천 공고 더 보기',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _kText.withOpacity(0.7),
                letterSpacing: -0.2,
              ),
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _kAccent.withOpacity(0.22),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '확인하기',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _kText.withOpacity(0.75),
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 공통 소형 위젯 ────────────────────────────────────────────────
class _RecommendBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF90CAF9).withOpacity(0.25),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: const Color(0xFF90CAF9).withOpacity(0.5),
        ),
      ),
      child: Text(
        '추천',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: _kText.withOpacity(0.65),
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

class _StationChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
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

class _SmallChip extends StatelessWidget {
  final String label;

  const _SmallChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _kShadow, width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: _kText.withOpacity(0.55),
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

// ── 빈 상태 / 오류 상태 ──────────────────────────────────────────
class _Level3EmptyState extends StatelessWidget {
  const _Level3EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 44,
            color: _kText.withOpacity(0.22),
          ),
          const SizedBox(height: 14),
          Text(
            '조건에 맞는 공고가 없어요.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _kText.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '검색어나 필터를 조정해보세요.',
            style: TextStyle(
              fontSize: 12,
              color: _kText.withOpacity(0.35),
            ),
          ),
        ],
      ),
    );
  }
}

