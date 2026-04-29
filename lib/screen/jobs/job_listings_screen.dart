import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import '../../widgets/job/job_listing_cards.dart';
import '../jobs/job_detail_screen.dart';
import '../../widgets/job/job_cover_image.dart';
import '../../pages/career/career_resume_shortcuts_row.dart';

/// C목록에 끼워 넣는 A·B 행용 썸네일 (기존 96의 60%)
const double _kAbThumbInCListSide = kJobListingAbThumbSide;
const int _kLevel1Limit = 8;
const int _kLevel2Limit = 10;

/// 채용 소탭 - 목록 모드
///
/// ## Sliver 구조
/// - 이력서/지원 단축 → 커리어 요약 (스크롤 시 위로 사라짐)
/// - 프리미엄: 2열 그리드. 추천(B) 섹션 상단이 뷰 상단에 닿으면 1클래스 캐러셀 오버레이
/// - 추천: 게시판형 행(구 3클래스)
/// - 전체 공고: 텍스트 위주 행(사진·해시태그 없음) + 12개마다 미니바
/// - 하단 검색 바 (Positioned)
class JobListingsScreen extends StatefulWidget {
  final LatLng? userLocation;
  final VoidCallback onMapToggle;
  final bool readOnly;

  const JobListingsScreen({
    super.key,
    this.userLocation,
    required this.onMapToggle,
    this.readOnly = false,
  });

  @override
  State<JobListingsScreen> createState() => _JobListingsScreenState();
}

class _JobListingsScreenState extends State<JobListingsScreen> {
  final _scrollController = ScrollController();

  /// 추천(B) 섹션 상단 — 프리미엄 고정 캐러셀은 이 지점이 뷰포트 상단에 닿은 뒤부터 표시
  final GlobalKey _bSectionTopKey = GlobalKey();

  // 검색
  String _searchQuery = '';

  // ── 커리어 프로파일 ───────────────────────────────────────────
  String _careerSummary = '';
  Map<String, dynamic>? _careerProfile;
  int _networkSumMonths = 0;
  int _totalCareerMonths = 0;
  StreamSubscription<Map<String, dynamic>?>? _careerSub;
  StreamSubscription<List<DentalNetworkEntry>>? _networkSub;

  // ── Level 3 페이지네이션 상태 ────────────────────────────────
  List<Job> _level3Jobs = [];
  List<Job> _level1Jobs = [];
  List<Job> _level2Jobs = [];
  bool _level3Loading = false;
  bool _level3HasMore = true;
  DocumentSnapshot? _level3LastDoc;
  bool _useMockData = false;

  /// 스크롤이 일정 이상이면 프리미엄 캐러셀을 목록 상단에 고정 표시
  bool _showPinnedPremium = false;

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
      _loadHighlightedJobs();
      _loadLevel3(reset: true);
      if (widget.readOnly) {
        _onScroll();
        return;
      }
      // 커리어 프로파일 + 치과 히스토리 합 — 상단 카드와 동일한 총 경력
      _careerSub = CareerProfileService.watchMyCareerProfile().listen((
        profile,
      ) {
        _careerProfile = profile;
        _applyCareerDerivedState();
      });
      _networkSub = CareerProfileService.watchNetworkEntries().listen((
        entries,
      ) {
        _networkSumMonths = entries.fold(0, (acc, e) => acc + e.months);
        _applyCareerDerivedState();
      });
      _onScroll(); // 스크롤 컨트롤러 연결 직후 프리미엄 고정 표시 동기화
    });
  }

  void _applyCareerDerivedState() {
    if (!mounted) return;
    final months = JobMatchService.totalCareerMonthsForCard(
      profile: _careerProfile,
      networkSumMonths: _networkSumMonths,
    );
    setState(() {
      _totalCareerMonths = months;
      _careerSummary = JobMatchService.buildCareerSummary(
        profile: _careerProfile,
        totalCareerMonths: months,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updatePinnedPremiumVisibility();
    });
  }

  @override
  void dispose() {
    _careerSub?.cancel();
    _networkSub?.cancel();
    _filterNotifier?.removeListener(_onFilterChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onFilterChanged() => _loadLevel3(reset: true);

  Future<void> _loadHighlightedJobs() async {
    final svc = context.read<JobService>();
    final results = await Future.wait([
      svc.fetchHighlightedJobs(jobLevel: 1, limit: _kLevel1Limit),
      svc.fetchHighlightedJobs(jobLevel: 2, limit: _kLevel2Limit),
    ]);
    if (!mounted) return;
    setState(() {
      _level1Jobs = results[0];
      _level2Jobs = results[1];
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updatePinnedPremiumVisibility();
    });
  }

  void _onScroll() {
    _updatePinnedPremiumVisibility();
    // 무한 스크롤: 하단 400px 이내 진입 시 다음 페이지 로드
    if (!_level3Loading && _level3HasMore && !_useMockData) {
      final pos = _scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - 400) {
        _loadLevel3();
      }
    }
  }

  /// B(추천) 섹션 상단이 스크롤 뷰포트 상단에 도달한 뒤에만 고정 캐러셀 표시
  void _updatePinnedPremiumVisibility() {
    final ctrl = _scrollController;
    if (!ctrl.hasClients) return;
    final ctx = _bSectionTopKey.currentContext;
    if (ctx == null) return;
    final target = ctx.findRenderObject();
    if (target == null || !target.attached) return;

    final viewport = RenderAbstractViewport.maybeOf(target);
    if (viewport == null) return;

    final revealed = viewport.getOffsetToReveal(target, 0.0);
    final threshold = revealed.offset;
    if (threshold.isNaN || threshold.isInfinite) return;

    final next = ctrl.offset >= threshold - 1.0;
    if (next != _showPinnedPremium) {
      setState(() => _showPinnedPremium = next);
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
        pageSize: 30,
        startAfter: _level3LastDoc,
        jobLevel: 3,
      );

      if (!mounted) return;

      if (result.jobs.isEmpty && _level3Jobs.isEmpty) {
        setState(() {
          _level3Jobs = generateMockLevel3Jobs(count: 38);
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
          _level3Jobs = generateMockLevel3Jobs(count: 38);
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
    final level1Ids = _level1Jobs.map((j) => j.id).toSet();
    final deduped2 =
        _level2Jobs.where((j) => !level1Ids.contains(j.id)).toList();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── 메인 스크롤 뷰 (앱 공통 배경과 동일) ─────────────────
        ColoredBox(
          color: AppColors.appBg,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              if (!widget.readOnly) ...[
                // ── 내 이력서 / 지원 내역 (소탭 바로 아래, 스크롤 시 사라짐) ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.sm,
                    ),
                    child: const CareerResumeShortcutsRow(),
                  ),
                ),
                // ── 커리어 요약 (스크롤로 사라짐) ──────────────────
                SliverToBoxAdapter(
                  child: _CareerSummarySection(careerSummary: _careerSummary),
                ),
              ],

              // ── 프리미엄: 2열 그리드 (진입 시 고정 캐러셀 없음) ──
              SliverToBoxAdapter(
                child: _PremiumGridSection(
                  jobs: _level1Jobs,
                  onJobTap: widget.readOnly ? null : _navigateToDetail,
                ),
              ),

              // ── 추천: 게시판형 행 (상단 위치로 고정 캐러셀 임계값 측정) ──
              SliverToBoxAdapter(
                child: KeyedSubtree(
                  key: _bSectionTopKey,
                  child: _Level2ListSection(
                    jobs: deduped2,
                    onJobTap: widget.readOnly ? null : _navigateToDetail,
                  ),
                ),
              ),

              // ── Level 3 헤더 ─────────────────────────────────────
              const SliverToBoxAdapter(child: _Level3Header()),

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
                padding: EdgeInsets.only(
                  bottom:
                      widget.readOnly
                          ? AppSpacing.lg + safeBottom
                          : 92 + safeBottom,
                ),
              ),
            ],
          ),
        ),

        // ── B가 뷰 상단에 닿은 뒤: 프리미엄 캐러셀 고정 ───────────
        if (_showPinnedPremium)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              color: AppColors.appBg,
              elevation: 2,
              shadowColor: Colors.black26,
              surfaceTintColor: Colors.transparent,
              child: JobLevel1Carousel(
                jobs: _level1Jobs,
                onJobTap: widget.readOnly ? (_, __) {} : null,
              ),
            ),
          ),

        // ── 하단 검색 바 (Positioned) ──────────────────────────
        if (!widget.readOnly)
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
    List<Job> jobs = _applyNonSortFilters(List.of(_level3Jobs), jobFilter);

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
        jobs.sort((a, b) => b.salaryRange.last.compareTo(a.salaryRange.last));
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

    // A·B클래스 공고 — 동일 필터 적용 (정렬은 A→B 원래 순서 유지)
    final level1Ids = _level1Jobs.map((j) => j.id).toSet();
    final rawFixed = <Job>[
      ..._level1Jobs,
      ..._level2Jobs.where((j) => !level1Ids.contains(j.id)),
    ];
    final fixedTop = _applyNonSortFilters(rawFixed, jobFilter);

    return SliverToBoxAdapter(
      child: Column(
        children: [
          // ── A·B클래스 고정 공고 (C행과 동일 정보량·소형 썸네일 60%) ──
          for (int i = 0; i < fixedTop.length; i++) ...[
            _JobRowAsCWithThumb(
              job: fixedTop[i],
              onTap:
                  widget.readOnly ? null : () => _navigateToDetail(fixedTop[i]),
            ),
            const Divider(
              height: 0.5,
              thickness: 0.5,
              indent: 16,
              endIndent: 16,
              color: AppColors.divider,
            ),
          ],
          // ── C클래스 공고 (필터 적용) ──
          for (int i = 0; i < jobs.length; i++) ...[
            JobListingRowBasic(
              job: jobs[i],
              onTap: widget.readOnly ? null : () => _navigateToDetail(jobs[i]),
            ),
            if (i < jobs.length - 1)
              const Divider(
                height: 0.5,
                thickness: 0.5,
                indent: 16,
                endIndent: 16,
                color: AppColors.divider,
              ),
          ],
        ],
      ),
    );
  }

  // ── 클라이언트 필터 헬퍼 (정렬 제외) ─────────────────────────────
  List<Job> _applyNonSortFilters(
    List<Job> source,
    JobFilterNotifier jobFilter,
  ) {
    List<Job> jobs = List.of(source);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      jobs =
          jobs.where((j) {
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
      jobs =
          jobs.where((j) {
            final et = j.employmentType.trim();
            if (et.isNotEmpty) return et.contains(want) || want.contains(et);
            return j.type.contains(want);
          }).toList();
    }

    if (jobFilter.regionFilter != '전체') {
      final r = jobFilter.regionFilter;
      jobs =
          jobs
              .where((j) => j.address.contains(r) || j.district.contains(r))
              .toList();
    }

    if (jobFilter.careerFilter != '전체') {
      jobs =
          jobs.where((j) {
            final c = j.career.toLowerCase();
            switch (jobFilter.careerFilter) {
              case '신입':
                return c.contains('신입') ||
                    c.contains('무관') ||
                    c.contains('경력없');
              case '1년 이상':
                return c.contains('1년') ||
                    c.contains('2년') ||
                    (c.contains('경력') &&
                        !c.contains('신입') &&
                        !c.contains('무관'));
              case '3년 이상':
                return c.contains('3년') || c.contains('4년') || c.contains('5년');
              case '5년 이상':
                return c.contains('5년') ||
                    c.contains('6년') ||
                    c.contains('7년') ||
                    c.contains('10년');
              default:
                return true;
            }
          }).toList();
    }

    if (jobFilter.salaryRange.start > 0 || jobFilter.salaryRange.end < 10000) {
      final minF = jobFilter.salaryRange.start;
      final maxF = jobFilter.salaryRange.end;
      jobs =
          jobs.where((j) {
            if (j.salaryRange.isEmpty) return true;
            final jobMin = j.salaryRange.first.toDouble();
            final jobMax = j.salaryRange.last.toDouble();
            return jobMax >= minF && jobMin <= maxF;
          }).toList();
    }

    if (jobFilter.hospitalType != '전체') {
      jobs =
          jobs.where((j) => j.hospitalType == jobFilter.hospitalType).toList();
    }

    if (jobFilter.selectedWorkDays.isNotEmpty) {
      jobs =
          jobs.where((j) {
            return jobFilter.selectedWorkDays.every(
              (day) => j.workDays.contains(day),
            );
          }).toList();
    }

    if (jobFilter.selectedSubwayLines.isNotEmpty) {
      jobs =
          jobs.where((j) {
            return j.subwayLines.any(
              (line) => jobFilter.selectedSubwayLines.contains(line),
            );
          }).toList();
    }

    if (jobFilter.conditions.isNotEmpty) {
      jobs =
          jobs.where((j) {
            return jobFilter.conditions.every((cond) {
              switch (cond) {
                case '신입가능':
                  return j.career.contains('신입') || j.career.contains('무관');
                case '야간없음':
                  return !j.nightShift;
                case '주4일':
                  return j.workDays.length <= 4;
                case '파트타임 가능':
                  return j.employmentType.contains('파트');
                case '역세권':
                  return j.isNearStation;
                case '즉시지원':
                  return j.canApplyNow;
                case '4대보험':
                  return j.benefits.any((b) => b.contains('4대')) ||
                      j.tags.any((t) => t.contains('4대'));
                case '퇴직금':
                  return j.benefits.any((b) => b.contains('퇴직')) ||
                      j.tags.any((t) => t.contains('퇴직'));
                case '연차':
                  return j.benefits.any((b) => b.contains('연차')) ||
                      j.tags.any((t) => t.contains('연차'));
                case '식비지원':
                  return j.benefits.any((b) => b.contains('식비')) ||
                      j.tags.any((t) => t.contains('식비'));
                default:
                  return true;
              }
            });
          }).toList();
    }

    return jobs;
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
      child:
          careerSummary.isNotEmpty
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
    final bottom =
        keyboardH > 0 ? keyboardH + AppSpacing.sm : AppSpacing.md + safeBottom;

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
              const Icon(Icons.search, color: AppColors.textDisabled, size: 22),
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
                Icon(Icons.tune_rounded, size: 18, color: AppColors.onAccent),
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
            Icon(Icons.map_outlined, size: 18, color: AppColors.onAccent),
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

// ── 프리미엄: 2열 그리드 (구 B클래스) ───────────────────────────────
class _PremiumGridSection extends StatelessWidget {
  final List<Job> jobs;
  final ValueChanged<Job>? onJobTap;

  const _PremiumGridSection({required this.jobs, required this.onJobTap});

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) return const SizedBox.shrink();

    return Container(
      color: AppColors.appBg,
      margin: const EdgeInsets.only(top: AppSpacing.xxl + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  '추천 · 프리미엄',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
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
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 5,
                mainAxisExtent: 262,
              ),
              itemCount: jobs.length,
              itemBuilder:
                  (_, i) => JobListingCardPremium(
                    job: jobs[i],
                    onTap: onJobTap == null ? null : () => onJobTap!(jobs[i]),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 추천: 게시판형 행 (구 3클래스) ─────────────────────────────────
class _Level2ListSection extends StatelessWidget {
  final List<Job> jobs;
  final ValueChanged<Job>? onJobTap;

  const _Level2ListSection({required this.jobs, required this.onJobTap});

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) return const SizedBox.shrink();

    return Container(
      color: AppColors.appBg,
      margin: const EdgeInsets.only(top: AppSpacing.xxl + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          for (int i = 0; i < jobs.length; i++) ...[
            JobListingRowRecommended(
              job: jobs[i],
              onTap: onJobTap == null ? null : () => onJobTap!(jobs[i]),
            ),
            if (i < jobs.length - 1)
              const Divider(
                height: 0.5,
                thickness: 0.5,
                indent: 16,
                endIndent: 16,
                color: AppColors.divider,
              ),
          ],
        ],
      ),
    );
  }
}

// ── A클래스 공고 미니 슬롯 (전체 공고 목록 중간 삽입, 2개/슬롯) ────
class _Level3Header extends StatelessWidget {
  const _Level3Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: (AppSpacing.xxl + 4) * 2),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      color: AppColors.appBg,
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

// ── A·B를 C목록 상단에 넣을 때: C행과 동일 텍스트 + 60% 썸네일 (해시태그·마감 없음) ─
class _JobRowAsCWithThumb extends StatelessWidget {
  final Job job;
  final VoidCallback? onTap;

  const _JobRowAsCWithThumb({required this.job, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final role = job.listRoleLine;

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
                  const SizedBox(height: 5),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: job.displayClinicName,
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
            // 우: 썸네일 최우측 정렬 + 즉시지원 배지 아래 우측 정렬
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (job.images.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: JobCoverImage(
                      source: job.images.first,
                      width: _kAbThumbInCListSide,
                      height: _kAbThumbInCListSide,
                      fit: BoxFit.cover,
                    ),
                  ),
                if (job.canApplyNow) ...[
                  const SizedBox(height: 5),
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

// ── A클래스 공고 미니 슬롯 (전체 공고 목록 중간 삽입, 2개/슬롯) ────
class _PremiumMiniSlot extends StatelessWidget {
  final int slotIndex;
  final List<Job> premiumJobs;
  final ValueChanged<Job> onTap;

  const _PremiumMiniSlot({
    required this.slotIndex,
    required this.premiumJobs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (premiumJobs.isEmpty) return const SizedBox.shrink();

    // 슬롯마다 다음 2개 공고 (무한 순환)
    final total = premiumJobs.length;
    final first = premiumJobs[(slotIndex * 2) % total];
    final second = premiumJobs[(slotIndex * 2 + 1) % total];
    final jobs = [first, second];

    return Container(
      color: AppColors.accent.withValues(alpha: 0.04),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.stars_rounded, size: 13, color: AppColors.accent),
              const SizedBox(width: 5),
              Text(
                '추천 · 프리미엄',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children:
                jobs.map((job) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: job == jobs.first ? AppSpacing.sm / 2 : 0,
                        left: job == jobs.last ? AppSpacing.sm / 2 : 0,
                      ),
                      child: GestureDetector(
                        onTap: () => onTap(job),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(AppRadius.md),
                                ),
                                child: SizedBox(
                                  height: 90,
                                  width: double.infinity,
                                  child:
                                      job.images.isNotEmpty
                                          ? JobCoverImage(
                                            source: job.images.first,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                          )
                                          : Container(
                                            color: AppColors.surfaceMuted,
                                            child: const Center(
                                              child: Icon(
                                                Icons.business_outlined,
                                                size: 20,
                                                color: AppColors.textDisabled,
                                              ),
                                            ),
                                          ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      job.displayClinicName,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                        letterSpacing: -0.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      job.listRoleLine,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textPrimary,
                                        letterSpacing: -0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── 찜하기 아이콘 버튼 ────────────────────────────────────────────
class _BookmarkIcon extends StatelessWidget {
  final String jobId;

  const _BookmarkIcon({required this.jobId});

  @override
  Widget build(BuildContext context) {
    final jobService = context.read<JobService>();
    return StreamBuilder<List<String>>(
      stream: jobService.watchBookmarkedJobIds(),
      builder: (context, snap) {
        final isBookmarked = (snap.data ?? []).contains(jobId);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (isBookmarked) {
              jobService.unbookmarkJob(jobId);
            } else {
              jobService.bookmarkJob(jobId);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(
              isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              size: 18,
              color: isBookmarked ? AppColors.accent : AppColors.textDisabled,
            ),
          ),
        );
      },
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
            style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
          ),
        ],
      ),
    );
  }
}
