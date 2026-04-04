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
import '../utils/job_ai_extract_normalize.dart';
import '../utils/job_image_attach_helpers.dart';
import '../web/web_file_drop_zone.dart';

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
  /// 게시·레거시 호환 (`hireRoles`를 `, `로 잇는 값과 [syncRoleFromHireRoles]로 동기화)
  String role;
  /// 채용직 — 치과위생사·간호조무사·기타(직접 입력) 다중
  List<String> hireRoles;
  String career;            // 경력 조건: '신입', '경력 무관', '1년 이상' 등
  /// 학력: 무관, 고등학교 졸업 이상, 전문대 졸업 이상
  String education;
  String employmentType;
  String workHours;
  /// 표시·게시용 급여 한 줄 (composeSalaryLine 결과 등)
  String salary;
  /// 협의 | 시 | 월 | 연 — [salaryAmount]와 함께 저장
  String salaryPayType;
  /// 만원 단위 숫자만(쉼표 없이)
  String salaryAmount;
  List<String> benefits;
  String description;
  String address;
  String contact;
  List<XFile> images;
  /// 홍보이미지 URL — AI 추출 없이 공고에 직접 노출
  List<String> promotionalImageUrls;

  // ── 신규 필드 ───────────────────────────────────────
  String? hospitalType;       // clinic | network | hospital | general
  int? chairCount;
  int? staffCount;
  /// 주요 진료 과목 (일반진료/교정/임플란트/소아치과/치주/보존/기타)
  List<String> specialties;
  /// 구강 스캐너 보유 여부
  bool? hasOralScanner;
  /// CT 보유 여부
  bool? hasCT;
  /// 3D 프린터 보유 여부
  bool? has3DPrinter;
  /// 기타 디지털 장비 원문
  String? digitalEquipmentRaw;
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

  // ── AI 추출 품질 필드 ────────────────────────────
  /// 담당업무 원문 줄글 (AI 원본 보관)
  String? mainDutiesRaw;
  /// 담당업무 항목 리스트 (폼 편집용)
  List<String> mainDutiesList;
  /// 모집 시작일 (저장만, 현재 UI 미사용)
  DateTime? recruitmentStart;
  /// 필드별 AI 신뢰 상태 (confirmed / inferred / conflict / missing)
  Map<String, String>? fieldStatus;
  /// 추출 메타 (sourceImageIndexes 등, 참고용)
  Map<String, dynamic>? fieldSources;

  JobPostData({
    this.clinicName = '',
    this.title = '',
    this.role = '',
    List<String>? hireRoles,
    this.career = '',
    this.education = '',
    this.employmentType = '',
    this.workHours = '',
    this.salary = '',
    this.salaryPayType = '',
    this.salaryAmount = '',
    List<String>? benefits,
    this.description = '',
    this.address = '',
    this.contact = '',
    List<XFile>? images,
    List<String>? promotionalImageUrls,
    this.hospitalType,
    this.chairCount,
    this.staffCount,
    List<String>? specialties,
    this.hasOralScanner,
    this.hasCT,
    this.has3DPrinter,
    this.digitalEquipmentRaw,
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
    this.mainDutiesRaw,
    List<String>? mainDutiesList,
    this.recruitmentStart,
    this.fieldStatus,
    this.fieldSources,
  }) : hireRoles = hireRoles ?? [],
       benefits = benefits ?? [],
       images = images ?? [],
       promotionalImageUrls = promotionalImageUrls ?? [],
       specialties = specialties ?? [],
       workDays = workDays ?? [],
       applyMethod = applyMethod ?? [],
       subwayLines = subwayLines ?? [],
       tags = tags ?? [],
       mainDutiesList = mainDutiesList ?? [];

  JobPostData copyWith({
    String? clinicName,
    String? title,
    String? role,
    List<String>? hireRoles,
    String? career,
    String? education,
    String? employmentType,
    String? workHours,
    String? salary,
    String? salaryPayType,
    String? salaryAmount,
    List<String>? benefits,
    String? description,
    String? address,
    String? contact,
    List<XFile>? images,
    List<String>? promotionalImageUrls,
    String? hospitalType,
    int? chairCount,
    int? staffCount,
    List<String>? specialties,
    bool? hasOralScanner,
    bool? hasCT,
    bool? has3DPrinter,
    String? digitalEquipmentRaw,
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
    String? mainDutiesRaw,
    List<String>? mainDutiesList,
    DateTime? recruitmentStart,
    Map<String, String>? fieldStatus,
    Map<String, dynamic>? fieldSources,
  }) {
    return JobPostData(
      clinicName: clinicName ?? this.clinicName,
      title: title ?? this.title,
      role: role ?? this.role,
      hireRoles: hireRoles ?? List.from(this.hireRoles),
      career: career ?? this.career,
      education: education ?? this.education,
      employmentType: employmentType ?? this.employmentType,
      workHours: workHours ?? this.workHours,
      salary: salary ?? this.salary,
      salaryPayType: salaryPayType ?? this.salaryPayType,
      salaryAmount: salaryAmount ?? this.salaryAmount,
      benefits: benefits ?? List.from(this.benefits),
      description: description ?? this.description,
      address: address ?? this.address,
      contact: contact ?? this.contact,
      images: images ?? List.from(this.images),
      promotionalImageUrls: promotionalImageUrls ?? List.from(this.promotionalImageUrls),
      hospitalType: hospitalType ?? this.hospitalType,
      chairCount: chairCount ?? this.chairCount,
      staffCount: staffCount ?? this.staffCount,
      specialties: specialties ?? List.from(this.specialties),
      hasOralScanner: hasOralScanner ?? this.hasOralScanner,
      hasCT: hasCT ?? this.hasCT,
      has3DPrinter: has3DPrinter ?? this.has3DPrinter,
      digitalEquipmentRaw: digitalEquipmentRaw ?? this.digitalEquipmentRaw,
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
      mainDutiesRaw: mainDutiesRaw ?? this.mainDutiesRaw,
      mainDutiesList: mainDutiesList ?? List.from(this.mainDutiesList),
      recruitmentStart: recruitmentStart ?? this.recruitmentStart,
      fieldStatus: fieldStatus ?? (this.fieldStatus != null ? Map.from(this.fieldStatus!) : null),
      fieldSources: fieldSources ?? (this.fieldSources != null ? Map.from(this.fieldSources!) : null),
    );
  }

  Map<String, dynamic> toMap() => {
    'clinicName': clinicName,
    'title': title,
    'role': role,
    if (hireRoles.isNotEmpty) 'hireRoles': hireRoles,
    'career': career,
    if (education.isNotEmpty) 'education': education,
    'employmentType': employmentType,
    'workHours': workHours,
    'salary': salary,
    if (salaryPayType.isNotEmpty) 'salaryPayType': salaryPayType,
    if (salaryAmount.isNotEmpty) 'salaryAmount': salaryAmount,
    'benefits': benefits,
    'description': description,
    'address': address,
    'contact': contact,
    if (promotionalImageUrls.isNotEmpty) 'promotionalImageUrls': promotionalImageUrls,
    if (hospitalType != null) 'hospitalType': hospitalType,
    if (chairCount != null) 'chairCount': chairCount,
    if (staffCount != null) 'staffCount': staffCount,
    if (specialties.isNotEmpty) 'specialties': specialties,
    if (hasOralScanner != null) 'hasOralScanner': hasOralScanner,
    if (hasCT != null) 'hasCT': hasCT,
    if (has3DPrinter != null) 'has3DPrinter': has3DPrinter,
    if (digitalEquipmentRaw != null) 'digitalEquipmentRaw': digitalEquipmentRaw,
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
    if (mainDutiesRaw != null) 'mainDutiesRaw': mainDutiesRaw,
    if (mainDutiesList.isNotEmpty) 'mainDutiesList': mainDutiesList,
    if (recruitmentStart != null) 'recruitmentStart': recruitmentStart!.toIso8601String(),
    if (fieldStatus != null && fieldStatus!.isNotEmpty) 'fieldStatus': fieldStatus,
    if (fieldSources != null && fieldSources!.isNotEmpty) 'fieldSources': fieldSources,
  };

  /// 급여 표시 문자열 (저장·프리뷰 공통)
  static String composeSalaryLine(String payType, String amount) {
    final a = amount.trim().replaceAll(',', '');
    switch (payType) {
      case '협의':
        return '협의';
      case '시':
        return a.isEmpty ? '' : '시 $a만원';
      case '월':
        return a.isEmpty ? '' : '월 $a만원';
      case '연':
        return a.isEmpty ? '' : '연 $a만원';
      default:
        return '';
    }
  }

  /// 기존 `salary` 한 줄만 있을 때 드롭다운·입력란 복원용
  static (String payType, String amount) inferSalaryPartsFromLegacy(String salary) {
    final t = salary.trim();
    if (t.isEmpty) return ('', '');
    if (t.contains('협의')) return ('협의', '');
    final m = RegExp(r'([\d,]+)').firstMatch(t);
    final digits = m?.group(1)?.replaceAll(',', '') ?? '';
    if (t.contains('시') || t.contains('시급')) return ('시', digits);
    if (t.contains('연') || t.contains('연봉')) return ('연', digits);
    return ('월', digits);
  }

  /// 채용직 다중 선택 → 게시용 `role` 한 줄
  static String joinHireRoles(List<String> list) {
    final seen = <String>{};
    final out = <String>[];
    for (final e in list) {
      final t = e.trim();
      if (t.isEmpty || seen.contains(t)) continue;
      seen.add(t);
      out.add(t);
    }
    return out.join(', ');
  }

  static List<String> parseHireRolesFromData(Map<String, dynamic> data) {
    final hr = data['hireRoles'];
    if (hr is List) {
      return hr.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    final r = (data['role'] as String? ?? '').trim();
    if (r.isEmpty) return [];
    return r
        .split(RegExp(r'\s*,\s*'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Firestore 또는 드래프트 데이터에서 복원
  factory JobPostData.fromMap(Map<String, dynamic> data) {
    final trans = data['transportation'] as Map<String, dynamic>?;
    DateTime? closing;
    if (data['closingDate'] is String) {
      try { closing = DateTime.parse(data['closingDate'] as String); } catch (_) {}
    }
    final originalSalary = (data['salary'] as String? ?? '').trim();
    var education = data['education'] as String? ?? '';
    var salaryPayType = data['salaryPayType'] as String? ?? '';
    var salaryAmount = data['salaryAmount'] as String? ?? '';
    var salary = originalSalary;
    if (salaryPayType.isEmpty && originalSalary.isNotEmpty) {
      final inf = JobPostData.inferSalaryPartsFromLegacy(originalSalary);
      salaryPayType = inf.$1;
      salaryAmount = inf.$2;
    }
    final composed = JobPostData.composeSalaryLine(salaryPayType, salaryAmount);
    if (composed.isNotEmpty) {
      salary = composed;
    }
    final hireRoles = JobPostData.parseHireRolesFromData(data);
    final roleLine = JobPostData.joinHireRoles(hireRoles);
    return JobPostData(
      clinicName: data['clinicName'] as String? ?? '',
      title: data['title'] as String? ?? '',
      role: roleLine,
      hireRoles: hireRoles,
      career: data['career'] as String? ?? '',
      education: education,
      employmentType: data['employmentType'] as String? ?? '',
      workHours: data['workHours'] as String? ?? '',
      salary: salary,
      salaryPayType: salaryPayType,
      salaryAmount: salaryAmount,
      benefits: List<String>.from(data['benefits'] ?? []),
      description: data['description'] as String? ?? '',
      address: data['address'] as String? ?? '',
      contact: data['contact'] as String? ?? '',
      hospitalType: data['hospitalType'] as String?,
      chairCount: (data['chairCount'] as num?)?.toInt(),
      staffCount: (data['staffCount'] as num?)?.toInt(),
      specialties: List<String>.from(data['specialties'] ?? []),
      hasOralScanner: data['hasOralScanner'] as bool?,
      hasCT: data['hasCT'] as bool?,
      has3DPrinter: data['has3DPrinter'] as bool?,
      digitalEquipmentRaw: data['digitalEquipmentRaw'] as String?,
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
      mainDutiesRaw: data['mainDutiesRaw'] as String?,
      mainDutiesList: List<String>.from(data['mainDutiesList'] ?? []),
      recruitmentStart: data['recruitmentStart'] is String
          ? (() { try { return DateTime.parse(data['recruitmentStart'] as String); } catch (_) { return null; } })()
          : null,
      fieldStatus: (data['fieldStatus'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())),
      fieldSources: data['fieldSources'] as Map<String, dynamic>?,
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
  late final TextEditingController _salaryAmountCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _contactCtrl;
  late final TextEditingController _benefitInputCtrl;
  late final TextEditingController _hireOtherCtrl;
  late final TextEditingController _dutyOtherCtrl;

  // 신규 컨트롤러
  late final TextEditingController _chairCountCtrl;
  late final TextEditingController _staffCountCtrl;
  late final TextEditingController _exitNumberCtrl;
  late final TextEditingController _digitalEquipmentRawCtrl;

  /// 웹 step3 −/＋ 버튼: 비운 뒤 ＋로 다시 포커스
  late final FocusNode _fClinicName;
  late final FocusNode _fTitle;
  late final FocusNode _fWorkHours;
  late final FocusNode _fSalary;
  late final FocusNode _fDescription;
  late final FocusNode _fAddress;
  late final FocusNode _fContact;
  late final FocusNode _fChairCount;
  late final FocusNode _fStaffCount;
  late final FocusNode _fExitNumber;
  late final FocusNode _fDigitalEquipment;
  late final FocusNode _fDutyOther;

  // 드롭다운
  String? _selectedEmploymentType;
  String? _selectedCareer;
  String? _selectedEducation;
  String? _selectedSalaryPayType;
  String? _selectedHospitalType;

  // AI 관련
  bool _aiReviewed = false;
  bool _isLoadingAi = false;
  bool _isSubmitting = false;
  bool _isLookingUpStation = false;
  List<NearbyStation> _nearbyStations = [];

  /// AI 파싱 완료 후 fieldStatus 보관 → 배너/뱃지 표시
  Map<String, String>? _aiFieldStatus;

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
  final GlobalKey _imageDropBoundaryKey = GlobalKey();
  static const _autoSaveDebounce = Duration(milliseconds: 1800);

  /// 웹 편집기 3단계(공고 상세) — 항목별 「항목 빼기」 표시
  bool get _step3 => widget.publisherWebEditorStep == 'step3';

  static const _hireRolePresets = ['치과위생사', '간호조무사'];
  static const _dutyPresets = ['데스크', '보험청구', '상담', '진료실'];
  static const _careers = ['신입', '경력 무관', '1년 이상', '2년 이상', '3년 이상', '5년 이상'];
  static const _educations = ['무관', '고등학교 졸업 이상', '전문대 졸업 이상'];
  static const _employmentTypes = ['정규직', '계약직', '파트타임', '인턴'];
  static const _salaryPayTypes = ['협의', '시', '월', '연'];
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
    _hydrateSalaryAndEducationFromData();
    _descriptionCtrl.text = _data.description;
    _addressCtrl.text = _data.address;
    _contactCtrl.text = _data.contact;
    _chairCountCtrl.text = _data.chairCount != null ? '${_data.chairCount}' : '';
    _staffCountCtrl.text = _data.staffCount != null ? '${_data.staffCount}' : '';
    _exitNumberCtrl.text = _data.exitNumber ?? '';
    _digitalEquipmentRawCtrl.text = _data.digitalEquipmentRaw ?? '';
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
    _salaryAmountCtrl = TextEditingController();
    _descriptionCtrl = TextEditingController(text: _data.description);
    _addressCtrl = TextEditingController(text: _data.address);
    _contactCtrl = TextEditingController(text: _data.contact);
    _benefitInputCtrl = TextEditingController();
    _hireOtherCtrl = TextEditingController();
    _dutyOtherCtrl = TextEditingController();
    _chairCountCtrl = TextEditingController(
      text: _data.chairCount != null ? '${_data.chairCount}' : '',
    );
    _staffCountCtrl = TextEditingController(
      text: _data.staffCount != null ? '${_data.staffCount}' : '',
    );
    _exitNumberCtrl = TextEditingController(text: _data.exitNumber ?? '');
    _digitalEquipmentRawCtrl = TextEditingController(text: _data.digitalEquipmentRaw ?? '');
    _selectedCareer = _data.career.isEmpty ? null : _data.career;
    _selectedEmploymentType =
        _data.employmentType.isEmpty ? null : _data.employmentType;
    _selectedHospitalType = _data.hospitalType;
    _hydrateSalaryAndEducationFromData();
    _aiFieldStatus = _data.fieldStatus != null && _data.fieldStatus!.isNotEmpty
        ? Map<String, String>.from(_data.fieldStatus!)
        : null;
    _fClinicName = FocusNode(debugLabel: 'job_clinicName');
    _fTitle = FocusNode(debugLabel: 'job_title');
    _fWorkHours = FocusNode(debugLabel: 'job_workHours');
    _fSalary = FocusNode(debugLabel: 'job_salary');
    _fDescription = FocusNode(debugLabel: 'job_description');
    _fAddress = FocusNode(debugLabel: 'job_address');
    _fContact = FocusNode(debugLabel: 'job_contact');
    _fChairCount = FocusNode(debugLabel: 'job_chairCount');
    _fStaffCount = FocusNode(debugLabel: 'job_staffCount');
    _fExitNumber = FocusNode(debugLabel: 'job_exitNumber');
    _fDigitalEquipment = FocusNode(debugLabel: 'job_digitalEquipment');
    _fDutyOther = FocusNode(debugLabel: 'job_dutyOther');
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    for (final c in [
      _clinicNameCtrl,
      _titleCtrl,
      _workHoursCtrl,
      _salaryAmountCtrl,
      _descriptionCtrl,
      _addressCtrl,
      _contactCtrl,
      _benefitInputCtrl,
      _hireOtherCtrl,
      _dutyOtherCtrl,
      _chairCountCtrl,
      _staffCountCtrl,
      _exitNumberCtrl,
      _digitalEquipmentRawCtrl,
    ]) {
      c.dispose();
    }
    for (final f in [
      _fClinicName,
      _fTitle,
      _fWorkHours,
      _fSalary,
      _fDescription,
      _fAddress,
      _fContact,
      _fChairCount,
      _fStaffCount,
      _fExitNumber,
      _fDigitalEquipment,
      _fDutyOther,
    ]) {
      f.dispose();
    }
    super.dispose();
  }

  void _hydrateSalaryAndEducationFromData() {
    var pay = _data.salaryPayType.trim();
    if (pay.isNotEmpty && !_salaryPayTypes.contains(pay)) pay = '';
    _selectedSalaryPayType = pay.isEmpty ? null : pay;
    _salaryAmountCtrl.text = _data.salaryAmount;
    final edu = _data.education.trim();
    _selectedEducation =
        edu.isNotEmpty && _educations.contains(edu) ? edu : null;
  }

  void _notify() {
    final chair = int.tryParse(_chairCountCtrl.text.trim());
    final staff = int.tryParse(_staffCountCtrl.text.trim());
    final exit = _exitNumberCtrl.text.trim();
    final payType = (_selectedSalaryPayType ?? '').trim();
    final amountRaw = _salaryAmountCtrl.text.trim().replaceAll(',', '');
    var salaryLine = JobPostData.composeSalaryLine(
      payType.isEmpty ? '' : payType,
      amountRaw,
    );

    _data = _data.copyWith(
      clinicName: _clinicNameCtrl.text,
      title: _titleCtrl.text,
      career: _selectedCareer ?? '',
      education: _selectedEducation ?? '',
      employmentType: _selectedEmploymentType ?? '',
      workHours: _workHoursCtrl.text,
      salaryPayType: payType,
      salaryAmount: amountRaw,
      salary: salaryLine,
      description: _descriptionCtrl.text,
      address: _addressCtrl.text,
      contact: _contactCtrl.text,
      hospitalType: _selectedHospitalType,
      chairCount: chair,
      staffCount: staff,
      exitNumber: exit.isNotEmpty ? exit : null,
      digitalEquipmentRaw: _digitalEquipmentRawCtrl.text.trim().isEmpty ? null : _digitalEquipmentRawCtrl.text.trim(),
    );
    final roleJoined = JobPostData.joinHireRoles(_data.hireRoles);
    if (roleJoined != _data.role) {
      _data = _data.copyWith(role: roleJoined);
    }

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
    // isEmpty 등 반응형 평가를 위해 rebuild 트리거
    if (mounted) setState(() {});
  }

  bool _hasMeaningfulPayload() {
    if (_data.images.isNotEmpty) return true;
    for (final v in _data.toMap().values) {
      if (v is String && v.isNotEmpty) return true;
      if (v is List && v.isNotEmpty) return true;
      if (v is Map && v.isNotEmpty) return true;
    }
    return false;
  }

  bool _isHttpImagePath(String p) {
    final t = p.trim().toLowerCase();
    return t.startsWith('http://') || t.startsWith('https://');
  }

  /// 임시저장: 로컬 파일은 Storage 업로드 후 `rawImageUrls`·`imageUrls`에 반영
  Future<Map<String, dynamic>> _buildDraftSavePayload() async {
    final base = _mergedFormData();
    if (_data.images.isEmpty) {
      return {
        ...base,
        'rawImageUrls': <String>[],
        'imageUrls': <String>[],
      };
    }

    final uploadIndices = <int>[];
    for (var i = 0; i < _data.images.length; i++) {
      if (!_isHttpImagePath(_data.images[i].path)) {
        uploadIndices.add(i);
      }
    }

    if (uploadIndices.isEmpty) {
      final urls = _data.images.map((x) => x.path).toList();
      return {
        ...base,
        'rawImageUrls': urls,
        'imageUrls': urls,
      };
    }

    var draftKey = _draftId ?? widget.draftId;
    if (draftKey == null || draftKey.isEmpty) {
      draftKey = await JobDraftService.saveDraft(
        draftId: null,
        formData: {
          ...base,
          'rawImageUrls': <String>[],
          'imageUrls': <String>[],
        },
      );
      if (draftKey != null) {
        _draftId = draftKey;
        widget.onDraftIdChanged?.call(draftKey);
      }
    }
    if (draftKey == null || draftKey.isEmpty) {
      return base;
    }

    final toUpload = uploadIndices.map((i) => _data.images[i]).toList();
    final uploaded = await JobImageUploader.uploadImages(
      jobId: draftKey,
      images: toUpload,
      onProgress: (batchIdx, progress) {
        if (!mounted) return;
        final globalIdx = uploadIndices[batchIdx];
        setState(() => _uploadProgress[globalIdx] = progress);
      },
    );

    var bi = 0;
    final rawOut = <String>[];
    final imgOut = <String>[];
    for (var i = 0; i < _data.images.length; i++) {
      final xf = _data.images[i];
      if (_isHttpImagePath(xf.path)) {
        rawOut.add(xf.path);
        imgOut.add(xf.path);
      } else {
        rawOut.add(uploaded[bi]);
        imgOut.add(uploaded[bi]);
        bi++;
      }
    }

    if (mounted) {
      setState(() {
        for (final idx in uploadIndices) {
          _uploadProgress.remove(idx);
        }
        // 로컬 경로를 유지하면 다음 자동저장마다 재업로드되므로 URL로 치환
        var ui = 0;
        final replaced = <XFile>[];
        for (var i = 0; i < _data.images.length; i++) {
          final xf = _data.images[i];
          if (_isHttpImagePath(xf.path)) {
            replaced.add(xf);
          } else {
            replaced.add(XFile(uploaded[ui], name: xf.name));
            ui++;
          }
        }
        _data = _data.copyWith(images: replaced);
      });
      widget.onDataChanged?.call(_data);
    }

    return {
      ...base,
      'rawImageUrls': rawOut,
      'imageUrls': imgOut,
    };
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
      final payload = await _buildDraftSavePayload();
      final id = await JobDraftService.saveDraft(
        draftId: _draftId ?? widget.draftId,
        formData: payload,
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

      // 2) Cloud Function 호출 (기본 60초 제한보다 길게 — 서버 parseJobImagesToForm 제한과 맞춤)
      final callable = FirebaseFunctions.instance.httpsCallable(
        'parseJobImagesToForm',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 180),
        ),
      );
      final result = await callable.call({
        'imageUrls': urls,
        'jobId': tempJobId,
      });
      final res = JobAiExtractNormalizer.normalize(
        Map<String, dynamic>.from(result.data as Map),
      );

      // 3) 결과를 폼에 반영
      if (!mounted) return;
      setState(() {
        if ((res['clinicName'] as String? ?? '').isNotEmpty) {
          _clinicNameCtrl.text = res['clinicName'] as String;
        }
        if ((res['title'] as String? ?? '').isNotEmpty) {
          _titleCtrl.text = res['title'] as String;
        }
        final roleRaw = (res['role'] as String? ?? '').trim();
        if (roleRaw.isNotEmpty) {
          final list = <String>[];
          if (_hireRolePresets.contains(roleRaw)) {
            list.add(roleRaw);
          } else if (roleRaw == '원장' || roleRaw == '데스크') {
            list.add('기타');
          } else {
            list.add(roleRaw);
          }
          _data = _data.copyWith(
            hireRoles: list,
            role: JobPostData.joinHireRoles(list),
          );
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
          final raw = (res['salary'] as String).trim();
          final inf = JobPostData.inferSalaryPartsFromLegacy(raw);
          var pt = inf.$1;
          if (pt.isNotEmpty && !_salaryPayTypes.contains(pt)) pt = '';
          _selectedSalaryPayType = pt.isEmpty ? null : pt;
          _salaryAmountCtrl.text = inf.$2;
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
        final wd = JobAiExtractNormalizer.workDaysToCodes(
          (res['workDays'] as List?)?.map((e) => e.toString()).toList(),
        );
        if (wd.isNotEmpty) {
          _data = _data.copyWith(workDays: wd);
        }

        final cc = res['chairCount'];
        final sc = res['staffCount'];
        final chairN = cc is int ? cc : (cc is num ? cc.round() : int.tryParse('$cc'.replaceAll(RegExp(r'[^\d]'), '')));
        final staffN = sc is int ? sc : (sc is num ? sc.round() : int.tryParse('$sc'.replaceAll(RegExp(r'[^\d]'), '')));
        if (chairN != null && chairN > 0) {
          _chairCountCtrl.text = '$chairN';
          _data = _data.copyWith(chairCount: chairN);
        }
        if (staffN != null && staffN > 0) {
          _staffCountCtrl.text = '$staffN';
          _data = _data.copyWith(staffCount: staffN);
        }

        final sn = (res['subwayStationName'] as String?)?.trim();
        if (sn != null && sn.isNotEmpty) {
          _data = _data.copyWith(subwayStationName: sn);
        }
        final sl = res['subwayLines'] as List?;
        if (sl != null && sl.isNotEmpty) {
          _data = _data.copyWith(
            subwayLines: sl.map((e) => e.toString()).where((s) => s.isNotEmpty).toList(),
          );
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

        // ── hospitalType: 한글 label 또는 영문 key ──
        final ht = res['hospitalType'] as String? ?? '';
        if (ht.isNotEmpty) {
          _selectedHospitalType =
              JobAiExtractNormalizer.hospitalTypeToKey(ht) ?? _matchHospitalType(ht);
        }

        // ── benefits: 공통 목록과 정규화 후 반영 ──
        final rawBenefits =
            (res['benefits'] as List?)?.map((e) => e.toString()).toList();
        if (rawBenefits != null && rawBenefits.isNotEmpty) {
          _data = _data.copyWith(benefits: _normalizeBenefits(rawBenefits));
        }

        // ── mainDuties ──
        final mainDutiesList = res['mainDutiesList'];
        if (mainDutiesList is List && mainDutiesList.isNotEmpty) {
          _data = _data.copyWith(
            mainDutiesList: mainDutiesList.map((e) => e.toString()).where((s) => s.isNotEmpty).toList(),
            mainDutiesRaw: res['mainDutiesRaw'] as String?,
          );
        }

        // ── specialties ──
        final specialtiesRaw = res['specialties'];
        if (specialtiesRaw is List && specialtiesRaw.isNotEmpty) {
          _data = _data.copyWith(
            specialties: specialtiesRaw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList(),
          );
        }

        // ── 디지털 장비 ──
        final hasOralScanner = res['hasOralScanner'];
        final hasCT = res['hasCT'];
        final has3DPrinter = res['has3DPrinter'];
        final digitalEquipmentRaw = res['digitalEquipmentRaw'] as String?;
        _data = _data.copyWith(
          hasOralScanner: hasOralScanner is bool ? hasOralScanner : null,
          hasCT: hasCT is bool ? hasCT : null,
          has3DPrinter: has3DPrinter is bool ? has3DPrinter : null,
          digitalEquipmentRaw: digitalEquipmentRaw,
        );

        // ── closingDate (AI 추출) ──
        final closingRaw = res['closingDate'] as String?;
        if (closingRaw != null && closingRaw.isNotEmpty) {
          try {
            final parsed = DateTime.parse(closingRaw);
            _data = _data.copyWith(closingDate: parsed);
          } catch (_) {}
        }

        // ── recruitmentStart (저장만) ──
        final recruitStartRaw = res['recruitmentStart'] as String?;
        if (recruitStartRaw != null && recruitStartRaw.isNotEmpty) {
          try {
            final parsed = DateTime.parse(recruitStartRaw);
            _data = _data.copyWith(recruitmentStart: parsed);
          } catch (_) {}
        }

        // ── fieldStatus 저장 → 배너/뱃지 표시 ──
        final fs = res['fieldStatus'];
        if (fs is Map) {
          final statusMap = fs.map((k, v) => MapEntry(k.toString(), v.toString()));
          _data = _data.copyWith(fieldStatus: statusMap);
          _aiFieldStatus = statusMap;
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
    // 채용직: hireRoles 우선, 레거시 `role` 한 줄은 파싱
    var hr = List<String>.from(result.hireRoles);
    if (hr.isEmpty && result.role.trim().isNotEmpty) {
      hr = result.role
          .split(RegExp(r'\s*,\s*'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final md = List<String>.from(result.mainDutiesList);
    hr = hr.map((e) {
      if (e == '원장') return '기타';
      return e;
    }).toList();
    var mdTouched = false;
    if (hr.remove('데스크') && !md.contains('데스크')) {
      md.add('데스크');
      mdTouched = true;
    }
    result = result.copyWith(
      hireRoles: hr,
      role: JobPostData.joinHireRoles(hr),
      mainDutiesList: md,
      mainDutiesRaw: mdTouched ? md.join('\n') : result.mainDutiesRaw,
    );
    // 학력: 선택지 외 값은 무관으로 맞춤 (드롭다운 value 오류 방지)
    final eduIn = result.education.trim();
    if (eduIn.isNotEmpty && !_educations.contains(eduIn)) {
      result = result.copyWith(education: '무관');
    }
    // 급여: 구버전 한 줄만 있을 때 구분·금액 복원
    if (result.salaryPayType.isEmpty && result.salary.trim().isNotEmpty) {
      final inf = JobPostData.inferSalaryPartsFromLegacy(result.salary);
      final composed = JobPostData.composeSalaryLine(inf.$1, inf.$2);
      result = result.copyWith(
        salaryPayType: inf.$1,
        salaryAmount: inf.$2,
        salary: composed.isNotEmpty ? composed : result.salary.trim(),
      );
    }
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

  Future<void> _onWebImageDrop(List<XFile> files) async {
    setState(() => _imageDropActive = false);
    await _appendImagesFromXFiles(files);
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

    // ── AI 상태 배너 (파싱 완료 후 표시) ──
    if (full || step3) {
      out.add(_buildAiStatusBanner());
    }

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
      // ── 그룹 A: 기본 정보 → 근무 조건 → 담당 업무 ──
      out.add(
        _sectionCard(
          title: _sectionTitle(publisher: '기본 정보', legacy: '🏥 기본 정보'),
          child: _buildBasicInfo(),
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
      // ── 그룹 B: 병원 정보 → 복리후생 ──
      out.add(
        _sectionCard(
          title: _sectionTitle(publisher: '병원 정보', legacy: '🏢 병원 정보'),
          child: _buildHospitalInfo(),
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
      // ── 나머지 ──
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

  /// step3: 우측 −(앱 레드)=비우기, ＋(앱 블루)=비운 뒤 다시 입력(포커스 또는 [onPlusWhenEmpty])
  Widget _wrapStep3Clear({
    required Widget child,
    required bool isEmpty,
    required VoidCallback onMinus,
    VoidCallback? onPlusWhenEmpty,
    FocusNode? focusWhenEmpty,
  }) {
    if (!_step3) return child;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: child),
        IconButton(
          tooltip: isEmpty ? '다시 입력' : '항목 비우기',
          padding: const EdgeInsets.only(left: 4, bottom: 2),
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          icon: Icon(
            isEmpty ? Icons.add : Icons.remove,
            size: 20,
            color: isEmpty ? AppColors.accent : AppColors.cardEmphasis,
          ),
          onPressed: isEmpty
              ? (onPlusWhenEmpty ??
                  (focusWhenEmpty != null ? () => focusWhenEmpty.requestFocus() : null))
              : onMinus,
        ),
      ],
    );
  }

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
    final dropChild = AnimatedContainer(
        key: kIsWeb ? _imageDropBoundaryKey : null,
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
  );

    if (kIsWeb) {
      return WebFileDropZone(
        boundaryKey: _imageDropBoundaryKey,
        onDrop: _onWebImageDrop,
        onDragEntered: () => setState(() => _imageDropActive = true),
        onDragExited: () => setState(() => _imageDropActive = false),
        child: dropChild,
      );
    }
    return DropTarget(
      onDragEntered: (_) => setState(() => _imageDropActive = true),
      onDragExited: (_) => setState(() => _imageDropActive = false),
      onDragDone: _onImageDropDone,
      child: dropChild,
    );
  }

  // ── 썸네일 위젯 (앱: Image.file / 웹: Image.memory 캐시) ──
  Widget _buildThumbnail(XFile file) {
    if (kIsWeb) {
      if (_isHttpImagePath(file.path)) {
        return Image.network(
          file.path,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 100,
            height: 100,
            color: AppColors.surfaceMuted,
            child: const Icon(Icons.image_outlined, color: AppColors.textDisabled),
          ),
        );
      }
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

  // ── 기본 정보 (순서: 제목 → 치과명 → 경력 → 채용직 → 담당 업무 → 학력 → 고용 → 급여) ──
  Widget _buildBasicInfo() {
    return Column(
      children: [
        _wrapStep3Clear(
          child: _field(
            controller: _titleCtrl,
            label: '공고 제목',
            hint: '예) 치과위생사 모집합니다',
            validator: (v) => (v?.isEmpty ?? true) ? '제목을 입력해주세요.' : null,
            focusNode: _fTitle,
          ),
          isEmpty: _titleCtrl.text.trim().isEmpty,
          onMinus: () {
            setState(() => _titleCtrl.clear());
            _notify();
          },
          focusWhenEmpty: _fTitle,
        ),
        const SizedBox(height: 12),
        _wrapStep3Clear(
          child: _field(
            controller: _clinicNameCtrl,
            label: '치과명',
            hint: '예) 서울미소치과',
            validator: (v) => (v?.isEmpty ?? true) ? '치과명을 입력해주세요.' : null,
            focusNode: _fClinicName,
          ),
          isEmpty: _clinicNameCtrl.text.trim().isEmpty,
          onMinus: () {
            setState(() => _clinicNameCtrl.clear());
            _notify();
          },
          focusWhenEmpty: _fClinicName,
        ),
        const SizedBox(height: 12),
        _wrapStep3Clear(
          child: _dropdown(
            label: '경력 조건',
            value: _selectedCareer,
            items: _careers,
            onChanged: (v) {
              setState(() => _selectedCareer = v);
              _notify();
            },
          ),
          isEmpty: _selectedCareer == null,
          onMinus: () {
            setState(() => _selectedCareer = null);
            _notify();
          },
        ),
        const SizedBox(height: 12),
        _buildHireRolesBlock(),
        const SizedBox(height: 12),
        _buildDutiesBlock(),
        const SizedBox(height: 12),
        _wrapStep3Clear(
          child: _dropdown(
            label: '학력',
            value: _selectedEducation,
            items: _educations,
            onChanged: (v) {
              setState(() => _selectedEducation = v);
              _notify();
            },
          ),
          isEmpty: _selectedEducation == null,
          onMinus: () {
            setState(() => _selectedEducation = null);
            _notify();
          },
        ),
        const SizedBox(height: 12),
        _wrapStep3Clear(
          child: _dropdown(
            label: '고용 형태',
            value: _selectedEmploymentType,
            items: _employmentTypes,
            onChanged: (v) {
              setState(() => _selectedEmploymentType = v);
              _notify();
            },
          ),
          isEmpty: _selectedEmploymentType == null,
          onMinus: () {
            setState(() => _selectedEmploymentType = null);
            _notify();
          },
        ),
        const SizedBox(height: 12),
        _buildSalaryRow(),
      ],
    );
  }

  void _toggleHirePreset(String p) {
    setState(() {
      final list = List<String>.from(_data.hireRoles);
      if (list.contains(p)) {
        list.remove(p);
      } else {
        list.add(p);
      }
      _data = _data.copyWith(
        hireRoles: list,
        role: JobPostData.joinHireRoles(list),
      );
    });
    _notify();
  }

  void _addHireCustom() {
    final v = _hireOtherCtrl.text.trim();
    if (v.isEmpty) return;
    setState(() {
      final list = List<String>.from(_data.hireRoles);
      if (!list.contains(v)) list.add(v);
      _hireOtherCtrl.clear();
      _data = _data.copyWith(
        hireRoles: list,
        role: JobPostData.joinHireRoles(list),
      );
    });
    _notify();
  }

  void _removeHireRole(String s) {
    setState(() {
      final list = List<String>.from(_data.hireRoles)..remove(s);
      _data = _data.copyWith(
        hireRoles: list,
        role: JobPostData.joinHireRoles(list),
      );
    });
    _notify();
  }

  void _toggleDutyPreset(String p) {
    setState(() {
      final list = List<String>.from(_data.mainDutiesList);
      if (list.contains(p)) {
        list.remove(p);
      } else {
        list.add(p);
      }
      _data = _data.copyWith(
        mainDutiesList: list,
        mainDutiesRaw: list.join('\n'),
      );
    });
    _notify();
  }

  void _addDutyCustom() {
    final v = _dutyOtherCtrl.text.trim();
    if (v.isEmpty) return;
    setState(() {
      final list = List<String>.from(_data.mainDutiesList);
      if (!list.contains(v)) list.add(v);
      _dutyOtherCtrl.clear();
      _data = _data.copyWith(
        mainDutiesList: list,
        mainDutiesRaw: list.join('\n'),
      );
    });
    _notify();
  }

  void _removeDuty(String s) {
    setState(() {
      final list = List<String>.from(_data.mainDutiesList)..remove(s);
      _data = _data.copyWith(
        mainDutiesList: list,
        mainDutiesRaw: list.isEmpty ? null : list.join('\n'),
      );
    });
    _notify();
  }

  Widget _buildHireRolesBlock() {
    final customs =
        _data.hireRoles.where((e) => !_hireRolePresets.contains(e)).toList();
    return _wrapStep3Clear(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _labelWithBadge('채용직', 'role'),
          const SizedBox(height: 8),
          Wrap(
            spacing: _pubWeb ? AppPublisher.formChipSpacing : 6,
            runSpacing: _pubWeb ? AppPublisher.formChipRunSpacing : 6,
            children: [
              ..._hireRolePresets.map((p) {
                final selected = _data.hireRoles.contains(p);
                return FilterChip(
                  label: Text(p),
                  selected: selected,
                  onSelected: (_) => _toggleHirePreset(p),
                  selectedColor: AppColors.accent.withOpacity(0.2),
                  checkmarkColor: AppColors.accent,
                  labelStyle: _ft(
                    size: 13,
                    weight: FontWeight.w600,
                    color: selected ? AppColors.accent : AppColors.textSecondary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: _rChip,
                    side: BorderSide(
                      color: selected
                          ? AppColors.accent.withOpacity(0.4)
                          : AppColors.divider,
                    ),
                  ),
                  backgroundColor: AppColors.white,
                );
              }),
              ...customs.map(
                (c) => Chip(
                  label: Text(c, style: _ft(size: 13, weight: FontWeight.w600)),
                  deleteIcon: const Icon(Icons.close_rounded, size: 16),
                  onDeleted: () => _removeHireRole(c),
                  backgroundColor: AppColors.accent.withOpacity(0.07),
                  side: BorderSide(color: AppColors.accent.withOpacity(0.25)),
                  shape: RoundedRectangleBorder(borderRadius: _rChip),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hireOtherCtrl,
                  style: _ft(size: 13, weight: FontWeight.w600, color: AppColors.textPrimary),
                  decoration: _pubWeb
                      ? _pubUnderlineDecoration(
                          label: null,
                          hint: '기타 직무 직접 입력',
                        )
                      : InputDecoration(
                          hintText: '기타 직무 직접 입력',
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
                onPressed: _addHireCustom,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  padding: _pubWeb
                      ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
                      : null,
                  shape: RoundedRectangleBorder(borderRadius: _rChip),
                ),
                child: const Text('추가'),
              ),
            ],
          ),
        ],
      ),
      isEmpty: _data.hireRoles.isEmpty && _hireOtherCtrl.text.trim().isEmpty,
      onMinus: () {
        setState(() {
          _hireOtherCtrl.clear();
          _data = _data.copyWith(hireRoles: [], role: '');
        });
        _notify();
      },
    );
  }

  Widget _buildDutiesBlock() {
    final customs =
        _data.mainDutiesList.where((e) => !_dutyPresets.contains(e)).toList();
    return _wrapStep3Clear(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _labelWithBadge('담당 업무', 'mainDuties'),
              const Spacer(),
              if (_step3)
                IconButton(
                  tooltip: _data.mainDutiesList.isEmpty ? '담당 업무 추가' : '담당 업무 모두 비우기',
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: Icon(
                    _data.mainDutiesList.isEmpty ? Icons.add : Icons.remove,
                    size: 20,
                    color: _data.mainDutiesList.isEmpty
                        ? AppColors.accent
                        : AppColors.cardEmphasis,
                  ),
                  onPressed: _data.mainDutiesList.isEmpty
                      ? () => _fDutyOther.requestFocus()
                      : () {
                          setState(() {
                            _dutyOtherCtrl.clear();
                            _data = _data.copyWith(mainDutiesList: [], mainDutiesRaw: null);
                          });
                          _notify();
                        },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: _pubWeb ? AppPublisher.formChipSpacing : 6,
            runSpacing: _pubWeb ? AppPublisher.formChipRunSpacing : 6,
            children: [
              ..._dutyPresets.map((p) {
                final selected = _data.mainDutiesList.contains(p);
                return FilterChip(
                  label: Text(p),
                  selected: selected,
                  onSelected: (_) => _toggleDutyPreset(p),
                  selectedColor: AppColors.accent.withOpacity(0.2),
                  checkmarkColor: AppColors.accent,
                  labelStyle: _ft(
                    size: 13,
                    weight: FontWeight.w600,
                    color: selected ? AppColors.accent : AppColors.textSecondary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: _rChip,
                    side: BorderSide(
                      color: selected
                          ? AppColors.accent.withOpacity(0.4)
                          : AppColors.divider,
                    ),
                  ),
                  backgroundColor: AppColors.white,
                );
              }),
              ...customs.map(
                (c) => Chip(
                  label: Text(c, style: _ft(size: 13, weight: FontWeight.w600)),
                  deleteIcon: const Icon(Icons.close_rounded, size: 16),
                  onDeleted: () => _removeDuty(c),
                  backgroundColor: AppColors.accent.withOpacity(0.07),
                  side: BorderSide(color: AppColors.accent.withOpacity(0.25)),
                  shape: RoundedRectangleBorder(borderRadius: _rChip),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dutyOtherCtrl,
                  focusNode: _fDutyOther,
                  style: _ft(size: 13, weight: FontWeight.w600, color: AppColors.textPrimary),
                  decoration: _pubWeb
                      ? _pubUnderlineDecoration(
                          label: null,
                          hint: '기타 업무 직접 입력',
                        )
                      : InputDecoration(
                          hintText: '기타 업무 직접 입력',
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
                onPressed: _addDutyCustom,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  padding: _pubWeb
                      ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
                      : null,
                  shape: RoundedRectangleBorder(borderRadius: _rChip),
                ),
                child: const Text('추가'),
              ),
            ],
          ),
        ],
      ),
      isEmpty: _data.mainDutiesList.isEmpty && _dutyOtherCtrl.text.trim().isEmpty,
      onMinus: () {
        setState(() {
          _dutyOtherCtrl.clear();
          _data = _data.copyWith(mainDutiesList: [], mainDutiesRaw: null);
        });
        _notify();
      },
    );
  }

  Widget _buildSalaryRow() {
    final negotiation = _selectedSalaryPayType == '협의';
    final amountEmpty = _salaryAmountCtrl.text.trim().isEmpty;
    final payEmpty = _selectedSalaryPayType == null;
    final salaryRow = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _dropdown(
            label: '급여',
            value: _selectedSalaryPayType,
            items: _salaryPayTypes,
            onChanged: (v) {
              setState(() {
                _selectedSalaryPayType = v;
                if (v == '협의') {
                  _salaryAmountCtrl.clear();
                }
              });
              _notify();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: _salaryAmountCtrl,
            focusNode: _fSalary,
            enabled: !negotiation && _selectedSalaryPayType != null,
            keyboardType: TextInputType.number,
            style: _ft(size: 14, weight: FontWeight.w600, color: AppColors.textPrimary),
            decoration: _pubWeb
                ? _pubUnderlineDecoration(
                    label: '금액',
                    hint: negotiation ? '—' : '예) 250',
                  )
                : InputDecoration(
                    labelText: '금액',
                    hintText: negotiation ? '—' : '예) 250',
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
                    filled: true,
                    fillColor: AppColors.appBg,
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            '만원',
            style: _ft(size: 14, weight: FontWeight.w600, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
    return _wrapStep3Clear(
      child: salaryRow,
      isEmpty: payEmpty && amountEmpty,
      onMinus: () {
        setState(() {
          _selectedSalaryPayType = null;
          _salaryAmountCtrl.clear();
        });
        _notify();
      },
      focusWhenEmpty: _fSalary,
    );
  }

  // ── 근무 조건 ──────────────────────────────────────────
  Widget _buildWorkConditions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _wrapStep3Clear(
          child: _field(
            controller: _workHoursCtrl,
            label: '근무 시간',
            hint: '예) 09:00 ~ 18:00 (주 5일)',
            fieldKey: 'workHours',
            focusNode: _fWorkHours,
          ),
          isEmpty: _workHoursCtrl.text.trim().isEmpty,
          onMinus: () {
            setState(() => _workHoursCtrl.clear());
            _notify();
          },
          focusWhenEmpty: _fWorkHours,
        ),
        const SizedBox(height: 16),
        _wrapStep3Clear(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _labelWithBadge('근무 요일', 'workDays'),
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
            ],
          ),
          isEmpty: _data.workDays.isEmpty,
          onMinus: () {
            setState(() => _data = _data.copyWith(workDays: []));
            _notify();
          },
        ),
        const SizedBox(height: 12),
        _wrapStep3Clear(
          child: _switchRow(
            label: '주말 근무',
            value: _data.weekendWork,
            onChanged: (v) {
              setState(() => _data = _data.copyWith(weekendWork: v));
              _notify();
            },
          ),
          isEmpty: !_data.weekendWork,
          onMinus: () {
            setState(() => _data = _data.copyWith(weekendWork: false));
            _notify();
          },
          onPlusWhenEmpty: () {
            setState(() => _data = _data.copyWith(weekendWork: true));
            _notify();
          },
        ),
        _wrapStep3Clear(
          child: _switchRow(
            label: '야간 진료',
            value: _data.nightShift,
            onChanged: (v) {
              setState(() => _data = _data.copyWith(nightShift: v));
              _notify();
            },
          ),
          isEmpty: !_data.nightShift,
          onMinus: () {
            setState(() => _data = _data.copyWith(nightShift: false));
            _notify();
          },
          onPlusWhenEmpty: () {
            setState(() => _data = _data.copyWith(nightShift: true));
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
        _wrapStep3Clear(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _labelWithBadge('복리후생 선택', 'benefits'),
              const SizedBox(height: 8),
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
                        selectedColor: AppColors.accent.withOpacity(0.2),
                        checkmarkColor: AppColors.accent,
                        labelStyle: _ft(
                          size: 13,
                          weight: FontWeight.w600,
                          color: _data.benefits.contains(b) ? AppColors.accent : AppColors.textSecondary,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: _rChip,
                          side: BorderSide(
                            color: selected ? AppColors.accent.withOpacity(0.4) : AppColors.divider,
                          ),
                        ),
                        backgroundColor: AppColors.white,
                      );
                    }).toList(),
              ),
              const SizedBox(height: 12),
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
          ),
          isEmpty: _data.benefits.isEmpty && _benefitInputCtrl.text.trim().isEmpty,
          onMinus: () {
            setState(() {
              _data = _data.copyWith(benefits: []);
              _benefitInputCtrl.clear();
            });
            _notify();
          },
        ),
      ],
    );
  }

  // ── 상세 내용 ──────────────────────────────────────────
  Widget _buildDescription() {
    return _wrapStep3Clear(
      child: _field(
        controller: _descriptionCtrl,
        label: '공고 상세 내용',
        hint: '근무 환경, 담당 업무, 우대사항 등을 자유롭게 작성해주세요.',
        maxLines: 6,
        focusNode: _fDescription,
      ),
      isEmpty: _descriptionCtrl.text.trim().isEmpty,
      onMinus: () {
        setState(() => _descriptionCtrl.clear());
        _notify();
      },
      focusWhenEmpty: _fDescription,
    );
  }

  // ── 주소 / 연락처 / 교통편 ───────────────────────────────
  Widget _buildAddressContact() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _wrapStep3Clear(
          child: _field(
            controller: _addressCtrl,
            label: '치과 주소',
            hint: '예) 서울시 강남구 테헤란로 123',
            validator: (v) => (v?.isEmpty ?? true) ? '주소를 입력해주세요.' : null,
            focusNode: _fAddress,
          ),
          isEmpty: _addressCtrl.text.trim().isEmpty,
          onMinus: () {
            setState(() => _addressCtrl.clear());
            _notify();
          },
          focusWhenEmpty: _fAddress,
        ),
        const SizedBox(height: 12),
        _wrapStep3Clear(
          child: _field(
            controller: _contactCtrl,
            label: '연락처',
            hint: '예) 02-1234-5678 또는 이메일',
            focusNode: _fContact,
          ),
          isEmpty: _contactCtrl.text.trim().isEmpty,
          onMinus: () {
            setState(() => _contactCtrl.clear());
            _notify();
          },
          focusWhenEmpty: _fContact,
        ),
        const SizedBox(height: 16),
        // 교통편 자동 조회
        _wrapStep3Clear(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                  focusNode: _fExitNumber,
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
                  focusNode: _fExitNumber,
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
            ],
          ),
          isEmpty: _nearbyStations.isEmpty &&
              (_data.subwayStationName == null || _data.subwayStationName!.trim().isEmpty) &&
              _exitNumberCtrl.text.trim().isEmpty,
          onMinus: () {
            setState(() {
              _nearbyStations = [];
              _data.subwayStationName = null;
              _data.subwayLines = [];
              _data.walkingDistanceMeters = null;
              _data.walkingMinutes = null;
              _exitNumberCtrl.clear();
            });
            _notify();
          },
          focusWhenEmpty: _fExitNumber,
        ),
        _wrapStep3Clear(
          child: _switchRow(
            label: '주차 가능',
            value: _data.parking,
            onChanged: (v) {
              setState(() => _data = _data.copyWith(parking: v));
              _notify();
            },
          ),
          isEmpty: !_data.parking,
          onMinus: () {
            setState(() => _data = _data.copyWith(parking: false));
            _notify();
          },
          onPlusWhenEmpty: () {
            setState(() => _data = _data.copyWith(parking: true));
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
    const specialtyOptions = [
      '일반진료', '교정', '임플란트', '소아치과', '치주', '보존', '기타',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _wrapStep3Clear(
          child: _dropdown(
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
          isEmpty: _selectedHospitalType == null,
          onMinus: () {
            setState(() => _selectedHospitalType = null);
            _notify();
          },
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _wrapStep3Clear(
                child: _field(
                  controller: _chairCountCtrl,
                  label: '체어 수',
                  hint: '예) 5',
                  focusNode: _fChairCount,
                ),
                isEmpty: _chairCountCtrl.text.trim().isEmpty,
                onMinus: () {
                  setState(() => _chairCountCtrl.clear());
                  _notify();
                },
                focusWhenEmpty: _fChairCount,
              ),
            ),
            SizedBox(width: _pubWeb ? AppPublisher.formFieldRowGap : 12),
            Expanded(
              child: _wrapStep3Clear(
                child: _field(
                  controller: _staffCountCtrl,
                  label: '스탭 수',
                  hint: '예) 8',
                  focusNode: _fStaffCount,
                ),
                isEmpty: _staffCountCtrl.text.trim().isEmpty,
                onMinus: () {
                  setState(() => _staffCountCtrl.clear());
                  _notify();
                },
                focusWhenEmpty: _fStaffCount,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _wrapStep3Clear(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('주요 진료 과목',
                  style: _ft(size: 13, weight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: _pubWeb ? AppPublisher.formChipSpacing : 6,
                runSpacing: _pubWeb ? AppPublisher.formChipRunSpacing : 6,
                children: specialtyOptions.map((opt) {
                  final selected = _data.specialties.contains(opt);
                  return FilterChip(
                    label: Text(opt),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        final list = List<String>.from(_data.specialties);
                        selected ? list.remove(opt) : list.add(opt);
                        _data = _data.copyWith(specialties: list);
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
            ],
          ),
          isEmpty: _data.specialties.isEmpty,
          onMinus: () {
            setState(() => _data = _data.copyWith(specialties: []));
            _notify();
          },
        ),
        const SizedBox(height: 16),
        Text('디지털 장비',
            style: _ft(size: 13, weight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        _wrapStep3Clear(
          child: _equipmentToggle(
            label: '구강 스캐너',
            value: _data.hasOralScanner,
            onChanged: (v) {
              setState(() => _data = _data.copyWith(hasOralScanner: v));
              _notify();
            },
          ),
          isEmpty: _data.hasOralScanner == null,
          onMinus: () {
            setState(() => _data = _data.copyWith(hasOralScanner: null));
            _notify();
          },
          onPlusWhenEmpty: () {
            setState(() => _data = _data.copyWith(hasOralScanner: false));
            _notify();
          },
        ),
        const SizedBox(height: 8),
        _wrapStep3Clear(
          child: _equipmentToggle(
            label: 'CT',
            value: _data.hasCT,
            onChanged: (v) {
              setState(() => _data = _data.copyWith(hasCT: v));
              _notify();
            },
          ),
          isEmpty: _data.hasCT == null,
          onMinus: () {
            setState(() => _data = _data.copyWith(hasCT: null));
            _notify();
          },
          onPlusWhenEmpty: () {
            setState(() => _data = _data.copyWith(hasCT: false));
            _notify();
          },
        ),
        const SizedBox(height: 8),
        _wrapStep3Clear(
          child: _equipmentToggle(
            label: '3D 프린터',
            value: _data.has3DPrinter,
            onChanged: (v) {
              setState(() => _data = _data.copyWith(has3DPrinter: v));
              _notify();
            },
          ),
          isEmpty: _data.has3DPrinter == null,
          onMinus: () {
            setState(() => _data = _data.copyWith(has3DPrinter: null));
            _notify();
          },
          onPlusWhenEmpty: () {
            setState(() => _data = _data.copyWith(has3DPrinter: false));
            _notify();
          },
        ),
        const SizedBox(height: 8),
        _wrapStep3Clear(
          child: _field(
            controller: _digitalEquipmentRawCtrl,
            label: '기타 장비',
            hint: '예) 파노라마, 레이저 등',
            maxLines: 1,
            focusNode: _fDigitalEquipment,
          ),
          isEmpty: _digitalEquipmentRawCtrl.text.trim().isEmpty,
          onMinus: () {
            setState(() => _digitalEquipmentRawCtrl.clear());
            _notify();
          },
          focusWhenEmpty: _fDigitalEquipment,
        ),
      ],
    );
  }

  /// 장비 보유 여부 토글 (있음 / 없음 / 미확인)
  Widget _equipmentToggle({
    required String label,
    required bool? value,
    required ValueChanged<bool?> onChanged,
  }) {
    Widget _chip(String text, bool? chipVal) {
      final isSelected = value == chipVal;
      return GestureDetector(
        onTap: () => onChanged(isSelected ? null : chipVal),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent.withOpacity(0.15) : AppColors.white,
            borderRadius: _rChip,
            border: Border.all(
              color: isSelected ? AppColors.accent.withOpacity(0.5) : AppColors.divider,
            ),
          ),
          child: Text(
            text,
            style: _ft(
              size: 13,
              weight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? AppColors.accent : AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label,
              style: _ft(size: 13, weight: FontWeight.w500, color: AppColors.textPrimary)),
        ),
        _chip('있음', true),
        const SizedBox(width: 6),
        _chip('없음', false),
        const SizedBox(width: 6),
        _chip('미확인', null),
      ],
    );
  }

  // ── 지원 방법 / 마감일 ───────────────────────────────────
  Widget _buildApplySection() {
    const methods = {'online': '앱 간편지원', 'phone': '전화 지원', 'email': '이메일 지원'};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _wrapStep3Clear(
          child: Column(
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
            ],
          ),
          isEmpty: _data.applyMethod.isEmpty,
          onMinus: () {
            setState(() => _data = _data.copyWith(applyMethod: []));
            _notify();
          },
        ),
        const SizedBox(height: 16),
        _wrapStep3Clear(
          child: _switchRow(
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
          isEmpty: !_data.isAlwaysHiring,
          onMinus: () {
            setState(() => _data = _data.copyWith(isAlwaysHiring: false));
            _notify();
          },
          onPlusWhenEmpty: () {
            setState(() => _data = _data.copyWith(isAlwaysHiring: true));
            _notify();
          },
        ),
        if (!_data.isAlwaysHiring) ...[
          const SizedBox(height: 8),
          _wrapStep3Clear(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _labelWithBadge('마감일', 'closingDate'),
                const SizedBox(height: 6),
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
            ),
            isEmpty: _data.closingDate == null,
            onMinus: () {
              setState(() => _data = _data.copyWith(closingDate: null));
              _notify();
            },
            onPlusWhenEmpty: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 14)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null && mounted) {
                setState(() => _data = _data.copyWith(closingDate: picked));
                _notify();
              }
            },
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

  // ── AI 상태 배너 ─────────────────────────────────────────────

  /// AI 추출 완료 후 상단에 표시되는 요약 배너.
  /// conflict·missing 필드가 있을 때만 경고 톤, 없으면 성공 톤.
  Widget _buildAiStatusBanner() {
    final status = _aiFieldStatus;
    if (status == null || status.isEmpty) return const SizedBox.shrink();

    final issueCount = status.values.where((v) => v == 'conflict' || v == 'missing').length;
    final hasIssue = issueCount > 0;

    final bgColor = hasIssue
        ? AppColors.cardEmphasis.withValues(alpha: 0.08)
        : AppColors.accent.withValues(alpha: 0.08);
    final borderColor = hasIssue
        ? AppColors.cardEmphasis.withValues(alpha: 0.35)
        : AppColors.accent.withValues(alpha: 0.28);
    final iconColor = hasIssue ? AppColors.cardEmphasis : AppColors.accent;
    final icon = hasIssue ? Icons.info_outline_rounded : Icons.check_circle_outline_rounded;
    final message = hasIssue
        ? 'AI 자동 추출 완료 · $issueCount개 항목 확인 필요'
        : 'AI 자동 추출 완료 · 모든 항목 정상 추출';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppPublisher.softRadius),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: _ft(size: 13, weight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _aiFieldStatus = null),
            child: Icon(
              Icons.close_rounded,
              size: 16,
              color: AppColors.textSecondary.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  // ── 필드 상태 뱃지 ───────────────────────────────────────────

  /// fieldKey에 해당하는 AI 상태 뱃지 반환.
  /// confirmed이거나 상태 없으면 SizedBox.shrink() 반환.
  Widget _fieldBadge(String fieldKey) {
    final status = _aiFieldStatus?[fieldKey];
    if (status == null || status == 'confirmed') return const SizedBox.shrink();

    final (label, bg, fg) = switch (status) {
      'inferred' => ('AI 추론값', const Color(0xFFF5F5F5), const Color(0xFF757575)),
      'conflict' => ('확인 필요', const Color(0xFFFFF3E0), const Color(0xFFE65100)),
      'missing'  => ('미추출', const Color(0xFFFFEBEE), const Color(0xFFC62828)),
      _          => ('', Colors.transparent, Colors.transparent),
    };

    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fg.withOpacity(0.4)),
      ),
      child: Text(label, style: _ft(size: 10, weight: FontWeight.w700, color: fg)),
    );
  }

  /// 라벨 + 뱃지를 Row로 묶어 반환 (필드 헤더용).
  Widget _labelWithBadge(String label, String fieldKey) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: _ft(size: 13, weight: FontWeight.w600, color: AppColors.textSecondary)),
        _fieldBadge(fieldKey),
      ],
    );
  }

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
    String? fieldKey,
    FocusNode? focusNode,
  }) {
    final hasBadge = fieldKey != null && (_aiFieldStatus?[fieldKey] != null && _aiFieldStatus?[fieldKey] != 'confirmed');

    if (hasBadge) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _labelWithBadge(label, fieldKey),
          const SizedBox(height: 4),
          _fieldCore(
            controller: controller,
            hint: hint,
            maxLines: maxLines,
            validator: validator,
            focusNode: focusNode,
          ),
        ],
      );
    }

    return _fieldCore(
      controller: controller,
      label: label,
      hint: hint,
      maxLines: maxLines,
      validator: validator,
      focusNode: focusNode,
    );
  }

  Widget _fieldCore({
    required TextEditingController controller,
    String? label,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
    FocusNode? focusNode,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
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


