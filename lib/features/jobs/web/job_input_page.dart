import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/router/app_route_observer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../services/job_draft_service.dart';
import '../../../models/job.dart';
import '../../../models/job_draft.dart';
import '../services/job_image_uploader.dart';
import '../utils/job_image_attach_helpers.dart';
import 'web_file_drop_zone.dart';

/// 공고 자료 입력 페이지 (/post-job/input)
///
/// 좌우 2-column 레이아웃:
///   - 좌측: 임시·게시 공고 목록 (초안 + 게시)
///   - 우측: 새로 만들기 (2단 슬라이드: 치과·홍보 → 캡처·텍스트 AI)
class JobInputPage extends StatefulWidget {
  const JobInputPage({super.key});

  @override
  State<JobInputPage> createState() => _JobInputPageState();
}

class _JobInputPageState extends State<JobInputPage> with RouteAware {
  /// 0: 치과 이미지, 1: 홍보 이미지 (1번째 슬라이드)
  int _tabSlide0 = 0;
  /// 0: 캡처 AI, 1: 텍스트 AI (2번째 슬라이드)
  int _tabSlide1 = 0;
  /// 0: 치과·홍보 슬라이드, 1: 캡처·텍스트 슬라이드
  int _wizardPage = 0;
  late final PageController _wizardPageController;

  final GlobalKey _clinicDropKey = GlobalKey();
  final GlobalKey _promoDropKey = GlobalKey();
  final GlobalKey _captureDropKey = GlobalKey();

  BorderRadius get _thumbRadius =>
      BorderRadius.circular(AppPublisher.softRadius);

  static const double _wizardPanelHeight = 440;

  // ── 치과 이미지 (편집기 자료 첨부 · imageUrls) ───────────
  final List<XFile> _clinicImages = [];
  final Map<String, Uint8List> _clinicCache = {};
  bool _clinicDropActive = false;

  // ── 홍보이미지 상태 ─────────────────────────────────────
  final List<XFile> _promoImages = [];
  final Map<String, Uint8List> _promoCache = {};
  bool _promoDropActive = false;

  // ── 캡처이미지 상태 ─────────────────────────────────────
  final List<XFile> _captureImages = [];
  final Map<String, Uint8List> _captureCache = {};
  bool _captureDropActive = false;

  final _textCtrl = TextEditingController();
  bool _isLoading = false;

  /// 복사 중인 임시저장 ID (해당 행에 로딩 표시)
  String? _busyCopyDraftId;
  /// 복사 중인 게시 공고 ID
  String? _busyCopyJobId;

  bool get _copyInFlight =>
      _busyCopyDraftId != null || _busyCopyJobId != null;

  /// 2번째 슬라이드에서 캡처/텍스트로 AI 초안 가능 여부
  bool get _hasAiReadyOnSlide2 =>
      (_tabSlide1 == 0 && _captureImages.isNotEmpty) ||
      (_tabSlide1 == 1 && _textCtrl.text.trim().length >= 10);

  bool get _hasMaterialsOnSlide1 =>
      _clinicImages.isNotEmpty || _promoImages.isNotEmpty;

  void _resetNewJobForm() {
    if (!mounted) return;
    setState(() {
      _clinicImages.clear();
      _clinicCache.clear();
      _promoImages.clear();
      _promoCache.clear();
      _captureImages.clear();
      _captureCache.clear();
      _textCtrl.clear();
      _tabSlide0 = 0;
      _tabSlide1 = 0;
      _wizardPage = 0;
      _clinicDropActive = false;
      _promoDropActive = false;
      _captureDropActive = false;
      _isLoading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_wizardPageController.hasClients) {
        _wizardPageController.jumpToPage(0);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _wizardPageController = PageController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _wizardPageController.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _resetNewJobForm();
  }

  static DateTime? _draftEventTime(JobDraft d) => d.updatedAt ?? d.createdAt;

  /// 상대 시각 (예: 0분 전, 30분 전, 2일 전). [isNewest]이면 접미사 `(최신)`.
  static String _relativeTimeLabel(DateTime t, {required bool isNewest}) {
    final now = DateTime.now();
    var diff = now.difference(t);
    if (diff.isNegative) diff = Duration.zero;

    final String core;
    if (diff.inMinutes < 1) {
      core = '0분 전';
    } else if (diff.inHours < 1) {
      core = '${diff.inMinutes}분 전';
    } else if (diff.inDays < 1) {
      core = '${diff.inHours}시간 전';
    } else {
      core = '${diff.inDays}일 전';
    }
    return isNewest ? '$core(최신)' : core;
  }

  static String _exactDateTimeLabel(DateTime t) =>
      DateFormat('yyyy.MM.dd HH:mm').format(t);

  // ══════════════════════════════════════════════════════════
  // 이미지 공통 헬퍼
  // ══════════════════════════════════════════════════════════

  Future<void> _appendImages(
    List<XFile> files,
    List<XFile> target,
    Map<String, Uint8List> cache, {
    int max = 10,
  }) async {
    if (files.isEmpty) return;
    final remaining = max - target.length;
    if (remaining <= 0) return;
    final allowed = <XFile>[];
    for (final f in files) {
      if (!isAllowedJobImageFileName(f.name)) continue;
      allowed.add(f);
      if (allowed.length >= remaining) break;
    }
    if (allowed.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '지원 이미지(jpg, png, gif, webp 등)만 추가할 수 있어요.',
              style: GoogleFonts.notoSansKr(fontSize: 14),
            ),
          ),
        );
      }
      return;
    }
    for (final f in allowed) {
      if (!cache.containsKey(f.name)) {
        cache[f.name] = await f.readAsBytes();
      }
    }
    setState(() {
      target.addAll(allowed);
      if (target.length > max) target.removeRange(max, target.length);
    });
  }

  Future<void> _pickAndAppend(
    List<XFile> target,
    Map<String, Uint8List> cache, {
    int max = 10,
  }) async {
    final remaining = max - target.length;
    if (remaining <= 0) return;
    final picked = await ImagePicker().pickMultiImage(limit: remaining);
    if (picked.isEmpty) return;
    await _appendImages(picked, target, cache, max: max);
  }

  // ══════════════════════════════════════════════════════════
  // 진행 여부 · CTA
  // ══════════════════════════════════════════════════════════

  bool get _canProceed {
    if (_wizardPage == 0) return true;
    if (_hasAiReadyOnSlide2) return true;
    if (_hasMaterialsOnSlide1) return true;
    return false;
  }

  String get _ctaLabel {
    if (_wizardPage == 0) return '다음 단계';
    if (_hasAiReadyOnSlide2) return 'AI 초안 생성하기';
    if (_hasMaterialsOnSlide1) return '편집기로 이동';
    return 'AI 초안 생성하기';
  }

  Future<void> _proceed() async {
    if (!_canProceed) return;
    if (_wizardPage == 0) {
      await _wizardPageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final tempJobId = 'tmp_${const Uuid().v4()}';
      final clinicUrls = _clinicImages.isEmpty
          ? <String>[]
          : await JobImageUploader.uploadImages(
              jobId: tempJobId, images: _clinicImages);
      final promoUrls = _promoImages.isEmpty
          ? <String>[]
          : await JobImageUploader.uploadImages(
              jobId: tempJobId, images: _promoImages);

      if (_hasAiReadyOnSlide2) {
        if (_tabSlide1 == 0) {
          final captureUrls = await JobImageUploader.uploadImages(
            jobId: tempJobId,
            images: _captureImages,
          );
          final draftId = await JobDraftService.saveDraft(formData: {
            if (clinicUrls.isNotEmpty) 'imageUrls': clinicUrls,
            if (promoUrls.isNotEmpty) 'promotionalImageUrls': promoUrls,
            'rawImageUrls': captureUrls,
            'sourceType': 'image',
            'currentStep': 'input',
            'aiParseStatus': 'idle',
          });
          if (!mounted || draftId == null) return;
          context.push('/post-job/edit/$draftId',
              extra: {'sourceType': 'image'});
        } else {
          final draftId = await JobDraftService.saveDraft(formData: {
            if (clinicUrls.isNotEmpty) 'imageUrls': clinicUrls,
            if (promoUrls.isNotEmpty) 'promotionalImageUrls': promoUrls,
            'rawInputText': _textCtrl.text.trim(),
            'sourceType': 'text',
            'currentStep': 'input',
            'aiParseStatus': 'idle',
          });
          if (!mounted || draftId == null) return;
          context.push('/post-job/edit/$draftId',
              extra: {'sourceType': 'text'});
        }
      } else {
        final onlyPromo = clinicUrls.isEmpty && promoUrls.isNotEmpty;
        final draftId = await JobDraftService.saveDraft(formData: {
          if (clinicUrls.isNotEmpty) 'imageUrls': clinicUrls,
          if (promoUrls.isNotEmpty) 'promotionalImageUrls': promoUrls,
          'sourceType': 'promotional',
          'currentStep': 'ai_generated',
          'aiParseStatus': 'done',
          'editorStep': onlyPromo ? 'step3' : 'step1',
        });
        if (!mounted || draftId == null) return;
        context.push('/post-job/edit/$draftId',
            extra: {'sourceType': 'promotional'});
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장 중 오류가 발생했어요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _goFromScratch() async {
    setState(() => _isLoading = true);
    try {
      final draftId = await JobDraftService.saveDraft(formData: {
        'sourceType': 'manual',
        'currentStep': 'ai_generated',
        'aiParseStatus': 'done',
        'editorStep': 'step3',
      });
      if (!mounted || draftId == null) return;
      context.push('/post-job/edit/$draftId',
          extra: {'sourceType': 'manual'});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('생성 중 오류가 발생했어요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ══════════════════════════════════════════════════════════
  // 드래프트 삭제 확인
  // ══════════════════════════════════════════════════════════

  Future<void> _confirmDeleteDraft(JobDraft d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '임시저장 삭제',
          style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w700),
        ),
        content: Text(
          '"${d.displayTitle}" 초안을 삭제할까요?\n삭제 후에는 복구할 수 없어요.',
          style: GoogleFonts.notoSansKr(fontSize: 14, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('취소',
                style: GoogleFonts.notoSansKr(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final deleted = await JobDraftService.deleteDraft(d.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted ? '삭제했어요.' : '삭제에 실패했어요. 다시 시도해 주세요.',
          style: GoogleFonts.notoSansKr(),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // 복사 → 새 임시저장 + 편집 화면
  // ══════════════════════════════════════════════════════════

  Future<void> _copyDraft(JobDraft d) async {
    if (!d.hasContent) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '복사할 내용이 없어요. 제목·내용 등을 입력한 뒤 다시 시도해 주세요.',
            style: GoogleFonts.notoSansKr(fontSize: 14),
          ),
        ),
      );
      return;
    }
    setState(() => _busyCopyDraftId = d.id);
    try {
      final newId = await JobDraftService.saveDraftAsCopyFromDraft(d);
      if (!mounted) return;
      if (newId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '복사에 실패했어요. 잠시 후 다시 시도해 주세요.',
              style: GoogleFonts.notoSansKr(fontSize: 14),
            ),
          ),
        );
        return;
      }
      context.push('/post-job/edit/$newId', extra: {'sourceType': 'copy'});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '복사 중 오류가 발생했어요.',
              style: GoogleFonts.notoSansKr(fontSize: 14),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyCopyDraftId = null);
    }
  }

  Future<void> _copyPublishedJob(QueryDocumentSnapshot doc) async {
    setState(() => _busyCopyJobId = doc.id);
    try {
      final json = doc.data() as Map<String, dynamic>;
      final job = Job.fromJson(json, docId: doc.id);
      final newId = await JobDraftService.saveDraftAsCopyFromPublishedJob(job);
      if (!mounted) return;
      if (newId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '복사에 실패했어요. 잠시 후 다시 시도해 주세요.',
              style: GoogleFonts.notoSansKr(fontSize: 14),
            ),
          ),
        );
        return;
      }
      context.push('/post-job/edit/$newId', extra: {'sourceType': 'copy'});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '복사 중 오류가 발생했어요.',
              style: GoogleFonts.notoSansKr(fontSize: 14),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyCopyJobId = null);
    }
  }

  // ══════════════════════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.webPublisherPageBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildLeftColumn()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 39),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 52),
                            child: Container(
                              width: 1,
                              height: 108,
                              decoration: BoxDecoration(
                                color: AppColors.divider,
                                borderRadius: BorderRadius.circular(0.5),
                              ),
                            ),
                          ),
                        ),
                        Expanded(child: _buildRightColumn()),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // 좌측: 임시 / 게시 목록
  // ══════════════════════════════════════════════════════════

  static const double _leftListCardHeight = 68;
  static const double _leftSideIconWidth = 40;

  TextStyle get _leftSectionSubtitleStyle => GoogleFonts.notoSansKr(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  Widget _buildLeftColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '임시 / 게시된 공고로 만들기',
          style: GoogleFonts.notoSansKr(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 20),
        Text('임시저장 공고', style: _leftSectionSubtitleStyle),
        const SizedBox(height: 10),
        _buildDraftsSection(),
        const SizedBox(height: 22),
        const Divider(height: 1, thickness: 1, color: AppColors.divider),
        const SizedBox(height: 22),
        Text('사용된 공고', style: _leftSectionSubtitleStyle),
        const SizedBox(height: 10),
        _buildPublishedSection(),
      ],
    );
  }

  Widget _buildLeftSideIconAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    bool busy = false,
    required Color iconColor,
  }) {
    return SizedBox(
      width: _leftSideIconWidth,
      height: _leftListCardHeight,
      child: Tooltip(
        message: tooltip,
        child: busy
            ? Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.blue,
                  ),
                ),
              )
            : IconButton(
                onPressed: onTap,
                icon: Icon(icon, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: _leftSideIconWidth,
                  minHeight: 40,
                ),
                style: IconButton.styleFrom(
                  foregroundColor: iconColor,
                  disabledForegroundColor: iconColor.withValues(alpha: 0.35),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
      ),
    );
  }

  Widget _buildDraftsSection() {
    return StreamBuilder<List<JobDraft>>(
      stream: JobDraftService.watchMyDrafts(),
      builder: (context, snap) {
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return _emptyHint('임시저장된 공고가 없어요.');
        }
        final shown = list.take(8).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < shown.length; i++)
              _buildDraftCard(shown[i], isNewest: i == 0),
          ],
        );
      },
    );
  }

  Widget _buildDraftTimeTexts(JobDraft d, {required bool isNewest}) {
    final t = _draftEventTime(d);
    if (t == null) {
      return Text(
        '저장 시각 없음',
        textAlign: TextAlign.right,
        style: GoogleFonts.notoSansKr(
          fontSize: 11,
          color: AppColors.white.withValues(alpha: 0.78),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _relativeTimeLabel(t, isNewest: isNewest),
          textAlign: TextAlign.right,
          style: GoogleFonts.notoSansKr(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.white.withValues(alpha: 0.92),
          ),
        ),
        Text(
          _exactDateTimeLabel(t),
          textAlign: TextAlign.right,
          style: GoogleFonts.notoSansKr(
            fontSize: 10,
            height: 1.2,
            color: AppColors.white.withValues(alpha: 0.78),
          ),
        ),
      ],
    );
  }

  Widget _buildDraftCard(JobDraft d, {required bool isNewest}) {
    final r = BorderRadius.circular(AppPublisher.buttonRadius);
    final line = BorderSide(color: AppColors.white.withValues(alpha: 0.35));
    final copyBusy = _busyCopyDraftId == d.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        height: _leftListCardHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => context.push('/post-job/edit/${d.id}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.white,
                  backgroundColor: AppColors.blue,
                  side: line,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: const Size.fromHeight(_leftListCardHeight),
                  shape: RoundedRectangleBorder(borderRadius: r),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        d.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSansKr(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildDraftTimeTexts(d, isNewest: isNewest),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.white.withValues(alpha: 0.75),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 2),
            _buildLeftSideIconAction(
              icon: Icons.content_copy_rounded,
              tooltip: d.hasContent ? '복사해서 새로 편집' : '복사할 내용이 없어요',
              busy: copyBusy,
              iconColor: AppColors.blue,
              onTap: (d.hasContent && !_copyInFlight)
                  ? () => _copyDraft(d)
                  : null,
            ),
            _buildLeftSideIconAction(
              icon: Icons.delete_outline,
              tooltip: '삭제',
              iconColor: AppColors.destructive,
              onTap: () => _confirmDeleteDraft(d),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPublishedSection() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .where('createdBy', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _emptyHint('사용된 공고가 없어요.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < docs.length; i++)
              _buildPublishedCard(docs[i], isNewest: i == 0),
          ],
        );
      },
    );
  }

  Widget _buildPublishedTimeTexts(DateTime? t, {required bool isNewest}) {
    if (t == null) {
      return Text(
        '—',
        textAlign: TextAlign.right,
        style: GoogleFonts.notoSansKr(
          fontSize: 11,
          color: AppColors.white.withValues(alpha: 0.78),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _relativeTimeLabel(t, isNewest: isNewest),
          textAlign: TextAlign.right,
          style: GoogleFonts.notoSansKr(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.white.withValues(alpha: 0.92),
          ),
        ),
        Text(
          _exactDateTimeLabel(t),
          textAlign: TextAlign.right,
          style: GoogleFonts.notoSansKr(
            fontSize: 10,
            height: 1.2,
            color: AppColors.white.withValues(alpha: 0.78),
          ),
        ),
      ],
    );
  }

  Widget _buildPublishedCard(QueryDocumentSnapshot doc,
      {required bool isNewest}) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] as String? ?? '(제목 없음)';
    final clinicName = data['clinicName'] as String? ?? '';
    final status = data['status'] as String? ?? 'pending';
    final createdAt = data['createdAt'] as Timestamp?;
    final createdDate = createdAt?.toDate();

    final r = BorderRadius.circular(AppPublisher.buttonRadius);
    final line = BorderSide(color: AppColors.white.withValues(alpha: 0.35));
    final copyBusy = _busyCopyJobId == doc.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Material(
              color: AppColors.blue,
              borderRadius: r,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.push('/publisher/jobs/${doc.id}'),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: r,
                    border: Border.fromBorderSide(line),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _statusChip(status, onBlue: true),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.notoSansKr(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildPublishedTimeTexts(createdDate,
                                isNewest: isNewest),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: AppColors.white.withValues(alpha: 0.75),
                            ),
                          ],
                        ),
                        if (clinicName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            clinicName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.notoSansKr(
                              fontSize: 11,
                              color: AppColors.white.withValues(alpha: 0.78),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 2),
          _buildLeftSideIconAction(
            icon: Icons.content_copy_rounded,
            tooltip: '복사해서 새로 편집',
            busy: copyBusy,
            iconColor: AppColors.blue,
            onTap: !_copyInFlight ? () => _copyPublishedJob(doc) : null,
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status, {bool onBlue = false}) {
    final (label, color) = switch (status) {
      'active' => ('게시중', AppColors.accent),
      'closed' => ('마감', AppColors.textDisabled),
      'rejected' => ('반려', AppColors.error),
      _ => ('대기', AppColors.textSecondary),
    };
    if (onBlue) {
      final chipText = switch (status) {
        'rejected' => const Color(0xFFFFC9C9),
        _ => AppColors.white,
      };
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(AppPublisher.softRadius),
        ),
        child: Text(
          label,
          style: GoogleFonts.notoSansKr(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: chipText,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppPublisher.softRadius),
      ),
      child: Text(
        label,
        style: GoogleFonts.notoSansKr(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _emptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        text,
        style: GoogleFonts.notoSansKr(
          fontSize: 13,
          color: AppColors.textDisabled,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // 우측: 새로 만들기
  // ══════════════════════════════════════════════════════════

  Widget _buildRightColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '새로 만들기',
          style: GoogleFonts.notoSansKr(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '타이핑 없이, 1분 만에 공고 만들기',
          style: GoogleFonts.notoSansKr(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        _buildWizardShell(),
        const SizedBox(height: 28),
        _buildCtaRow(),
        const SizedBox(height: 12),
        _buildFromScratchButton(),
      ],
    );
  }

  Widget _buildWizardShell() {
    return SizedBox(
      height: _wizardPanelHeight,
      child: PageView(
        controller: _wizardPageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _wizardPage = i),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildWizardTabRow(
                labels: const ['치과 이미지 업로드', '홍보 이미지 업로드'],
                selected: _tabSlide0,
                onSelect: (i) => setState(() => _tabSlide0 = i),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildSlide0Body(),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildWizardTabRow(
                labels: const ['캡처 이미지 AI 추출', '텍스트 AI추출'],
                selected: _tabSlide1,
                onSelect: (i) => setState(() => _tabSlide1 = i),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildSlide1Body(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWizardTabRow({
    required List<String> labels,
    required int selected,
    required ValueChanged<int> onSelect,
  }) {
    return Row(
      children: List.generate(labels.length, (i) {
        final isSel = selected == i;
        return Expanded(
          child: InkWell(
            onTap: () => onSelect(i),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 12,
                      fontWeight:
                          isSel ? FontWeight.w700 : FontWeight.w500,
                      color: isSel
                          ? AppColors.accent
                          : AppColors.textSecondary,
                      letterSpacing: -0.12,
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  height: 3,
                  alignment: Alignment.bottomCenter,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    height: isSel ? 3 : 1,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isSel ? AppColors.accent : AppColors.divider,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSlide0Body() {
    return switch (_tabSlide0) {
      0 => _buildImageUploadSection(
            images: _clinicImages,
            cache: _clinicCache,
            dropActive: _clinicDropActive,
            dropKey: _clinicDropKey,
            onPick: () => _pickAndAppend(_clinicImages, _clinicCache, max: 10),
            onRemove: (i) => setState(() {
              final r = _clinicImages.removeAt(i);
              _clinicCache.remove(r.name);
            }),
            onDropDone: (d) async {
              setState(() => _clinicDropActive = false);
              await _appendImages(
                flattenDropItems(d.files),
                _clinicImages,
                _clinicCache,
                max: 10,
              );
            },
            onWebDrop: (files) async {
              setState(() => _clinicDropActive = false);
              await _appendImages(files, _clinicImages, _clinicCache, max: 10);
            },
            onDragEnter: () => setState(() => _clinicDropActive = true),
            onDragExit: () => setState(() => _clinicDropActive = false),
            hint:
                '다음 화면 「자료 첨부」의 치과 이미지에 그대로 반영됩니다.\n(최대 10장)',
            title: '치과 내부·시설 사진을 올려주세요',
            maxImages: 10,
          ),
      1 => _buildImageUploadSection(
            images: _promoImages,
            cache: _promoCache,
            dropActive: _promoDropActive,
            dropKey: _promoDropKey,
            onPick: () => _pickAndAppend(_promoImages, _promoCache, max: 10),
            onRemove: (i) => setState(() {
              final r = _promoImages.removeAt(i);
              _promoCache.remove(r.name);
            }),
            onDropDone: (d) async {
              setState(() => _promoDropActive = false);
              await _appendImages(
                flattenDropItems(d.files),
                _promoImages,
                _promoCache,
                max: 10,
              );
            },
            onWebDrop: (files) async {
              setState(() => _promoDropActive = false);
              await _appendImages(files, _promoImages, _promoCache, max: 10);
            },
            onDragEnter: () => setState(() => _promoDropActive = true),
            onDragExit: () => setState(() => _promoDropActive = false),
            hint: '치과 소개·시설·분위기 사진 등\nAI 추출 없이 공고에 바로 게시됩니다.',
            title: '홍보용 이미지가 있으시다면 올려주세요',
            maxImages: 10,
          ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildSlide1Body() {
    return switch (_tabSlide1) {
      0 => _buildImageUploadSection(
            images: _captureImages,
            cache: _captureCache,
            dropActive: _captureDropActive,
            dropKey: _captureDropKey,
            onPick: () => _pickAndAppend(_captureImages, _captureCache, max: 8),
            onRemove: (i) => setState(() {
              final r = _captureImages.removeAt(i);
              _captureCache.remove(r.name);
            }),
            onDropDone: (d) async {
              setState(() => _captureDropActive = false);
              await _appendImages(
                flattenDropItems(d.files),
                _captureImages,
                _captureCache,
                max: 8,
              );
            },
            onWebDrop: (files) async {
              setState(() => _captureDropActive = false);
              await _appendImages(files, _captureImages, _captureCache, max: 8);
            },
            onDragEnter: () => setState(() => _captureDropActive = true),
            onDragExit: () => setState(() => _captureDropActive = false),
            hint: 'AI가 내용을 읽어 초안을 만들어 드려요(최대 8장).',
            title: '기존 게시물을 캡처해서 올려주세요',
            maxImages: 8,
          ),
      1 => _buildTextSection(),
      _ => const SizedBox.shrink(),
    };
  }

  // ── 이미지 업로드 공통 위젯 ───────────────────────────────

  Widget _buildImageUploadSection({
    required List<XFile> images,
    required Map<String, Uint8List> cache,
    required bool dropActive,
    required GlobalKey dropKey,
    required VoidCallback onPick,
    required void Function(int) onRemove,
    required Future<void> Function(DropDoneDetails) onDropDone,
    required Future<void> Function(List<XFile>) onWebDrop,
    required VoidCallback onDragEnter,
    required VoidCallback onDragExit,
    required String hint,
    required String title,
    int maxImages = 10,
  }) {
    final inner = Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '아래를 눌러 폴더에서 사진을 고르거나, 이미지를 이 영역으로 끌어다 놓을 수 있어요.',
            style: GoogleFonts.notoSansKr(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          if (images.isEmpty)
            GestureDetector(
              onTap: onPick,
              child: DottedBorder(
                borderType: BorderType.RRect,
                radius: Radius.circular(AppPublisher.softRadius),
                color: AppColors.accent.withValues(alpha: 0.38),
                strokeWidth: 1.2,
                dashPattern: const [6, 4],
                padding: EdgeInsets.zero,
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(AppPublisher.softRadius),
                    color: AppColors.accent.withValues(alpha: 0.03),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 36,
                            color: AppColors.accent.withValues(alpha: 0.5)),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          style: GoogleFonts.notoSansKr(
                            fontSize: 14,
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hint,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.notoSansKr(
                            fontSize: 11,
                            color: AppColors.textDisabled,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...images.asMap().entries.map((e) {
                  final bytes = cache[e.value.name];
                  return _thumbTile(bytes, () => onRemove(e.key));
                }),
                if (images.length < maxImages)
                  GestureDetector(
                    onTap: onPick,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: _thumbRadius,
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: const Icon(Icons.add,
                          color: AppColors.textDisabled),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );

    final dropChild = AnimatedContainer(
      key: kIsWeb ? dropKey : null,
      duration: const Duration(milliseconds: 150),
      padding:
          dropActive ? const EdgeInsets.only(left: 6) : EdgeInsets.zero,
      decoration: dropActive
          ? const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.accent, width: 3),
              ),
            )
          : null,
      child: inner,
    );

    if (kIsWeb) {
      return WebFileDropZone(
        boundaryKey: dropKey,
        onDrop: onWebDrop,
        onDragEntered: onDragEnter,
        onDragExited: onDragExit,
        child: dropChild,
      );
    }
    return DropTarget(
      onDragEntered: (_) => onDragEnter(),
      onDragExited: (_) => onDragExit(),
      onDragDone: onDropDone,
      child: dropChild,
    );
  }

  Widget _thumbTile(Uint8List? bytes, VoidCallback onRemove) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: _thumbRadius,
          border: Border.all(color: AppColors.divider),
        ),
        child: ClipRRect(
          borderRadius: _thumbRadius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (bytes != null)
                Image.memory(bytes, fit: BoxFit.cover)
              else
                const ColoredBox(
                  color: AppColors.webPublisherPageBg,
                  child: Icon(Icons.image_outlined,
                      color: AppColors.textDisabled),
                ),
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.black.withValues(alpha: 0.54),
                    ),
                    child: const Icon(Icons.close,
                        size: 11, color: AppColors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 텍스트 AI 추출 ────────────────────────────────────

  Widget _buildTextSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '공고 내용을 그대로 붙여넣어주세요',
            style: GoogleFonts.notoSansKr(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _textCtrl,
            maxLines: 10,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.notoSansKr(fontSize: 14, height: 1.6),
            decoration: InputDecoration(
              hintText:
                  '기존 채용 사이트, 메신저, 문서 등에 있는\n공고 텍스트를 복사해서 붙여넣어주세요.',
              hintStyle: GoogleFonts.notoSansKr(
                fontSize: 13,
                color: AppColors.textDisabled,
                height: 1.6,
              ),
              border: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.divider),
              ),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.divider),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide:
                    BorderSide(color: AppColors.accent, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  // ── CTA: 이전 단계(좌) + 주 버튼(우) 동일 높이 ───────────────

  static const double _ctaBackSlotWidth = 132;

  Widget _buildCtaRow() {
    return SizedBox(
      height: AppPublisher.ctaHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _ctaBackSlotWidth,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _wizardPage == 1
                  ? TextButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () {
                              _wizardPageController.previousPage(
                                duration: const Duration(milliseconds: 320),
                                curve: Curves.easeOutCubic,
                              );
                            },
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      label: Text(
                        '이전 단계',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          Expanded(child: _buildPrimaryCtaButton()),
        ],
      ),
    );
  }

  Widget _buildPrimaryCtaButton() {
    return ElevatedButton(
      onPressed: (_canProceed && !_isLoading) ? _proceed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.white,
        disabledBackgroundColor: AppColors.disabledBg,
        disabledForegroundColor: AppColors.disabledText,
        elevation: 0,
        minimumSize: const Size.fromHeight(AppPublisher.ctaHeight),
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(AppPublisher.buttonRadius),
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.white))
          : Text(
              _ctaLabel,
              style: GoogleFonts.notoSansKr(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.18,
              ),
            ),
    );
  }

  Widget _buildFromScratchButton() {
    return Center(
      child: TextButton(
        onPressed: _isLoading ? null : _goFromScratch,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: Text(
          '직접 작성하기',
          style: GoogleFonts.notoSansKr(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.textDisabled,
          ),
        ),
      ),
    );
  }
}
