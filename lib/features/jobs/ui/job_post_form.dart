import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
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
class JobPostForm extends StatefulWidget {
  final JobPostData? initialData;
  final ValueChanged<JobPostData>? onDataChanged;
  final Future<void> Function(JobPostData data)? onSubmit;
  final String? draftId;
  final ValueChanged<String>? onDraftIdChanged;

  const JobPostForm({
    super.key,
    this.initialData,
    this.onDataChanged,
    this.onSubmit,
    this.draftId,
    this.onDraftIdChanged,
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

  static const _roles = ['치과위생사', '치과조무사', '데스크', '원장', '기타'];
  static const _careers = ['신입', '경력 무관', '1년 이상', '2년 이상', '3년 이상', '5년 이상'];
  static const _employmentTypes = ['정규직', '계약직', '파트타임', '인턴'];
  static const _commonBenefits = ['4대보험', '퇴직금', '연차', '식비지원', '주차지원', '명절상여'];

  @override
  void initState() {
    super.initState();
    _data = widget.initialData ?? JobPostData();
    _draftId = widget.draftId;
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

  // ── 임시저장 (auto-save with debounce) ──
  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 3), _autoSave);
  }

  Future<void> _autoSave() async {
    // 내용이 비어 있으면 저장하지 않음
    if (!_data.toMap().values.any(
      (v) => v is String && v.isNotEmpty || v is List && v.isNotEmpty,
    )) return;

    if (_isSavingDraft) return;
    if (!mounted) return;
    setState(() => _isSavingDraft = true);

    try {
      final id = await JobDraftService.saveDraft(
        draftId: _draftId,
        formData: _data.toMap(),
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
        final benefits =
            (res['benefits'] as List?)?.map((e) => e.toString()).toList();
        if (benefits != null && benefits.isNotEmpty) {
          _data = _data.copyWith(benefits: benefits);
        }
        _uploadProgress.clear();
        _aiReviewed = false;
      });
      _notify();

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

  // ── 이미지 선택 ────────────────────────────────────────
  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final remaining = 10 - _data.images.length;
    if (remaining <= 0) return;
    final picked = await picker.pickMultiImage(limit: remaining);
    if (picked.isEmpty) return;

    // 웹에서 미리보기 bytes를 선택 시점에 캐싱
    if (kIsWeb) {
      for (final f in picked) {
        if (!_previewCache.containsKey(f.name)) {
          _previewCache[f.name] = await f.readAsBytes();
        }
      }
    }

    final combined = [..._data.images, ...picked];
    final limited = combined.take(10).toList();
    setState(() {
      _data = _data.copyWith(images: limited);
    });
    _notify();
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
    if (_data.images.isNotEmpty && !_aiReviewed) {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      onChanged: _notify,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          _sectionCard(
            title: '📷 공고 사진 / AI 자동입력',
            child: _buildImageSection(),
          ),
          const SizedBox(height: 16),
          _sectionCard(title: '🏥 기본 정보', child: _buildBasicInfo()),
          const SizedBox(height: 16),
          _sectionCard(title: '🏢 병원 정보', child: _buildHospitalInfo()),
          const SizedBox(height: 16),
          _sectionCard(title: '⏰ 근무 조건', child: _buildWorkConditions()),
          const SizedBox(height: 16),
          _sectionCard(title: '📋 지원 방법 / 마감일', child: _buildApplySection()),
          const SizedBox(height: 16),
          _sectionCard(title: '🎁 복리후생', child: _buildBenefits()),
          const SizedBox(height: 16),
          _sectionCard(title: '📝 상세 내용', child: _buildDescription()),
          const SizedBox(height: 16),
          _sectionCard(title: '📍 주소 / 연락처 / 교통편', child: _buildAddressContact()),
          const SizedBox(height: 16),
          if (_data.tags.isNotEmpty)
            _sectionCard(title: '🏷️ 자동 생성 태그', child: _buildTagsPreview()),
          if (_data.tags.isNotEmpty) const SizedBox(height: 16),
          const SizedBox(height: 8),
          _buildSubmitSection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── 섹션 카드 래퍼 ─────────────────────────────────────
  Widget _sectionCard({required String title, required Widget child}) {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '공고 이미지를 업로드하면 AI가 자동으로 폼을 채워줘요. (최대 10장, jpg/png, 장당 5MB 이하)',
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
                      borderRadius: BorderRadius.circular(10),
                      child: _buildThumbnail(_data.images[i]),
                    ),
                    // 업로드 진행도 오버레이
                    if (progress != null && progress < 1.0)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
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
            OutlinedButton.icon(
              onPressed: _data.images.length < 10 ? _pickImages : null,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: Text('사진 추가 (${_data.images.length}/10)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(color: AppColors.divider),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // AI 자동채움 버튼
            ElevatedButton.icon(
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
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
      ],
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
          spacing: 6,
          runSpacing: 6,
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
                borderRadius: BorderRadius.circular(8),
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
          spacing: 8,
          runSpacing: 8,
          children:
              _commonBenefits.map((b) {
                final selected = _data.benefits.contains(b);
                return FilterChip(
                  label: Text(b),
                  selected: selected,
                  onSelected: (_) => _toggleBenefit(b),
                  selectedColor: AppColors.error.withOpacity(0.25),
                  checkmarkColor: AppColors.textPrimary,
                  labelStyle: _ft(
                    size: 13,
                    weight: FontWeight.w600,
                    color: _data.benefits.contains(b) ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: selected ? AppColors.error.withOpacity(0.4) : AppColors.divider,
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
                decoration: InputDecoration(
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
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('추가'),
            ),
          ],
        ),
        if (_data.benefits.any((b) => !_commonBenefits.contains(b))) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
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
                        backgroundColor: AppColors.accent.withOpacity(0.1),
                        side: BorderSide.none,
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
        if (_data.subwayStationName != null && _data.subwayStationName!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accent.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.subway, size: 18, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_data.subwayStationName}'
                    '${_data.walkingMinutes != null ? " 도보 ${_data.walkingMinutes}분" : ""}'
                    '${_data.walkingDistanceMeters != null ? " (${_data.walkingDistanceMeters}m)" : ""}',
                    style: _ft(size: 13, weight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
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
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
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
      if (!mounted) return;
      setState(() {
        _data.subwayStationName = result.info.subwayStationName;
        _data.subwayLines = result.info.subwayLines;
        _data.walkingDistanceMeters = result.info.walkingDistanceMeters;
        _data.walkingMinutes = result.info.walkingMinutes;
        _data.lat = result.lat;
        _data.lng = result.lng;
      });
      _notify();
      if (mounted) {
        _showSnack(
            '${result.info.subwayStationName ?? "역"} 도보 ${result.info.walkingMinutes ?? "?"}분 조회 완료');
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
            const SizedBox(width: 12),
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
          spacing: 6,
          runSpacing: 6,
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
                borderRadius: BorderRadius.circular(8),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(10),
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
      spacing: 6,
      runSpacing: 6,
      children: _data.tags.map((t) => Chip(
        label: Text(t, style: _ft(size: 12, weight: FontWeight.w600)),
        backgroundColor: AppColors.accent.withOpacity(0.08),
        side: BorderSide.none,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: _ft(size: 13, weight: FontWeight.w600, color: AppColors.textSecondary)),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.accent,
        ),
      ],
    );
  }

  // ── 제출 섹션 ──────────────────────────────────────────
  Widget _buildSubmitSection() {
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
          ),
        const SizedBox(height: 12),
        // ── 임시저장 버튼 + 상태 표시 ──
        Row(
          children: [
            Expanded(
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
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
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
      decoration: InputDecoration(
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
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        filled: true,
        fillColor: AppColors.appBg,
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
    return DropdownButtonFormField<String>(
      value: value,
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
      decoration: InputDecoration(
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
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        filled: true,
        fillColor: AppColors.appBg,
      ),
    );
  }
}


