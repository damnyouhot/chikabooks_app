import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../data/mock_jobs.dart';
import '../../../../models/job.dart';
import '../../../../notifiers/job_filter_notifier.dart';
import '../../../../services/job_service.dart';
import '../widgets/applicant_web_shell.dart';
import '../widgets/inline_login_modal.dart';
import '../widgets/job_filter_bar.dart';
import '../widgets/job_tier_sections.dart';

/// 웹 일반계정 첫 화면 — 등급별 공고 보드.
///
/// 비로그인도 둘러볼 수 있게 두지만, 카드 클릭(상세 진입) 시점에 인라인
/// 로그인 모달을 띄워 [showInlineLoginRequired] 흐름으로 자연스럽게 가입을
/// 유도한다.
class JobBoardPage extends StatefulWidget {
  const JobBoardPage({super.key});

  @override
  State<JobBoardPage> createState() => _JobBoardPageState();
}

class _JobBoardPageState extends State<JobBoardPage> {
  // ── 등급별 공고 ──
  List<Job> _level1 = [];
  List<Job> _level2 = [];
  List<Job> _level3 = [];

  bool _highlightedLoading = true;
  bool _level3Loading = false;
  bool _level3HasMore = true;
  DocumentSnapshot? _level3LastDoc;
  // Firestore 결과가 0건이면 일반(레벨3) 영역에 mock 데이터를 fallback 으로 노출.
  // mock 데이터 사용 중에는 무한 스크롤(추가 페이지 요청)을 비활성화한다.
  bool _useMockLevel3 = false;

  // 필터 노티파이어 — 변경되면 level3 재로딩
  JobFilterNotifier? _filter;

  static const int _kPremiumLimit = 8;
  static const int _kRecommendedLimit = 9;
  static const int _kStandardPageSize = 20;
  // Firestore 가 비어있을 때 채워 넣을 mock 갯수.
  // 모바일 [JobListingsScreen] 과 동일한 비율로 맞춰 UX 일관성을 유지한다.
  static const int _kPremiumMockCount = 6;
  static const int _kRecommendedMockCount = 8;
  static const int _kStandardMockCount = 30;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _filter = context.read<JobFilterNotifier>();
      _filter!.addListener(_onFilterChanged);
      _loadHighlighted();
      _loadLevel3(reset: true);
    });
  }

  @override
  void dispose() {
    _filter?.removeListener(_onFilterChanged);
    super.dispose();
  }

  void _onFilterChanged() => _loadLevel3(reset: true);

  // ══════════════════════════════════════════════════════════════════
  // 데이터 로딩
  // ══════════════════════════════════════════════════════════════════

  Future<void> _loadHighlighted() async {
    final svc = context.read<JobService>();
    try {
      // Live 공고를 먼저 받아오되, mock 갯수만큼은 항상 자리를 비워서
      // Firestore 가 부족할 때도 보드가 비지 않도록 한다.
      final results = await Future.wait([
        svc.fetchHighlightedJobs(
          jobLevel: 1,
          limit: _kPremiumLimit - _kPremiumMockCount,
        ),
        svc.fetchHighlightedJobs(
          jobLevel: 2,
          limit: _kRecommendedLimit - _kRecommendedMockCount,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _level1 = _withMockBaseline(
          liveJobs: results[0],
          mockJobs: mockLevel1Jobs,
          mockCount: _kPremiumMockCount,
          totalLimit: _kPremiumLimit,
        );
        _level2 = _withMockBaseline(
          liveJobs: results[1],
          mockJobs: mockLevel2Jobs,
          mockCount: _kRecommendedMockCount,
          totalLimit: _kRecommendedLimit,
        );
        _highlightedLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // 네트워크 오류 등으로 Firestore 조회가 실패해도 mock 으로 대체해
      // 사용자가 빈 화면을 마주치지 않도록 한다.
      setState(() {
        _level1 = mockLevel1Jobs.take(_kPremiumLimit).toList();
        _level2 = mockLevel2Jobs.take(_kRecommendedLimit).toList();
        _highlightedLoading = false;
      });
    }
  }

  /// Firestore live 공고와 mock 공고를 합쳐 일정 갯수를 보장한다.
  /// (모바일 `JobListingsScreen._withMockBaseline` 과 동일 규칙)
  List<Job> _withMockBaseline({
    required List<Job> liveJobs,
    required List<Job> mockJobs,
    required int mockCount,
    required int totalLimit,
  }) {
    final live = List<Job>.of(liveJobs)
      ..sort((a, b) => b.postedAt.compareTo(a.postedAt));
    return <Job>[
      ...live,
      ...mockJobs.take(mockCount),
    ].take(totalLimit).toList();
  }

  Future<void> _loadLevel3({bool reset = false}) async {
    if (_level3Loading) return;
    // mock fallback 으로 채워둔 상태에선 추가 페이징을 시도하지 않는다.
    if (!reset && (!_level3HasMore || _useMockLevel3)) return;

    if (reset) {
      setState(() {
        _level3 = [];
        _level3LastDoc = null;
        _level3HasMore = true;
        _useMockLevel3 = false;
      });
    }
    setState(() => _level3Loading = true);

    try {
      final svc = context.read<JobService>();
      final result = await svc.fetchJobsPaged(
        pageSize: _kStandardPageSize,
        startAfter: _level3LastDoc,
        jobLevel: 3,
      );
      if (!mounted) return;

      // 첫 페이지 결과가 비었고 누적된 데이터도 없으면 mock 으로 fallback
      // (filter 가 걸려 0건일 수도 있으니 reset 일 때만 mock 으로 대체한다.)
      if (reset && result.jobs.isEmpty && _level3.isEmpty) {
        setState(() {
          _level3 = _applyClientSideFilter(
            generateMockLevel3Jobs(count: _kStandardMockCount),
          );
          _level3LastDoc = null;
          _level3HasMore = false;
          _useMockLevel3 = true;
          _level3Loading = false;
        });
        return;
      }

      setState(() {
        _level3.addAll(_applyClientSideFilter(result.jobs));
        _level3LastDoc = result.lastDoc;
        _level3HasMore = result.hasMore;
        _level3Loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // 네트워크 오류 — 첫 로딩이면 mock 으로 대체해 빈 화면을 피한다.
      if (reset && _level3.isEmpty) {
        setState(() {
          _level3 = _applyClientSideFilter(
            generateMockLevel3Jobs(count: _kStandardMockCount),
          );
          _level3HasMore = false;
          _useMockLevel3 = true;
          _level3Loading = false;
        });
      } else {
        setState(() => _level3Loading = false);
      }
    }
  }

  /// Phase 1: Firestore 쿼리에 다중 필터를 모두 넣기보다는
  /// 클라이언트 측에서 안전하게 필터링 (Phase 2 에서 인덱스 최적화 예정).
  ///
  /// 검색은 사용자가 화면에서 보는 텍스트(`displayTitle`/`displayClinicName`)
  /// 까지 포함하므로 "(샘플)" 같은 접두어로 입력해도 잘 매칭된다.
  List<Job> _applyClientSideFilter(List<Job> jobs) {
    final f = _filter;
    if (f == null) return jobs;
    return jobs.where((j) {
      if (f.searchQuery.trim().isNotEmpty) {
        final q = f.searchQuery.trim().toLowerCase();
        final hay = [
          j.title,
          j.displayTitle,
          j.clinicName,
          j.displayClinicName,
          j.address,
          j.district,
          j.tags.join(' '),
          j.hireRoles.join(' '),
        ].join(' ').toLowerCase();
        if (!hay.contains(q)) return false;
      }
      if (f.regionFilter != '전체' &&
          !j.address.contains(f.regionFilter)) {
        return false;
      }
      if (f.positionFilter != '전체' && !j.type.contains(f.positionFilter)) {
        return false;
      }
      if (f.careerFilter != '전체' && j.career != f.careerFilter) {
        // '신입' / '경력' 등 정확 매칭이 아니면 통과시킴 (커리어가 '미정'이거나 비어있는 케이스)
        if (j.career == '미정' || j.career.isEmpty) return true;
        return false;
      }
      return true;
    }).toList();
  }

  // ══════════════════════════════════════════════════════════════════
  // 카드 클릭 — 인라인 로그인 모달
  // ══════════════════════════════════════════════════════════════════

  Future<void> _handleJobTap(Job job) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // 이미 로그인 — 그대로 상세로
      context.push('/jobs/${job.id}');
      return;
    }

    final ok = await showInlineLoginRequired(
      context,
      title: '공고 상세를 보려면 로그인하세요',
      subtitle: '카카오로 1초만에 시작할 수 있어요.',
      nextPath: '/jobs/${job.id}',
    );
    if (!mounted) return;
    if (ok) {
      // 로그인 성공 — 같은 자리에서 상세로 이어가기
      context.push('/jobs/${job.id}');
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return ApplicantWebShell(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 검색 + 필터 ──
          const JobFilterBar(),
          const SizedBox(height: AppApplicant.sectionSpacing),

          if (_highlightedLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            // ── 프리미엄 (레벨 1) ──
            // 등급에 관계없이 사용자가 건 필터(검색·지역 등)를 모든 섹션에
            // 동일하게 적용해 일반 잡 보드 UX 와 일치시킨다.
            if (_applyClientSideFilter(_level1).isNotEmpty) ...[
              JobBoardSectionHeader(
                title: '이번 주 프리미엄 공고',
                subtitle: '치과가 직접 추천하는 핵심 공고',
                badge: 'PREMIUM',
              ),
              PremiumJobCarousel(
                jobs: _applyClientSideFilter(_level1),
                onJobTap: _handleJobTap,
              ),
              const SizedBox(height: AppApplicant.sectionSpacing),
            ],

            // ── 추천 (레벨 2) ──
            if (_applyClientSideFilter(_level2).isNotEmpty) ...[
              JobBoardSectionHeader(
                title: '추천 공고',
                subtitle: '조건에 잘 맞는 공고들',
              ),
              RecommendedJobGrid(
                jobs: _applyClientSideFilter(_level2),
                onJobTap: _handleJobTap,
              ),
              const SizedBox(height: AppApplicant.sectionSpacing),
            ],
          ],

          // ── 일반 (레벨 3) — 무한 스크롤 ──
          JobBoardSectionHeader(
            title: '전체 공고',
            subtitle: '${_level3.length}개의 공고',
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppApplicant.cardRadius),
              border: Border.all(color: AppColors.divider),
            ),
            clipBehavior: Clip.antiAlias,
            child: StandardJobList(
              jobs: _level3,
              onJobTap: _handleJobTap,
            ),
          ),

          if (_level3HasMore) ...[
            const SizedBox(height: 20),
            Center(
              child: OutlinedButton.icon(
                onPressed: _level3Loading ? null : () => _loadLevel3(),
                icon: _level3Loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded, size: 18),
                label: Text(
                  _level3Loading ? '불러오는 중…' : '더 보기',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.divider),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 60),
        ],
      ),
    );
  }
}
