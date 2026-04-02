import 'package:cloud_firestore/cloud_firestore.dart';

/// 공고 임시저장 엔티티
/// Firestore 경로: `jobDrafts/{draftId}`
class JobDraft {
  final String id;
  final String ownerUid;
  final String clinicName;
  final String title;
  final String role;
  final String career;
  final String employmentType;
  final String workHours;
  final String salary;
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
  final List<String> workDays;
  final bool weekendWork;
  final bool nightShift;
  final List<String> applyMethod;
  final bool isAlwaysHiring;
  final DateTime? closingDate;
  final String? subwayStationName;
  final List<String> subwayLines;
  final int? walkingDistanceMeters;
  final int? walkingMinutes;
  final String? exitNumber;
  final bool parking;
  final double? lat;
  final double? lng;
  final List<String> tags;

  // AI 파이프라인 필드
  final String? currentStep;
  final String? aiParseStatus;
  final String? sourceType;
  final String? rawInputText;
  final List<String> rawImageUrls;
  final String? clinicProfileId;

  /// 웹 공고 Stepper 상태 (`step1` | `step2` | `step3`) — 클라이언트 전용, 미설정 시 기본 흐름
  final String? editorStep;

  const JobDraft({
    required this.id,
    required this.ownerUid,
    this.clinicName = '',
    this.title = '',
    this.role = '',
    this.career = '',
    this.employmentType = '',
    this.workHours = '',
    this.salary = '',
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
    this.workDays = const [],
    this.weekendWork = false,
    this.nightShift = false,
    this.applyMethod = const [],
    this.isAlwaysHiring = false,
    this.closingDate,
    this.subwayStationName,
    this.subwayLines = const [],
    this.walkingDistanceMeters,
    this.walkingMinutes,
    this.exitNumber,
    this.parking = false,
    this.lat,
    this.lng,
    this.tags = const [],
    this.currentStep,
    this.aiParseStatus,
    this.sourceType,
    this.rawInputText,
    this.rawImageUrls = const [],
    this.clinicProfileId,
    this.editorStep,
  });

  factory JobDraft.fromMap(Map<String, dynamic> data, {required String id}) {
    final trans = data['transportation'] as Map<String, dynamic>?;
    DateTime? closing;
    if (data['closingDate'] is String) {
      try { closing = DateTime.parse(data['closingDate'] as String); } catch (_) {}
    } else if (data['closingDate'] is Timestamp) {
      closing = (data['closingDate'] as Timestamp).toDate();
    }

    return JobDraft(
      id: id,
      ownerUid: data['ownerUid'] as String? ?? '',
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
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
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
      subwayLines: List<String>.from(trans?['subwayLines'] ?? data['subwayLines'] ?? []),
      walkingDistanceMeters: (trans?['walkingDistanceMeters'] as num?)?.toInt(),
      walkingMinutes: (trans?['walkingMinutes'] as num?)?.toInt(),
      exitNumber: trans?['exitNumber'] as String?,
      parking: (trans?['parking'] as bool?) ?? (data['parking'] as bool?) ?? false,
      lat: (data['lat'] as num?)?.toDouble(),
      lng: (data['lng'] as num?)?.toDouble(),
      tags: List<String>.from(data['tags'] ?? []),
      currentStep: data['currentStep'] as String?,
      aiParseStatus: data['aiParseStatus'] as String?,
      sourceType: data['sourceType'] as String?,
      rawInputText: data['rawInputText'] as String?,
      rawImageUrls: List<String>.from(data['rawImageUrls'] ?? []),
      clinicProfileId: data['clinicProfileId'] as String?,
      editorStep: data['editorStep'] as String?,
    );
  }

  factory JobDraft.fromDoc(DocumentSnapshot doc) {
    return JobDraft.fromMap(doc.data() as Map<String, dynamic>, id: doc.id);
  }

  Map<String, dynamic> toMap() => {
        'ownerUid': ownerUid,
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
        'imageUrls': imageUrls,
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
        if (currentStep != null) 'currentStep': currentStep,
        if (aiParseStatus != null) 'aiParseStatus': aiParseStatus,
        if (sourceType != null) 'sourceType': sourceType,
        if (rawInputText != null) 'rawInputText': rawInputText,
        if (rawImageUrls.isNotEmpty) 'rawImageUrls': rawImageUrls,
        if (clinicProfileId != null) 'clinicProfileId': clinicProfileId,
        if (editorStep != null) 'editorStep': editorStep,
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
      description.isNotEmpty ||
      address.isNotEmpty;
}

