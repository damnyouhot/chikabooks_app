import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_badge.dart';
import '../../data/mock_jobs.dart';
import '../../models/job.dart';
import '../../notifiers/job_filter_notifier.dart';
import '../../services/career_profile_service.dart';
import '../../services/job_match_service.dart';
import '../../services/job_service.dart';
import '../../widgets/job/job_level1_carousel.dart';
import '../../widgets/job/filter_bottom_sheet.dart';
import '../jobs/job_detail_screen.dart';
import '../../widgets/job/job_cover_image.dart';

/// 채용 소탭 - 목록 모드
///
/// ## Sliver 구조
/// - 타이틀 섹션 (일반 스크롤, 스크롤 시 사라짐): 커리어 제목 + 인포/설정 + 커리어 요약
/// - Level 1 A클래스 (SliverAppBar pinned): 프리미엄 PageView 캐러셀 (항상 상단 고정)
/// - Level 2 B클래스 (일반 스크롤): 추천 2열 바둑판
/// - Level 3 B클래스 (일반 스크롤): 게시판형 리스트 + 12개마다 미니바
/// - 하단 검색 바 (Positioned): 필터 + 지도 버튼 포함
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

  // 검색
  String _searchQuery = '';

  // ── 커리어 프로파일 ───────────────────────────────────────────
  String _careerSummary = '';
  Map<String, dynamic>? _careerProfile;
  int _totalCareerMonths = 0;
  StreamSubscription<Map<String, dynamic>?>? _careerSub;

  // ── Level 3 페이지네이션 상태 ────────────────────────────────
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

  void _onScroll() {
    // 무한 스크롤: 하단 400px 이내 진입 시 다음 페이지 로드
    if (!_level3Loading && _level3HasMore && !_useMockData) {
      final pos = _scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - 400) {
        _loadLevel3();
      }
    }
  }

  // ── Level 3 페이지 로드 ──────────────────────────────────────
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
    final safeBottom = MediaQuery.of(context).padding.bottom;

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
            // ── 커리어 요약 (스크롤로 사라짐) ──────────────────
            SliverToBoxAdapter(
              child: _CareerSummarySection(careerSummary: _careerSummary),
            ),

            // ── Level 1 A클래스: 소탭 바로 아래 항상 고정 ──────
            SliverAppBar(
              pinned: true,
              automaticallyImplyLeading: false,
              backgroundColor: AppColors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 2,
              toolbarHeight: 0,
              collapsedHeight: JobLevel1Carousel.stickyHeight,
              expandedHeight: JobLevel1Carousel.stickyHeight,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.none,
                background: JobLevel1Carousel(jobs: mockLevel1Jobs),
              ),
            ),

            // ── Level 2: 추천 2열 그리드 ────────────────────────
            SliverToBoxAdapter(
              child: _Level2Section(jobs: deduped2),
            ),

            // ── Level 3 헤더 ─────────────────────────────────────
            const SliverToBoxAdapter(
              child: _Level3Header(),
            ),

            // ── Level 3 리스트 ───────────────────────────────────
            _buildLevel3Sliver(jobFilter),

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

            // 하단 여백 (검색 바 + safe area)
            SliverPadding(
              padding: EdgeInsets.only(bottom: 92 + safeBottom),
            ),
          ],
        ),

        // ── 하단 검색 바 (Positioned) ──────────────────────────
        _BottomSearchBar(
          searchQuery: _searchQuery,
          activeFilterCount: _activeFilterCount(jobFilter),
          onSearchChanged: (q) {
            setState(() => _searchQuery = q);
            context.read<JobFilterNotifier>().setSearchQuery(q);
          },
          onFilterPressed: () => FilterBottomSheet.show(context, jobFilter),
          onMapToggle: widget.onMapToggle,
        ),
      ],
    );
  }

  // ── Level 3 리스트 Sliver ────────────────────────────────────
  Widget _buildLevel3Sliver(JobFilterNotifier jobFilter) {
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

    if (jobFilter.employmentType != '전체') {
      final want = jobFilter.employmentType;
      jobs = jobs.where((j) {
        final et = j.employmentType.trim();
        if (et.isNotEmpty) {
          return et.contains(want) || want.contains(et);
        }
        return j.type.contains(want);
      }).toList();
    }

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
          final userLat = widget.userLocation!.latitude;
          final userLng = widget.userLocation!.longitude;
          jobs.sort((a, b) {
            final da = Geolocator.distanceBetween(
              userLat,
              userLng,
              a.lat,
              a.lng,
            );
            final db = Geolocator.distanceBetween(
              userLat,
              userLng,
              b.lat,
              b.lng,
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
              const Divider(
                height: 0.5,
                thickness: 0.5,
                indent: 16,
                endIndent: 16,
                color: AppColors.divider,
              ),
            // 12개마다 미니바 삽입 (A클래스 확인하기 → 맨 위로 스크롤)
            if ((i + 1) % 12 == 0 && i < jobs.length - 1)
              _MiniBar(
                onTap: () {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                  );
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

// ── 커리어 요약 섹션 (스크롤로 사라짐, 타이틀은 job_page 공통 헤더에서 표시) ──
class _CareerSummarySection extends StatelessWidget {
  final String careerSummary;

  const _CareerSummarySection({required this.careerSummary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 16, top: 2, bottom: 6),
      child: careerSummary.isNotEmpty
          ? Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  size: 12,
                  color: AppColors.textDisabled,
                ),
                const SizedBox(width: 4),
                Text(
                  careerSummary,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            )
          : const Text(
              '커리어 카드를 등록하면 맞춤 공고를 추천해드려요',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textDisabled,
                letterSpacing: -0.2,
              ),
            ),
    );
  }
}


// ── 하단 검색 바 (Positioned) ────────────────────────────────────
class _BottomSearchBar extends StatefulWidget {
  final String searchQuery;
  final int activeFilterCount;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilterPressed;
  final VoidCallback onMapToggle;

  const _BottomSearchBar({
    required this.searchQuery,
    required this.activeFilterCount,
    required this.onSearchChanged,
    required this.onFilterPressed,
    required this.onMapToggle,
  });

  @override
  State<_BottomSearchBar> createState() => _BottomSearchBarState();
}

class _BottomSearchBarState extends State<_BottomSearchBar> {
  late final TextEditingController _ctrl;
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.searchQuery);
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void didUpdateWidget(covariant _BottomSearchBar old) {
    super.didUpdateWidget(old);
    if (old.searchQuery != widget.searchQuery &&
        _ctrl.text != widget.searchQuery) {
      _ctrl.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardH = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final bottom = keyboardH > 0
        ? keyboardH + AppSpacing.sm
        : AppSpacing.md + safeBottom;

    return Positioned(
      left: AppSpacing.md,
      right: AppSpacing.md,
      bottom: bottom,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.search,
                color: AppColors.textDisabled,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focusNode,
                  onChanged: widget.onSearchChanged,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: '치과명, 동네로 검색',
                    hintStyle: TextStyle(
                      fontSize: 15,
                      color: AppColors.textDisabled,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (_focused)
                GestureDetector(
                  onTap: () {
                    _focusNode.unfocus();
                    _ctrl.clear();
                    widget.onSearchChanged('');
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '취소',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
              else ...[
                _FilterChipButton(
                  count: widget.activeFilterCount,
                  onTap: widget.onFilterPressed,
                ),
                const SizedBox(width: 8),
                _MapToggleChip(onTap: widget.onMapToggle),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── 필터 칩 (지도 버튼과 동일 accent + '필터' 라벨, 적용 개수 뱃지) ───
class _FilterChipButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _FilterChipButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: AppColors.onAccent,
                ),
                SizedBox(width: 4),
                Text(
                  '필터',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onAccent,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (count > 0)
          Positioned(
            right: -2,
            top: -5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.appBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.accent, width: 1.2),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

// ── 지도 전환 칩 ──────────────────────────────────────────────────
class _MapToggleChip extends StatelessWidget {
  final VoidCallback onTap;

  const _MapToggleChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 18,
              color: AppColors.onAccent,
            ),
            SizedBox(width: 4),
            Text(
              '지도',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.onAccent,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
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
      color: AppColors.white,
      margin: const EdgeInsets.only(top: AppSpacing.lg + 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Center(
              child: Text(
                '채용 서비스 곧 정식 오픈 예정입니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                  letterSpacing: -0.2,
                  height: 1.35,
                ),
              ),
            ),
          ),
          // 섹션 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.sm + 2,
            ),
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
                const SizedBox(width: AppSpacing.sm),
                const Text(
                  '추천 공고',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  '커리어 카드 기반',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textDisabled,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),

          // 2열 그리드
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 206,
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
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: 이미지
            SizedBox(
              height: 118,
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppRadius.md),
                ),
                child: job.images.isNotEmpty
                    ? JobCoverImage(
                        source: job.images.first,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      )
                    : Container(
                        color: AppColors.surfaceMuted,
                        width: double.infinity,
                        child: Stack(
                          children: [
                            const Center(
                              child: Icon(
                                Icons.business_outlined,
                                size: 22,
                                color: AppColors.textDisabled,
                              ),
                            ),
                            Positioned(
                              top: 6,
                              left: 6,
                              child: AppBadge(
                                label: '추천',
                                bgColor:
                                    AppColors.accent.withValues(alpha: 0.12),
                                textColor: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            // 하단: 텍스트
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.displayClinicName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _districtAndRoles(job),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textDisabled,
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 3,
                    runSpacing: 0,
                    children: (job.tags.isNotEmpty ? job.tags : job.benefits)
                        .take(2)
                        .map((b) => _SmallChip(label: b))
                        .toList(),
                  ),
                ],
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

  String _districtAndRoles(Job job) {
    final d = _shortDistrict(job);
    final r = job.listRoleLine;
    if (d.isEmpty) return r.isEmpty ? '—' : r;
    if (r.isEmpty) return d;
    return '$d · $r';
  }
}

// ── Level 3 헤더 ──────────────────────────────────────────────────
class _Level3Header extends StatelessWidget {
  const _Level3Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.lg),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      color: AppColors.white,
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Text(
            '전체 공고',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            '최신 등록 순',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textDisabled,
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
    if (job.isAlwaysHiring) return '상시채용';
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
        color: AppColors.white,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 좌: 제목 + 병원명 + 직무 + 위치
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
                    job.displayTitle,
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
                    job.displayClinicName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    job.listRoleLine,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textDisabled,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 11,
                        color: AppColors.textDisabled,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        job.district.isNotEmpty
                            ? job.district
                            : job.address,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textDisabled,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (job.isNearStation) ...[
                        const SizedBox(width: 5),
                        const _StationChip(),
                      ],
                    ],
                  ),
                  if (job.tags.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 3,
                      runSpacing: 0,
                      children: job.tags
                          .take(3)
                          .map((t) => _SmallChip(label: t))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),

            // 우: 썸네일 (이미지 있을 때) + D-day + 즉시지원
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (job.images.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: JobCoverImage(
                        source: job.images.first,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                Text(
                  _dDayText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _isUrgent
                        ? AppColors.error
                        : AppColors.textDisabled,
                    letterSpacing: -0.2,
                  ),
                ),
                if (job.canApplyNow) ...[
                  const SizedBox(height: 4),
                  AppBadge(
                    label: '즉시지원',
                    bgColor: AppColors.accent.withValues(alpha: 0.12),
                    textColor: AppColors.accent,
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

// ── 미니바 ───────────────────────────────────────────────────────
class _MiniBar extends StatelessWidget {
  final VoidCallback onTap;

  const _MiniBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 11,
      ),
      color: AppColors.accent.withValues(alpha: 0.06),
      child: Row(
        children: [
          Icon(
            Icons.stars_rounded,
            size: 15,
            color: AppColors.accent,
          ),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Text(
              '추천 공고 더 보기',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: -0.2,
              ),
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.sm),
              ),
              child: const Text(
                '확인하기',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
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
class _StationChip extends StatelessWidget {
  const _StationChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(4),
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
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          color: AppColors.textDisabled,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

// ── 빈 상태 ──────────────────────────────────────────────────────
class _Level3EmptyState extends StatelessWidget {
  const _Level3EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 44,
            color: AppColors.textDisabled,
          ),
          SizedBox(height: 14),
          Text(
            '조건에 맞는 공고가 없어요.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '검색어나 필터를 조정해보세요.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}
