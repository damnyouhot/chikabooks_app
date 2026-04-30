import 'dart:async';
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
import '../../../core/widgets/web_site_footer.dart';
import '../../../core/theme/app_tokens.dart';
import '../../auth/web/web_account_menu_button.dart';
import '../../../services/job_draft_service.dart';
import '../../../models/job.dart';
import '../../../models/job_draft.dart';
import '../../publisher/services/clinic_profile_service.dart';
import '../services/job_image_uploader.dart';
import '../utils/job_image_attach_helpers.dart';
import 'job_post_top_bar.dart';
import 'web_file_drop_zone.dart';

/// 공고 자료 입력 페이지 (/post-job/input)
///
/// 좌우 2-column (문서 DESIGN_PUBLISHER_JOBS.md, 최대 가로 1100px):
///   - 화면 **왼쪽** 열: 1분 만에 공고 만들기 (`_buildRightColumn`)
///   - 화면 **오른쪽** 열: 임시·게시 목록 (`_buildLeftColumn`)
///   - 양열은 동일 `Expanded(flex: 1)`; Row 가로는 `LayoutBuilder`로만 확정(무한 폭 끌어당김 방지)
class JobInputPage extends StatefulWidget {
  const JobInputPage({super.key});

  @override
  State<JobInputPage> createState() => _JobInputPageState();
}

class _JobInputPageState extends State<JobInputPage> with RouteAware {
  /// wizard 현재 단계: 0=홍보이미지, 1=캡처이미지, 2=텍스트추출
  int _wizardPage = 0;
  late final PageController _wizardPageController;

  final GlobalKey _promoDropKey = GlobalKey();
  final GlobalKey _captureDropKey = GlobalKey();

  BorderRadius get _thumbRadius =>
      BorderRadius.circular(AppPublisher.softRadius);

  static const double _wizardPanelHeight = 440;

  /// 마법사 열(`_buildRightColumn`) 높이 기준 세로 가운데에 두는 구분선 길이
  static const double _wizardDividerLineHeight = 280;

  /// 본문 2열 래퍼 최대 가로 (`docs/DESIGN_PUBLISHER_JOBS.md` /post-job/input)
  static const double _kInputPageMaxWidth = 1100;

  /// 양 열 사이 세로 구분선 좌우 패딩 합의값(한쪽)
  static const double _kColumnDividerPaddingH = 48;

  // ── 치과 이미지 (편집기 자료 첨부 · imageUrls) ───────────
  final List<XFile> _clinicImages = [];
  final Map<String, Uint8List> _clinicCache = {};

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

  /// 제출 진행 다이얼로그 ([_showSubmitProgressDialog]와 짝)
  StateSetter? _submitDialogSetState;
  String _submitStatusMessage = '';

  /// 분류별 업로드 진행(치과·홍보·캡처 …). null이면 단일 인디케이터·문구만 표시.
  List<double>? _submitPhaseProgress;
  List<String>? _submitPhaseLabels;
  Timer? _submitTipTimer;
  int _submitTipIndex = 0;
  bool _submitDialogPopped = false;

  /// 하단 로테이션 안내 — 기본 12pt 대비 1.5배·볼드
  static const double _submitTipFontSize = 12.0 * 1.5;

  /// 업로드·저장 대기 중 하단 안내 로테이션 (`_AiLoadingView` 톤과 맞춤)
  static const _submitMarketingTips = <String>[
    '사진만 올리면 급여·근무 조건까지\n초안으로 정리돼요.',
    '게시 전 사업자등록증 첨부와\n사업자 인증이 필수예요.',
    '추출이 끝나면 병원명·연락처를\n꼭 한 번 더 확인해 주세요.',
  ];

  /// 복사 중인 임시저장 ID (해당 행에 로딩 표시)
  String? _busyCopyDraftId;

  /// 복사 중인 게시 공고 ID
  String? _busyCopyJobId;

  bool get _copyInFlight => _busyCopyDraftId != null || _busyCopyJobId != null;

  Future<Map<String, dynamic>> _preferredClinicDraftFields() async {
    final profile = await ClinicProfileService.getPreferredProfileForJob();
    if (profile == null) return const {};
    return {
      'clinicProfileId': profile.id,
      if (profile.effectiveName.trim().isNotEmpty)
        'clinicName': profile.effectiveName.trim(),
      if (profile.address.trim().isNotEmpty) 'address': profile.address.trim(),
      if (profile.phone.trim().isNotEmpty) 'contact': profile.phone.trim(),
    };
  }

  /// 4번째 단계(page 3)에서 AI 추출 가능 여부
  bool get _hasAiReadyOnSlide2 =>
      _captureImages.isNotEmpty ||
      _promoImages.isNotEmpty ||
      _textCtrl.text.trim().length >= 10;

  bool get _hasMaterialsOnSlide1 => _promoImages.isNotEmpty;

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
      _wizardPage = 0;
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
    _submitTipTimer?.cancel();
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
    if (_wizardPage < 2) return true;
    if (_hasAiReadyOnSlide2) return true;
    if (_hasMaterialsOnSlide1) return true;
    return false;
  }

  String get _ctaLabel {
    if (_wizardPage < 2) return '다음';
    if (_hasAiReadyOnSlide2) return '추출 시작';
    if (_hasMaterialsOnSlide1) return '편집기로 이동';
    return '추출 시작';
  }

  void _resetSubmitProgressUi() {
    _submitDialogPopped = false;
    _submitDialogSetState = null;
    _submitPhaseProgress = null;
    _submitPhaseLabels = null;
    _submitStatusMessage = '';
    _submitTipIndex = 0;
  }

  /// 이번 제출에서 업로드되는 분류 순서(비어 있지 않은 배치만, 실제 업로드 순서와 동일)
  List<String> _buildUploadPhaseLabels() {
    final labels = <String>[];
    if (_clinicImages.isNotEmpty) labels.add('치과 내외부 사진');
    if (_promoImages.isNotEmpty) labels.add('홍보 이미지');
    if (_hasAiReadyOnSlide2 && _captureImages.isNotEmpty) {
      labels.add('캡처 이미지');
    }
    return labels;
  }

  void _startSubmitTipRotation() {
    _submitTipTimer?.cancel();
    _submitTipTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _submitTipIndex = (_submitTipIndex + 1) % _submitMarketingTips.length;
      _syncSubmitDialog();
    });
  }

  void _stopSubmitTipRotation() {
    _submitTipTimer?.cancel();
    _submitTipTimer = null;
  }

  void _syncSubmitDialog() {
    _submitDialogSetState?.call(() {});
  }

  void _dismissSubmitDialog() {
    if (_submitDialogPopped) return;
    _submitDialogPopped = true;
    _submitDialogSetState = null;
    if (!mounted) return;
    final nav = Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) nav.pop();
  }

  void _showSubmitProgressDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.black.withValues(alpha: 0.35),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setSt) {
            _submitDialogSetState = setSt;
            return PopScope(
              canPop: false,
              child: AlertDialog(
                backgroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppPublisher.inputPanelRadius,
                  ),
                ),
                content: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 300,
                    maxWidth: 400,
                  ),
                  child: _buildSubmitProgressDialogBody(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSubmitProgressDialogBody() {
    final tips = _submitMarketingTips;
    final tip = tips[_submitTipIndex % tips.length];
    final tipStyle = GoogleFonts.notoSansKr(
      fontSize: _submitTipFontSize,
      fontWeight: FontWeight.w800,
      color: AppColors.textSecondary,
      height: 1.45,
    );

    final labels = _submitPhaseLabels;
    final prog = _submitPhaseProgress;
    if (labels != null &&
        prog != null &&
        labels.length == prog.length &&
        labels.isNotEmpty) {
      final n = labels.length;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(n, (k) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          labels[k],
                          style: GoogleFonts.notoSansKr(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppPublisher.softRadius,
                          ),
                          child: LinearProgressIndicator(
                            value: prog[k].clamp(0.0, 1.0),
                            minHeight: 5,
                            backgroundColor: AppColors.divider,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(tip, textAlign: TextAlign.center, style: tipStyle),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppPublisher.softRadius),
          child: const LinearProgressIndicator(
            backgroundColor: AppColors.divider,
            color: AppColors.accent,
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _submitStatusMessage.isEmpty ? '처리 중이에요…' : _submitStatusMessage,
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSansKr(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 12),
        Text(tip, textAlign: TextAlign.center, style: tipStyle),
      ],
    );
  }

  Future<List<String>> _uploadBatchWithProgress({
    required String jobId,
    required List<XFile> images,
    required int phaseIndex,
    required int totalPhases,
  }) async {
    if (images.isEmpty) return [];
    final n = images.length;
    _submitStatusMessage = '';
    _syncSubmitDialog();

    final urls = await JobImageUploader.uploadImages(
      jobId: jobId,
      images: images,
      onProgress: (i, p) {
        if (!mounted) return;
        final agg = ((i + p) / n).clamp(0.0, 1.0);
        _submitPhaseProgress = List<double>.generate(totalPhases, (j) {
          if (j < phaseIndex) return 1.0;
          if (j == phaseIndex) return agg;
          return 0.0;
        });
        _syncSubmitDialog();
      },
    );
    if (mounted) {
      _submitPhaseProgress = List<double>.generate(totalPhases, (j) {
        if (j <= phaseIndex) return 1.0;
        return 0.0;
      });
      _syncSubmitDialog();
    }
    return urls;
  }

  Future<void> _proceed() async {
    if (!_canProceed) return;
    if (_wizardPage < 2) {
      await _wizardPageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    setState(() => _isLoading = true);
    _resetSubmitProgressUi();
    _submitStatusMessage = '준비하는 중이에요…';
    _showSubmitProgressDialog();
    await Future<void>.delayed(Duration.zero);
    _syncSubmitDialog();
    _startSubmitTipRotation();

    try {
      final phaseLabels = _buildUploadPhaseLabels();
      final totalPhases = phaseLabels.length;
      if (totalPhases > 0) {
        _submitPhaseLabels = phaseLabels;
        _submitPhaseProgress = List<double>.filled(totalPhases, 0.0);
        _submitStatusMessage = '';
      } else {
        _submitPhaseLabels = null;
        _submitPhaseProgress = null;
        _submitStatusMessage = '준비하는 중이에요…';
      }
      _syncSubmitDialog();

      final tempJobId = 'tmp_${const Uuid().v4()}';
      var phaseIndex = 0;

      final clinicUrls =
          _clinicImages.isNotEmpty
              ? await _uploadBatchWithProgress(
                jobId: tempJobId,
                images: _clinicImages,
                phaseIndex: phaseIndex++,
                totalPhases: totalPhases,
              )
              : <String>[];

      final promoUrls =
          _promoImages.isNotEmpty
              ? await _uploadBatchWithProgress(
                jobId: tempJobId,
                images: _promoImages,
                phaseIndex: phaseIndex++,
                totalPhases: totalPhases,
              )
              : <String>[];

      if (_hasAiReadyOnSlide2) {
        if (_captureImages.isNotEmpty || _promoImages.isNotEmpty) {
          final captureUrls =
              _captureImages.isNotEmpty
                  ? await _uploadBatchWithProgress(
                    jobId: tempJobId,
                    images: _captureImages,
                    phaseIndex: phaseIndex++,
                    totalPhases: totalPhases,
                  )
                  : <String>[];

          _submitPhaseLabels = null;
          _submitPhaseProgress = null;
          _submitStatusMessage = '초안을 저장하는 중이에요…';
          _syncSubmitDialog();

          final draftId = await JobDraftService.saveDraft(
            formData: {
              ...await _preferredClinicDraftFields(),
              if (clinicUrls.isNotEmpty) 'imageUrls': clinicUrls,
              if (promoUrls.isNotEmpty) 'promotionalImageUrls': promoUrls,
              'rawImageUrls': captureUrls,
              'sourceType': 'image',
              'currentStep': 'input',
              'aiParseStatus': 'idle',
            },
          );
          if (!mounted || draftId == null) return;
          _dismissSubmitDialog();
          context.push(
            '/post-job/edit/$draftId',
            extra: {'sourceType': 'image'},
          );
        } else {
          _submitPhaseLabels = null;
          _submitPhaseProgress = null;
          _submitStatusMessage = '초안을 저장하는 중이에요…';
          _syncSubmitDialog();

          final draftId = await JobDraftService.saveDraft(
            formData: {
              ...await _preferredClinicDraftFields(),
              if (clinicUrls.isNotEmpty) 'imageUrls': clinicUrls,
              if (promoUrls.isNotEmpty) 'promotionalImageUrls': promoUrls,
              'rawInputText': _textCtrl.text.trim(),
              'sourceType': 'text',
              'currentStep': 'input',
              'aiParseStatus': 'idle',
            },
          );
          if (!mounted || draftId == null) return;
          _dismissSubmitDialog();
          context.push(
            '/post-job/edit/$draftId',
            extra: {'sourceType': 'text'},
          );
        }
      } else {
        _submitPhaseLabels = null;
        _submitPhaseProgress = null;
        _submitStatusMessage = '초안을 저장하는 중이에요…';
        _syncSubmitDialog();

        final draftId = await JobDraftService.saveDraft(
          formData: {
            ...await _preferredClinicDraftFields(),
            if (clinicUrls.isNotEmpty) 'imageUrls': clinicUrls,
            if (promoUrls.isNotEmpty) 'promotionalImageUrls': promoUrls,
            'sourceType': 'promotional',
            'currentStep': 'ai_generated',
            'aiParseStatus': 'done',
            // 진입 단계는 항상 공고 상세(step2)부터 시작
            'editorStep': 'step2',
          },
        );
        if (!mounted || draftId == null) return;
        _dismissSubmitDialog();
        context.push(
          '/post-job/edit/$draftId',
          extra: {'sourceType': 'promotional'},
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('저장 중 오류가 발생했어요.')));
      }
    } finally {
      _stopSubmitTipRotation();
      _dismissSubmitDialog();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _goFromScratch() async {
    setState(() => _isLoading = true);
    _resetSubmitProgressUi();
    _submitStatusMessage = '빈 초안을 만드는 중이에요…';
    _showSubmitProgressDialog();
    await Future<void>.delayed(Duration.zero);
    _syncSubmitDialog();
    _startSubmitTipRotation();

    try {
      final draftId = await JobDraftService.saveDraft(
        formData: {
          ...await _preferredClinicDraftFields(),
          'sourceType': 'manual',
          'currentStep': 'ai_generated',
          'aiParseStatus': 'done',
          'editorStep': 'step2',
        },
      );
      if (!mounted || draftId == null) return;
      _dismissSubmitDialog();
      context.push('/post-job/edit/$draftId', extra: {'sourceType': 'manual'});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('생성 중 오류가 발생했어요.')));
      }
    } finally {
      _stopSubmitTipRotation();
      _dismissSubmitDialog();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ══════════════════════════════════════════════════════════
  // 드래프트 삭제 확인
  // ══════════════════════════════════════════════════════════

  Future<void> _confirmDeleteDraft(JobDraft d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
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
                child: Text(
                  '취소',
                  style: GoogleFonts.notoSansKr(color: AppColors.textSecondary),
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.destructive,
                ),
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
      if (d.clinicProfileId == null || d.clinicProfileId!.isEmpty) {
        final fields = await _preferredClinicDraftFields();
        if (fields.isNotEmpty) {
          await JobDraftService.saveDraft(draftId: newId, formData: fields);
        }
      }
      if (!mounted) return;
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
      final fields = await _preferredClinicDraftFields();
      if (fields.isNotEmpty) {
        await JobDraftService.saveDraft(draftId: newId, formData: fields);
      }
      if (!mounted) return;
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
    const outerPad = EdgeInsets.symmetric(horizontal: 20, vertical: 40);
    return Scaffold(
      backgroundColor: AppColors.webPublisherPageBg,
      body: Column(
        children: [
          // ── 상단 흰 띠: 공고 시작 ────────────────────
          if (kIsWeb)
            JobPostTopBar(
              currentStep: JobPostStep.input,
              prevStep: JobPostStep.home,
              onPrev: () => context.go('/login'),
              trailing: const WebAccountMenuButton(),
            ),
          // ── 본문 ────────────────────────────────────────────
          Expanded(
            child: Center(
              child: Padding(
                padding: outerPad,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _kInputPageMaxWidth,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final rowW = constraints.maxWidth;
                      return ListView(
                        shrinkWrap: true,
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            width: rowW,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: _buildRightColumn(),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: _kColumnDividerPaddingH,
                                  ),
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: Container(
                                      width: 1,
                                      height: _wizardDividerLineHeight,
                                      decoration: BoxDecoration(
                                        color: AppColors.divider,
                                        borderRadius: BorderRadius.circular(
                                          0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: _buildLeftColumn(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          if (kIsWeb) const WebSiteFooter(backgroundColor: AppColors.white),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // 우측 패널: 임시 / 게시 목록
  // ══════════════════════════════════════════════════════════

  static const double _leftListCardHeight = 76;
  static const double _leftSideIconWidth = 40;

  TextStyle get _leftSectionSubtitleStyle => GoogleFonts.notoSansKr(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  Widget _buildLeftColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
        child:
            busy
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
    final created = d.createdAt;
    final updated = d.updatedAt;
    final showCreatedLine =
        created != null &&
        updated != null &&
        updated.difference(created).inMinutes > 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '마지막 저장 · ${_relativeTimeLabel(t, isNewest: isNewest)}',
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
        if (showCreatedLine)
          Text(
            '처음 저장 ${_exactDateTimeLabel(created)}',
            textAlign: TextAlign.right,
            style: GoogleFonts.notoSansKr(
              fontSize: 9,
              height: 1.15,
              color: AppColors.white.withValues(alpha: 0.62),
            ),
          ),
      ],
    );
  }

  Future<String> _draftClinicName(JobDraft d) async {
    final pid = d.clinicProfileId;
    if (pid != null && pid.isNotEmpty) {
      final p = await ClinicProfileService.getProfile(pid);
      final name = p?.effectiveName.trim();
      if (name != null && name.isNotEmpty) return name;
    }
    final fallback = d.clinicName.trim();
    return fallback.isNotEmpty ? fallback : '치과 미선택';
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  minimumSize: const Size.fromHeight(_leftListCardHeight),
                  shape: RoundedRectangleBorder(borderRadius: r),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.notoSansKr(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          FutureBuilder<String>(
                            future: _draftClinicName(d),
                            builder: (context, snap) {
                              return Text(
                                snap.data ?? '치과 확인 중',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.notoSansKr(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.white.withValues(
                                    alpha: 0.68,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
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
              onTap:
                  (d.hasContent && !_copyInFlight) ? () => _copyDraft(d) : null,
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
      stream:
          FirebaseFirestore.instance
              .collection('jobDrafts')
              .where('ownerUid', isEqualTo: uid)
              .snapshots(),
      builder: (context, snap) {
        return StreamBuilder<QuerySnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('jobs')
                  .orderBy('createdAt', descending: true)
                  .limit(120)
                  .snapshots(),
          builder: (context, jobsSnap) {
            final draftDocs = snap.data?.docs ?? [];
            final jobDocs = jobsSnap.data?.docs ?? [];
            final publishedJobIds = _publishedJobIdsFromDrafts(draftDocs);
            final docs = _filterMyPublishedJobs(
              uid: uid,
              jobDocs: jobDocs,
              publishedJobIds: publishedJobIds,
            );

            if (docs.isEmpty) {
              if (snap.hasError || jobsSnap.hasError) {
                return _emptyHint('공고 목록을 불러오지 못했어요. 잠시 후 다시 확인해 주세요.');
              }
              if (snap.connectionState == ConnectionState.waiting ||
                  jobsSnap.connectionState == ConnectionState.waiting) {
                return _emptyHint('공고 목록을 불러오는 중이에요...');
              }
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
      },
    );
  }

  Set<String> _publishedJobIdsFromDrafts(List<QueryDocumentSnapshot> drafts) {
    final ids = <String>{};
    for (final doc in drafts) {
      final data = doc.data() as Map<String, dynamic>;
      final id = (data['publishedJobId'] as String?)?.trim();
      if (id != null && id.isNotEmpty) ids.add(id);
    }
    return ids;
  }

  List<QueryDocumentSnapshot> _filterMyPublishedJobs({
    required String uid,
    required List<QueryDocumentSnapshot> jobDocs,
    required Set<String> publishedJobIds,
  }) {
    final docs =
        jobDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['createdBy'] == uid ||
              data['ownerUid'] == uid ||
              data['clinicId'] == uid ||
              publishedJobIds.contains(doc.id);
        }).toList();
    docs.sort((a, b) {
      final at = _publishedSortTime(a);
      final bt = _publishedSortTime(b);
      return bt.compareTo(at);
    });
    return docs.take(10).toList();
  }

  DateTime _publishedSortTime(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    for (final key in ['createdAt', 'postedAt', 'adStartAt', 'updatedAt']) {
      final value = data[key];
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
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

  Widget _buildPublishedCard(
    QueryDocumentSnapshot doc, {
    required bool isNewest,
  }) {
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
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
                            _buildPublishedTimeTexts(
                              createdDate,
                              isNewest: isNewest,
                            ),
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
  // 좌측 패널: 1분 만에 공고 만들기
  // ══════════════════════════════════════════════════════════

  Widget _buildRightColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '1분 공고 만들기',
          style: GoogleFonts.notoSansKr(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '기존 공고를 그대로 캡처, 던져 넣으세요',
          style: GoogleFonts.notoSansKr(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        _buildWizardShell(),
      ],
    );
  }

  Widget _buildWizardShell() {
    return SizedBox(
      height: _wizardPanelHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 탭 인디케이터 — PageView 바깥에 고정
          _buildWizardStepIndicator(),
          const SizedBox(height: 12),
          // 콘텐츠만 PageView로 슬라이드
          Expanded(
            child: PageView(
              controller: _wizardPageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _wizardPage = i),
              children: [
                // Page 0: 홍보 이미지
                SingleChildScrollView(
                  child: _buildImageUploadSection(
                    images: _promoImages,
                    cache: _promoCache,
                    dropActive: _promoDropActive,
                    dropKey: _promoDropKey,
                    onPick:
                        () =>
                            _pickAndAppend(_promoImages, _promoCache, max: 10),
                    onRemove:
                        (i) => setState(() {
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
                      await _appendImages(
                        files,
                        _promoImages,
                        _promoCache,
                        max: 10,
                      );
                    },
                    onDragEnter: () => setState(() => _promoDropActive = true),
                    onDragExit: () => setState(() => _promoDropActive = false),
                    hint: '치과 소개·시설·분위기 사진 등\nAI 추출 없이 공고에 바로 게시됩니다.',
                    title: '홍보용 이미지가 있으시다면 올려주세요',
                    maxImages: 10,
                  ),
                ),
                // Page 1: 캡처 이미지
                SingleChildScrollView(
                  child: _buildImageUploadSection(
                    images: _captureImages,
                    cache: _captureCache,
                    dropActive: _captureDropActive,
                    dropKey: _captureDropKey,
                    onPick:
                        () => _pickAndAppend(
                          _captureImages,
                          _captureCache,
                          max: 8,
                        ),
                    onRemove:
                        (i) => setState(() {
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
                      await _appendImages(
                        files,
                        _captureImages,
                        _captureCache,
                        max: 8,
                      );
                    },
                    onDragEnter:
                        () => setState(() => _captureDropActive = true),
                    onDragExit:
                        () => setState(() => _captureDropActive = false),
                    hint: 'AI가 내용을 읽어 초안을 만들어 드려요(최대 8장).',
                    title: '기존 게시물을 캡처해서 올려주세요',
                    maxImages: 8,
                  ),
                ),
                // Page 2: 텍스트 추출
                SingleChildScrollView(child: _buildTextSection()),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // CTA 고정 — 슬라이드 밖
          _buildCtaRow(),
          const SizedBox(height: 12),
          _buildFromScratchButton(),
        ],
      ),
    );
  }

  Widget _buildWizardStepIndicator() {
    const steps = ['홍보 이미지', '캡처 이미지', '텍스트 추출'];
    return Row(
      children: List.generate(steps.length, (i) {
        final isCurrent = _wizardPage == i;
        return Expanded(
          child: GestureDetector(
            onTap:
                () => _wizardPageController.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                ),
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    steps[i],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 12,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color:
                          isCurrent
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
                    height: isCurrent ? 3 : 1,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isCurrent ? AppColors.accent : AppColors.divider,
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
            '클릭하거나 파일을 끌어 넣으세요',
            textAlign: TextAlign.center,
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
                    borderRadius: BorderRadius.circular(
                      AppPublisher.softRadius,
                    ),
                    color: AppColors.accent.withValues(alpha: 0.03),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 36,
                          color: AppColors.accent.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          style: GoogleFonts.notoSansKr(
                            fontSize: 14,
                            color: AppColors.textPrimary,
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
                      child: const Icon(
                        Icons.add,
                        color: AppColors.textDisabled,
                      ),
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
      padding: dropActive ? const EdgeInsets.only(left: 6) : EdgeInsets.zero,
      decoration:
          dropActive
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
                  child: Icon(
                    Icons.image_outlined,
                    color: AppColors.textDisabled,
                  ),
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
                    child: const Icon(
                      Icons.close,
                      size: 11,
                      color: AppColors.white,
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
              hintText: '기존 채용 사이트, 메신저, 문서 등에 있는\n공고 텍스트를 복사해서 붙여넣어주세요.',
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
                borderSide: BorderSide(color: AppColors.accent, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  // ── CTA: 이전(좌) + 다음(우) 동일 높이 ElevatedButton ───────────

  static const double _ctaBackSlotWidth = 120;

  Widget _buildCtaRow() {
    final canGoBack = _wizardPage > 0 && !_isLoading;
    return SizedBox(
      height: AppPublisher.ctaHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _ctaBackSlotWidth,
            child: ElevatedButton.icon(
              onPressed:
                  canGoBack
                      ? () => _wizardPageController.previousPage(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                      )
                      : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.textPrimary,
                disabledBackgroundColor: AppColors.disabledBg,
                disabledForegroundColor: AppColors.disabledText,
                elevation: 0,
                side: BorderSide(
                  color: canGoBack ? AppColors.divider : AppColors.disabledBg,
                ),
                minimumSize: const Size.fromHeight(AppPublisher.ctaHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppPublisher.buttonRadius,
                  ),
                ),
              ),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 13),
              label: Text(
                '이전',
                style: GoogleFonts.notoSansKr(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
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
          borderRadius: BorderRadius.circular(AppPublisher.buttonRadius),
        ),
      ),
      child:
          _isLoading
              ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white,
                ),
              )
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: Text(
          '처음부터 직접 작성하기',
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
