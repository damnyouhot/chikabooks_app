import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'job_manage_section.dart';
import 'job_analytics_section.dart';
import 'web_typography.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/web_site_footer.dart';
import '../../../core/theme/app_tokens.dart' show AppPublisher, AppRadius;
import '../../auth/web/web_account_menu_button.dart';

/// 구인등록 웹 페이지 셸 (/post-job)
///
/// 세 개 탭으로 구성:
///   Tab 0 — 공고 등록 (새 입력 플로우 `/post-job/input`로 리다이렉트)
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
  bool _submitted = false;

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
                  onPressed: () => context.push('/me/clinic'),
                  icon: const Icon(Icons.verified_outlined, size: 16),
                  label: const Text('병원 정보'),
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
