import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../models/clinic_profile.dart' show BizVerificationStatus, ClinicProfile;
import '../../../models/job_draft.dart';
import '../../../services/job_draft_service.dart';
import '../../publisher/services/clinic_profile_service.dart';
import '../../publisher/widgets/biz_license_upload_section.dart';
import '../../publisher/widgets/publisher_clinic_identity_section.dart';
import '../ui/job_post_form.dart';
import '../ui/job_post_preview.dart';
import '../utils/job_ai_extract_normalize.dart';

/// AI 초안 편집 페이지 (/post-job/edit/:draftId)
///
/// AI가 추출한 초안을 JobPostForm에 채운 상태로 보여주고,
/// 사용자가 수정 후 게시 단계로 넘어간다.
class JobDraftEditorPage extends StatefulWidget {
  final String draftId;
  const JobDraftEditorPage({super.key, required this.draftId});

  @override
  State<JobDraftEditorPage> createState() => _JobDraftEditorPageState();
}

class _JobDraftEditorPageState extends State<JobDraftEditorPage> {
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
        promoUrls = extra.map((e) => e.toString()).where((s) => _isHttpUrl(s)).toList();
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
      images: urls.map((u) {
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

  @override
  void initState() {
    super.initState();
    _loadDraftAndParse();
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
        sourceType: extra?['sourceType'] as String? ??
            draft.sourceType ?? 'text',
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
      _extraDraftFields = {
        ..._extraDraftFields,
        'clinicProfileId': p.id,
      };
    });
  }

  void _applyDraftToData(JobDraft draft) {
    setState(() {
      _draftReady = true;
      _draftUpdatedAt = draft.updatedAt;
      _extraDraftFields = _persistExtraFromDraft(draft);
      _editorStep = draft.editorStep ?? 'step1';
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
        mainDutiesRaw: draft.mainDutiesRaw,
        mainDutiesList: List.from(draft.mainDutiesList),
        recruitmentStart: draft.recruitmentStart,
        fieldStatus: draft.fieldStatus != null
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
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 180),
      ),
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
    final chairN = cc is int
        ? cc
        : (cc is num
            ? cc.round()
            : int.tryParse('$cc'.replaceAll(RegExp(r'[^\d]'), '')));
    final staffN = sc is int
        ? sc
        : (sc is num
            ? sc.round()
            : int.tryParse('$sc'.replaceAll(RegExp(r'[^\d]'), '')));

    final mainDutiesListRaw = res['mainDutiesList'];
    final mainDutiesList = mainDutiesListRaw is List
        ? mainDutiesListRaw
            .map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList()
        : <String>[];

    final specialtiesRaw = res['specialties'];
    final specialties = specialtiesRaw is List
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
    final DateTime? recruitmentStart = mergeEmptyOnly
        ? (_data.recruitmentStart ?? recruitmentStartParsed)
        : (recruitmentStartParsed ?? _data.recruitmentStart);

    final fsRaw = res['fieldStatus'];
    final Map<String, String>? fieldStatusParsed = fsRaw is Map
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

    final newBenefits = (res['benefits'] as List?)
            ?.map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList() ??
        <String>[];
    final newSubwayLines = (res['subwayLines'] as List?)
            ?.map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList() ??
        <String>[];

    setState(() {
      final d = _data;
      _data = d.copyWith(
        clinicName: mergeEmptyOnly
            ? _mergeStrPreferExisting(d.clinicName, res['clinicName'])
            : _firstNonEmpty(res['clinicName'], d.clinicName),
        title: mergeEmptyOnly
            ? _mergeStrPreferExisting(d.title, res['title'])
            : _firstNonEmpty(res['title'], d.title),
        role: mergeEmptyOnly
            ? _mergeStrPreferExisting(d.role, res['role'])
            : _firstNonEmpty(res['role'], d.role),
        career: mergeEmptyOnly
            ? _mergeStrPreferExisting(d.career, res['career'])
            : _firstNonEmpty(res['career'], d.career),
        employmentType: mergeEmptyOnly
            ? _mergeStrPreferExisting(d.employmentType, res['employmentType'])
            : _firstNonEmpty(res['employmentType'], d.employmentType),
        workHours: mergeEmptyOnly
            ? _mergeStrPreferExisting(d.workHours, res['workHours'])
            : _firstNonEmpty(res['workHours'], d.workHours),
        salary: mergeEmptyOnly
            ? _mergeStrPreferExisting(d.salary, res['salary'])
            : _firstNonEmpty(res['salary'], d.salary),
        benefits: mergeEmptyOnly
            ? (d.benefits.isNotEmpty
                ? d.benefits
                : (newBenefits.isNotEmpty ? newBenefits : d.benefits))
            : (newBenefits.isNotEmpty ? newBenefits : d.benefits),
        description: mergeEmptyOnly
            ? _mergeStrPreferExisting(d.description, res['description'])
            : _firstNonEmpty(res['description'], d.description),
        address: mergeEmptyOnly
            ? _mergeStrPreferExisting(d.address, res['address'])
            : _firstNonEmpty(res['address'], d.address),
        contact: mergeEmptyOnly
            ? _mergeStrPreferExisting(d.contact, res['contact'])
            : _firstNonEmpty(res['contact'], d.contact),
        hospitalType: mergeEmptyOnly
            ? ((d.hospitalType != null && d.hospitalType!.trim().isNotEmpty)
                ? d.hospitalType
                : (htKey ?? d.hospitalType))
            : (htKey ?? d.hospitalType),
        workDays: mergeEmptyOnly
            ? (d.workDays.isNotEmpty
                ? d.workDays
                : (wd.isNotEmpty ? wd : d.workDays))
            : (wd.isNotEmpty ? wd : d.workDays),
        weekendWork: mergeEmptyOnly
            ? d.weekendWork
            : (_parseBool(res['weekendWork']) ?? d.weekendWork),
        nightShift:
            mergeEmptyOnly ? d.nightShift : (_parseBool(res['nightShift']) ?? d.nightShift),
        chairCount: mergeEmptyOnly
            ? (d.chairCount ?? chairN)
            : (chairN ?? d.chairCount),
        staffCount: mergeEmptyOnly
            ? (d.staffCount ?? staffN)
            : (staffN ?? d.staffCount),
        subwayStationName: mergeEmptyOnly
            ? _mergeStrNullablePreferExisting(
                d.subwayStationName, res['subwayStationName'] as String?)
            : _firstNonEmptyNullable(
                res['subwayStationName'] as String?, d.subwayStationName),
        subwayLines: mergeEmptyOnly
            ? (d.subwayLines.isNotEmpty
                ? d.subwayLines
                : (newSubwayLines.isNotEmpty ? newSubwayLines : d.subwayLines))
            : (newSubwayLines.isNotEmpty ? newSubwayLines : d.subwayLines),
        mainDutiesList: mergeEmptyOnly
            ? (d.mainDutiesList.isNotEmpty
                ? d.mainDutiesList
                : (mainDutiesList.isNotEmpty ? mainDutiesList : d.mainDutiesList))
            : (mainDutiesList.isNotEmpty ? mainDutiesList : d.mainDutiesList),
        mainDutiesRaw: mergeEmptyOnly
            ? (d.mainDutiesList.isNotEmpty
                ? d.mainDutiesRaw
                : (mainDutiesList.isNotEmpty
                    ? res['mainDutiesRaw'] as String?
                    : d.mainDutiesRaw))
            : (mainDutiesList.isNotEmpty
                ? res['mainDutiesRaw'] as String?
                : d.mainDutiesRaw),
        specialties: mergeEmptyOnly
            ? (d.specialties.isNotEmpty
                ? d.specialties
                : (specialties.isNotEmpty ? specialties : d.specialties))
            : (specialties.isNotEmpty ? specialties : d.specialties),
        hasOralScanner: mergeEmptyOnly
            ? (d.hasOralScanner ?? hasOralScanner)
            : (hasOralScanner ?? d.hasOralScanner),
        hasCT: mergeEmptyOnly ? (d.hasCT ?? hasCT) : (hasCT ?? d.hasCT),
        has3DPrinter: mergeEmptyOnly
            ? (d.has3DPrinter ?? has3DPrinter)
            : (has3DPrinter ?? d.has3DPrinter),
        digitalEquipmentRaw: mergeEmptyOnly
            ? (d.digitalEquipmentRaw?.trim().isNotEmpty == true
                ? d.digitalEquipmentRaw
                : (digitalEquipmentRaw ?? d.digitalEquipmentRaw))
            : (digitalEquipmentRaw ?? d.digitalEquipmentRaw),
        closingDate: closingDate,
        recruitmentStart: recruitmentStart,
        fieldStatus: mergedFieldStatus,
      );
    });
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
      final List<String> pass1ImageUrls = raw.isNotEmpty
          ? raw
          : (clinic.isNotEmpty ? clinic : promo);

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
        formData: {
          ..._extraDraftFields,
          'aiParseStatus': 'failed',
        },
      );
      if (mounted) {
        setState(() {
          _extraDraftFields = {
            ..._extraDraftFields,
            'aiParseStatus': 'failed',
          };
        });
      }
      if (mounted) {
        String msg = 'AI 분석 중 오류가 발생했어요. 직접 입력하셔도 됩니다.';
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('timeout') || errStr.contains('deadline')) {
          msg = 'AI 분석 시간이 초과했어요. 텍스트가 너무 길면 줄여서 다시 시도해 주세요.';
        } else if (errStr.contains('not-found') || errStr.contains('image')) {
          msg = '이미지를 불러올 수 없어요. 다른 이미지로 다시 시도해 주세요.';
        } else if (errStr.contains('network') || errStr.contains('unavailable')) {
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
      if (lower.contains('있') || lower.contains('예') || lower == 'true' || lower == 'yes') return true;
      if (lower.contains('없') || lower.contains('아니') || lower == 'false' || lower == 'no') return false;
    }
    return null;
  }

  void _onDataChanged(JobPostData d) {
    setState(() {
      _data = d;
      final httpUrls = d.images
          .map((x) => x.path.trim())
          .where((p) => p.startsWith('http://') || p.startsWith('https://'))
          .toList();
      // 자료 첨부(치과) 갤러리 → imageUrls만. rawImageUrls(캡처 AI)와 혼동하지 않음.
      _extraDraftFields = {
        ..._extraDraftFields,
        'imageUrls': httpUrls,
      };
    });
  }

  Future<void> _setEditorStep(String step) async {
    setState(() => _editorStep = step);
    await JobDraftService.saveDraft(
      draftId: widget.draftId,
      formData: {
        ..._extraDraftFields,
        'editorStep': step,
      },
    );
    if (mounted) {
      setState(() {
        _extraDraftFields = {
          ..._extraDraftFields,
          'editorStep': step,
        };
      });
    }
  }

  Future<void> _goNextStep() async {
    if (_editorStep == 'step1') {
      await _setEditorStep('step2');
      return;
    }
    if (_editorStep == 'step2') {
      final pid = _selectedProfile?.id;
      if (pid != null) {
        final p = await ClinicProfileService.getProfile(pid);
        if (p != null && mounted) {
          setState(() {
            _selectedProfile = p;
            _data = _data.copyWith(
              clinicName: _data.clinicName.isEmpty
                  ? p.effectiveName
                  : _data.clinicName,
              address:
                  _data.address.isEmpty ? p.address : _data.address,
            );
          });
        }
      }
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
    final pid = _selectedProfile?.id;
    if (pid == null) return;
    final fresh = await ClinicProfileService.getProfile(pid);
    if (!mounted) return;
    if (fresh == null || !fresh.isBusinessVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '사업자 인증이 완료된 후 게시 단계로 이동할 수 있어요.',
            style: GoogleFonts.notoSansKr(fontSize: 14),
          ),
        ),
      );
      return;
    }
    setState(() => _selectedProfile = fresh);
    // 최종 저장: 폼의 toMap에는 이미지 URL이 없으므로 Firestore 최신본과 병합
    final latest = await JobDraftService.fetchDraft(widget.draftId);
    await JobDraftService.saveDraft(
      draftId: widget.draftId,
      formData: {
        ..._data.toMap(),
        ..._extraDraftFields,
        if (latest != null && latest.rawImageUrls.isNotEmpty)
          'rawImageUrls': latest.rawImageUrls,
        if (latest != null && latest.imageUrls.isNotEmpty) 'imageUrls': latest.imageUrls,
        'currentStep': 'review',
      },
    );
    if (mounted) context.push('/post-job/publish/${widget.draftId}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.webPublisherPageBg,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(child: _buildBodyAfterLoad()),
        ],
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
              child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.accent),
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
              Icon(Icons.error_outline, size: 48, color: AppColors.error.withValues(alpha: 0.85)),
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
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/post-job/input'),
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
              child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.accent),
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
          IconButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/post-job/input'),
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
          const SizedBox(width: 8),
          Text(
            '공고 편집',
            style: GoogleFonts.notoSansKr(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          if (_selectedProfile != null) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppPublisher.softRadius),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
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
          const Spacer(),
          SizedBox(
            height: AppPublisher.ctaHeight,
            child: ElevatedButton(
              onPressed: _goToPublish,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppPublisher.buttonRadius),
                ),
              ),
              child: Text(
                '게시 단계로',
                style: GoogleFonts.notoSansKr(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390),
                child: JobPostPreview(data: _dataForPreview()),
              ),
            ),
          ),
        ),
        Container(width: 1, color: AppColors.divider),
        Expanded(
          flex: 6,
          child: _buildFormSection(),
        ),
      ],
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
          padding: const EdgeInsets.all(20),
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
                          const Icon(Icons.warning_amber_rounded,
                              size: 18, color: AppColors.error),
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
                  if (_editorStep == 'step1') _buildStep1Body(profile),
                  if (_editorStep == 'step2')
                    PublisherClinicIdentitySection(
                      profile: profile,
                      onSaved: () async {
                        final u =
                            await ClinicProfileService.getProfile(profile.id);
                        if (u != null && mounted) {
                          setState(() => _selectedProfile = u);
                        }
                      },
                    ),
                  if (_editorStep == 'step3')
                    JobPostForm(
                      key: ValueKey('editor_s3_${widget.draftId}'),
                      initialData: _data,
                      draftId: widget.draftId,
                      publisherWebStyle: true,
                      publisherWebEditorStep: 'step3',
                      extraDraftFields: _extraDraftFields,
                      initialDraftUpdatedAt: _draftUpdatedAt,
                      onDataChanged: _onDataChanged,
                      onDraftIdChanged: (_) {},
                      onSubmit: (_) async => _goToPublish(),
                    ),
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
        border: Border(
          left: BorderSide(color: AppColors.accent, width: 3),
        ),
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
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    const labels = ['자료 첨부', '치과 정보', '공고 상세'];
    final idx = _editorStep == 'step1'
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
        final stepId = i == 0 ? 'step1' : i == 1 ? 'step2' : 'step3';
        return InkWell(
          onTap: () => _setEditorStep(stepId),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: active
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

  Widget _buildStep1Body(ClinicProfile profile) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final form = JobPostForm(
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
    final license = _buildLicenseSide(profile);
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: form),
          const SizedBox(width: 20),
          Expanded(child: license),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        form,
        const SizedBox(height: 20),
        license,
      ],
    );
  }

  Widget _buildLicenseSide(ClinicProfile profile) {
    if (profile.isBusinessVerified) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.05),
          border: Border(
            left: BorderSide(color: AppColors.accent, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_outlined, color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  '사업자 인증 완료',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '등록증은 내부 검증용이며 외부에 공개되지 않습니다.',
              style: GoogleFonts.notoSansKr(
                fontSize: 12,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    return BizLicenseUploadSection(
      profileId: profile.id,
      onCompleted: () async {
        final updated = await ClinicProfileService.getProfile(profile.id);
        if (updated != null && mounted) {
          setState(() => _selectedProfile = updated);
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
                  borderRadius: BorderRadius.circular(AppPublisher.buttonRadius),
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
    (sec: 0,  icon: Icons.cloud_upload_outlined,         msg: '이미지를 업로드하는 중이에요...'),
    (sec: 6,  icon: Icons.image_search_outlined,          msg: 'AI가 공고 이미지를 분석하고 있어요...'),
    (sec: 18, icon: Icons.manage_search_outlined,         msg: '치과 정보와 근무 조건을 추출하는 중이에요...'),
    (sec: 45, icon: Icons.playlist_add_check_outlined,    msg: '담당 업무와 복리후생을 정리하는 중이에요...'),
    (sec: 95, icon: Icons.check_circle_outline_rounded,   msg: '거의 다 됐어요! 조금만 기다려주세요...'),
  ];

  /// 진행 바 최대 예상 시간 (초) — Callable/함수 상한(180초)에 맞춤, 실제 완료 전 95%까지만 채움
  static const _maxSec = 170.0;

  late final DateTime _startTime;
  Timer? _ticker;
  int _elapsed = 0;

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
  }

  @override
  void dispose() {
    _ticker?.cancel();
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
        child: Column(
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
                style: GoogleFonts.notoSansKr(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '이미지가 많을수록 시간이 걸릴 수 있어요',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansKr(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 28),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: _progress),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOut,
                builder: (_, value, __) => LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: AppColors.divider,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${(_progress * 100).toInt()}%',
              style: GoogleFonts.notoSansKr(
                fontSize: 11,
                color: AppColors.textDisabled,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
