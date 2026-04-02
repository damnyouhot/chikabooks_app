import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../services/job_image_uploader.dart';
import '../../../services/job_draft_service.dart';
import '../../../services/transportation_lookup_service.dart';
import '../../../utils/tag_generator.dart';
import '../../../models/job.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../utils/job_image_attach_helpers.dart';

// ── 폼 전용 타이포그래피 헬퍼 ─────────────────────────────
TextStyle _ft({
  double size = 14,
  FontWeight weight = FontWeight.w600,
  Color? color,
  double letterSpacing = -0.4,
}) => GoogleFonts.notoSansKr(
  fontSize: size,
  fontWeight: weight,
  color: color,
  letterSpacing: letterSpacing,
);

/// 구인공고 폼 데이터 모델
class JobPostData {
  String clinicName;
  String title;
  String role;
  String career;            // 경력 조건: '신입', '경력 무관', '1년 이상' 등
  String employmentType;
  String workHours;
  String salary;
  List<String> benefits;
  String description;
  String address;
  String contact;
  List<XFile> images;

  // ── 신규 필드 ───────────────────────────────────────
  String? hospitalType;       // clinic | network | hospital | general
  int? chairCount;
  int? staffCount;
  List<String> workDays;      // ['mon','tue',...]
  bool weekendWork;
  bool nightShift;
  List<String> applyMethod;   // ['online','phone','email']
  bool isAlwaysHiring;
  DateTime? closingDate;
  // 교통편 (자동 + 수동)
  String? subwayStationName;
  List<String> subwayLines;
  int? walkingDistanceMeters;
  int? walkingMinutes;
  String? exitNumber;
  bool parking;
  // 좌표 (지오코딩 결과)
  double? lat;
  double? lng;
  // 태그 (자동 생성)
  List<String> tags;

  JobPostData({
    this.clinicName = '',
    this.title = '',
    this.role = '',
    this.career = '',
    this.employmentType = '',
    this.workHours = '',
    this.salary = '',
    List<String>? benefits,
    this.description = '',
    this.address = '',
    this.contact = '',
    List<XFile>? images,
    this.hospitalType,
    this.chairCount,
    this.staffCount,
    List<String>? workDays,
    this.weekendWork = false,
    this.nightShift = false,
    List<String>? applyMethod,
    this.isAlwaysHiring = false,
    this.closingDate,
    this.subwayStationName,
    List<String>? subwayLines,
    this.walkingDistanceMeters,
    this.walkingMinutes,
    this.exitNumber,
    this.parking = false,
    this.lat,
    this.lng,
    List<String>? tags,
  }) : benefits = benefits ?? [],
       images = images ?? [],
       workDays = workDays ?? [],
       applyMethod = applyMethod ?? [],
       subwayLines = subwayLines ?? [],
       tags = tags ?? [];

  JobPostData copyWith({
    String? clinicName,
    String? title,
    String? role,
    String? career,
    String? employmentType,
    String? workHours,
    String? salary,
    List<String>? benefits,
    String? description,
    String? address,
    String? contact,
    List<XFile>? images,
    String? hospitalType,
    int? chairCount,
    int? staffCount,
    List<String>? workDays,
    bool? weekendWork,
    bool? nightShift,
    List<String>? applyMethod,
    bool? isAlwaysHiring,
    DateTime? closingDate,
    String? subwayStationName,
    List<String>? subwayLines,
    int? walkingDistanceMeters,
    int? walkingMinutes,
    String? exitNumber,
    bool? parking,
    double? lat,
    double? lng,
    List<String>? tags,
  }) {
    return JobPostData(
      clinicName: clinicName ?? this.clinicName,
      title: title ?? this.title,
      role: role ?? this.role,
      career: career ?? this.career,
      employmentType: employmentType ?? this.employmentType,
      workHours: workHours ?? this.workHours,
      salary: salary ?? this.salary,
      benefits: benefits ?? List.from(this.benefits),
      description: description ?? this.description,
      address: address ?? this.address,
      contact: contact ?? this.contact,
      images: images ?? List.from(this.images),
      hospitalType: hospitalType ?? this.hospitalType,
      chairCount: chairCount ?? this.chairCount,
      staffCount: staffCount ?? this.staffCount,
      workDays: workDays ?? List.from(this.workDays),
      weekendWork: weekendWork ?? this.weekendWork,
      nightShift: nightShift ?? this.nightShift,
      applyMethod: applyMethod ?? List.from(this.applyMethod),
      isAlwaysHiring: isAlwaysHiring ?? this.isAlwaysHiring,
      closingDate: closingDate ?? this.closingDate,
      subwayStationName: subwayStationName ?? this.subwayStationName,
      subwayLines: subwayLines ?? List.from(this.subwayLines),
      walkingDistanceMeters: walkingDistanceMeters ?? this.walkingDistanceMeters,
      walkingMinutes: walkingMinutes ?? this.walkingMinutes,
      exitNumber: exitNumber ?? this.exitNumber,
      parking: parking ?? this.parking,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      tags: tags ?? List.from(this.tags),
    );
  }

  Map<String, dynamic> toMap() => {
    'clinicName': clinicName,
    'title': title,
    'role': role,
    'career': career,
    'employmentType': employmentType,
    'workHours': workHours,
    'salary': salary,
    'benefits': benefits,
    'description': description,
    'address': address,
    'contact': contact,
    if (hospitalType != null) 'hospitalType': hospitalType,
    if (chairCount != null) 'chairCount': chairCount,
    if (staffCount != null) 'staffCount': staffCount,
    if (workDays.isNotEmpty) 'workDays': workDays,
    'weekendWork': weekendWork,
    'nightShift': nightShift,
    if (applyMethod.isNotEmpty) 'applyMethod': applyMethod,
    'isAlwaysHiring': isAlwaysHiring,
    if (closingDate != null) 'closingDate': closingDate!.toIso8601String(),
    if (subwayStationName != null || subwayLines.isNotEmpty || walkingMinutes != null)
      'transportation': {
        if (subwayStationName != null) 'subwayStationName': subwayStationName,
        if (subwayLines.isNotEmpty) 'subwayLines': subwayLines,
        if (walkingDistanceMeters != null) 'walkingDistanceMeters': walkingDistanceMeters,
        if (walkingMinutes != null) 'walkingMinutes': walkingMinutes,
        if (exitNumber != null) 'exitNumber': exitNumber,
        'parking': parking,
      },
    if (lat != null) 'lat': lat,
    if (lng != null) 'lng': lng,
    if (tags.isNotEmpty) 'tags': tags,
  };

  /// Firestore 또는 드래프트 데이터에서 복원
  factory JobPostData.fromMap(Map<String, dynamic> data) {
    final trans = data['transportation'] as Map<String, dynamic>?;
    DateTime? closing;
    if (data['closingDate'] is String) {
      try { closing = DateTime.parse(data['closingDate'] as String); } catch (_) {}
    }
    return JobPostData(
      clinicName: data['clinicName'] as String? ?? '',
      title: data['title'] as String? ?? '',
      role: data['role'] as String? ?? '',
      career: data['career'] as String? ?? '',
      employmentType: data['employmentType'] as String? ?? '',
      workHours: data['workHours'] as String? ?? '',
      salary: data['salary'] as String? ?? '',
      benefits: List<String>.from(data['benefits'] ?? []),
      description: data['description'] as String? ?? '',
      address: data['address'] as String? ?? '',
      contact: data['contact'] as String? ?? '',
      hospitalType: data['hospitalType'] as String?,
      chairCount: (data['chairCount'] as num?)?.toInt(),
      staffCount: (data['staffCount'] as num?)?.toInt(),
      workDays: List<String>.from(data['workDays'] ?? []),
      weekendWork: (data['weekendWork'] as bool?) ?? false,
      nightShift: (data['nightShift'] as bool?) ?? false,
      applyMethod: List<String>.from(data['applyMethod'] ?? []),
      isAlwaysHiring: (data['isAlwaysHiring'] as bool?) ?? false,
      closingDate: closing,
      subwayStationName: trans?['subwayStationName'] as String?,
      subwayLines: List<String>.from(trans?['subwayLines'] ?? []),
      walkingDistanceMeters: (trans?['walkingDistanceMeters'] as num?)?.toInt(),
      walkingMinutes: (trans?['walkingMinutes'] as num?)?.toInt(),
      exitNumber: trans?['exitNumber'] as String?,
      parking: (trans?['parking'] as bool?) ?? false,
      lat: (data['lat'] as num?)?.toDouble(),
      lng: (data['lng'] as num?)?.toDouble(),
      tags: List<String>.from(data['tags'] ?? []),
    );
  }
}

/// 앱/웹 공통 구인공고 입력 폼
///
/// [onDataChanged] : 폼 값이 바뀔 때마다 호출 (프리뷰 업데이트용)
/// [onSubmit]      : 제출 버튼 클릭 시 호출
/// [draftId]       : 기존 드래프트 ID (임시저장 불러오기용)
/// [onDraftIdChanged] : 드래프트 생성/변경 시 부모에 알림
/// [publisherWebStyle] : 웹 공고자 플로우 — 흰 패널+구분선만 (`job_input_page`와 동일 톤, 그림자 없음)
/// [extraDraftFields] : `currentStep`·`rawImageUrls` 등 [JobPostData.toMap]에 없는 필드 — 매 저장 시 병합
/// [initialDraftUpdatedAt] : Firestore `updatedAt` — 재접속 후에도 「마지막 저장」 시각 표시용
/// [publisherWebEditorStep] : 웹 편집기 Stepper — `step1`(사진만)·`step3`(사진 제외 상세). null 이면 기존 전체 폼.
class JobPostForm extends StatefulWidget {
  final JobPostData? initialData;
  final ValueChanged<JobPostData>? onDataChanged;
  final Future<void> Function(JobPostData data)? onSubmit;
  final String? draftId;
  final ValueChanged<String>? onDraftIdChanged;
  final bool publisherWebStyle;
  final Map<String, dynamic>? extraDraftFields;
  final DateTime? initialDraftUpdatedAt;
  /// `step1` | `step3` — [publisherWebStyle] true 일 때만 사용
  final String? publisherWebEditorStep;

  const JobPostForm({
    super.key,
    this.initialData,
    this.onDataChanged,
    this.onSubmit,
    this.draftId,
    this.onDraftIdChanged,
    this.publisherWebStyle = false,
    this.extraDraftFields,
    this.initialDraftUpdatedAt,
    this.publisherWebEditorStep,
  });

  @override
  State<JobPostForm> createState() => _JobPostFormState();
}

class _JobPostFormState extends State<JobPostForm> {
  final _formKey = GlobalKey<FormState>();
  late JobPostData _data;

  // 텍스트 컨트롤러
  late final TextEditingController _clinicNameCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _workHoursCtrl;
  late final TextEditingController _salaryCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _contactCtrl;
  late final TextEditingController _benefitInputCtrl;

  // 신규 컨트롤러
  late final TextEditingController _chairCountCtrl;
  late final TextEditingController _staffCountCtrl;
  late final TextEditingController _exitNumberCtrl;

  // 드롭다운
  String? _selectedRole;
  String? _selectedEmploymentType;
  String? _selectedCareer;
  String? _selectedHospitalType;

  // AI 관련
  bool _aiReviewed = false;
  bool _isLoadingAi = false;
  bool _isSubmitting = false;
  bool _isLookingUpStation = false;
  List<NearbyStation> _nearbyStations = [];

  // 업로드 진행도 (이미지 인덱스 → 0.0~1.0)
  final Map<int, double> _uploadProgress = {};
  // 웹 미리보기 캐시 (XFile.name → bytes, 선택 시점에 한 번만 읽음)
  final Map<String, Uint8List> _previewCache = {};
  static const _uuid = Uuid();

  // ── 임시저장 관련 ──
  String? _draftId;
  Timer? _autoSaveTimer;
  bool _isSavingDraft = false;
  DateTime? _lastSavedAt;
  bool _imageDropActive = false;
  static const _autoSaveDebounce = Duration(milliseconds: 1800);

  static const _roles = ['치과위생사', '간호조무사', '데스크', '원장', '기타'];
  static const _careers = ['신입', '경력 무관', '1년 이상', '2년 이상', '3년 이상', '5년 이상'];
  static const _employmentTypes = ['정규직', '계약직', '파트타임', '인턴'];
  static const _commonBenefits = ['4대보험', '퇴직금', '연차', '식비지원', '주차지원', '명절상여'];

  /// 공고자 웹(`job_input_page` 텍스트 탭 등과 동일: 직각·구분선 중심)
  bool get _pubWeb => widget.publisherWebStyle;
  /// 웹 편집기 Stepper: AI 자동채우기·최종 등록 버튼 숨김
  bool get _webEditorMode =>
      _pubWeb && widget.publisherWebEditorStep != null;
  /// 웹 공고자: 썸네일·레거시 아웃라인 필드 등
  BorderRadius get _rBox =>
      _pubWeb ? BorderRadius.circular(AppPublisher.softRadius) : BorderRadius.circular(10);
  BorderRadius get _rChip =>
      _pubWeb ? BorderRadius.circular(AppPublisher.softRadius) : BorderRadius.circular(8);
  /// 웹 공고자: 주요 버튼(사진 추가·AI·임시저장·등록 등)
  BorderRadius get _rBtn =>
      _pubWeb ? BorderRadius.circular(AppPublisher.buttonRadius) : BorderRadius.circular(10);

  @override
  void didUpdateWidget(JobPostForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.draftId != oldWidget.draftId) {
      _draftId = widget.draftId;
    }
    if (widget.initialDraftUpdatedAt != oldWidget.initialDraftUpdatedAt &&
        widget.initialDraftUpdatedAt != null) {
      _lastSavedAt = widget.initialDraftUpdatedAt;
    }
    _maybeRehydrateControllersAfterParentDraftLoad(oldWidget);
  }

  /// 부모가 비동기로 드래프트를 채운 뒤 같은 [draftId]로 리빌드할 때 컨트롤러 동기화
  void _maybeRehydrateControllersAfterParentDraftLoad(JobPostForm oldWidget) {
    final id = widget.draftId;
    if (id == null || id.isEmpty || id != oldWidget.draftId) return;
    final oldD = oldWidget.initialData ?? JobPostData();
    final newD = widget.initialData ?? JobPostData();
    final wasBlank =
        oldD.title.trim().isEmpty && oldD.clinicName.trim().isEmpty;
    final hasNow =
        newD.title.trim().isNotEmpty || newD.clinicName.trim().isNotEmpty;
    if (wasBlank && hasNow) {
      _hydrateControllersFromData(newD);
    }
  }

  void _hydrateControllersFromData(JobPostData d) {
    _data = _sanitizeFormData(d);
    _clinicNameCtrl.text = _data.clinicName;
    _titleCtrl.text = _data.title;
    _workHoursCtrl.text = _data.workHours;
    _salaryCtrl.text = _data.salary;
    _descriptionCtrl.text = _data.description;
    _addressCtrl.text = _data.address;
    _contactCtrl.text = _data.contact;
    _chairCountCtrl.text = _data.chairCount != null ? '${_data.chairCount}' : '';
    _staffCountCtrl.text = _data.staffCount != null ? '${_data.staffCount}' : '';
    _exitNumberCtrl.text = _data.exitNumber ?? '';
    _selectedRole = _data.role.isEmpty ? null : _data.role;
    _selectedCareer = _data.career.isEmpty ? null : _data.career;
    _selectedEmploymentType =
        _data.employmentType.isEmpty ? null : _data.employmentType;
    _selectedHospitalType = _data.hospitalType;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _data = _sanitizeFormData(widget.initialData ?? JobPostData());
    _draftId = widget.draftId;
    _lastSavedAt = widget.initialDraftUpdatedAt;
    _clinicNameCtrl = TextEditingController(text: _data.clinicName);
    _titleCtrl = TextEditingController(text: _data.title);
    _workHoursCtrl = TextEditingController(text: _data.workHours);
    _salaryCtrl = TextEditingController(text: _data.salary);
    _descriptionCtrl = TextEditingController(text: _data.description);
    _addressCtrl = TextEditingController(text: _data.address);
    _contactCtrl = TextEditingController(text: _data.contact);
    _benefitInputCtrl = TextEditingController();
    _chairCountCtrl = TextEditingController(
      text: _data.chairCount != null ? '${_data.chairCount}' : '',
    );
    _staffCountCtrl = TextEditingController(
      text: _data.staffCount != null ? '${_data.staffCount}' : '',
    );
    _exitNumberCtrl = TextEditingController(text: _data.exitNumber ?? '');
    _selectedRole = _data.role.isEmpty ? null : _data.role;
    _selectedCareer = _data.career.isEmpty ? null : _data.career;
    _selectedEmploymentType =
        _data.employmentType.isEmpty ? null : _data.employmentType;
    _selectedHospitalType = _data.hospitalType;
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    for (final c in [
      _clinicNameCtrl,
      _titleCtrl,
      _workHoursCtrl,
      _salaryCtrl,
      _descriptionCtrl,
      _addressCtrl,
      _contactCtrl,
      _benefitInputCtrl,
      _chairCountCtrl,
      _staffCountCtrl,
      _exitNumberCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _notify() {
    final chair = int.tryParse(_chairCountCtrl.text.trim());
    final staff = int.tryParse(_staffCountCtrl.text.trim());
    final exit = _exitNumberCtrl.text.trim();

    _data = _data.copyWith(
      clinicName: _clinicNameCtrl.text,
      title: _titleCtrl.text,
      role: _selectedRole ?? '',
      career: _selectedCareer ?? '',
      employmentType: _selectedEmploymentType ?? '',
      workHours: _workHoursCtrl.text,
      salary: _salaryCtrl.text,
      description: _descriptionCtrl.text,
      address: _addressCtrl.text,
      contact: _contactCtrl.text,
      hospitalType: _selectedHospitalType,
      chairCount: chair,
      staffCount: staff,
      exitNumber: exit.isNotEmpty ? exit : null,
    );

    // 태그 자동 생성
    _data.tags = TagGenerator.generate(
      benefits: _data.benefits,
      workDays: _data.workDays,
      weekendWork: _data.weekendWork,
      nightShift: _data.nightShift,
      career: _data.career,
      applyMethod: _data.applyMethod,
      subwayStationName: _data.subwayStationName,
      walkingMinutes: _data.walkingMinutes,
    );

    widget.onDataChanged?.call(_data);
    _scheduleAutoSave();
  }

  bool _hasMeaningfulPayload() {
    for (final v in _data.toMap().values) {
      if (v is String && v.isNotEmpty) return true;
      if (v is List && v.isNotEmpty) return true;
      if (v is Map && v.isNotEmpty) return true;
    }
    return false;
  }

  Map<String, dynamic> _mergedFormData() => {
        ..._data.toMap(),
        ...?widget.extraDraftFields,
      };

  // ── 임시저장 (auto-save with debounce) ──
  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(_autoSaveDebounce, _autoSave);
  }

  Future<void> _autoSave() async {
    // 기존 드래프트 편집 중이면 메타/타임스탬프 유지를 위해 항상 저장 가능
    if (_draftId == null && !_hasMeaningfulPayload()) return;

    if (_isSavingDraft) return;
    if (!mounted) return;
    setState(() => _isSavingDraft = true);

    try {
      final id = await JobDraftService.saveDraft(
        draftId: _draftId,
        formData: _mergedFormData(),
      );
      if (id != null && mounted) {
        final isNew = _draftId == null;
        _draftId = id;
        _lastSavedAt = DateTime.now();
        if (isNew) widget.onDraftIdChanged?.call(id);
        setState(() {});
      }
    } catch (e) {
      debugPrint('⚠️ autoSave error: $e');
    } finally {
      if (mounted) setState(() => _isSavingDraft = false);
    }
  }

  /// 수동 임시저장 (버튼 클릭용)
  Future<void> _manualSaveDraft() async {
    _autoSaveTimer?.cancel();
    await _autoSave();
    if (mounted && _lastSavedAt != null) {
      _showSnack('임시저장 완료');
    }
  }

  // ── AI 자동채움 (Storage 업로드 → Callable) ────────────
  Future<void> _runAiAutofill() async {
    if (_data.images.isEmpty) {
      _showSnack('이미지를 먼저 업로드해주세요.');
      return;
    }
    setState(() => _isLoadingAi = true);

    try {
      // 1) Storage에 임시 업로드
      final tempJobId = 'tmp_${_uuid.v4()}';
      final urls = await JobImageUploader.uploadImages(
        jobId: tempJobId,
        images: _data.images,
        onProgress: (idx, progress) {
          if (mounted) setState(() => _uploadProgress[idx] = progress);
        },
      );

      // 2) Cloud Function 호출
      final callable = FirebaseFunctions.instance.httpsCallable(
        'parseJobImagesToForm',
      );
      final result = await callable.call({
        'imageUrls': urls,
        'jobId': tempJobId,
      });
      final res = Map<String, dynamic>.from(result.data as Map);

      // 3) 결과를 폼에 반영
      if (!mounted) return;
      setState(() {
        if ((res['clinicName'] as String? ?? '').isNotEmpty) {
          _clinicNameCtrl.text = res['clinicName'] as String;
        }
        if ((res['title'] as String? ?? '').isNotEmpty) {
          _titleCtrl.text = res['title'] as String;
        }
        if ((res['role'] as String? ?? '').isNotEmpty &&
            _roles.contains(res['role'])) {
          _selectedRole = res['role'] as String;
        }
        if ((res['career'] as String? ?? '').isNotEmpty) {
          _selectedCareer = _matchCareer(res['career'] as String);
        }
        if ((res['employmentType'] as String? ?? '').isNotEmpty &&
            _employmentTypes.contains(res['employmentType'])) {
          _selectedEmploymentType = res['employmentType'] as String;
        }
        if ((res['workHours'] as String? ?? '').isNotEmpty) {
          _workHoursCtrl.text = res['workHours'] as String;
        }
        if ((res['salary'] as String? ?? '').isNotEmpty) {
          _salaryCtrl.text = res['salary'] as String;
        }
        if ((res['description'] as String? ?? '').isNotEmpty) {
          _descriptionCtrl.text = res['description'] as String;
        }
        if ((res['address'] as String? ?? '').isNotEmpty) {
          _addressCtrl.text = res['address'] as String;
        }
        if ((res['contact'] as String? ?? '').isNotEmpty) {
          _contactCtrl.text = res['contact'] as String;
        }

        // ── workDays: 한글("월","화"…) → 영문 코드("mon","tue"…) ──
        final rawDays =
            (res['workDays'] as List?)?.map((e) => e.toString()).toList();
        if (rawDays != null && rawDays.isNotEmpty) {
          _data = _data.copyWith(workDays: _koreanDaysToKeys(rawDays));
        }

        // ── weekendWork / nightShift: 문자열 → bool ──
        final ww = res['weekendWork'];
        if (ww != null) {
          _data = _data.copyWith(weekendWork: _toBoolField(ww));
        }
        final ns = res['nightShift'];
        if (ns != null) {
          _data = _data.copyWith(nightShift: _toBoolField(ns));
        }

        // ── hospitalType: 한글 label → 영문 key ──
        final ht = res['hospitalType'] as String? ?? '';
        if (ht.isNotEmpty) {
          _selectedHospitalType = _matchHospitalType(ht);
        }

        // ── benefits: 공통 목록과 정규화 후 반영 ──
        final rawBenefits =
            (res['benefits'] as List?)?.map((e) => e.toString()).toList();
        if (rawBenefits != null && rawBenefits.isNotEmpty) {
          _data = _data.copyWith(benefits: _normalizeBenefits(rawBenefits));
        }

        _uploadProgress.clear();
        _aiReviewed = false;
      });
      _notify();
      // 추출 직후 1회 즉시 임시저장 (디바운스와 무관)
      _autoSaveTimer?.cancel();
      await _autoSave();

      if (res['_mock'] == true) {
        _showSnack('이미지 업로드 완료! AI 키 미설정 상태로 직접 입력해주세요.');
      } else {
        _showSnack('AI 자동입력 완료! 내용을 꼭 검토해주세요.');
      }
    } catch (e) {
      _showSnack('자동입력 실패: 직접 입력 후 제출해주세요.');
      if (mounted) setState(() => _uploadProgress.clear());
    } finally {
      if (mounted) setState(() => _isLoadingAi = false);
    }
  }

  /// draft나 initialData 로딩 시 한글 workDays·benefits 등을 정규화
  JobPostData _sanitizeFormData(JobPostData d) {
    var result = d;
    // workDays: 한글이 섞여있으면 영문 코드로 변환
    if (d.workDays.isNotEmpty) {
      final hasKorean = d.workDays.any((v) => _korDayToKey.containsKey(v.trim()));
      if (hasKorean) {
        result = result.copyWith(workDays: _koreanDaysToKeys(d.workDays));
      }
    }
    // benefits: 공통 항목과 부분 매칭 정규화
    if (d.benefits.isNotEmpty) {
      result = result.copyWith(benefits: _normalizeBenefits(d.benefits));
    }
    return result;
  }

  // ── AI 추출 결과 정규화 헬퍼 ─────────────────────────────

  /// 한글 요일("월","화"…) → 영문 키("mon","tue"…)
  static const _korDayToKey = {
    '월': 'mon', '화': 'tue', '수': 'wed',
    '목': 'thu', '금': 'fri', '토': 'sat', '일': 'sun',
    '월요일': 'mon', '화요일': 'tue', '수요일': 'wed',
    '목요일': 'thu', '금요일': 'fri', '토요일': 'sat', '일요일': 'sun',
  };
  static const _validDayCodes = {'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'};
  List<String> _koreanDaysToKeys(List<String> raw) {
    final keys = <String>[];
    for (final d in raw) {
      final t = d.trim();
      // 이미 영문 코드면 그대로 사용
      if (_validDayCodes.contains(t)) {
        if (!keys.contains(t)) keys.add(t);
        continue;
      }
      final k = _korDayToKey[t];
      if (k != null && !keys.contains(k)) keys.add(k);
    }
    return keys;
  }

  /// 자유형 career 텍스트 → _careers 목록 가장 가까운 항목
  String? _matchCareer(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    if (_careers.contains(t)) return t;
    // "경력 무관" 변형
    if (t.contains('무관')) return '경력 무관';
    // "신입" 변형
    if (t.contains('신입')) return '신입';
    // "n년 이상" 패턴
    final m = RegExp(r'(\d+)\s*년').firstMatch(t);
    if (m != null) {
      final y = int.tryParse(m.group(1)!) ?? 0;
      if (y >= 5) return '5년 이상';
      if (y >= 3) return '3년 이상';
      if (y >= 2) return '2년 이상';
      if (y >= 1) return '1년 이상';
    }
    return null;
  }

  /// 문자열/bool 혼합 → bool (AI가 "격주 토요일" 같은 텍스트를 줄 수 있음)
  bool _toBoolField(dynamic v) {
    if (v is bool) return v;
    if (v is String) {
      final s = v.trim().toLowerCase();
      if (s.isEmpty || s == 'false' || s == '없음' || s == '없어요' || s == 'no') {
        return false;
      }
      return true;
    }
    return false;
  }

  /// 한글 hospitalType label → 영문 key
  String? _matchHospitalType(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    for (final e in Job.hospitalTypeLabels.entries) {
      if (e.value == t || e.key == t) return e.key;
    }
    if (t.contains('네트워크')) return 'network';
    if (t.contains('종합') || t.contains('대학')) return 'general';
    if (t.contains('병원')) return 'hospital';
    return 'clinic';
  }

  /// AI 추출 benefits → _commonBenefits 정규화
  /// "4대보험 지원" → "4대보험" 매칭, 나머지는 그대로
  List<String> _normalizeBenefits(List<String> raw) {
    final result = <String>[];
    for (final b in raw) {
      final t = b.trim();
      if (t.isEmpty) continue;
      // 정확 매칭
      if (_commonBenefits.contains(t)) {
        if (!result.contains(t)) result.add(t);
        continue;
      }
      // 공통 항목 부분 매칭 ("4대보험 지원" → "4대보험")
      bool matched = false;
      for (final c in _commonBenefits) {
        if (t.contains(c) || c.contains(t)) {
          if (!result.contains(c)) result.add(c);
          matched = true;
          break;
        }
      }
      if (!matched && !result.contains(t)) result.add(t);
    }
    return result;
  }

  // ── 이미지 선택 · 드롭 ─────────────────────────────────
  Future<void> _pickImages() async {
    final remaining = 10 - _data.images.length;
    if (remaining <= 0) return;
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(limit: remaining);
    if (picked.isEmpty) return;
    await _appendImagesFromXFiles(picked);
  }

  Future<void> _appendImagesFromXFiles(List<XFile> picked) async {
    if (picked.isEmpty) return;
    final remaining = 10 - _data.images.length;
    if (remaining <= 0) return;

    final allowed = <XFile>[];
    for (final f in picked) {
      if (!isAllowedJobImageFileName(f.name)) continue;
      allowed.add(f);
      if (allowed.length >= remaining) break;
    }
    if (allowed.isEmpty) {
      if (mounted) {
        _showSnack('지원 이미지(jpg, png, gif, webp 등)만 추가할 수 있어요.');
      }
      return;
    }

    if (kIsWeb) {
      for (final f in allowed) {
        if (!_previewCache.containsKey(f.name)) {
          _previewCache[f.name] = await f.readAsBytes();
        }
      }
    }

    final combined = [..._data.images, ...allowed];
    final limited = combined.take(10).toList();
    setState(() {
      _data = _data.copyWith(images: limited);
    });
    _notify();
  }

  Future<void> _onImageDropDone(DropDoneDetails details) async {
    setState(() => _imageDropActive = false);
    final flat = flattenDropItems(details.files);
    await _appendImagesFromXFiles(flat);
  }

  // ── 복리후생 토글 ──────────────────────────────────────
  void _toggleBenefit(String benefit) {
    final list = List<String>.from(_data.benefits);
    if (list.contains(benefit)) {
      list.remove(benefit);
    } else {
      list.add(benefit);
    }
    setState(() => _data = _data.copyWith(benefits: list));
    _notify();
  }

  // ── 제출 ───────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_data.images.isNotEmpty && !_aiReviewed && !_webEditorMode) {
      _showSnack('AI 자동입력 내용을 검토했다고 체크해주세요.');
      return;
    }
    setState(() => _isSubmitting = true);

    try {
      // 1) jobId를 먼저 생성 (Storage 경로와 Firestore 문서 ID 일치)
      final jobId = _uuid.v4();

      // 2) 이미지가 있으면 Storage 업로드 후 URL 획득
      List<String> imageUrls = [];
      if (_data.images.isNotEmpty) {
        imageUrls = await JobImageUploader.uploadImages(
          jobId: jobId,
          images: _data.images,
          onProgress: (idx, progress) {
            if (mounted) setState(() => _uploadProgress[idx] = progress);
          },
        );
      }

      // 3) createJobPosting Callable (jobId 전달 → 서버에서 해당 ID로 문서 생성)
      final callable = FirebaseFunctions.instance.httpsCallable(
        'createJobPosting',
      );
      await callable.call({..._data.toMap(), 'jobId': jobId, 'images': imageUrls});

      // 4) 제출 성공 → 드래프트 삭제
      _autoSaveTimer?.cancel();
      if (_draftId != null) {
        await JobDraftService.deleteDraft(_draftId!);
        _draftId = null;
      }

      // 5) 외부 onSubmit 콜백 (웹 페이지에서 완료 화면 전환 등)
      await widget.onSubmit?.call(_data);
    } catch (e) {
      _showSnack('등록 실패: $e');
    } finally {
      if (mounted)
        setState(() {
          _isSubmitting = false;
          _uploadProgress.clear();
        });
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: _rBox),
      ),
    );
  }

  /// 웹 공고자: `web_login_page`와 동일한 밑줄 입력
  InputDecoration _pubUnderlineDecoration({required String? label, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: _ft(
        size: 13,
        weight: FontWeight.w400,
        color: AppColors.textDisabled,
      ),
      labelStyle: _ft(
        size: 13,
        weight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      isDense: true,
      border: UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.divider),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.divider),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.accent, width: 2),
      ),
      errorBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.cardEmphasis),
      ),
      focusedErrorBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.cardEmphasis, width: 1.5),
      ),
      filled: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      onChanged: _notify,
      child: ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: widget.publisherWebStyle
            ? const EdgeInsets.symmetric(vertical: 12, horizontal: 0)
            : const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: _buildMainFormSections(),
      ),
    );
  }

  List<Widget> _buildMainFormSections() {
    final full = !_webEditorMode;
    final step1 = widget.publisherWebEditorStep == 'step1';
    final step3 = widget.publisherWebEditorStep == 'step3';

    final out = <Widget>[];
    void gap() =>
        out.add(const SizedBox(height: AppPublisher.formSectionSpacing));

    if (full || step1) {
      out.add(
        _sectionCard(
          title: _sectionTitle(
            publisher: step1 ? '치과 이미지 (공고에 노출)' : '공고 사진 · AI 자동입력',
            legacy: '📷 공고 사진 / AI 자동입력',
          ),
          child: _buildImageSection(),
        ),
      );
      gap();
    }

    if (full || step3) {
      out.add(
        _sectionCard(
          title: _sectionTitle(publisher: '기본 정보', legacy: '🏥 기본 정보'),
          child: _buildBasicInfo(),
        ),
      );
      gap();
      out.add(
        _sectionCard(
          title: _sectionTitle(publisher: '병원 정보', legacy: '🏢 병원 정보'),
          child: _buildHospitalInfo(),
        ),
      );
      gap();
      out.add(
        _sectionCard(
          title: _sectionTitle(publisher: '근무 조건', legacy: '⏰ 근무 조건'),
          child: _buildWorkConditions(),
        ),
      );
      gap();
      out.add(
        _sectionCard(
          title: _sectionTitle(
            publisher: '지원 방법 · 마감일',
            legacy: '📋 지원 방법 / 마감일',
          ),
          child: _buildApplySection(),
        ),
      );
      gap();
      out.add(
        _sectionCard(
          title: _sectionTitle(publisher: '복리후생', legacy: '🎁 복리후생'),
          child: _buildBenefits(),
        ),
      );
      gap();
      out.add(
        _sectionCard(
          title: _sectionTitle(publisher: '상세 내용', legacy: '📝 상세 내용'),
          child: _buildDescription(),
        ),
      );
      gap();
      out.add(
        _sectionCard(
          title: _sectionTitle(
            publisher: '주소 · 연락처 · 교통',
            legacy: '📍 주소 / 연락처 / 교통편',
          ),
          child: _buildAddressContact(),
        ),
      );
      gap();
      if (_data.tags.isNotEmpty) {
        out.add(
          _sectionCard(
            title: _sectionTitle(
              publisher: '자동 생성 태그',
              legacy: '🏷️ 자동 생성 태그',
            ),
            child: _buildTagsPreview(),
          ),
        );
        gap();
      }
    }

    out.add(const SizedBox(height: AppPublisher.formSectionSpacing));
    out.add(_buildSubmitSection());
    out.add(const SizedBox(height: 40));
    return out;
  }

  String _sectionTitle({required String publisher, required String legacy}) =>
      widget.publisherWebStyle ? publisher : legacy;

  // ── 섹션 카드 래퍼 ─────────────────────────────────────
  Widget _sectionCard({required String title, required Widget child}) {
    if (widget.publisherWebStyle) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: _ft(
                size: AppPublisher.formSectionTitleSize,
                weight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppPublisher.formSectionTitleGap),
            child,
            const SizedBox(height: AppPublisher.formSectionBottomGap),
          ],
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: _ft(size: 14, weight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  // ── 이미지 + AI 섹션 ───────────────────────────────────
  Widget _buildImageSection() {
    return DropTarget(
      onDragEntered: (_) => setState(() => _imageDropActive = true),
      onDragExited: (_) => setState(() => _imageDropActive = false),
      onDragDone: _onImageDropDone,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: _imageDropActive
            ? const EdgeInsets.all(10)
            : EdgeInsets.zero,
        decoration: _pubWeb
            ? (_imageDropActive
                ? BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.accent, width: 2),
                    ),
                  )
                : null)
            : BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: _imageDropActive ? AppColors.accent : AppColors.divider,
                    width: _imageDropActive ? 2 : 1,
                  ),
                ),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '아래 영역을 눌러 폴더에서 사진을 고르거나, 이미지 파일을 이곳으로 끌어다 놓을 수 있어요.',
              style: _ft(
                size: 12,
                weight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '공고 이미지를 올리면 AI가 폼을 채워줘요. (최대 10장, jpg/png, 장당 5MB 이하)',
              style: _ft(
                size: 12,
                weight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            // 이미지 그리드
            if (_data.images.isNotEmpty) ...[
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _data.images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final progress = _uploadProgress[i];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: _rBox,
                      child: _buildThumbnail(_data.images[i]),
                    ),
                    // 업로드 진행도 오버레이
                    if (progress != null && progress < 1.0)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: _rBox,
                          child: Container(
                            color: AppColors.black.withOpacity(0.45),
                            child: Center(
                              child: Text(
                                '${(progress * 100).toInt()}%',
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // 삭제 버튼
                    if (progress == null || progress >= 1.0)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () {
                            final removed = _data.images[i];
                            final list = List<XFile>.from(_data.images)
                              ..removeAt(i);
                            // 웹 캐시도 함께 정리
                            _previewCache.remove(removed.name);
                            setState(
                              () => _data = _data.copyWith(images: list),
                            );
                            _notify();
                          },
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.black.withOpacity(0.54),
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 12,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            // 이미지 추가 버튼
            SizedBox(
              height: _pubWeb ? AppPublisher.ctaHeight : null,
              child: OutlinedButton.icon(
                onPressed: _data.images.length < 10 ? _pickImages : null,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: Text('사진 추가 (${_data.images.length}/10)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: AppColors.divider),
                  shape: RoundedRectangleBorder(
                    borderRadius: _rBtn,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
            ),
            if (!_webEditorMode) ...[
              SizedBox(width: _pubWeb ? AppPublisher.formButtonRowGap : 10),
              // AI 자동채움 (웹 편집기 Stepper 에서는 숨김 — 상단 AI 초안과 중복)
              SizedBox(
                height: _pubWeb ? AppPublisher.ctaHeight : null,
                child: ElevatedButton.icon(
                  onPressed: _isLoadingAi ? null : _runAiAutofill,
                  icon:
                      _isLoadingAi
                          ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                          : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(_isLoadingAi ? '분석 중...' : 'AI로 자동 채우기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cardEmphasis,
                    foregroundColor: AppColors.onCardEmphasis,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: _rBtn,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
        ),
      ),
    );
  }

  // ── 썸네일 위젯 (앱: Image.file / 웹: Image.memory 캐시) ──
  Widget _buildThumbnail(XFile file) {
    if (kIsWeb) {
      final bytes = _previewCache[file.name];
      if (bytes != null) {
        return Image.memory(
          bytes,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
        );
      }
      return Container(
        width: 100,
        height: 100,
        color: AppColors.surfaceMuted,
        child: const Center(
          child: Icon(Icons.image_outlined, color: AppColors.textDisabled),
        ),
      );
    }
    return Image.file(
      File(file.path),
      width: 100,
      height: 100,
      fit: BoxFit.cover,
    );
  }

  // ── 기본 정보 ──────────────────────────────────────────
  Widget _buildBasicInfo() {
    return Column(
      children: [
        _field(
          controller: _clinicNameCtrl,
          label: '치과명',
          hint: '예) 서울미소치과',
          validator: (v) => (v?.isEmpty ?? true) ? '치과명을 입력해주세요.' : null,
        ),
        const SizedBox(height: 12),
        _field(
          controller: _titleCtrl,
          label: '공고 제목',
          hint: '예) 치과위생사 모집합니다',
          validator: (v) => (v?.isEmpty ?? true) ? '제목을 입력해주세요.' : null,
        ),
        const SizedBox(height: 12),
        _dropdown(
          label: '채용 직무',
          value: _selectedRole,
          items: _roles,
          onChanged: (v) {
            setState(() => _selectedRole = v);
            _notify();
          },
        ),
        const SizedBox(height: 12),
        _dropdown(
          label: '경력 조건',
          value: _selectedCareer,
          items: _careers,
          onChanged: (v) {
            setState(() => _selectedCareer = v);
            _notify();
          },
        ),
        const SizedBox(height: 12),
        _dropdown(
          label: '고용 형태',
          value: _selectedEmploymentType,
          items: _employmentTypes,
          onChanged: (v) {
            setState(() => _selectedEmploymentType = v);
            _notify();
          },
        ),
      ],
    );
  }

  // ── 근무 조건 ──────────────────────────────────────────
  Widget _buildWorkConditions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(
          controller: _workHoursCtrl,
          label: '근무 시간',
          hint: '예) 09:00 ~ 18:00 (주 5일)',
        ),
        const SizedBox(height: 12),
        _field(
          controller: _salaryCtrl,
          label: '급여',
          hint: '예) 월 250~300만원 (경력 협의)',
        ),
        const SizedBox(height: 16),
        Text('근무 요일', style: _ft(size: 13, weight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: _pubWeb ? AppPublisher.formChipSpacing : 6,
          runSpacing: _pubWeb ? AppPublisher.formChipRunSpacing : 6,
          children: Job.workDayLabels.entries.map((e) {
            final selected = _data.workDays.contains(e.key);
            return FilterChip(
              label: Text(e.value),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  final list = List<String>.from(_data.workDays);
                  selected ? list.remove(e.key) : list.add(e.key);
                  _data = _data.copyWith(workDays: list);
                });
                _notify();
              },
              selectedColor: AppColors.accent.withOpacity(0.2),
              checkmarkColor: AppColors.accent,
              labelStyle: _ft(size: 13, weight: FontWeight.w600,
                color: selected ? AppColors.accent : AppColors.textSecondary),
              shape: RoundedRectangleBorder(
                borderRadius: _rChip,
                side: BorderSide(color: selected ? AppColors.accent.withOpacity(0.4) : AppColors.divider),
              ),
              backgroundColor: AppColors.white,
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        _switchRow(
          label: '주말 근무',
          value: _data.weekendWork,
          onChanged: (v) {
            setState(() => _data = _data.copyWith(weekendWork: v));
            _notify();
          },
        ),
        _switchRow(
          label: '야간 진료',
          value: _data.nightShift,
          onChanged: (v) {
            setState(() => _data = _data.copyWith(nightShift: v));
            _notify();
          },
        ),
      ],
    );
  }

  // ── 복리후생 ───────────────────────────────────────────
  Widget _buildBenefits() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: _pubWeb ? AppPublisher.formChipSpacing : 8,
          runSpacing: _pubWeb ? AppPublisher.formChipRunSpacing : 8,
          children:
              _commonBenefits.map((b) {
                final selected = _data.benefits.contains(b);
                return FilterChip(
                  label: Text(b),
                  selected: selected,
                  onSelected: (_) => _toggleBenefit(b),
                  selectedColor: AppColors.cardEmphasis.withOpacity(0.18),
                  checkmarkColor: AppColors.textPrimary,
                  labelStyle: _ft(
                    size: 13,
                    weight: FontWeight.w600,
                    color: _data.benefits.contains(b) ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: _rChip,
                    side: BorderSide(
                      color: selected ? AppColors.cardEmphasis.withOpacity(0.45) : AppColors.divider,
                    ),
                  ),
                  backgroundColor: AppColors.white,
                );
              }).toList(),
        ),
        const SizedBox(height: 12),
        // 직접 입력 추가
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _benefitInputCtrl,
                style: _ft(size: 13, weight: FontWeight.w600, color: AppColors.textPrimary),
                decoration: _pubWeb
                    ? _pubUnderlineDecoration(
                        label: null,
                        hint: '기타 복리후생 직접 입력',
                      )
                    : InputDecoration(
                        hintText: '기타 복리후생 직접 입력',
                        hintStyle: _ft(
                          size: 13,
                          weight: FontWeight.w400,
                          color: AppColors.textDisabled,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: _rBox,
                          borderSide: const BorderSide(color: AppColors.divider),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: _rBox,
                          borderSide: const BorderSide(color: AppColors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: _rBox,
                          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                        ),
                      ),
              ),
            ),
            SizedBox(width: _pubWeb ? AppPublisher.formButtonRowGap : 8),
            TextButton(
              onPressed: () {
                final v = _benefitInputCtrl.text.trim();
                if (v.isEmpty) return;
                setState(() {
                  _data = _data.copyWith(benefits: [..._data.benefits, v]);
                  _benefitInputCtrl.clear();
                });
                _notify();
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                padding: _pubWeb
                    ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: _rChip,
                ),
              ),
              child: const Text('추가'),
            ),
          ],
        ),
        if (_data.benefits.any((b) => !_commonBenefits.contains(b))) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: _pubWeb ? AppPublisher.formChipSpacing : 6,
            runSpacing: _pubWeb ? AppPublisher.formChipRunSpacing : 6,
            children:
                _data.benefits
                    .where((b) => !_commonBenefits.contains(b))
                    .map(
                      (b) => Chip(
                        label: Text(
                          b,
                          style: _ft(size: 12, weight: FontWeight.w600),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () {
                          final list = List<String>.from(_data.benefits)
                            ..remove(b);
                          setState(
                            () => _data = _data.copyWith(benefits: list),
                          );
                          _notify();
                        },
                        backgroundColor: AppColors.accent.withValues(alpha: 0.08),
                        side: _pubWeb
                            ? BorderSide(color: AppColors.divider)
                            : BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: _rChip),
                        padding: _pubWeb
                            ? const EdgeInsets.symmetric(horizontal: 4)
                            : null,
                      ),
                    )
                    .toList(),
          ),
        ],
      ],
    );
  }

  // ── 상세 내용 ──────────────────────────────────────────
  Widget _buildDescription() {
    return _field(
      controller: _descriptionCtrl,
      label: '공고 상세 내용',
      hint: '근무 환경, 담당 업무, 우대사항 등을 자유롭게 작성해주세요.',
      maxLines: 6,
    );
  }

  // ── 주소 / 연락처 / 교통편 ───────────────────────────────
  Widget _buildAddressContact() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(
          controller: _addressCtrl,
          label: '치과 주소',
          hint: '예) 서울시 강남구 테헤란로 123',
          validator: (v) => (v?.isEmpty ?? true) ? '주소를 입력해주세요.' : null,
        ),
        const SizedBox(height: 12),
        _field(
          controller: _contactCtrl,
          label: '연락처',
          hint: '예) 02-1234-5678 또는 이메일',
        ),
        const SizedBox(height: 16),
        // 교통편 자동 조회
        Text('교통편', style: _ft(size: 13, weight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        if (_nearbyStations.isNotEmpty) ...[
          ..._nearbyStations.asMap().entries.map((entry) {
            final idx = entry.key;
            final s = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: _pubWeb
                    ? BoxDecoration(
                        color: idx == 0
                            ? AppColors.accent.withOpacity(0.06)
                            : AppColors.accent.withOpacity(0.02),
                        border: Border(
                          bottom: BorderSide(color: AppColors.divider),
                        ),
                      )
                    : BoxDecoration(
                        color: AppColors.accent.withOpacity(0.06),
                        borderRadius: _rBox,
                        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
                      ),
                child: Row(
                  children: [
                    Icon(Icons.subway, size: 16,
                        color: idx == 0 ? AppColors.accent : AppColors.textDisabled),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _nearbyStationLabel(s),
                        style: _ft(
                          size: 13,
                          weight: idx == 0 ? FontWeight.w600 : FontWeight.w400,
                          color: idx == 0 ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 28, height: 28,
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 14),
                        onPressed: () {
                          setState(() {
                            _nearbyStations.removeAt(idx);
                            if (_nearbyStations.isEmpty) {
                              _data.subwayStationName = null;
                              _data.subwayLines = [];
                              _data.walkingDistanceMeters = null;
                              _data.walkingMinutes = null;
                            } else {
                              final first = _nearbyStations.first;
                              _data.subwayStationName = first.name;
                              _data.subwayLines = List.from(first.lines);
                              _data.walkingDistanceMeters = first.distanceMeters;
                              _data.walkingMinutes = first.walkingMinutes;
                            }
                          });
                          _notify();
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: AppColors.textDisabled,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          _field(
            controller: _exitNumberCtrl,
            label: '출구 번호 (선택)',
            hint: '예) 11번 출구',
          ),
          const SizedBox(height: 8),
        ] else if (_data.subwayStationName != null && _data.subwayStationName!.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: _pubWeb
                ? BoxDecoration(
                    color: AppColors.accent.withOpacity(0.04),
                    border: Border(bottom: BorderSide(color: AppColors.divider)),
                  )
                : BoxDecoration(
                    color: AppColors.accent.withOpacity(0.06),
                    borderRadius: _rBox,
                    border: Border.all(color: AppColors.accent.withOpacity(0.2)),
                  ),
            child: Row(
              children: [
                const Icon(Icons.subway, size: 16, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _legacySubwayOneLine(),
                    style: _ft(size: 13, weight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ),
                SizedBox(
                  width: 28, height: 28,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 14),
                    onPressed: () {
                      setState(() {
                        _data.subwayStationName = null;
                        _data.subwayLines = [];
                        _data.walkingDistanceMeters = null;
                        _data.walkingMinutes = null;
                      });
                      _notify();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: AppColors.textDisabled,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _field(
            controller: _exitNumberCtrl,
            label: '출구 번호 (선택)',
            hint: '예) 11번 출구',
          ),
          const SizedBox(height: 8),
        ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _isLookingUpStation ? null : _lookupStation,
                icon: _isLookingUpStation
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search, size: 18),
                label: Text(_isLookingUpStation ? '조회 중...' : '가까운 역 찾기'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent),
                  shape: RoundedRectangleBorder(borderRadius: _rBtn),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '반경 1,000m',
                style: _ft(size: 11, weight: FontWeight.w400, color: AppColors.textDisabled),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '주소 입력 후 버튼을 누르면 가까운 역을 자동 찾아줍니다.',
            style: _ft(size: 11, weight: FontWeight.w400, color: AppColors.textDisabled),
          ),
          const SizedBox(height: 8),
        ],
        _switchRow(
          label: '주차 가능',
          value: _data.parking,
          onChanged: (v) {
            setState(() => _data = _data.copyWith(parking: v));
            _notify();
          },
        ),
      ],
    );
  }

  String _nearbyStationLabel(NearbyStation s) {
    final lineStr =
        s.lines.isEmpty ? '' : ' ${s.lines.join(' · ')}';
    return '${s.name}$lineStr · ${s.distanceMeters}m';
  }

  /// _nearbyStations 없이 draft 등으로만 역이 있을 때
  String _legacySubwayOneLine() {
    final name = _data.subwayStationName ?? '';
    final lines = _data.subwayLines;
    final lineStr = lines.isEmpty ? '' : ' ${lines.join(' · ')}';
    final m = _data.walkingDistanceMeters;
    final dist = m != null ? ' · ${m}m' : '';
    return '$name$lineStr$dist';
  }

  Future<void> _lookupStation() async {
    final address = _addressCtrl.text.trim();
    if (address.isEmpty) {
      _showSnack('주소를 먼저 입력해주세요.');
      return;
    }
    setState(() => _isLookingUpStation = true);
    try {
      final result =
          await TransportationLookupService.lookupByAddress(address);
      if (result == null) {
        if (mounted) _showSnack('주변 지하철역을 찾을 수 없습니다.');
        return;
      }
      if (result.failReason != null) {
        if (mounted) _showSnack('역 조회 실패: ${result.failReason}');
        return;
      }
      if (!mounted) return;
      setState(() {
        _nearbyStations = List.from(result.stations);
        _data.lat = result.lat;
        _data.lng = result.lng;
        // 가장 가까운 역을 기본 대표역으로 설정
        if (_nearbyStations.isNotEmpty) {
          final first = _nearbyStations.first;
          _data.subwayStationName = first.name;
          _data.subwayLines = List.from(first.lines);
          _data.walkingDistanceMeters = first.distanceMeters;
          _data.walkingMinutes = first.walkingMinutes;
        }
      });
      _notify();
      if (mounted) {
        _showSnack('${_nearbyStations.length}개 역 조회 완료');
      }
    } catch (e) {
      if (mounted) _showSnack('교통편 조회 실패: $e');
    } finally {
      if (mounted) setState(() => _isLookingUpStation = false);
    }
  }

  // ── 병원 정보 ──────────────────────────────────────────
  Widget _buildHospitalInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dropdown(
          label: '병원 유형',
          value: _selectedHospitalType,
          items: Job.hospitalTypeLabels.values.toList(),
          onChanged: (v) {
            final key = Job.hospitalTypeLabels.entries
                .firstWhere((e) => e.value == v, orElse: () => const MapEntry('', ''))
                .key;
            setState(() => _selectedHospitalType = key.isNotEmpty ? key : null);
            _notify();
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _field(
                controller: _chairCountCtrl,
                label: '체어 수',
                hint: '예) 5',
              ),
            ),
            SizedBox(width: _pubWeb ? AppPublisher.formFieldRowGap : 12),
            Expanded(
              child: _field(
                controller: _staffCountCtrl,
                label: '스탭 수',
                hint: '예) 8',
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── 지원 방법 / 마감일 ───────────────────────────────────
  Widget _buildApplySection() {
    const methods = {'online': '앱 간편지원', 'phone': '전화 지원', 'email': '이메일 지원'};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('지원 방법', style: _ft(size: 13, weight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: _pubWeb ? AppPublisher.formChipSpacing : 6,
          runSpacing: _pubWeb ? AppPublisher.formChipRunSpacing : 6,
          children: methods.entries.map((e) {
            final selected = _data.applyMethod.contains(e.key);
            return FilterChip(
              label: Text(e.value),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  final list = List<String>.from(_data.applyMethod);
                  selected ? list.remove(e.key) : list.add(e.key);
                  _data = _data.copyWith(applyMethod: list);
                });
                _notify();
              },
              selectedColor: AppColors.accent.withOpacity(0.2),
              checkmarkColor: AppColors.accent,
              labelStyle: _ft(size: 13, weight: FontWeight.w600,
                color: selected ? AppColors.accent : AppColors.textSecondary),
              shape: RoundedRectangleBorder(
                borderRadius: _rChip,
                side: BorderSide(color: selected ? AppColors.accent.withOpacity(0.4) : AppColors.divider),
              ),
              backgroundColor: AppColors.white,
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _switchRow(
          label: '상시채용',
          value: _data.isAlwaysHiring,
          onChanged: (v) {
            setState(() {
              _data = _data.copyWith(isAlwaysHiring: v);
              if (v) _data.closingDate = null;
            });
            _notify();
          },
        ),
        if (!_data.isAlwaysHiring) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _data.closingDate ?? DateTime.now().add(const Duration(days: 14)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() => _data = _data.copyWith(closingDate: picked));
                _notify();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
              decoration: _pubWeb
                  ? const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.divider),
                      ),
                    )
                  : BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: _rBox,
                      color: AppColors.appBg,
                    ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    _data.closingDate != null
                        ? '마감일: ${_data.closingDate!.year}-${_data.closingDate!.month.toString().padLeft(2, '0')}-${_data.closingDate!.day.toString().padLeft(2, '0')}'
                        : '마감일 선택',
                    style: _ft(size: 13, weight: FontWeight.w600,
                      color: _data.closingDate != null ? AppColors.textPrimary : AppColors.textDisabled),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── 태그 프리뷰 ─────────────────────────────────────────
  Widget _buildTagsPreview() {
    return Wrap(
      spacing: _pubWeb ? AppPublisher.formChipSpacing : 6,
      runSpacing: _pubWeb ? AppPublisher.formChipRunSpacing : 6,
      children: _data.tags.map((t) => Chip(
        label: Text(t, style: _ft(size: 12, weight: FontWeight.w600)),
        backgroundColor: AppColors.accent.withOpacity(0.08),
        side: _pubWeb
            ? BorderSide(color: AppColors.divider)
            : BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: _rChip),
        visualDensity: VisualDensity.compact,
      )).toList(),
    );
  }

  // ── Switch 행 헬퍼 ──────────────────────────────────────
  Widget _switchRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: _pubWeb ? const EdgeInsets.symmetric(vertical: 2) : EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: _ft(size: 13, weight: FontWeight.w600, color: AppColors.textSecondary),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.white,
            activeTrackColor: AppColors.accent,
          ),
        ],
      ),
    );
  }

  /// 웹 편집기: 임시저장만 (게시는 상단 「게시 단계로」)
  Widget _buildWebEditorSubmitFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: AppPublisher.ctaHeight,
            child: OutlinedButton.icon(
              onPressed: _isSavingDraft ? null : _manualSaveDraft,
              icon: _isSavingDraft
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(
                '임시저장',
                style: _ft(
                  size: 14,
                  weight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppPublisher.buttonRadius),
                ),
              ),
            ),
          ),
          if (_lastSavedAt != null || _draftId != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  _lastSavedAt != null
                      ? '마지막 저장: ${_lastSavedAt!.hour.toString().padLeft(2, '0')}:${_lastSavedAt!.minute.toString().padLeft(2, '0')}'
                      : '임시저장됨',
                  style: _ft(
                    size: 11,
                    weight: FontWeight.w500,
                    color: AppColors.textDisabled,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '게시는 상단의 「게시 단계로」에서 진행할 수 있어요.',
              textAlign: TextAlign.center,
              style: _ft(
                size: 12,
                weight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 제출 섹션 ──────────────────────────────────────────
  Widget _buildSubmitSection() {
    if (_webEditorMode) {
      return _buildWebEditorSubmitFooter();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI 검토 확인 체크박스 (이미지가 있을 때만)
        if (_data.images.isNotEmpty)
          CheckboxListTile(
            value: _aiReviewed,
            onChanged: (v) => setState(() => _aiReviewed = v ?? false),
            title: Text(
              'AI 자동입력 내용을 직접 검토했습니다.',
              style: _ft(size: 13, weight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.accent,
            checkboxShape: _pubWeb
                ? RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppPublisher.softRadius),
                  )
                : null,
            side: _pubWeb ? const BorderSide(color: AppColors.divider, width: 1.5) : null,
          ),
        const SizedBox(height: 12),
        // ── 임시저장 버튼 + 상태 표시 ──
        Row(
          children: [
            Expanded(
              child: widget.publisherWebStyle
                  ? SizedBox(
                      height: AppPublisher.ctaHeight,
                      child: OutlinedButton.icon(
                        onPressed: _isSavingDraft ? null : _manualSaveDraft,
                        icon: _isSavingDraft
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined, size: 18),
                        label: Text(
                          '임시저장',
                          style: _ft(size: 14, weight: FontWeight.w600, color: AppColors.accent),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.accent,
                          side: const BorderSide(color: AppColors.accent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppPublisher.buttonRadius),
                          ),
                        ),
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: _isSavingDraft ? null : _manualSaveDraft,
                      icon: _isSavingDraft
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(
                        '임시저장',
                        style: _ft(size: 14, weight: FontWeight.w600, color: AppColors.accent),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        side: const BorderSide(color: AppColors.accent),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
            ),
          ],
        ),
        if (_lastSavedAt != null || _draftId != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Center(
              child: Text(
                _lastSavedAt != null
                    ? '마지막 저장: ${_lastSavedAt!.hour.toString().padLeft(2, '0')}:${_lastSavedAt!.minute.toString().padLeft(2, '0')}'
                    : '임시저장됨',
                style: _ft(
                  size: 11,
                  weight: FontWeight.w500,
                  color: AppColors.textDisabled,
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),
        // ── 제출 버튼 ──
        SizedBox(
          width: double.infinity,
          height: widget.publisherWebStyle ? AppPublisher.ctaHeight : null,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.white,
              elevation: 0,
              padding: widget.publisherWebStyle
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  widget.publisherWebStyle ? AppPublisher.buttonRadius : 14,
                ),
              ),
            ),
            child:
                _isSubmitting
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                    : Text(
                      '구인공고 등록하기',
                      style: _ft(size: 16, weight: FontWeight.w800),
                    ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            '등록 후 검수를 거쳐 게시됩니다.',
            style: _ft(
              size: 12,
              weight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  // ── 공통 텍스트 필드 ───────────────────────────────────
  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: _ft(size: 14, weight: FontWeight.w600, color: AppColors.textPrimary),
      decoration: _pubWeb
          ? _pubUnderlineDecoration(label: label, hint: hint)
          : InputDecoration(
              labelText: label,
              hintText: hint,
              hintStyle: _ft(
                size: 13,
                weight: FontWeight.w400,
                color: AppColors.textDisabled,
              ),
              labelStyle: _ft(
                size: 13,
                weight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: _rBox,
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: _rBox,
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: _rBox,
                borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: _rBox,
                borderSide: const BorderSide(color: AppColors.error),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: _rBox,
                borderSide: const BorderSide(color: AppColors.error, width: 1.5),
              ),
              filled: true,
              fillColor: AppColors.appBg,
            ),
    );
  }

  /// 웹 공고: 드롭다운 패널·항목 호버가 M3 기본(보라/라벤더 톤)으로 나가지 않도록
  ThemeData _pubDropdownMenuTheme(ThemeData base) {
    return base.copyWith(
      canvasColor: AppColors.white,
      highlightColor: AppColors.accent.withValues(alpha: 0.12),
      hoverColor: AppColors.accent.withValues(alpha: 0.10),
      splashColor: AppColors.accent.withValues(alpha: 0.14),
      colorScheme: base.colorScheme.copyWith(
        surface: AppColors.white,
        onSurface: AppColors.textPrimary,
        primary: AppColors.accent,
        onPrimary: AppColors.white,
        surfaceContainerHighest: AppColors.accent.withValues(alpha: 0.10),
        surfaceContainerHigh: AppColors.surfaceMuted,
        surfaceContainer: AppColors.white,
      ),
    );
  }

  // ── 드롭다운 ───────────────────────────────────────────
  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final field = DropdownButtonFormField<String>(
      value: value,
      dropdownColor: _pubWeb ? AppColors.white : null,
      borderRadius:
          _pubWeb ? BorderRadius.circular(AppPublisher.buttonRadius) : null,
      items:
          items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                    e,
                    style: _ft(
                      size: 14,
                      weight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              )
              .toList(),
      onChanged: onChanged,
      style: _ft(size: 14, weight: FontWeight.w600, color: AppColors.textPrimary),
      decoration: _pubWeb
          ? _pubUnderlineDecoration(label: label, hint: null)
          : InputDecoration(
              labelText: label,
              labelStyle: _ft(
                size: 13,
                weight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: _rBox,
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: _rBox,
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: _rBox,
                borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: _rBox,
                borderSide: const BorderSide(color: AppColors.error),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: _rBox,
                borderSide: const BorderSide(color: AppColors.error, width: 1.5),
              ),
              filled: true,
              fillColor: AppColors.appBg,
            ),
    );
    if (!_pubWeb) return field;
    return Theme(
      data: _pubDropdownMenuTheme(Theme.of(context)),
      child: field,
    );
  }
}


