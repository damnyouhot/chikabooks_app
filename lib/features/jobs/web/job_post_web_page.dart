import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../ui/job_post_form.dart';
import '../ui/job_post_preview.dart';
import 'job_manage_section.dart';
import 'job_analytics_section.dart';
import 'web_typography.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/web_site_footer.dart';
import '../../../core/theme/app_tokens.dart' show AppPublisher, AppRadius;
import '../../../models/job_draft.dart';
import '../../../services/job_draft_service.dart';
import '../../auth/web/web_account_menu_button.dart';

/// 구인등록 웹 페이지 셸 (/post-job)
///
/// 세 개 탭으로 구성:
///   Tab 0 — 공고 등록 (좌 프리뷰 + 우 폼)
///   Tab 1 — 공고 관리 (내 공고 목록 + 지원자 열람)
///   Tab 2 — 공고 분석 (조회수 추이 / 비교표)
/// 하단 푸터에 개인정보처리방침 / 이용약관 링크 포함
class JobPostWebPage extends StatefulWidget {
  const JobPostWebPage({super.key});

  @override
  State<JobPostWebPage> createState() => _JobPostWebPageState();
}

class _JobPostWebPageState extends State<JobPostWebPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  JobPostData _data = JobPostData();
  bool _submitted = false;
  String? _currentDraftId;
  DateTime? _draftUpdatedAt;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _onDataChanged(JobPostData d) => setState(() => _data = d);

  void _onDraftIdChanged(String id) {
    _currentDraftId = id;
  }

  Future<void> _onSubmit(JobPostData d) async {
    _currentDraftId = null;
    _draftUpdatedAt = null;
    if (mounted) setState(() => _submitted = true);
  }

  /// 드래프트를 불러와 폼에 반영
  Future<void> _loadDraft(JobDraft draft) async {
    setState(() {
      _currentDraftId = draft.id;
      _draftUpdatedAt = draft.updatedAt;
      _data = JobPostData(
        clinicName: draft.clinicName,
        title: draft.title,
        role: draft.role,
        hireRoles: List.from(draft.hireRoles),
        career: draft.career,
        education: draft.education,
        employmentType: draft.employmentType,
        workHours: draft.workHours,
        salary: draft.salary,
        salaryPayType: draft.salaryPayType,
        salaryAmount: draft.salaryAmount,
        benefits: List.from(draft.benefits),
        description: draft.description,
        address: draft.address,
        contact: draft.contact,
        hospitalType: draft.hospitalType,
        chairCount: draft.chairCount,
        staffCount: draft.staffCount,
        workDays: List.from(draft.workDays),
        weekendWork: draft.weekendWork,
        nightShift: draft.nightShift,
        applyMethod: List.from(draft.applyMethod),
        isAlwaysHiring: draft.isAlwaysHiring,
        closingDate: draft.closingDate,
        subwayStationName: draft.subwayStationName,
        subwayLines: List.from(draft.subwayLines),
        walkingDistanceMeters: draft.walkingDistanceMeters,
        walkingMinutes: draft.walkingMinutes,
        exitNumber: draft.exitNumber,
        parking: draft.parking,
        lat: draft.lat,
        lng: draft.lng,
        tags: List.from(draft.tags),
      );
    });
    _tabCtrl.animateTo(0);
  }

  /// 드래프트 삭제
  Future<void> _deleteDraft(String draftId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('임시저장 삭제'),
        content: const Text('이 임시저장을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.cardEmphasis,
              foregroundColor: AppColors.onCardEmphasis,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await JobDraftService.deleteDraft(draftId);
      if (_currentDraftId == draftId) {
        setState(() {
          _currentDraftId = null;
          _draftUpdatedAt = null;
          _data = JobPostData();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _buildSuccessScreen();

    return Theme(
      data: WebTypo.themeData(Theme.of(context)),
      child: Scaffold(
        backgroundColor: AppColors.appBg,
        body: Column(
          children: [
            // ── 상단: 로고 + 탭바 ──
            _buildHeader(),

            // ── 탭 콘텐츠 ──
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                // 내부 수평 스크롤과 제스처 충돌 방지 → 탭 전환은 탭바로만
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildPostTab(),
                  const JobManageSection(),
                  const JobAnalyticsSection(),
                ],
              ),
            ),

            // ── 하단 푸터 ──
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── 상단 헤더 (로고 + 탭바) ──────────────────────────
  Widget _buildHeader() {
    return Container(
      color: AppColors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 로고 + 유틸 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 36, 28, 8),
            child: Row(
              children: [
                // 로고
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(AppPublisher.softRadius),
                  ),
                  child: const Icon(
                    Icons.local_hospital_outlined,
                    size: 20,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '하이진랩',
                  style: WebTypo.heading(color: AppColors.textPrimary),
                ),
                const Spacer(),
                // 내 정보 (마이페이지) 진입
                TextButton.icon(
                  onPressed: () => context.push('/me'),
                  icon: const Icon(Icons.account_box_outlined, size: 16),
                  label: const Text('내 정보'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
                // 사업자 인증 버튼
                TextButton.icon(
                  onPressed: () => context.push('/clinic-verify'),
                  icon: const Icon(Icons.verified_outlined, size: 16),
                  label: const Text('사업자 인증'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
                if (kIsWeb) ...[
                  const SizedBox(width: 4),
                  const WebAccountMenuButton(),
                ],
              ],
            ),
          ),
          // 탭바
          TabBar(
            controller: _tabCtrl,
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.textDisabled,
            indicatorColor: AppColors.accent,
            indicatorWeight: 2.5,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: WebTypo.sectionTitle(),
            unselectedLabelStyle: WebTypo.sectionTitle(
              color: AppColors.textDisabled,
            ),
            tabs: const [
              Tab(text: '공고 등록'),
              Tab(text: '공고 관리'),
              Tab(text: '공고 분석'),
            ],
          ),
          // 구분선
          const Divider(height: 1, thickness: 0.6, color: AppColors.divider),
        ],
      ),
    );
  }

  // ── 공고 등록 탭 → 새 플로우로 리다이렉트 ────────────────
  Widget _buildPostTab() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/post-job/input');
    });
    return const Center(child: CircularProgressIndicator());
  }

  // ── 데스크톱: 좌 프리뷰 + 우 폼 ─────────────────────
  Widget _buildDesktopLayout(BoxConstraints outer) {
    const double leftWidth = 420;
    const double rightWidth = 520;
    const double totalWidth = leftWidth + rightWidth;

    return Center(
      child: SizedBox(
        width: totalWidth,
        height: outer.maxHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 좌: 헤더 + 고정 프리뷰 ──
            Container(
              width: leftWidth,
              decoration: const BoxDecoration(
                color: AppColors.white,
                border: Border(
                  right: BorderSide(color: AppColors.divider, width: 0.8),
                ),
              ),
              child: Column(
                children: [
                  _buildSideHeader(),
                  _buildDraftListPanel(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      child: JobPostPreview(data: _data),
                    ),
                  ),
                ],
              ),
            ),
            // ── 우: 폼 ──
            SizedBox(
              width: rightWidth,
              child: Column(
                children: [
                  _buildFormTopBar(),
                  Expanded(
                    child: JobPostForm(
                      key: ValueKey(_currentDraftId ?? 'new'),
                      initialData: _data,
                      publisherWebStyle: true,
                      onDataChanged: _onDataChanged,
                      onSubmit: _onSubmit,
                      draftId: _currentDraftId,
                      onDraftIdChanged: _onDraftIdChanged,
                      initialDraftUpdatedAt: _draftUpdatedAt,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 좌측 사이드 헤더 ────────────────────────────────
  Widget _buildSideHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(AppPublisher.softRadius),
                ),
                child: const Icon(
                  Icons.local_hospital_outlined,
                  size: 20,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '하이진랩 구인등록',
                style: WebTypo.sectionTitle(color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '지원자가 보게 될 화면을\n실시간으로 확인해보세요.',
            style: WebTypo.caption(
              color: AppColors.textSecondary,
              size: 13,
            ).copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }

  // ── 좌측 임시저장 목록 패널 ────────────────────────
  Widget _buildDraftListPanel() {
    return StreamBuilder<List<JobDraft>>(
      stream: JobDraftService.watchMyDrafts(),
      builder: (context, snapshot) {
        final drafts = snapshot.data ?? [];
        if (drafts.isEmpty) return const SizedBox.shrink();

        return Container(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.divider, width: 0.8),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.drafts_outlined,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    '임시저장 (${drafts.length})',
                    style: WebTypo.caption(
                      color: AppColors.textSecondary,
                      size: 13,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...drafts.map((draft) => _buildDraftTile(draft)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDraftTile(JobDraft draft) {
    final isActive = _currentDraftId == draft.id;
    final updatedText = draft.updatedAt != null
        ? DateFormat('MM/dd HH:mm').format(draft.updatedAt!)
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isActive
            ? AppColors.accent.withOpacity(0.08)
            : AppColors.surfaceMuted.withOpacity(0.35),
        borderRadius: BorderRadius.circular(AppPublisher.softRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppPublisher.softRadius),
          onTap: () => _loadDraft(draft),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  isActive ? Icons.edit_note : Icons.description_outlined,
                  size: 18,
                  color: isActive ? AppColors.accent : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        draft.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive ? AppColors.accent : AppColors.textPrimary,
                        ),
                      ),
                      if (updatedText.isNotEmpty)
                        Text(
                          updatedText,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textDisabled,
                          ),
                        ),
                    ],
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(AppPublisher.softRadius),
                  onTap: () => _deleteDraft(draft.id),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.textDisabled,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 폼 상단 바 (초기화 버튼) ────────────────────────
  Widget _buildFormTopBar() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '구인공고 등록',
              style: WebTypo.heading(color: AppColors.textPrimary),
            ),
          ),
          // 초기화 버튼 (새 공고로)
          TextButton.icon(
            onPressed: () => setState(() {
              _currentDraftId = null;
              _data = JobPostData();
            }),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('새 공고'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => setState(() {
              _currentDraftId = null;
              _data = JobPostData();
            }),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('초기화'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ── 하단 푸터 (사업자 정보 · 개인정보 / 약관 링크) ────
  Widget _buildFooter() {
    return const WebSiteFooter(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 28),
    );
  }

  // ── 제출 완료 화면 ───────────────────────────────────
  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      bottomNavigationBar: const WebSiteFooter(backgroundColor: AppColors.white),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  size: 40,
                  color: AppColors.accent.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '등록 신청 완료!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '구인공고가 접수되었습니다.\n검수 후 앱에 게시될 예정이에요. (보통 1~2 영업일 소요)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              // 공고 관리로 이동
              SizedBox(
                height: AppPublisher.ctaHeight,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _submitted = false;
                      _data = JobPostData();
                    });
                    _tabCtrl.animateTo(1); // 공고 관리 탭으로 이동
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppPublisher.buttonRadius),
                    ),
                  ),
                  child: const Text(
                    '내 공고 확인하기',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 새 공고 등록
              SizedBox(
                height: AppPublisher.ctaHeight,
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _submitted = false;
                    _data = JobPostData();
                  }),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: AppColors.textPrimary.withOpacity(0.2)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppPublisher.buttonRadius),
                    ),
                  ),
                  child: const Text(
                    '새 공고 등록하기',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
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
