import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../ui/job_post_form.dart';
import '../ui/job_post_preview.dart';
import 'web_typography.dart';

const _kBg = Color(0xFFF4F0F8);
const _kText = Color(0xFF3D4A5C);
const _kBlue = Color(0xFF4A90D9);
const _kPink = Color(0xFFF7CBCA);
const _kPinkDark = Color(0xFFE57373);

/// 구인등록 웹 페이지 (/post-job)
///
/// Desktop (width >= 1024): 좌 – 모바일 프리뷰 | 우 – 입력 폼
/// Mobile  (width < 1024) : 폼 단독 (프리뷰는 탭으로 전환 가능)
class JobPostWebPage extends StatefulWidget {
  const JobPostWebPage({super.key});

  @override
  State<JobPostWebPage> createState() => _JobPostWebPageState();
}

class _JobPostWebPageState extends State<JobPostWebPage>
    with SingleTickerProviderStateMixin {
  JobPostData _data = JobPostData();
  bool _submitted = false;

  void _onDataChanged(JobPostData d) => setState(() => _data = d);

  Future<void> _onSubmit(JobPostData d) async {
    // JobPostForm 내부에서 Storage 업로드 + createJobPosting Callable 처리 완료
    // 여기서는 완료 화면 전환만 담당
    if (mounted) setState(() => _submitted = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _buildSuccessScreen();

    return Theme(
      data: WebTypo.themeData(Theme.of(context)),
      child: _buildMainScaffold(),
    );
  }

  Widget _buildMainScaffold() {
    return Scaffold(
      backgroundColor: _kBg,
      body: LayoutBuilder(
        builder:
            (context, constraints) =>
            // 창 크기와 무관하게 항상 데스크톱 레이아웃 유지
            // (좁으면 가로 스크롤로 처리)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: constraints.maxWidth < 940 ? 940 : constraints.maxWidth,
                height: constraints.maxHeight,
                child: _buildDesktopLayout(
                  BoxConstraints(
                    maxWidth:
                        constraints.maxWidth < 940 ? 940 : constraints.maxWidth,
                    maxHeight: constraints.maxHeight,
                  ),
                ),
              ),
            ),
      ),
    );
  }

  // ── 데스크톱: 좌 프리뷰 + 우 폼 (가운데 정렬, 최대폭 제한) ─────
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
                color: Color(0xFFEDE6F5),
                border: Border(
                  right: BorderSide(color: Color(0xFFD8CDE8), width: 0.8),
                ),
              ),
              child: Column(
                children: [
                  _buildSideHeader(),
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
                  _buildTopBar(isDesktop: true),
                  Expanded(
                    child: JobPostForm(
                      initialData: _data,
                      onDataChanged: _onDataChanged,
                      onSubmit: _onSubmit,
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

  // ── 좌측 사이드 헤더 ────────────────────────────────────
  Widget _buildSideHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFD8CDE8), width: 0.8),
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
                  color: _kBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_hospital_outlined,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Text('치카북스 구인등록', style: WebTypo.sectionTitle(color: _kText)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '지원자가 보게 될 화면을\n실시간으로 확인해보세요.',
            style: WebTypo.caption(
              color: _kText.withOpacity(0.6),
              size: 13,
            ).copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }

  // ── 상단 바 ─────────────────────────────────────────────
  Widget _buildTopBar({required bool isDesktop}) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 28 : 20,
        44,
        isDesktop ? 28 : 20,
        14,
      ),
      child: Row(
        children: [
          if (!isDesktop) ...[
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _kBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.local_hospital_outlined,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ],
          Expanded(
            child: Text('구인공고 등록', style: WebTypo.heading(color: _kText)),
          ),
          // 사업자 인증 버튼
          TextButton.icon(
            onPressed: () => context.push('/clinic-verify'),
            icon: const Icon(Icons.verified_outlined, size: 16),
            label: const Text('사업자 인증'),
            style: TextButton.styleFrom(
              foregroundColor: _kBlue,
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
          // 초기화 버튼
          TextButton.icon(
            onPressed: () => setState(() => _data = JobPostData()),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('초기화'),
            style: TextButton.styleFrom(
              foregroundColor: _kText.withOpacity(0.5),
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ── 제출 완료 화면 ──────────────────────────────────────
  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: _kBg,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _kPink.withOpacity(0.35),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  size: 40,
                  color: _kPinkDark.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '등록 신청 완료!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _kText,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '구인공고가 접수되었습니다.\n검수 후 앱에 게시될 예정이에요. (보통 1~2 영업일 소요)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: _kText.withOpacity(0.6),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      () => setState(() {
                        _submitted = false;
                        _data = JobPostData();
                      }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '새 공고 등록하기',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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


