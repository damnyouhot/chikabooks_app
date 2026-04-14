import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../auth/web/web_account_menu_button.dart';
import '../../../models/clinic_profile.dart'
    show BizVerificationStatus, ClinicProfile;
import '../../../models/job_draft.dart';
import '../../../services/job_draft_service.dart';
import '../../../utils/tag_generator.dart';
import '../../publisher/services/clinic_profile_service.dart';
import '../../publisher/widgets/biz_license_upload_section.dart';
import '../../publisher/widgets/publisher_clinic_identity_section.dart';
import '../ui/job_post_form.dart';
import '../ui/job_post_preview.dart';
import '../ui/job_preview_scroll_anchor.dart';
import '../utils/job_ai_extract_normalize.dart';
import '../utils/job_draft_sync_debug.dart';
import '../utils/job_post_field_sync.dart';

/// AI 초안 편집 페이지 (/post-job/edit/:draftId)
///
/// AI가 추출한 초안을 JobPostForm에 채운 상태로 보여주고,
/// 사용자가 수정 후 게시 단계로 넘어간다.
///
/// 에디터 단계(`editorStep`): **1** 치과 사진 · **2** 공고 상세 · **3** 치과 인증
/// (레거시 저장값은 [_migrateEditorStep]으로 매핑)
class JobDraftEditorPage extends StatefulWidget {
  final String draftId;
  const JobDraftEditorPage({super.key, required this.draftId});

  @override
  State<JobDraftEditorPage> createState() => _JobDraftEditorPageState();
}

class _JobDraftEditorPageState extends State<JobDraftEditorPage> {
  /// Step2(공고 상세) [JobPostForm] — AI 병합 후 [applyDraftFromParent]로 SSOT 동기화.
  final GlobalKey<JobPostFormState> _detailFormKey =
      GlobalKey<JobPostFormState>();

  JobPostData _data = JobPostData();

  /// Firestore 반영 후에만 폼 마운트 — 빈 initialData로 TextEditingController 고정 방지
  bool _draftReady = false;
  String? _loadError;

  /// [JobPostData.toMap]에 없는 드래프트 메타 — 폼 임시저장 시 항상 병합
  Map<String, dynamic> _extraDraftFields = {};
  DateTime? _draftUpdatedAt;
  ClinicProfile? _selectedProfile;
  bool _isLoadingAi = false;

  /// [ClinicProfileService.ensureDefaultProfileForDraft] 완료 후 true
  bool _profileReady = false;
  String _editorStep = 'step1';
  String? _aiError;

  /// 사업자 인증 완료 상태에서만 true — 새 등록증 교체 UI 진입
  bool _licenseReplaceMode = false;

  bool _retryingBusinessCheck = false;

  /// 좌측 미리보기 단일 스크롤 — [JobPostPreview]와 동일 인스턴스 유지.
  final ScrollController _previewScrollController = ScrollController();
  final Map<JobPreviewScrollAnchor, GlobalKey> _previewSectionKeys =
      createJobPreviewSectionKeys();

  /// 우측 폼 스크롤 컨트롤러 — 마우스 위치 기반 라우팅에 사용.
  final ScrollController _formScrollController = ScrollController();

  /// true: 마우스가 좌측(프리뷰) 영역에 있음 / false: 우측(에디터) 영역
  bool _mouseOnLeft = true;

  Map<String, dynamic> _persistExtraFromDraft(JobDraft d) {
    final m = <String, dynamic>{};
    if (d.currentStep != null && d.currentStep!.isNotEmpty) {
      m['currentStep'] = d.currentStep;
    }
    if (d.aiParseStatus != null && d.aiParseStatus!.isNotEmpty) {
      m['aiParseStatus'] = d.aiParseStatus;
    }
    if (d.sourceType != null && d.sourceType!.isNotEmpty) {
      m['sourceType'] = d.sourceType;
    }
    if (d.rawInputText != null && d.rawInputText!.trim().isNotEmpty) {
      m['rawInputText'] = d.rawInputText;
    }
    if (d.rawImageUrls.isNotEmpty) m['rawImageUrls'] = d.rawImageUrls;
    if (d.imageUrls.isNotEmpty) m['imageUrls'] = d.imageUrls;
    if (d.promotionalImageUrls.isNotEmpty) {
      m['promotionalImageUrls'] = d.promotionalImageUrls;
    }
    if (d.clinicProfileId != null && d.clinicProfileId!.isNotEmpty) {
      m['clinicProfileId'] = d.clinicProfileId;
    }
    if (d.editorStep != null && d.editorStep!.isNotEmpty) {
      m['editorStep'] = d.editorStep;
    }
    return m;
  }

  /// Firestore에 저장된 URL → 폼 [JobPostData.images] (치과·자료 첨부 = [JobDraft.imageUrls]만)
  /// [rawImageUrls]는 캡처 AI 입력용이며 여기에 넣지 않는다.
  List<XFile> _imagesFromDraft(JobDraft d) {
    return d.imageUrls.map((u) {
      final seg = Uri.tryParse(u)?.pathSegments.last;
      final name = (seg != null && seg.isNotEmpty) ? seg : 'image.jpg';
      return XFile(u, name: name);
    }).toList();
  }

  /// 좌측 미리보기: [JobPostData.images]가 비어 있거나 비HTTP 경로(blob/로컬)를
  /// 포함하면 드래프트 메타 URL(Firebase Storage)로 갤러리 표시.
  /// [promotionalImageUrls]도 `_extraDraftFields` 폴백 처리.
  JobPostData _dataForPreview() {
    // ── 홍보이미지: _data 우선, 없으면 extraDraftFields 폴백 ──
    List<String> promoUrls = _data.promotionalImageUrls;
    if (promoUrls.isEmpty) {
      final extra = _extraDraftFields['promotionalImageUrls'];
      if (extra is List && extra.isNotEmpty) {
        promoUrls =
            extra.map((e) => e.toString()).where((s) => _isHttpUrl(s)).toList();
      }
    }

    // ── 일반 이미지 ──
    if (_data.images.isNotEmpty &&
        _data.images.every((x) => _isHttpUrl(x.path))) {
      return _data.copyWith(promotionalImageUrls: promoUrls);
    }

    final imgs = _extraDraftFields['imageUrls'];
    final List<String> urls = [];
    if (imgs is List && imgs.isNotEmpty) {
      urls.addAll(imgs.map((e) => e.toString()).where((s) => _isHttpUrl(s)));
    }

    if (urls.isEmpty) {
      return _data.copyWith(images: [], promotionalImageUrls: promoUrls);
    }
    return _data.copyWith(
      promotionalImageUrls: promoUrls,
      images:
          urls.map((u) {
            final seg = Uri.tryParse(u)?.pathSegments.last;
            final name = (seg != null && seg.isNotEmpty) ? seg : 'image.jpg';
            return XFile(u, name: name);
          }).toList(),
    );
  }

  static bool _isHttpUrl(String s) {
    final t = s.trim().toLowerCase();
    return t.startsWith('http://') || t.startsWith('https://');
  }

  /// 예전 순서(1:자료 2:치과정보 3:공고상세)로 저장된 [editorStep]을
  /// 현재 순서(1:사진 2:공고상세 3:인증)로 맞춘다.
  static String _migrateEditorStep(String? saved) {
    switch (saved) {
      case 'step2':
        return 'step3';
      case 'step3':
        return 'step2';
      default:
        return saved ?? 'step1';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDraftAndParse();
  }

  @override
  void dispose() {
    _previewScrollController.dispose();
    _formScrollController.dispose();
    super.dispose();
  }

  /// Step3 폼 포커스 진입 시 좌측 프리뷰를 해당 섹션으로 스크롤.
  void _scrollPreviewTo(JobPreviewScrollAnchor anchor) {
    final key = _previewSectionKeys[anchor]!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = key.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    });
  }

  Future<void> _loadDraftAndParse() async {
    final draft = await JobDraftService.fetchDraft(widget.draftId);
    if (!mounted) return;
    if (draft == null) {
      setState(() {
        _draftReady = true;
        _loadError = '임시저장 초안을 찾을 수 없어요. 목록에서 다시 선택해 주세요.';
      });
      return;
    }

    final step = draft.currentStep ?? '';
    final aiStatus = draft.aiParseStatus ?? 'idle';
    final needsAi =
        step == 'input' && aiStatus != 'running' && aiStatus != 'done';

    // AI 분석이 필요하면 우측은 폼 대신 로딩만 (빈 폼 1프레임 노출 방지)
    if (needsAi) {
      setState(() => _isLoadingAi = true);
    }

    _applyDraftToData(draft);
    await _ensureProfile(draft);
    if (!mounted) return;
    final prof = _selectedProfile;
    if (prof != null) {
      _mergeClinicProfileDefaultsIntoData(prof);
    }

    if (needsAi) {
      await JobDraftService.saveDraft(
        draftId: widget.draftId,
        formData: {
          ..._persistExtraFromDraft(draft),
          'aiParseStatus': 'running',
        },
      );
      if (mounted) {
        setState(() {
          _extraDraftFields = {
            ..._extraDraftFields,
            'aiParseStatus': 'running',
          };
        });
      }

      if (!mounted) return;
      final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
      await _callAiParsing(
        draft: draft,
        sourceType:
            extra?['sourceType'] as String? ?? draft.sourceType ?? 'text',
        rawText: draft.rawInputText ?? '',
      );
    }
  }

  Future<void> _ensureProfile(JobDraft draft) async {
    setState(() => _profileReady = false);
    final p = await ClinicProfileService.ensureDefaultProfileForDraft(
      draftId: widget.draftId,
      existingClinicProfileId: draft.clinicProfileId,
    );
    if (!mounted) return;
    if (p == null) {
      setState(() {
        _profileReady = true;
        _loadError = '치과 프로필을 준비하지 못했어요. 잠시 후 다시 시도해 주세요.';
      });
      return;
    }
    setState(() {
      _selectedProfile = p;
      _profileReady = true;
      _extraDraftFields = {..._extraDraftFields, 'clinicProfileId': p.id};
    });
  }

  /// 드래프트에 비어 있을 때 [ClinicProfile]로 치과명·주소·연락처 보강.
  /// `editorStep: step2`로 바로 진입(추출 없이 새 공고) 시에도 step1→2와 동일하게 채움.
  void _mergeClinicProfileDefaultsIntoData(ClinicProfile p) {
    final name = _data.clinicName.trim();
    final addr = _data.address.trim();
    final ct = _data.contact.trim();
    if (name.isNotEmpty && addr.isNotEmpty && ct.isNotEmpty) return;

    final eff = p.effectiveName.trim();
    final pAddr = p.address.trim();
    final pPhone = p.phone.trim();

    setState(() {
      _data = _data.copyWith(
        clinicName: name.isEmpty && eff.isNotEmpty ? eff : _data.clinicName,
        address: addr.isEmpty && pAddr.isNotEmpty ? p.address : _data.address,
        contact: ct.isEmpty && pPhone.isNotEmpty ? p.phone : _data.contact,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_editorStep == 'step2') {
        _detailFormKey.currentState?.applyDraftFromParent(_data);
      }
    });
  }

  void _applyDraftToData(JobDraft draft) {
    setState(() {
      _draftReady = true;
      _draftUpdatedAt = draft.updatedAt;
      _extraDraftFields = _persistExtraFromDraft(draft);
      _editorStep = _migrateEditorStep(draft.editorStep);
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
        images: _imagesFromDraft(draft),
        promotionalImageUrls: List.from(draft.promotionalImageUrls),
        hospitalType: draft.hospitalType,
        chairCount: draft.chairCount,
        staffCount: draft.staffCount,
        specialties: List.from(draft.specialties),
        hasOralScanner: draft.hasOralScanner,
        hasCT: draft.hasCT,
        has3DPrinter: draft.has3DPrinter,
        digitalEquipmentRaw: draft.digitalEquipmentRaw,
        workDays: List.from(draft.workDays),
        weekendWork: draft.weekendWork,
        nightShift: draft.nightShift,
        applyMethod: List.from(draft.applyMethod),
        requiredDocuments: List.from(draft.requiredDocuments),
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
        tagsUserEdited: draft.tagsUserEdited,
        mainDutiesRaw: draft.mainDutiesRaw,
        mainDutiesList: List.from(draft.mainDutiesList),
        recruitmentStart: draft.recruitmentStart,
        fieldStatus:
            draft.fieldStatus != null
                ? Map<String, String>.from(draft.fieldStatus!)
                : null,
        fieldSources: draft.fieldSources,
      );
    });
  }

  /// 1차 입력(캡처/치과)과 2차(홍보)가 같은 URL 집합이면 보조 패스 생략
  bool _urlListsSameSet(List<String> a, List<String> b) {
    final sa = a.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    final sb = b.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    return sa.length == sb.length && sa.containsAll(sb);
  }

  Future<Map<String, dynamic>> _fetchParseJobForm({
    required List<String> imageUrls,
    required String sourceType,
    required String rawText,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'parseJobImagesToForm',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 180)),
    );
    final result = await callable.call({
      'imageUrls': imageUrls,
      'sourceType': sourceType,
      'rawText': rawText,
    });
    return JobAiExtractNormalizer.normalize(
      Map<String, dynamic>.from(result.data as Map),
    );
  }

  /// [mergeEmptyOnly]: true면 이미 채워진 필드는 유지(홍보 이미지 2차 패스용)
  void _applyNormalizedResult(
    Map<String, dynamic> res, {
    required bool mergeEmptyOnly,
  }) {
    if (!mounted) return;

    final wd = JobAiExtractNormalizer.workDaysToCodes(res['workDays'] as List?);
    final htKey = JobAiExtractNormalizer.hospitalTypeToKey(
      res['hospitalType'] as String?,
    );
    final cc = res['chairCount'];
    final sc = res['staffCount'];
    final chairN =
        cc is int
            ? cc
            : (cc is num
                ? cc.round()
                : int.tryParse('$cc'.replaceAll(RegExp(r'[^\d]'), '')));
    final staffN =
        sc is int
            ? sc
            : (sc is num
                ? sc.round()
                : int.tryParse('$sc'.replaceAll(RegExp(r'[^\d]'), '')));

    final mainDutiesListRaw = res['mainDutiesList'];
    final mainDutiesList =
        mainDutiesListRaw is List
            ? mainDutiesListRaw
                .map((e) => e.toString())
                .where((s) => s.isNotEmpty)
                .toList()
            : <String>[];

    final specialtiesRaw = res['specialties'];
    final specialties =
        specialtiesRaw is List
            ? specialtiesRaw
                .map((e) => e.toString())
                .where((s) => s.isNotEmpty)
                .toList()
            : <String>[];

    final hasOralScanner =
        res['hasOralScanner'] is bool ? res['hasOralScanner'] as bool : null;
    final hasCT = res['hasCT'] is bool ? res['hasCT'] as bool : null;
    final has3DPrinter =
        res['has3DPrinter'] is bool ? res['has3DPrinter'] as bool : null;
    final digitalEquipmentRaw = res['digitalEquipmentRaw'] as String?;

    DateTime? closingDate = _data.closingDate;
    final closingRaw = res['closingDate'] as String?;
    if (mergeEmptyOnly) {
      if (_data.closingDate == null &&
          closingRaw != null &&
          closingRaw.isNotEmpty) {
        try {
          closingDate = DateTime.parse(closingRaw);
        } catch (_) {}
      }
    } else if (closingRaw != null && closingRaw.isNotEmpty) {
      try {
        closingDate = DateTime.parse(closingRaw);
      } catch (_) {}
    }

    DateTime? recruitmentStartParsed;
    final recruitRaw = res['recruitmentStart'] as String?;
    if (recruitRaw != null && recruitRaw.isNotEmpty) {
      try {
        recruitmentStartParsed = DateTime.parse(recruitRaw);
      } catch (_) {}
    }
    final DateTime? recruitmentStart =
        mergeEmptyOnly
            ? (_data.recruitmentStart ?? recruitmentStartParsed)
            : (recruitmentStartParsed ?? _data.recruitmentStart);

    final fsRaw = res['fieldStatus'];
    final Map<String, String>? fieldStatusParsed =
        fsRaw is Map
            ? fsRaw.map((k, v) => MapEntry(k.toString(), v.toString()))
            : null;

    final Map<String, String>? mergedFieldStatus;
    if (mergeEmptyOnly) {
      final base = Map<String, String>.from(_data.fieldStatus ?? {});
      if (fieldStatusParsed != null) {
        for (final e in fieldStatusParsed.entries) {
          final existing = base[e.key];
          if (existing == null || existing.trim().isEmpty) {
            base[e.key] = e.value;
          }
        }
      }
      mergedFieldStatus = base.isNotEmpty ? base : _data.fieldStatus;
    } else {
      mergedFieldStatus = fieldStatusParsed ?? _data.fieldStatus;
    }

    final newBenefits = JobPostFieldSync.normalizeBenefits(
      (res['benefits'] as List?)
              ?.map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList() ??
          <String>[],
    );
    final newSubwayLines =
        (res['subwayLines'] as List?)
            ?.map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList() ??
        <String>[];
    final newRequiredDocuments = JobPostFieldSync.normalizeDocuments(
      (res['requiredDocuments'] as List?)
              ?.map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList() ??
          <String>[],
    );

    final d = _data;
    final parsedHireFromAi = JobPostFieldSync.hireRolesFromExtract(res);

    final careerMergedRaw =
        mergeEmptyOnly
            ? _mergeStrPreferExisting(d.career, res['career'])
            : _firstNonEmpty(res['career'], d.career);
    final careerOut = JobPostFieldSync.pickCareerForStorage(
      careerMergedRaw,
      d.career,
    );

    final empMergedRaw =
        mergeEmptyOnly
            ? _mergeStrPreferExisting(d.employmentType, res['employmentType'])
            : _firstNonEmpty(res['employmentType'], d.employmentType);
    final employmentOut = JobPostFieldSync.pickEmploymentType(
      empMergedRaw,
      d.employmentType,
    );

    final List<String> mergedHireRoles;
    if (mergeEmptyOnly) {
      if (d.hireRoles.isNotEmpty) {
        mergedHireRoles = List<String>.from(d.hireRoles);
      } else if (parsedHireFromAi.isNotEmpty) {
        mergedHireRoles = parsedHireFromAi;
      } else {
        mergedHireRoles = List<String>.from(d.hireRoles);
      }
    } else {
      mergedHireRoles =
          parsedHireFromAi.isNotEmpty
              ? parsedHireFromAi
              : List<String>.from(d.hireRoles);
    }
    final mergedRoleLine = JobPostData.joinHireRoles(mergedHireRoles);

    final eduMergedRaw =
        mergeEmptyOnly
            ? _mergeStrPreferExisting(d.education, res['education'])
            : _firstNonEmpty(res['education'], d.education);
    final educationOut = JobPostFieldSync.pickEducationForStorage(
      eduMergedRaw,
      d.education,
    );

    final salaryMerged = _mergeSalaryAi(d, res, mergeEmptyOnly);

    final titleOut =
        mergeEmptyOnly
            ? _mergeStrPreferExisting(d.title, res['title'])
            : _firstNonEmpty(res['title'], d.title);
    final clinicNameOut =
        mergeEmptyOnly
            ? _mergeStrPreferExisting(d.clinicName, res['clinicName'])
            : _firstNonEmpty(res['clinicName'], d.clinicName);
    final workHoursOut =
        mergeEmptyOnly
            ? _mergeStrPreferExisting(d.workHours, res['workHours'])
            : _firstNonEmpty(res['workHours'], d.workHours);
    final benefitsOut =
        mergeEmptyOnly
            ? (d.benefits.isNotEmpty
                ? d.benefits
                : (newBenefits.isNotEmpty ? newBenefits : d.benefits))
            : (newBenefits.isNotEmpty ? newBenefits : d.benefits);
    final requiredDocumentsOut =
        mergeEmptyOnly
            ? (d.requiredDocuments.isNotEmpty
                ? d.requiredDocuments
                : (newRequiredDocuments.isNotEmpty
                    ? newRequiredDocuments
                    : d.requiredDocuments))
            : (newRequiredDocuments.isNotEmpty
                ? newRequiredDocuments
                : d.requiredDocuments);
    final descriptionOut =
        mergeEmptyOnly
            ? _mergeStrPreferExisting(d.description, res['description'])
            : _firstNonEmpty(res['description'], d.description);
    final addressOut =
        mergeEmptyOnly
            ? _mergeStrPreferExisting(d.address, res['address'])
            : _firstNonEmpty(res['address'], d.address);
    final contactOut =
        mergeEmptyOnly
            ? _mergeStrPreferExisting(d.contact, res['contact'])
            : _firstNonEmpty(res['contact'], d.contact);

    // applyMethod AI 동기화 + email 자동 감지
    final newApplyMethodRaw =
        (res['applyMethod'] as List?)
            ?.map((e) => e.toString())
            .where((s) => s.isNotEmpty && s != 'phone')
            .toList() ??
        <String>[];
    final applyMethodOut = List<String>.from(d.applyMethod)..remove('phone');
    for (final m in newApplyMethodRaw) {
      if (!applyMethodOut.contains(m)) applyMethodOut.add(m);
    }
    if (!applyMethodOut.contains('online')) applyMethodOut.insert(0, 'online');
    if (contactOut.contains('@') && !applyMethodOut.contains('email')) {
      applyMethodOut.add('email');
    }

    final hospitalTypeOut =
        mergeEmptyOnly
            ? ((d.hospitalType != null && d.hospitalType!.trim().isNotEmpty)
                ? d.hospitalType
                : (htKey ?? d.hospitalType))
            : (htKey ?? d.hospitalType);
    final workDaysOut =
        mergeEmptyOnly
            ? (d.workDays.isNotEmpty
                ? d.workDays
                : (wd.isNotEmpty ? wd : d.workDays))
            : (wd.isNotEmpty ? wd : d.workDays);
    final chairCountOut =
        mergeEmptyOnly ? (d.chairCount ?? chairN) : (chairN ?? d.chairCount);
    final staffCountOut =
        mergeEmptyOnly ? (d.staffCount ?? staffN) : (staffN ?? d.staffCount);
    final subwayStationNameOut =
        mergeEmptyOnly
            ? _mergeStrNullablePreferExisting(
              d.subwayStationName,
              res['subwayStationName'] as String?,
            )
            : _firstNonEmptyNullable(
              res['subwayStationName'] as String?,
              d.subwayStationName,
            );
    final mainDutiesListOut =
        mergeEmptyOnly
            ? (d.mainDutiesList.isNotEmpty
                ? d.mainDutiesList
                : (mainDutiesList.isNotEmpty
                    ? mainDutiesList
                    : d.mainDutiesList))
            : (mainDutiesList.isNotEmpty ? mainDutiesList : d.mainDutiesList);
    final specialtiesOut =
        mergeEmptyOnly
            ? (d.specialties.isNotEmpty
                ? d.specialties
                : (specialties.isNotEmpty ? specialties : d.specialties))
            : (specialties.isNotEmpty ? specialties : d.specialties);
    final hasOralScannerOut =
        mergeEmptyOnly
            ? (d.hasOralScanner ?? hasOralScanner)
            : (hasOralScanner ?? d.hasOralScanner);
    final hasCTOut = mergeEmptyOnly ? (d.hasCT ?? hasCT) : (hasCT ?? d.hasCT);
    final has3DPrinterOut =
        mergeEmptyOnly
            ? (d.has3DPrinter ?? has3DPrinter)
            : (has3DPrinter ?? d.has3DPrinter);
    final digitalEquipmentRawOut =
        mergeEmptyOnly
            ? (d.digitalEquipmentRaw?.trim().isNotEmpty == true
                ? d.digitalEquipmentRaw
                : (digitalEquipmentRaw ?? d.digitalEquipmentRaw))
            : (digitalEquipmentRaw ?? d.digitalEquipmentRaw);

    final fieldStatusMerged = JobPostFieldSync.patchFieldStatusForFilledValues(
      mergedFieldStatus,
      {
        'title': titleOut.trim().isNotEmpty,
        'clinicName': clinicNameOut.trim().isNotEmpty,
        'career': careerOut.trim().isNotEmpty,
        'education': educationOut.trim().isNotEmpty,
        'employmentType': employmentOut.trim().isNotEmpty,
        'role': mergedRoleLine.trim().isNotEmpty,
        'mainDuties': mainDutiesListOut.isNotEmpty,
        'salary': salaryMerged.salaryLine.trim().isNotEmpty,
        'workHours': workHoursOut.trim().isNotEmpty,
        'workDays': workDaysOut.isNotEmpty,
        'benefits': benefitsOut.isNotEmpty,
        'description': descriptionOut.trim().isNotEmpty,
        'address': addressOut.trim().isNotEmpty,
        'contact': contactOut.trim().isNotEmpty,
        'subwayStationName': (subwayStationNameOut ?? '').trim().isNotEmpty,
        'applyMethod': applyMethodOut.isNotEmpty,
        'hospitalType': (hospitalTypeOut ?? '').trim().isNotEmpty,
        'chairCount': chairCountOut != null,
        'staffCount': staffCountOut != null,
        'specialties': specialtiesOut.isNotEmpty,
        'hasOralScanner': hasOralScannerOut != null,
        'hasCT': hasCTOut != null,
        'has3DPrinter': has3DPrinterOut != null,
        'digitalEquipmentRaw': (digitalEquipmentRawOut ?? '').trim().isNotEmpty,
        'requiredDocuments': requiredDocumentsOut.isNotEmpty,
        'closingDate': d.isAlwaysHiring || closingDate != null,
      },
    );

    setState(() {
      _data = d.copyWith(
        tagsUserEdited: d.tagsUserEdited,
        clinicName: clinicNameOut,
        title: titleOut,
        hireRoles: mergedHireRoles,
        role: mergedRoleLine,
        career: careerOut,
        education: educationOut,
        employmentType: employmentOut,
        workHours: workHoursOut,
        salary: salaryMerged.salaryLine,
        salaryPayType: salaryMerged.payType,
        salaryAmount: salaryMerged.amount,
        benefits: benefitsOut,
        description: descriptionOut,
        address: addressOut,
        contact: contactOut,
        hospitalType: hospitalTypeOut,
        workDays: workDaysOut,
        weekendWork:
            mergeEmptyOnly
                ? d.weekendWork
                : (_parseBool(res['weekendWork']) ?? d.weekendWork),
        nightShift:
            mergeEmptyOnly
                ? d.nightShift
                : (_parseBool(res['nightShift']) ?? d.nightShift),
        chairCount: chairCountOut,
        staffCount: staffCountOut,
        subwayStationName: subwayStationNameOut,
        subwayLines:
            mergeEmptyOnly
                ? (d.subwayLines.isNotEmpty
                    ? d.subwayLines
                    : (newSubwayLines.isNotEmpty
                        ? newSubwayLines
                        : d.subwayLines))
                : (newSubwayLines.isNotEmpty ? newSubwayLines : d.subwayLines),
        mainDutiesList: mainDutiesListOut,
        mainDutiesRaw:
            mergeEmptyOnly
                ? (mainDutiesListOut.isNotEmpty
                    ? d.mainDutiesRaw
                    : (mainDutiesList.isNotEmpty
                        ? res['mainDutiesRaw'] as String?
                        : d.mainDutiesRaw))
                : (mainDutiesListOut.isNotEmpty
                    ? res['mainDutiesRaw'] as String?
                    : d.mainDutiesRaw),
        specialties: specialtiesOut,
        hasOralScanner: hasOralScannerOut,
        hasCT: hasCTOut,
        has3DPrinter: has3DPrinterOut,
        digitalEquipmentRaw: digitalEquipmentRawOut,
        requiredDocuments: requiredDocumentsOut,
        applyMethod: applyMethodOut,
        closingDate: closingDate,
        recruitmentStart: recruitmentStart,
        fieldStatus: fieldStatusMerged,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      JobDraftSyncDebug.logPipeline('parent_after_ai_merge', _data);
      if (_editorStep == 'step2') {
        _detailFormKey.currentState?.applyDraftFromParent(_data);
      }
    });
  }

  /// 급여 한 줄 + `salaryPayType` / `salaryAmount` (폼·저장과 동일 규칙).
  ({String salaryLine, String payType, String amount}) _mergeSalaryAi(
    JobPostData d,
    Map<String, dynamic> res,
    bool mergeEmptyOnly,
  ) {
    const validPay = {'협의', '시', '월', '연'};
    final mergedOne =
        mergeEmptyOnly
            ? _mergeStrPreferExisting(d.salary, res['salary'])
            : _firstNonEmpty(res['salary'], d.salary);
    final rpt = (res['salaryPayType'] as String?)?.trim() ?? '';
    final ram =
        (res['salaryAmount'] as String?)?.trim().replaceAll(',', '') ?? '';

    if (mergeEmptyOnly && d.salary.trim().isNotEmpty) {
      return (
        salaryLine: d.salary,
        payType: d.salaryPayType,
        amount: d.salaryAmount,
      );
    }

    if (validPay.contains(rpt)) {
      var line = JobPostData.composeSalaryLine(rpt, ram);
      if (line.isEmpty && mergedOne.trim().isNotEmpty) {
        final inf = JobPostData.inferSalaryPartsFromLegacy(mergedOne);
        line = JobPostData.composeSalaryLine(inf.$1, inf.$2);
        if (line.isEmpty) line = mergedOne.trim();
        return (salaryLine: line, payType: inf.$1, amount: inf.$2);
      }
      return (
        salaryLine: line.isNotEmpty ? line : mergedOne.trim(),
        payType: rpt,
        amount: ram,
      );
    }

    final inf = JobPostData.inferSalaryPartsFromLegacy(mergedOne);
    var line = JobPostData.composeSalaryLine(inf.$1, inf.$2);
    if (line.isEmpty && mergedOne.trim().isNotEmpty) {
      line = mergedOne.trim();
    }
    return (salaryLine: line, payType: inf.$1, amount: inf.$2);
  }

  String _mergeStrPreferExisting(String current, dynamic resVal) {
    final c = current.trim();
    if (c.isNotEmpty) return current;
    final r = (resVal as String?)?.trim() ?? '';
    return r.isNotEmpty ? r : current;
  }

  String? _mergeStrNullablePreferExisting(String? current, String? resVal) {
    if (current != null && current.trim().isNotEmpty) return current;
    final r = resVal?.trim() ?? '';
    return r.isNotEmpty ? r : current;
  }

  Future<void> _callAiParsing({
    required JobDraft draft,
    required String sourceType,
    required String rawText,
  }) async {
    setState(() {
      _isLoadingAi = true;
      _aiError = null;
    });

    try {
      final raw = draft.rawImageUrls;
      final clinic = draft.imageUrls;
      final promo = draft.promotionalImageUrls;

      /// 우선순위: 캡처(raw) → 치과 자료(clinic) → 홍보(promo)
      final List<String> pass1ImageUrls =
          raw.isNotEmpty ? raw : (clinic.isNotEmpty ? clinic : promo);

      final bool runPromoSecondPass =
          promo.isNotEmpty && !_urlListsSameSet(pass1ImageUrls, promo);

      final res1 = await _fetchParseJobForm(
        imageUrls: pass1ImageUrls,
        sourceType: sourceType,
        rawText: rawText,
      );
      if (!mounted) return;
      _applyNormalizedResult(res1, mergeEmptyOnly: false);

      if (runPromoSecondPass) {
        try {
          final res2 = await _fetchParseJobForm(
            imageUrls: promo,
            sourceType: 'promotional',
            rawText: '',
          );
          if (!mounted) return;
          _applyNormalizedResult(res2, mergeEmptyOnly: true);
        } catch (_) {
          /* 1차 결과는 유지 */
        }
      }

      if (mounted && !_data.tagsUserEdited) {
        setState(() {
          _data = _data.copyWith(
            tags: TagGenerator.generate(
              benefits: _data.benefits,
              workDays: _data.workDays,
              weekendWork: _data.weekendWork,
              nightShift: _data.nightShift,
              career: _data.career,
              applyMethod: _data.applyMethod,
              subwayStationName: _data.subwayStationName,
              walkingMinutes: _data.walkingMinutes,
            ),
          );
        });
      }

      await JobDraftService.saveDraft(
        draftId: widget.draftId,
        formData: {
          ..._data.toMap(),
          ..._extraDraftFields,
          'currentStep': 'ai_generated',
          'aiParseStatus': 'done',
        },
      );
      if (mounted) {
        setState(() {
          _extraDraftFields = {
            ..._extraDraftFields,
            'currentStep': 'ai_generated',
            'aiParseStatus': 'done',
          };
        });
      }
    } catch (e) {
      await JobDraftService.saveDraft(
        draftId: widget.draftId,
        formData: {..._extraDraftFields, 'aiParseStatus': 'failed'},
      );
      if (mounted) {
        setState(() {
          _extraDraftFields = {..._extraDraftFields, 'aiParseStatus': 'failed'};
        });
      }
      if (mounted) {
        String msg = 'AI 분석 중 오류가 발생했어요. 직접 입력하셔도 됩니다.';
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('timeout') || errStr.contains('deadline')) {
          msg = 'AI 분석 시간이 초과했어요. 텍스트가 너무 길면 줄여서 다시 시도해 주세요.';
        } else if (errStr.contains('not-found') || errStr.contains('image')) {
          msg = '이미지를 불러올 수 없어요. 다른 이미지로 다시 시도해 주세요.';
        } else if (errStr.contains('network') ||
            errStr.contains('unavailable')) {
          msg = '네트워크 오류가 발생했어요. 인터넷 연결을 확인해 주세요.';
        }
        setState(() => _aiError = msg);
      }
    } finally {
      if (mounted) setState(() => _isLoadingAi = false);
    }
  }

  String _firstNonEmpty(dynamic a, String fallback) {
    final s = a as String? ?? '';
    return s.isNotEmpty ? s : fallback;
  }

  String? _firstNonEmptyNullable(dynamic a, String? fallback) {
    final s = a as String? ?? '';
    return s.isNotEmpty ? s : fallback;
  }

  bool? _parseBool(dynamic v) {
    if (v is bool) return v;
    if (v is String) {
      final lower = v.toLowerCase().trim();
      if (lower.contains('있') ||
          lower.contains('예') ||
          lower == 'true' ||
          lower == 'yes')
        return true;
      if (lower.contains('없') ||
          lower.contains('아니') ||
          lower == 'false' ||
          lower == 'no')
        return false;
    }
    return null;
  }

  void _onDataChanged(JobPostData d) {
    setState(() {
      _data = d;
      final httpUrls =
          d.images
              .map((x) => x.path.trim())
              .where((p) => p.startsWith('http://') || p.startsWith('https://'))
              .toList();
      // 자료 첨부(치과) 갤러리 → imageUrls만. rawImageUrls(캡처 AI)와 혼동하지 않음.
      _extraDraftFields = {
        ..._extraDraftFields,
        'imageUrls': httpUrls,
        'promotionalImageUrls': d.promotionalImageUrls,
      };
    });
    JobDraftSyncDebug.logPipeline('onDataChanged', d);
  }

  Future<void> _setEditorStep(String step) async {
    setState(() => _editorStep = step);
    await JobDraftService.saveDraft(
      draftId: widget.draftId,
      formData: {..._extraDraftFields, 'editorStep': step},
    );
    if (mounted) {
      setState(() {
        _extraDraftFields = {..._extraDraftFields, 'editorStep': step};
      });
    }
  }

  Future<void> _goNextStep() async {
    if (_editorStep == 'step1') {
      final pid = _selectedProfile?.id;
      if (pid != null) {
        final p = await ClinicProfileService.getProfile(pid);
        if (p != null && mounted) {
          setState(() {
            _selectedProfile = p;
            _data = _data.copyWith(
              clinicName:
                  _data.clinicName.isEmpty ? p.effectiveName : _data.clinicName,
              address: _data.address.isEmpty ? p.address : _data.address,
              contact: _data.contact.isEmpty ? p.phone : _data.contact,
            );
          });
        }
      }
      await _setEditorStep('step2');
      return;
    }
    if (_editorStep == 'step2') {
      await _setEditorStep('step3');
    }
  }

  void _goPrevStep() {
    if (_editorStep == 'step3') {
      _setEditorStep('step2');
    } else if (_editorStep == 'step2') {
      _setEditorStep('step1');
    }
  }

  Future<void> _goToPublish() async {
    if (_selectedProfile?.id != null) {
      final fresh = await ClinicProfileService.getProfile(_selectedProfile!.id);
      if (fresh != null && mounted) setState(() => _selectedProfile = fresh);
    }
    // 최종 저장: 폼의 toMap에는 이미지 URL이 없으므로 Firestore 최신본과 병합
    final latest = await JobDraftService.fetchDraft(widget.draftId);
    await JobDraftService.saveDraft(
      draftId: widget.draftId,
      formData: {
        ..._data.toMap(),
        ..._extraDraftFields,
        if (latest != null && latest.rawImageUrls.isNotEmpty)
          'rawImageUrls': latest.rawImageUrls,
        if (latest != null && latest.imageUrls.isNotEmpty)
          'imageUrls': latest.imageUrls,
        'currentStep': 'review',
      },
    );
    if (mounted) context.push('/post-job/product/${widget.draftId}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.webPublisherPageBg,
      body: Column(
        children: [_buildTopBar(), Expanded(child: _buildBodyAfterLoad())],
      ),
    );
  }

  Widget _buildBodyAfterLoad() {
    if (!_draftReady) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '저장된 공고를 불러오는 중…',
              style: GoogleFonts.notoSansKr(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.error.withValues(alpha: 0.85),
              ),
              const SizedBox(height: 16),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansKr(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed:
                    () =>
                        context.canPop()
                            ? context.pop()
                            : context.go('/post-job/input'),
                child: Text(
                  '돌아가기',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (!_profileReady) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '치과 프로필을 준비하는 중…',
              style: GoogleFonts.notoSansKr(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) {
          return _buildNarrowLayout();
        }
        return _buildWideLayout();
      },
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          // ── 좌측: 뒤로가기 + 치과 칩 ─────────────────────────
          IconButton(
            onPressed: () =>
                context.canPop()
                    ? context.pop()
                    : context.go('/post-job/input'),
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
          if (_selectedProfile != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppPublisher.softRadius),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                _selectedProfile!.effectiveName,
                style: GoogleFonts.notoSansKr(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
          // ── 중앙: 페이지 타이틀 ────────────────────────────────
          const Spacer(),
          Text(
            '2. 공고 상세',
            style: GoogleFonts.notoSansKr(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          // ── 우측: 계정 메뉴 + 다음 단계 버튼 ─────────────────
          const Spacer(),
          const WebAccountMenuButton(),
          const SizedBox(width: 12),
          SizedBox(
            height: AppPublisher.ctaHeight,
            child: ElevatedButton(
              onPressed: _goToPublish,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppPublisher.buttonRadius,
                  ),
                ),
              ),
              child: Text(
                '게시 단계로',
                style: GoogleFonts.notoSansKr(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxPreviewH = (constraints.maxHeight - 48).clamp(280.0, 844.0);
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerSignal: (event) {
            if (event is! PointerScrollEvent) return;
            // 이 핸들러가 이벤트를 독점해 자식 Scrollable의 이중 스크롤을 방지
            GestureBinding.instance.pointerSignalResolver.register(event, (e) {
              if (e is! PointerScrollEvent) return;
              final ctrl =
                  _mouseOnLeft ? _previewScrollController : _formScrollController;
              if (!ctrl.hasClients) return;
              final pos = ctrl.position;
              final newOffset =
                  (pos.pixels + e.scrollDelta.dy).clamp(
                    pos.minScrollExtent,
                    pos.maxScrollExtent,
                  );
              pos.jumpTo(newOffset);
            });
          },
          child: MouseRegion(
            onHover: (event) {
              // LayoutBuilder constraints 기준 좌우 판별
              final isLeft = event.localPosition.dx < constraints.maxWidth / 2;
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
                      Expanded(
                        flex: 46,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 28, 16, 28),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 390),
                              child: JobPostPreview(
                                data: _dataForPreview(),
                                maxHeight: maxPreviewH,
                                scrollController: _previewScrollController,
                                sectionKeys: _previewSectionKeys,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(width: 1, color: AppColors.divider),
                      Expanded(flex: 54, child: _buildFormSection()),
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
    return _buildFormSection();
  }

  Widget _buildFormSection() {
    if (_isLoadingAi) {
      return const _AiLoadingView();
    }

    final pid = _selectedProfile?.id;
    if (pid == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<ClinicProfile?>(
      stream: ClinicProfileService.watchProfile(pid),
      initialData: _selectedProfile,
      builder: (context, snap) {
        final profile = snap.data ?? _selectedProfile!;
        return SingleChildScrollView(
          controller: _formScrollController,
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_aiError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        border: const Border(
                          left: BorderSide(color: AppColors.error, width: 3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _aiError!,
                              style: GoogleFonts.notoSansKr(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildVerificationStickyBanner(profile),
                  const SizedBox(height: 12),
                  _buildStepIndicator(),
                  const SizedBox(height: 20),
                  if (_editorStep == 'step1') _buildStep1Body(),
                  if (_editorStep == 'step2')
                    JobPostForm(
                      key: _detailFormKey,
                      initialData: _data,
                      draftId: widget.draftId,
                      publisherWebStyle: true,
                      publisherWebEditorStep: 'step3',
                      extraDraftFields: _extraDraftFields,
                      initialDraftUpdatedAt: _draftUpdatedAt,
                      onDataChanged: _onDataChanged,
                      onDraftIdChanged: (_) {},
                      onSubmit: (_) async => _goToPublish(),
                      onWebEditorPreviewScrollTo: _scrollPreviewTo,
                    ),
                  if (_editorStep == 'step3') _buildStep3Body(profile),
                  const SizedBox(height: 28),
                  _buildStepNav(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _retryBusinessCheck(ClinicProfile profile) async {
    if (_retryingBusinessCheck) return;
    setState(() => _retryingBusinessCheck = true);
    try {
      final fn = FirebaseFunctions.instance.httpsCallable(
        'checkBusinessStatus',
      );
      await fn.call({'profileId': profile.id});
      final u = await ClinicProfileService.getProfile(profile.id);
      if (u != null && mounted) {
        setState(() {
          _selectedProfile = u;
          if (u.isBusinessVerified) {
            _licenseReplaceMode = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('다시 확인에 실패했습니다: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _retryingBusinessCheck = false);
    }
  }

  Future<void> _onTapReplaceBusinessLicense() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            '등록증을 바꿀까요?',
            style: GoogleFonts.notoSansKr(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          content: Text(
            '새 파일을 올리면 사업자 정보를 다시 확인합니다. 이전 등록증은 내부 인증 목적으로만 보관되며 외부에 공개되지 않습니다.',
            style: GoogleFonts.notoSansKr(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                '취소',
                style: GoogleFonts.notoSansKr(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                '계속',
                style: GoogleFonts.notoSansKr(
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (ok == true && mounted) {
      setState(() => _licenseReplaceMode = true);
    }
  }

  Widget _buildVerificationStickyBanner(ClinicProfile profile) {
    if (profile.isBusinessVerified) return const SizedBox.shrink();
    final bv = profile.businessVerification;
    final fr = bv.failReason;
    String msg;
    if (fr == 'nts_api_error') {
      msg = '인증 지연 중입니다. 잠시 후 다시 시도해 주세요.';
    } else if (bv.status == BizVerificationStatus.pendingAuto) {
      msg = '사업자 인증 진행 중입니다…';
    } else if (bv.status == BizVerificationStatus.manualReview) {
      msg = '사업자 정보를 검토 중입니다. 완료되면 알려 드릴게요.';
    } else if (bv.status == BizVerificationStatus.rejected) {
      msg = '사업자 인증에 실패했습니다. 등록증을 다시 올려 주세요.';
    } else {
      msg = '사업자 인증이 완료되면 게시할 수 있어요.';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.06),
        border: Border(left: BorderSide(color: AppColors.accent, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: GoogleFonts.notoSansKr(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (fr == 'nts_api_error') ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed:
                  _retryingBusinessCheck
                      ? null
                      : () => _retryBusinessCheck(profile),
              child:
                  _retryingBusinessCheck
                      ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accent,
                        ),
                      )
                      : Text(
                        '다시 확인',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    const labels = ['치과 사진 첨부', '공고 상세', '치과 인증'];
    final idx =
        _editorStep == 'step1'
            ? 0
            : _editorStep == 'step2'
            ? 1
            : 2;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: List.generate(3, (i) {
        final active = i == idx;
        final stepId =
            i == 0
                ? 'step1'
                : i == 1
                ? 'step2'
                : 'step3';
        return InkWell(
          onTap: () => _setEditorStep(stepId),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color:
                  active
                      ? AppColors.accent.withValues(alpha: 0.12)
                      : AppColors.white,
              border: Border.all(
                color: active ? AppColors.accent : AppColors.divider,
              ),
              borderRadius: BorderRadius.circular(AppPublisher.softRadius),
            ),
            child: Text(
              '${i + 1}. ${labels[i]}',
              style: GoogleFonts.notoSansKr(
                fontSize: 12,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStep1Body() {
    return JobPostForm(
      key: ValueKey('editor_s1_${widget.draftId}'),
      initialData: _data,
      draftId: widget.draftId,
      publisherWebStyle: true,
      publisherWebEditorStep: 'step1',
      extraDraftFields: _extraDraftFields,
      initialDraftUpdatedAt: _draftUpdatedAt,
      onDataChanged: _onDataChanged,
      onDraftIdChanged: (_) {},
      onSubmit: (_) async => _goToPublish(),
    );
  }

  /// 3단계: 사업자 인증 카드 + 치과 프로필(OCR) 확인
  Widget _buildStep3Body(ClinicProfile profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLicenseSide(profile),
        SizedBox(height: AppPublisher.formSectionSpacing),
        PublisherClinicIdentitySection(
          profile: profile,
          inlineFieldLabels: true,
          onSaved: () async {
            final u = await ClinicProfileService.getProfile(profile.id);
            if (u != null && mounted) {
              setState(() => _selectedProfile = u);
            }
          },
        ),
      ],
    );
  }

  Widget _buildLicenseSide(ClinicProfile profile) {
    return BizLicenseUploadSection(
      profileId: profile.id,
      publisherStyleOcrLabelWidth: true,
      replacementMode: _licenseReplaceMode,
      persistedProfile: profile,
      onReplaceLicenseWithDialog: _onTapReplaceBusinessLicense,
      onReplacementCancel:
          _licenseReplaceMode
              ? () {
                if (mounted) setState(() => _licenseReplaceMode = false);
              }
              : null,
      onCompleted: () async {
        final updated = await ClinicProfileService.getProfile(profile.id);
        if (updated != null && mounted) {
          setState(() {
            _selectedProfile = updated;
            if (updated.isBusinessVerified) {
              _licenseReplaceMode = false;
            }
          });
        }
      },
    );
  }

  Widget _buildStepNav() {
    return Row(
      children: [
        if (_editorStep != 'step1')
          OutlinedButton(
            onPressed: _goPrevStep,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppPublisher.buttonRadius),
              ),
            ),
            child: Text(
              '이전',
              style: GoogleFonts.notoSansKr(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        const Spacer(),
        if (_editorStep != 'step3')
          SizedBox(
            height: AppPublisher.ctaHeight,
            child: ElevatedButton(
              onPressed: _goNextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppPublisher.buttonRadius,
                  ),
                ),
              ),
              child: Text(
                '다음',
                style: GoogleFonts.notoSansKr(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── AI 로딩 단계별 메시지 위젯 ──────────────────────────────────

class _AiLoadingView extends StatefulWidget {
  const _AiLoadingView();

  @override
  State<_AiLoadingView> createState() => _AiLoadingViewState();
}

class _AiLoadingViewState extends State<_AiLoadingView> {
  static const _stages = [
    (sec: 0, icon: Icons.cloud_upload_outlined, msg: '이미지를 업로드하는\n중이에요...'),
    (
      sec: 6,
      icon: Icons.image_search_outlined,
      msg: 'AI가 공고 이미지를\n분석하고 있어요...',
    ),
    (
      sec: 18,
      icon: Icons.manage_search_outlined,
      msg: '치과 정보와 근무 조건을\n추출하는 중이에요...',
    ),
    (
      sec: 45,
      icon: Icons.playlist_add_check_outlined,
      msg: '담당 업무와 복리후생을\n정리하는 중이에요...',
    ),
    (
      sec: 95,
      icon: Icons.check_circle_outline_rounded,
      msg: '거의 다 됐어요!\n조금만 기다려주세요...',
    ),
  ];

  /// 게이지 아래 로테이션 (사업자 인증·다음 단계 등)
  static const _tipLines = <String>[
    '이미지가 많을수록\n시간이 걸릴 수 있어요',
    '게시 전 사업자등록증을 첨부하고\n사업자 인증을 완료해야 해요.',
    '추출이 끝나면 병원명·연락처를\n꼭 한 번 더 확인해 주세요.',
  ];

  /// 단계 제목 아래 안내 — 기본 12pt 대비 1.5배·볼드
  static const _tipFontSize = 12.0 * 1.5;

  /// 진행 바 최대 예상 시간 (초) — Callable/함수 상한(180초)에 맞춤, 실제 완료 전 95%까지만 채움
  static const _maxSec = 170.0;

  late final DateTime _startTime;
  Timer? _ticker;
  Timer? _tipTicker;
  int _elapsed = 0;
  int _tipIndex = 0;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed = DateTime.now().difference(_startTime).inSeconds;
      });
    });
    _tipTicker = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() {
        _tipIndex = (_tipIndex + 1) % _tipLines.length;
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _tipTicker?.cancel();
    super.dispose();
  }

  int get _stageIndex {
    for (var i = _stages.length - 1; i >= 0; i--) {
      if (_elapsed >= _stages[i].sec) return i;
    }
    return 0;
  }

  double get _progress {
    final raw = (_elapsed / _maxSec).clamp(0.0, 0.95);
    // easeOut: 빠르게 오르다 느려짐
    return 1 - (1 - raw) * (1 - raw);
  }

  @override
  Widget build(BuildContext context) {
    final stage = _stages[_stageIndex];

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 60),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth;
            final barW = maxW * 2 / 3;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Icon(
                    stage.icon,
                    key: ValueKey(_stageIndex),
                    size: 48,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 24),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    stage.msg,
                    key: ValueKey(_stageIndex),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: barW,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      AppPublisher.softRadius,
                    ),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: _progress),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOut,
                      builder:
                          (_, value, __) => LinearProgressIndicator(
                            value: value,
                            minHeight: 6,
                            backgroundColor: AppColors.divider,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.accent,
                            ),
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: barW,
                  child: Text(
                    '${(_progress * 100).toInt()}%',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 11,
                      color: AppColors.textDisabled,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: maxW,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: Text(
                      _tipLines[_tipIndex],
                      key: ValueKey<int>(_tipIndex),
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansKr(
                        fontSize: _tipFontSize,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
