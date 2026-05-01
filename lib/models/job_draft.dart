import 'package:cloud_firestore/cloud_firestore.dart';

import 'transportation_info.dart';

/// 공고 임시저장 엔티티
/// Firestore 경로: `jobDrafts/{draftId}`
class JobDraft {
  final String id;
  final String ownerUid;
  final String registeredClinicName;
  final String clinicName;
  final String title;
  final String role;
  final List<String> hireRoles;
  final String career;
  final String education;
  final String employmentType;
  final String workHours;
  final String salary;
  final String salaryPayType;
  final String salaryAmount;
  final List<String> benefits;
  final String description;
  final String address;
  final String contact;
  final List<String> imageUrls;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  // 신규 필드
  final String? hospitalType;
  final int? chairCount;
  final int? staffCount;

  /// 주요 진료 과목
  final List<String> specialties;

  /// 디지털 장비 보유
  final bool? hasOralScanner;
  final bool? hasCT;
  final bool? has3DPrinter;
  final String? digitalEquipmentRaw;
  final List<String> workDays;
  final bool weekendWork;
  final bool nightShift;
  final List<String> applyMethod;
  final List<String> requiredDocuments;
  final bool isAlwaysHiring;
  final DateTime? closingDate;
  final String? subwayStationName;
  final List<String> subwayLines;
  final List<TransportationStation> selectedStations;
  final int? walkingDistanceMeters;
  final int? walkingMinutes;
  final String? exitNumber;
  final bool parking;
  final double? lat;
  final double? lng;
  final List<String> tags;

  /// 자동 생성 태그를 사용자가 편집했으면 true — AI 재추출 시 태그 덮어쓰기 방지
  final bool tagsUserEdited;

  // AI 파이프라인 필드
  final String? currentStep;
  final String? aiParseStatus;
  final String? sourceType;
  final String? rawInputText;
  final List<String> rawImageUrls;

  /// 홍보이미지 URL — AI 추출 없이 공고에 직접 노출
  final List<String> promotionalImageUrls;
  final String? clinicProfileId;

  /// 로고파일 URL — 단일 이미지
  final String? logoUrl;

  // ── AI 추출 품질 필드 ────────────────────────────
  final String? mainDutiesRaw;
  final List<String> mainDutiesList;
  final DateTime? recruitmentStart;
  final Map<String, String>? fieldStatus;
  final Map<String, dynamic>? fieldSources;

  /// 웹 공고 Stepper: `step1` 사진 · `step2` 공고 상세 · `step3` 치과 인증 — 클라이언트 전용
  final String? editorStep;

  const JobDraft({
    required this.id,
    required this.ownerUid,
    this.registeredClinicName = '',
    this.clinicName = '',
    this.title = '',
    this.role = '',
    this.hireRoles = const [],
    this.career = '',
    this.education = '',
    this.employmentType = '',
    this.workHours = '',
    this.salary = '',
    this.salaryPayType = '',
    this.salaryAmount = '',
    this.benefits = const [],
    this.description = '',
    this.address = '',
    this.contact = '',
    this.imageUrls = const [],
    this.updatedAt,
    this.createdAt,
    this.hospitalType,
    this.chairCount,
    this.staffCount,
    this.specialties = const [],
    this.hasOralScanner,
    this.hasCT,
    this.has3DPrinter,
    this.digitalEquipmentRaw,
    this.workDays = const [],
    this.weekendWork = false,
    this.nightShift = false,
    this.applyMethod = const [],
    this.requiredDocuments = const [],
    this.isAlwaysHiring = false,
    this.closingDate,
    this.subwayStationName,
    this.subwayLines = const [],
    this.selectedStations = const [],
    this.walkingDistanceMeters,
    this.walkingMinutes,
    this.exitNumber,
    this.parking = false,
    this.lat,
    this.lng,
    this.tags = const [],
    this.tagsUserEdited = false,
    this.currentStep,
    this.aiParseStatus,
    this.sourceType,
    this.rawInputText,
    this.rawImageUrls = const [],
    this.promotionalImageUrls = const [],
    this.clinicProfileId,
    this.logoUrl,
    this.mainDutiesRaw,
    this.mainDutiesList = const [],
    this.recruitmentStart,
    this.fieldStatus,
    this.fieldSources,
    this.editorStep,
  });

  factory JobDraft.fromMap(Map<String, dynamic> data, {required String id}) {
    final trans = data['transportation'] as Map<String, dynamic>?;
    final selectedStations = _transportStationsFromMap(trans);
    DateTime? closing;
    if (data['closingDate'] is String) {
      try {
        closing = DateTime.parse(data['closingDate'] as String);
      } catch (_) {}
    } else if (data['closingDate'] is Timestamp) {
      closing = (data['closingDate'] as Timestamp).toDate();
    }

    return JobDraft(
      id: id,
      ownerUid: data['ownerUid'] as String? ?? '',
      registeredClinicName:
          data['registeredClinicName'] as String? ??
          data['businessRegisteredName'] as String? ??
          '',
      clinicName: data['clinicName'] as String? ?? '',
      title: data['title'] as String? ?? '',
      role: data['role'] as String? ?? '',
      hireRoles: List<String>.from(data['hireRoles'] ?? []),
      career: data['career'] as String? ?? '',
      education: data['education'] as String? ?? '',
      employmentType: data['employmentType'] as String? ?? '',
      workHours: data['workHours'] as String? ?? '',
      salary: data['salary'] as String? ?? '',
      salaryPayType: data['salaryPayType'] as String? ?? '',
      salaryAmount: data['salaryAmount'] as String? ?? '',
      benefits: List<String>.from(data['benefits'] ?? []),
      description: data['description'] as String? ?? '',
      address: data['address'] as String? ?? '',
      contact: data['contact'] as String? ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      updatedAt: _dateValue(data['updatedAt']),
      createdAt: _dateValue(data['createdAt']),
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
      requiredDocuments: List<String>.from(data['requiredDocuments'] ?? []),
      isAlwaysHiring: (data['isAlwaysHiring'] as bool?) ?? false,
      closingDate: closing,
      subwayStationName: trans?['subwayStationName'] as String?,
      subwayLines: List<String>.from(
        trans?['subwayLines'] ?? data['subwayLines'] ?? [],
      ),
      selectedStations: selectedStations,
      walkingDistanceMeters: (trans?['walkingDistanceMeters'] as num?)?.toInt(),
      walkingMinutes: (trans?['walkingMinutes'] as num?)?.toInt(),
      exitNumber: trans?['exitNumber'] as String?,
      parking:
          (trans?['parking'] as bool?) ?? (data['parking'] as bool?) ?? false,
      lat: (data['lat'] as num?)?.toDouble(),
      lng: (data['lng'] as num?)?.toDouble(),
      tags: List<String>.from(data['tags'] ?? []),
      tagsUserEdited: (data['tagsUserEdited'] as bool?) ?? false,
      currentStep: data['currentStep'] as String?,
      aiParseStatus: data['aiParseStatus'] as String?,
      sourceType: data['sourceType'] as String?,
      rawInputText: data['rawInputText'] as String?,
      rawImageUrls: List<String>.from(data['rawImageUrls'] ?? []),
      promotionalImageUrls: List<String>.from(
        data['promotionalImageUrls'] ?? [],
      ),
      clinicProfileId: data['clinicProfileId'] as String?,
      logoUrl: data['logoUrl'] as String?,
      editorStep: data['editorStep'] as String?,
      mainDutiesRaw: data['mainDutiesRaw'] as String?,
      mainDutiesList: List<String>.from(data['mainDutiesList'] ?? []),
      recruitmentStart: _dateValue(data['recruitmentStart']),
      fieldStatus: (data['fieldStatus'] as Map?)?.map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      ),
      fieldSources: data['fieldSources'] as Map<String, dynamic>?,
    );
  }

  factory JobDraft.fromDoc(DocumentSnapshot doc) {
    return JobDraft.fromMap(doc.data() as Map<String, dynamic>, id: doc.id);
  }

  Map<String, dynamic> toMap() => {
    'ownerUid': ownerUid,
    if (registeredClinicName.isNotEmpty)
      'registeredClinicName': registeredClinicName,
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
    'imageUrls': imageUrls,
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
    if (requiredDocuments.isNotEmpty) 'requiredDocuments': requiredDocuments,
    'isAlwaysHiring': isAlwaysHiring,
    if (closingDate != null) 'closingDate': closingDate!.toIso8601String(),
    'transportation': {
      if (subwayStationName != null) 'subwayStationName': subwayStationName,
      if (subwayLines.isNotEmpty) 'subwayLines': subwayLines,
      if (selectedStations.isNotEmpty)
        'selectedStations':
            selectedStations
                .where((s) => s.hasValue)
                .map((s) => s.toJson())
                .toList(),
      if (walkingDistanceMeters != null)
        'walkingDistanceMeters': walkingDistanceMeters,
      if (walkingMinutes != null) 'walkingMinutes': walkingMinutes,
      if (exitNumber != null) 'exitNumber': exitNumber,
      'parking': parking,
    },
    if (lat != null) 'lat': lat,
    if (lng != null) 'lng': lng,
    if (tags.isNotEmpty) 'tags': tags,
    if (tagsUserEdited) 'tagsUserEdited': true,
    if (currentStep != null) 'currentStep': currentStep,
    if (aiParseStatus != null) 'aiParseStatus': aiParseStatus,
    if (sourceType != null) 'sourceType': sourceType,
    if (rawInputText != null) 'rawInputText': rawInputText,
    if (rawImageUrls.isNotEmpty) 'rawImageUrls': rawImageUrls,
    if (promotionalImageUrls.isNotEmpty)
      'promotionalImageUrls': promotionalImageUrls,
    if (clinicProfileId != null) 'clinicProfileId': clinicProfileId,
    if (logoUrl != null && logoUrl!.isNotEmpty) 'logoUrl': logoUrl,
    if (editorStep != null) 'editorStep': editorStep,
    if (mainDutiesRaw != null) 'mainDutiesRaw': mainDutiesRaw,
    if (mainDutiesList.isNotEmpty) 'mainDutiesList': mainDutiesList,
    if (recruitmentStart != null)
      'recruitmentStart': recruitmentStart!.toIso8601String(),
    if (fieldStatus != null && fieldStatus!.isNotEmpty)
      'fieldStatus': fieldStatus,
    if (fieldSources != null && fieldSources!.isNotEmpty)
      'fieldSources': fieldSources,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  /// 표시용 제목 (비어 있으면 기본값)
  String get displayTitle {
    if (title.isNotEmpty) return title;
    if (clinicName.isNotEmpty) return '$clinicName (작성 중)';
    return '새 공고 (작성 중)';
  }

  /// 내용이 하나라도 있는지 (빈 드래프트인지 확인)
  bool get hasContent =>
      clinicName.isNotEmpty ||
      title.isNotEmpty ||
      role.isNotEmpty ||
      hireRoles.isNotEmpty ||
      description.isNotEmpty ||
      address.isNotEmpty;

  static List<TransportationStation> _transportStationsFromMap(
    Map<String, dynamic>? trans,
  ) {
    if (trans == null) return [];
    final raw = trans['selectedStations'];
    final stations =
        raw is List
            ? raw
                .whereType<Map>()
                .map(
                  (e) => TransportationStation.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .where((s) => s.hasValue)
                .toList()
            : <TransportationStation>[];
    if (stations.isNotEmpty) return stations;

    final legacy = TransportationStation(
      name: (trans['subwayStationName'] as String? ?? '').trim(),
      lines: List<String>.from(trans['subwayLines'] ?? []),
      walkingDistanceMeters: (trans['walkingDistanceMeters'] as num?)?.toInt(),
      walkingMinutes: (trans['walkingMinutes'] as num?)?.toInt(),
      exitNumber: trans['exitNumber'] as String?,
    );
    return legacy.hasValue ? [legacy] : [];
  }

  static DateTime? _dateValue(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
