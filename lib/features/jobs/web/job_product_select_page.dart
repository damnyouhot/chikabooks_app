import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/mock_jobs.dart';
import '../../../models/job.dart';
import '../../../models/job_draft.dart';
import '../../../services/job_draft_service.dart';
import '../../../services/order_service.dart';
import '../../payment/toss_payment_service.dart';
import '../../../services/voucher_service.dart';
import '../../../models/voucher.dart';
import '../../../widgets/job/job_listing_cards.dart';
import '../../auth/web/web_account_menu_button.dart';
import '../../publisher/services/clinic_profile_service.dart';
import '../ui/job_post_form.dart';

// ── 상품 클래스 정의 ──────────────────────────────────────────
enum _ProductClass { a, b, c }

extension _ProductClassExt on _ProductClass {
  String get label => switch (this) {
    _ProductClass.a => 'A 클래스',
    _ProductClass.b => 'B 클래스',
    _ProductClass.c => 'C 클래스',
  };

  String get tierKey => switch (this) {
    _ProductClass.a => 'premium',
    _ProductClass.b => 'standard',
    _ProductClass.c => 'basic',
  };

  int get priceWon => switch (this) {
    _ProductClass.a => 880000,
    _ProductClass.b => 440000,
    _ProductClass.c => 110000,
  };

  String get priceLabel => switch (this) {
    _ProductClass.a => '880,000원',
    _ProductClass.b => '440,000원',
    _ProductClass.c => '110,000원',
  };

  int get displayDays => switch (this) {
    _ProductClass.a => 60,
    _ProductClass.b => 30,
    _ProductClass.c => 14,
  };

  String get tagline => switch (this) {
    _ProductClass.a => '최상위 노출 · 60일 · 프리미엄 배지',
    _ProductClass.b => '추천 노출 · 30일 · 추천 배지',
    _ProductClass.c => '기본 노출 · 14일',
  };

  List<String> get features => switch (this) {
    _ProductClass.a => [
      '검색 최상단 고정 노출',
      '프리미엄 골드 배지 표시',
      '공고 60일 유지',
      '지원자 무제한',
      '공고 수정 무제한',
    ],
    _ProductClass.b => [
      '추천 섹션 우선 노출',
      '추천 블루 배지 표시',
      '공고 30일 유지',
      '지원자 무제한',
    ],
    _ProductClass.c => [
      '일반 목록 노출',
      '공고 14일 유지',
      '지원자 50명 제한',
    ],
  };

  Color get badgeColor => switch (this) {
    _ProductClass.a => const Color(0xFFB8860B), // 골드
    _ProductClass.b => AppColors.blue,
    _ProductClass.c => AppColors.textSecondary,
  };

  Color get badgeBg => switch (this) {
    _ProductClass.a => const Color(0xFFFFF8E1),
    _ProductClass.b => const Color(0xFFE8EAF6),
    _ProductClass.c => const Color(0xFFF0F0F0),
  };

  Color get cardBorder => switch (this) {
    _ProductClass.a => const Color(0xFFB8860B),
    _ProductClass.b => AppColors.blue,
    _ProductClass.c => AppColors.divider,
  };
}

/// 공고상품 선택 페이지 (/post-job/product/:draftId)
///
/// step 3: 상품 클래스(A/B/C) 선택 → 결제 → 게시
class JobProductSelectPage extends StatefulWidget {
  final String draftId;
  const JobProductSelectPage({super.key, required this.draftId});

  @override
  State<JobProductSelectPage> createState() => _JobProductSelectPageState();
}

class _JobProductSelectPageState extends State<JobProductSelectPage> {
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _loadError;

  JobPostData _previewData = JobPostData();
  Map<String, dynamic> _extraDraftFields = {};
  String? _clinicProfileId;
  List<Voucher> _vouchers = [];

  _ProductClass _selected = _ProductClass.b;
  bool _mouseOnLeft = false;

  late final ScrollController _previewScrollController;
  late final ScrollController _rightScrollController;
  final _sectionKeyA = GlobalKey();
  final _sectionKeyB = GlobalKey();
  final _sectionKeyC = GlobalKey();

  @override
  void initState() {
    super.initState();
    _previewScrollController = ScrollController();
    _rightScrollController = ScrollController();
    _loadDraft();
  }

  @override
  void dispose() {
    _previewScrollController.dispose();
    _rightScrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(_ProductClass cls) {
    // 고정 헤더(앱바 + 탭바) 높이 — 스크롤 목표 오프셋을 헤더 아래로 보정
    const kHeaderH = 82.0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_previewScrollController.hasClients) return;
      final key = switch (cls) {
        _ProductClass.a => _sectionKeyA,
        _ProductClass.b => _sectionKeyB,
        _ProductClass.c => _sectionKeyC,
      };
      final ctx = key.currentContext;
      if (ctx == null) return;
      final obj = ctx.findRenderObject();
      if (obj == null) return;
      final viewport = RenderAbstractViewport.of(obj);
      final double rawOffset = viewport.getOffsetToReveal(obj, 0.0).offset;
      _previewScrollController.animateTo(
        (rawOffset - kHeaderH).clamp(
          _previewScrollController.position.minScrollExtent,
          _previewScrollController.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _loadDraft() async {
    try {
      final draft = await JobDraftService.fetchDraft(widget.draftId);
      if (!mounted) return;
      if (draft == null) {
        setState(() {
          _isLoading = false;
          _loadError = '초안을 찾을 수 없어요. 목록에서 다시 선택해 주세요.';
        });
        return;
      }
      final vouchers = await VoucherService.getAvailableVouchers();
      if (!mounted) return;
      setState(() {
        _previewData = _buildPreviewDataFromDraft(draft);
        _extraDraftFields = _extractExtraFields(draft);
        _clinicProfileId = draft.clinicProfileId;
        _vouchers = vouchers;
        _isLoading = false;
      });
      _scrollToSection(_selected);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = '불러오기 실패: $e';
        });
      }
    }
  }

  JobPostData _buildPreviewDataFromDraft(JobDraft d) {
    final imageUrls = d.imageUrls;
    final images = imageUrls.map((u) {
      final seg = Uri.tryParse(u)?.pathSegments.last;
      final name = (seg?.isNotEmpty == true) ? seg! : 'image.jpg';
      return XFile(u, name: name);
    }).toList();
    return JobPostData(
      clinicName: d.clinicName,
      title: d.title,
      role: d.role,
      hireRoles: List.from(d.hireRoles),
      career: d.career,
      education: d.education,
      employmentType: d.employmentType,
      workHours: d.workHours,
      salary: d.salary,
      salaryPayType: d.salaryPayType,
      salaryAmount: d.salaryAmount,
      benefits: List.from(d.benefits),
      description: d.description,
      address: d.address,
      contact: d.contact,
      images: images,
      promotionalImageUrls: List.from(d.promotionalImageUrls),
      hospitalType: d.hospitalType,
      chairCount: d.chairCount,
      staffCount: d.staffCount,
      specialties: List.from(d.specialties),
      hasOralScanner: d.hasOralScanner,
      hasCT: d.hasCT,
      has3DPrinter: d.has3DPrinter,
      digitalEquipmentRaw: d.digitalEquipmentRaw,
      workDays: List.from(d.workDays),
      weekendWork: d.weekendWork,
      nightShift: d.nightShift,
      applyMethod: List.from(d.applyMethod),
    );
  }

  Map<String, dynamic> _extractExtraFields(JobDraft d) {
    final m = <String, dynamic>{};
    if (d.imageUrls.isNotEmpty) m['imageUrls'] = d.imageUrls;
    if (d.promotionalImageUrls.isNotEmpty) {
      m['promotionalImageUrls'] = d.promotionalImageUrls;
    }
    if (d.clinicProfileId != null) m['clinicProfileId'] = d.clinicProfileId;
    return m;
  }

  Future<void> _confirmPurchase() async {
    if (_isProcessing) return;

    final cid = _clinicProfileId;
    if (cid == null) {
      // clinicProfileId 없으면 ensureDefault 재시도
      final p = await ClinicProfileService.ensureDefaultProfileForDraft(
        draftId: widget.draftId,
        existingClinicProfileId: null,
      );
      if (!mounted || p == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '치과 프로필 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.',
              style: GoogleFonts.notoSansKr(fontSize: 14),
            ),
          ),
        );
        return;
      }
      setState(() => _clinicProfileId = p.id);
    }

    setState(() => _isProcessing = true);
    try {
      // 선택한 상품 클래스를 draft에 저장
      await JobDraftService.saveDraft(
        draftId: widget.draftId,
        formData: {
          ..._extraDraftFields,
          'productTier': _selected.tierKey,
          'productLabel': _selected.label,
          'currentStep': 'product_selected',
        },
      );

      final pid = _clinicProfileId!;
      final voucherId =
          _vouchers.isNotEmpty ? _vouchers.first.id : null;

      final orderResult = await OrderService.createOrder(
        draftId: widget.draftId,
        clinicProfileId: pid,
        voucherId: voucherId,
      );

      if (!mounted) return;

      if (!orderResult.requiresPayment) {
        // 공고권 전용(0원) → 바로 확인
        final confirmResult = await OrderService.confirmPayment(
          orderId: orderResult.orderId,
        );
        if (mounted && confirmResult.success) {
          context.go('/post-job/success/${confirmResult.jobId}');
        }
      } else {
        // 유료 결제 — 토스페이먼츠 결제창 호출
        final user = FirebaseAuth.instance.currentUser;
        await TossPaymentService.requestPayment(
          orderId: orderResult.orderId,
          orderName: '${_selected.label} 공고 게시 30일',
          amount: orderResult.amount,
          customerEmail: user?.email ?? '',
          customerName: user?.displayName,
        );
        // 결제창으로 이동 후 successUrl/failUrl 로 리다이렉트됨
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '결제 처리 중 오류가 발생했어요: $e',
              style: GoogleFonts.notoSansKr(fontSize: 14),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ══════════════════════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.webPublisherPageBg,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () =>
                context.canPop()
                    ? context.pop()
                    : context.go('/post-job/edit/${widget.draftId}'),
            icon: const Icon(Icons.arrow_back, size: 20),
            tooltip: '뒤로',
            style: IconButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              padding: const EdgeInsets.all(8),
              minimumSize: const Size(40, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const Spacer(),
          Text(
            '3. 공고상품 선택',
            style: GoogleFonts.notoSansKr(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          if (kIsWeb) const WebAccountMenuButton(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: AppColors.accent,
          ),
        ),
      );
    }
    if (_loadError != null) {
      return Center(
        child: Text(
          _loadError!,
          style: GoogleFonts.notoSansKr(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return _buildNarrowLayout();
        }
        return _buildWideLayout(constraints.maxHeight);
      },
    );
  }

  Widget _buildWideLayout(double maxH) {
    final phoneH = (maxH - 48).clamp(280.0, 844.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerSignal: (event) {
            if (event is! PointerScrollEvent) return;
            GestureBinding.instance.pointerSignalResolver.register(event, (e) {
              if (e is! PointerScrollEvent) return;
              final ctrl = _mouseOnLeft
                  ? _previewScrollController
                  : _rightScrollController;
              if (!ctrl.hasClients) return;
              final pos = ctrl.position;
              pos.jumpTo(
                (pos.pixels + e.scrollDelta.dy).clamp(
                  pos.minScrollExtent,
                  pos.maxScrollExtent,
                ),
              );
            });
          },
          child: MouseRegion(
            onHover: (event) {
              final isLeft =
                  event.localPosition.dx < constraints.maxWidth / 2;
              if (isLeft != _mouseOnLeft) {
                setState(() => _mouseOnLeft = isLeft);
              }
            },
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1320),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 좌측: 실제 앱 목록 카드 미리보기 ────────────────
                      Expanded(
                        flex: 46,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 28, 16, 28),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: _buildListingPreview(phoneH),
                          ),
                        ),
                      ),
                      Container(width: 1, color: AppColors.divider),
                      // ── 우측: 상품 선택 ─────────────────────────────────
                      Expanded(
                        flex: 54,
                        child: SingleChildScrollView(
                          controller: _rightScrollController,
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 560),
                              child: _buildProductPanel(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNarrowLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildListingPreview(480),
          const SizedBox(height: 24),
          _buildProductPanel(),
        ],
      ),
    );
  }

  // ── 실제 앱 채용 목록 미리보기 ──────────────────────────────────

  /// JobPostData + 선택 클래스 → Job 변환 (프리뷰 전용)
  Job _buildJobFromDraft({required int jobLevel}) {
    final d = _previewData;
    final imageUrls =
        (_extraDraftFields['imageUrls'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        d.images.map((x) => x.path).toList();
    return Job(
      id: widget.draftId,
      title: d.title,
      clinicName: d.clinicName,
      address: d.address,
      district: _districtFrom(d.address),
      lat: 0,
      lng: 0,
      type: d.role,
      career: d.career,
      salaryRange: const [0, 0],
      salaryText: d.salary,
      employmentType: d.employmentType,
      workHours: d.workHours,
      postedAt: DateTime.now(),
      details: d.description,
      benefits: List.from(d.benefits),
      images: imageUrls,
      jobLevel: jobLevel,
      matchScore: 78,
      education: d.education,
      hireRoles: List.from(d.hireRoles),
      hospitalType: d.hospitalType,
      chairCount: d.chairCount,
      staffCount: d.staffCount,
      specialties: List.from(d.specialties),
      promotionalImageUrls: List.from(d.promotionalImageUrls),
      workDays: List.from(d.workDays),
      weekendWork: d.weekendWork,
      nightShift: d.nightShift,
      applyMethod: List.from(d.applyMethod),
      tags: List.from(d.benefits),
      canApplyNow: false,
    );
  }

  /// 주소 문자열에서 최소 행정구역(동·읍·면 → 구·군 순) 추출
  String _districtFrom(String address) {
    final parts = address.trim().split(RegExp(r'\s+'));
    for (final p in parts) {
      if ((p.endsWith('동') || p.endsWith('읍') || p.endsWith('면')) &&
          p.length >= 3) return p;
    }
    for (final p in parts) {
      if ((p.endsWith('구') || p.endsWith('군')) && p.length >= 3) return p;
    }
    return parts.length >= 2 ? parts.take(2).join(' ') : address;
  }

  Widget _buildListingPreview(double phoneH) {
    return Center(
      child: SizedBox(
        width: 390,
        height: phoneH,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.appBg,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // ── 스크롤 가능 콘텐츠 (터치 비활성) ────────────────
              IgnorePointer(
                child: SingleChildScrollView(
                  controller: _previewScrollController,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(top: 82, bottom: 84),
                  child: _buildUnifiedListingContent(),
                ),
              ),
              // ── 고정 헤더 (앱바 + 소탭바) ────────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: AppColors.appBg,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _previewAppBar(),
                      _previewTabBar(),
                    ],
                  ),
                ),
              ),
              // ── 고정 하단 검색바 ─────────────────────────────────
              Positioned(
                bottom: 10,
                left: 12,
                right: 12,
                child: _previewBottomSearchBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewAppBar() {
    return Container(
      color: AppColors.appBg,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Text(
            '채용',
            style: GoogleFonts.notoSansKr(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          const Icon(Icons.search_rounded,
              size: 22, color: AppColors.textPrimary),
          const SizedBox(width: 8),
          const Icon(Icons.notifications_none_rounded,
              size: 22, color: AppColors.textPrimary),
        ],
      ),
    );
  }

  /// 실제 앱 CareerTabHeader / AppSegmentedControl 목업 (정적, 채용·지원 선택 고정)
  Widget _previewTabBar() {
    Widget tabItem(String label, bool selected) {
      return Expanded(
        child: Container(
          margin: const EdgeInsets.all(3),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.segmentSelected : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected
                  ? AppColors.onSegmentSelected
                  : AppColors.onSegmentUnselected,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          tabItem('채용 · 지원', true),
          tabItem('커리어 카드', false),
        ],
      ),
    );
  }

  // ── 단일 스크롤 콘텐츠 (전체 섹션 포함) ─────────────────────────

  Widget _buildUnifiedListingContent() {
    final cls = _selected;
    final aJob = cls == _ProductClass.a ? _buildJobFromDraft(jobLevel: 1) : null;
    final bJob = cls == _ProductClass.b ? _buildJobFromDraft(jobLevel: 2) : null;
    final cJob = cls == _ProductClass.c ? _buildJobFromDraft(jobLevel: 3) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _previewCareerSummary(),
        KeyedSubtree(key: _sectionKeyA, child: _previewSectionA(aJob)),
        KeyedSubtree(key: _sectionKeyB, child: _previewSectionB(bJob)),
        KeyedSubtree(key: _sectionKeyC, child: _previewSectionC(cJob)),
      ],
    );
  }

  /// 실제 앱 _CareerSummarySection 와 동일한 커리어 요약 텍스트
  Widget _previewCareerSummary() {
    return const Padding(
      padding: EdgeInsets.only(left: 20, right: 16, top: 2, bottom: 6),
      child: Text(
        '커리어 카드를 등록하면 맞춤 공고를 추천해드려요',
        style: TextStyle(
          fontSize: 11,
          color: AppColors.textDisabled,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  /// 실제 앱 _BottomSearchBar 외형 (하단 고정, 터치 없음)
  Widget _previewBottomSearchBar() {
    return Container(
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.textDisabled, size: 22),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '치과명, 동네로 검색',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textDisabled,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
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
          const SizedBox(width: 8),
          Container(
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
        ],
      ),
    );
  }

  /// 실제 앱 _PremiumGridSection·_Level2ListSection·_Level3Header 와 동일한
  /// 3px 세로 바 + 텍스트 섹션 헤더
  Widget _previewSectionBarHeader({
    required String title,
    String? subtitle,
    required Color barColor,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
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
              color: barColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: -0.3,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 6),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textDisabled,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Divider get _rowDivider => const Divider(
        height: 0.5,
        thickness: 0.5,
        indent: 16,
        endIndent: 16,
        color: AppColors.divider,
      );

  // ── A 클래스: 프리미엄 2열 그리드 ────────────────────────────────

  Widget _previewSectionA(Job? customerJob) {
    const itemH = 262.0;
    final customerIds = customerJob != null ? {customerJob.id} : <String>{};
    final mocks = mockLevel1Jobs
        .where((j) => !customerIds.contains(j.id))
        .take(customerJob != null ? 3 : 4)
        .toList();
    final allItems = [if (customerJob != null) customerJob, ...mocks];

    Widget gridPair(Job left, Job? right, {
      double leftOpacity = 1.0,
      double rightOpacity = 1.0,
    }) {
      Widget cell(Job j, double opacity) {
        final w = JobListingCardPremium(job: j, hideSamplePrefix: true);
        return Expanded(
          child: opacity < 1.0 ? Opacity(opacity: opacity, child: w) : w,
        );
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: SizedBox(
          height: itemH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cell(left, leftOpacity),
              const SizedBox(width: 10),
              right != null
                  ? cell(right, rightOpacity)
                  : const Expanded(child: SizedBox.shrink()),            ],
          ),
        ),
      );
    }

    final pairs = <Widget>[];
    for (int i = 0; i < allItems.length; i += 2) {
      final isCustomerRow = customerJob != null && i == 0;
      pairs.add(
        gridPair(
          allItems[i],
          i + 1 < allItems.length ? allItems[i + 1] : null,
          leftOpacity: isCustomerRow ? 1.0 : 0.28,
          rightOpacity: 0.28,
        ),
      );
    }

    return Container(
      color: AppColors.appBg,
      padding: const EdgeInsets.only(top: AppSpacing.xxl + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _previewSectionBarHeader(
            title: '추천 · 프리미엄',
            barColor: AppColors.accent,
          ),
          ...pairs,
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  // ── B 클래스: 추천 게시판형 행 ────────────────────────────────────

  Widget _previewSectionB(Job? customerJob) {
    final l1Ids = mockLevel1Jobs.map((j) => j.id).toSet();
    final baseMocks = mockLevel2Jobs
        .where((j) => !l1Ids.contains(j.id))
        .take(customerJob != null ? 3 : 4)
        .toList();
    final allRows = [if (customerJob != null) customerJob, ...baseMocks];

    return Container(
      color: AppColors.appBg,
      padding: const EdgeInsets.only(top: AppSpacing.xxl + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _previewSectionBarHeader(
            title: '추천 공고',
            subtitle: '커리어 카드 기반',
            barColor: AppColors.accent,
          ),
          for (int i = 0; i < allRows.length; i++) ...[
            Opacity(
              opacity: (customerJob != null && i == 0) ? 1.0 : 0.38,
              child: JobListingRowRecommended(job: allRows[i], hideSamplePrefix: true),
            ),
            if (i < allRows.length - 1) _rowDivider,
          ],
        ],
      ),
    );
  }

  // ── C 클래스: 전체 공고 텍스트형 행 ──────────────────────────────

  Widget _previewSectionC(Job? customerJob) {
    final l1Ids = mockLevel1Jobs.map((j) => j.id).toSet();
    final baseMocks = mockLevel2Jobs
        .where((j) => !l1Ids.contains(j.id))
        .take(customerJob != null ? 4 : 5)
        .toList();
    final allRows = [if (customerJob != null) customerJob, ...baseMocks];

    return Container(
      color: AppColors.appBg,
      padding: EdgeInsets.only(top: (AppSpacing.xxl + 4) * 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _previewSectionBarHeader(
            title: '전체 공고',
            subtitle: '최신 등록 순',
            barColor: AppColors.divider,
          ),
          for (int i = 0; i < allRows.length; i++) ...[
            Opacity(
              opacity: (customerJob != null && i == 0) ? 1.0 : 0.38,
              child: JobListingRowBasic(job: allRows[i], hideSamplePrefix: true),
            ),
            if (i < allRows.length - 1) _rowDivider,
          ],
        ],
      ),
    );
  }

  // ── 우측 상품 선택 패널 ──────────────────────────────────────

  Widget _buildProductPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '공고 상품을 선택해 주세요',
          style: GoogleFonts.notoSansKr(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '선택한 상품에 따라 공고 노출 방식이 달라져요.',
          style: GoogleFonts.notoSansKr(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        _buildClassCard(
          cls: _ProductClass.a,
          medal: '🥇',
          subtitle: '전국 유저에서 알림, 탭상단 고정 노출되는 가장 강력한 공고',
          baseClassLabel: 'B클래스 항목 전체 포함',
          features: const [
            ('🔔', '전국 모든 유저 알림 발송'),
            ('📍', '광고 영역 최상단 고정 배치'),
            ('🔁', '스크롤 중에도 상단 고정'),
            ('🗺', '지도 내 포인트 노출'),
            ('📈', '매칭 추천 최우선순위'),
          ],
        ),
        const SizedBox(height: 12),
        _buildClassCard(
          cls: _ProductClass.b,
          medal: '🥈',
          subtitle: '지역 기반으로 사진과 함께 노출되는 공고',
          baseClassLabel: 'C클래스 항목 전체 포함',
          features: const [
            ('🔔', '해당 시/도 유저 알림 발송'),
            ('📍', '광고 및 추천 영역 우선 노출'),
            ('📈', '매칭 추천에서 우대 노출'),
            ('🖼', "필터 적용 후 '전체 공고'에서도 사진 포함 노출"),
          ],
        ),
        const SizedBox(height: 12),
        _buildClassCard(
          cls: _ProductClass.c,
          medal: '🥉',
          subtitle: '부담 없이 채용을 시작하고 싶을 때',
          features: const [
            ('📄', '전체 공고 목록에 노출'),
            ('🗺', '지도 노출'),
            ('⏱', '노출 기간: 10일'),
          ],
        ),
        const SizedBox(height: 20),
        _buildComparisonTable(),
        const SizedBox(height: 20),
        if (_vouchers.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildVoucherChip(),
          ),
        SizedBox(
          height: AppPublisher.ctaHeight,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _confirmPurchase,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.white,
              disabledBackgroundColor: AppColors.disabledBg,
              disabledForegroundColor: AppColors.disabledText,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppPublisher.buttonRadius),
              ),
            ),
            child: _isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : Text(
                    _vouchers.isNotEmpty
                        ? '무료 공고권으로 게시하기  ·  ${_selected.label}'
                        : '${_selected.priceLabel}  ·  결제하고 게시하기',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.notoSansKr(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
              children: [
                const TextSpan(text: '결제 진행 시 '),
                TextSpan(
                  text: '이용약관',
                  style: const TextStyle(
                    decoration: TextDecoration.underline,
                    color: AppColors.blue,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => context.push('/terms'),
                ),
                const TextSpan(text: ', '),
                TextSpan(
                  text: '개인정보처리방침',
                  style: const TextStyle(
                    decoration: TextDecoration.underline,
                    color: AppColors.blue,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => context.push('/privacy'),
                ),
                const TextSpan(text: ', '),
                TextSpan(
                  text: '환불 및 청약철회 정책',
                  style: const TextStyle(
                    decoration: TextDecoration.underline,
                    color: AppColors.blue,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => context.push('/refund'),
                ),
                const TextSpan(text: '에 동의한 것으로 봅니다.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildClassCard({
    required _ProductClass cls,
    required String medal,
    required String subtitle,
    required List<(String, String)> features,
    String? baseClassLabel,
  }) {
    final isSelected = _selected == cls;
    return GestureDetector(
      onTap: () {
        setState(() => _selected = cls);
        _scrollToSection(cls);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8EAF6) : AppColors.white,
          borderRadius: BorderRadius.circular(AppPublisher.buttonRadius),
          border: Border.all(
            color: isSelected ? AppColors.blue : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 헤더 ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 선택 라디오
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(top: 2, right: 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? AppColors.blue : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.blue
                            : AppColors.textDisabled,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check,
                            size: 12, color: AppColors.white)
                        : null,
                  ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '$medal ${cls.label}',
                                  style: GoogleFonts.notoSansKr(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected
                                        ? AppColors.blue
                                        : AppColors.textPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                TextSpan(
                                  text: ' · ',
                                  style: GoogleFonts.notoSansKr(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                    height: 1.35,
                                  ),
                                ),
                                TextSpan(
                                  text: subtitle,
                                  style: GoogleFonts.notoSansKr(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          cls.priceLabel,
                          style: GoogleFonts.notoSansKr(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? AppColors.blue
                                : AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ── 기본 클래스 포함 뱃지 ─────────────────────────
            if (baseClassLabel != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.blue.withValues(alpha: 0.10)
                        : AppColors.surfaceMuted,
                    borderRadius:
                        BorderRadius.circular(AppPublisher.softRadius),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 13,
                        color: isSelected
                            ? AppColors.blue
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        baseClassLabel,
                        style: GoogleFonts.notoSansKr(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? AppColors.blue
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // ── 추가 항목 레이블 (baseClassLabel 있을 때) ──────
            if (baseClassLabel != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 0.5,
                        color: AppColors.divider,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '+ 추가 혜택',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDisabled,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 0.5,
                        color: AppColors.divider,
                      ),
                    ),
                  ],
                ),
              ),
            // ── 기능 목록 (2열) ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
              child: _buildFeatureTwoColumn(features),
            ),
          ],
        ),
      ),
    );
  }

  /// 클래스 카드 혜택 목록 — 2열 그리드, 본문 색상은 검정 계열([AppColors.textPrimary])
  Widget _buildFeatureTwoColumn(List<(String, String)> features) {
    const color = AppColors.textPrimary;
    final rows = <Widget>[];
    for (var i = 0; i < features.length; i += 2) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _featureItem(features[i], color)),
              const SizedBox(width: 10),
              if (i + 1 < features.length)
                Expanded(child: _featureItem(features[i + 1], color))
              else
                const Expanded(child: SizedBox()),
            ],
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }

  Widget _featureItem((String, String) f, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          f.$1,
          style: TextStyle(fontSize: 13, color: color),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            f.$2,
            style: GoogleFonts.notoSansKr(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonTable() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppPublisher.buttonRadius),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 헤더
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppPublisher.buttonRadius),
                topRight: Radius.circular(AppPublisher.buttonRadius),
              ),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Expanded(
                  flex: 5,
                  child: Text('📌 항목',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      )),
                ),
                _tableHead('A 프리미엄'),
                _tableHead('B 추천'),
                _tableHead('C 일반'),
              ],
            ),
          ),
          _tableRow('알림 발송', '전국 전체', '지역(시/도)', '없음'),
          _tableRow('광고 노출', '최상단', '우선 노출', '없음'),
          _tableRow('반복 노출', '강함', '중간', '없음'),
          _tableRow('매칭 우대', '최고', '우대', '없음'),
          _tableRow('전체 공고', '사진 상단', '사진 포함', '기본'),
          _tableRow('노출 기간', '10일', '10일', '10일', isLast: true),
        ],
      ),
    );
  }

  Widget _tableHead(String text) {
    return Expanded(
      flex: 3,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _tableRow(
    String label,
    String a,
    String b,
    String c, {
    bool isLast = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.divider, width: 0.5),
              ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          _tableCell(a, highlight: true),
          _tableCell(b),
          _tableCell(c, dim: true),
        ],
      ),
    );
  }

  Widget _tableCell(String text,
      {bool highlight = false, bool dim = false}) {
    return Expanded(
      flex: 3,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
          color: highlight
              ? AppColors.blue
              : dim
                  ? AppColors.textDisabled
                  : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildVoucherChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppPublisher.buttonRadius),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard_rounded,
              size: 18, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '무료 공고권 ${_vouchers.length}장 보유 — 결제 없이 바로 게시할 수 있어요',
              style: GoogleFonts.notoSansKr(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
