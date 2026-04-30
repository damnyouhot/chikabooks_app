import 'package:cloud_firestore/cloud_firestore.dart';

import 'transportation_info.dart';

/// 구인 공고 (Firestore `jobs` + 목업 공통)
///
/// 웹 등록 필드(`role`, `description`, `salary` 등)와 앱 레거시 필드(`type`, `details`,
/// `salaryRange`)를 [fromJson]에서 한 번에 정규화한다.
class Job {
  final String id;
  final String title;
  final String clinicName;
  final String address;
  final String district; // 동/구 짧은 표시용 (예: "역삼동 · 강남구")
  final double lat;
  final double lng;

  /// 직종/직무 (목록 필터·매칭) — 웹 `role`과 동기화
  final String type;

  /// 경력 조건 텍스트 (예: 신입, 2년 이상). 없으면 `미정`
  final String career;

  /// 급여 범위 [만원] (필터·정렬·매칭). 미파싱 시 [0,0]
  final List<int> salaryRange;

  /// 급여 표시용 원문 (웹 `salary` / `salaryText`)
  final String salaryText;

  /// 고용 형태 (정규직, 파트타임 등) — 웹 `employmentType`
  final String employmentType;

  final String workHours;
  final String contact;

  /// 공개 상태: active, pending, closed … ([isListedInApp] 참고)
  final String? status;

  final DateTime postedAt;
  final String details;
  final List<String> benefits;
  final List<String> images;

  // ── 레벨/매칭 필드 ──────────────────────────────
  final int jobLevel; // 1=프리미엄, 2=추천, 3=일반
  final int matchScore;
  final bool isNearStation;
  final DateTime? closingDate;
  final bool canApplyNow;

  // ── 기본 정보 추가 ──────────────────────────────
  /// 학력 조건 (예: "대졸 이상", "무관")
  final String education;

  /// 모집 직종 목록 (복수 직종 모집 시 사용)
  final List<String> hireRoles;

  // ── 병원 정보 (3.1) ─────────────────────────────
  /// clinic | network | hospital | general (null = 미입력)
  final String? hospitalType;
  final int? chairCount;
  final int? staffCount;

  /// 진료과목 태그 (임플란트, 교정 등)
  final List<String> specialties;
  final bool? hasOralScanner;
  final bool? hasCT;
  final bool? has3DPrinter;

  /// 기타 디지털 장비 자유 입력 텍스트
  final String? digitalEquipmentRaw;

  // ── 근무 조건 (3.2) ─────────────────────────────
  /// 영문 코드 리스트: mon, tue, wed, thu, fri, sat, sun
  final List<String> workDays;
  final bool weekendWork;
  final bool nightShift;

  // ── 지원 관련 (3.3) ─────────────────────────────
  /// online | phone | email (복수 선택)
  final List<String> applyMethod;
  final bool isAlwaysHiring;

  /// 제출 서류 목록
  final List<String> requiredDocuments;

  // ── 담당 업무 (3.3-2) ───────────────────────────
  final List<String> mainDutiesList;

  // ── 교통편 (3.4) ────────────────────────────────
  final TransportationInfo? transportation;

  /// 필터용 최상위 배열 (transportation.subwayLines와 동일값)
  final List<String> subwayLines;
  final bool hasParking;

  // ── 태그 (3.5) ──────────────────────────────────
  final List<String> tags;

  // ── 홍보 이미지 (3.6) ───────────────────────────
  final List<String> promotionalImageUrls;

  // ── 광고·노출 구조 (3.7) ────────────────────────
  final DateTime? adStartAt;
  final DateTime? adEndAt;
  final int priorityScore;

  Job({
    required this.id,
    required this.title,
    required this.clinicName,
    required this.address,
    this.district = '',
    required this.lat,
    required this.lng,
    required this.type,
    required this.career,
    required this.salaryRange,
    this.salaryText = '',
    this.employmentType = '',
    this.workHours = '',
    this.contact = '',
    this.status,
    required this.postedAt,
    required this.details,
    required this.benefits,
    required this.images,
    this.jobLevel = 3,
    this.matchScore = 0,
    this.isNearStation = false,
    this.closingDate,
    this.canApplyNow = false,
    // 기본 정보 추가
    this.education = '',
    this.hireRoles = const [],
    // 병원 정보
    this.hospitalType,
    this.chairCount,
    this.staffCount,
    this.specialties = const [],
    this.hasOralScanner,
    this.hasCT,
    this.has3DPrinter,
    this.digitalEquipmentRaw,
    // 근무 조건
    this.workDays = const [],
    this.weekendWork = false,
    this.nightShift = false,
    // 지원 관련
    this.applyMethod = const [],
    this.isAlwaysHiring = false,
    this.requiredDocuments = const [],
    // 담당 업무
    this.mainDutiesList = const [],
    // 교통편
    this.transportation,
    this.subwayLines = const [],
    this.hasParking = false,
    // 태그
    this.tags = const [],
    // 홍보 이미지
    this.promotionalImageUrls = const [],
    // 광고
    this.adStartAt,
    this.adEndAt,
    this.priorityScore = 0,
  });

  /// 앱 목록·지도에 노출할지 (마감/삭제/반려 제외)
  bool get isListedInApp {
    final s = (status ?? '').trim().toLowerCase();
    if (s.isEmpty) return true;
    const hidden = {'closed', 'deleted', 'rejected', 'draft'};
    return !hidden.contains(s);
  }

  /// 카드·상세·배지 공통 급여 문구
  String get salaryDisplayLine {
    final t = salaryText.trim();
    if (t.isNotEmpty) return t;
    final lo = salaryRange.isNotEmpty ? salaryRange[0] : 0;
    final hi = salaryRange.length > 1 ? salaryRange[1] : lo;
    if (lo <= 0 && hi <= 0) return '협의';
    if (lo == hi) return '$lo만원';
    return '$lo~$hi만원';
  }

  /// 앱 노출용 공고 제목 — `(샘플)` 접두사 (중복 방지)
  static const String kSamplePrefix = '(샘플)';

  String get displayTitle {
    final t = title.trim();
    if (t.isEmpty) return kSamplePrefix;
    if (t.startsWith(kSamplePrefix)) return title;
    return '$kSamplePrefix$t';
  }

  /// 카드 1행 등 병원명 표시용
  String get displayClinicName {
    final n = clinicName.trim();
    if (n.isEmpty) return kSamplePrefix;
    if (n.startsWith(kSamplePrefix)) return clinicName;
    return '$kSamplePrefix$n';
  }

  /// 목록 2행: 직무 · 고용 · 경력 (빈 값·`미정`은 생략)
  String get listRoleLine {
    final parts = <String>[];
    if (type.trim().isNotEmpty) parts.add(type.trim());
    if (employmentType.trim().isNotEmpty) parts.add(employmentType.trim());
    final c = career.trim();
    if (c.isNotEmpty && c != '미정') parts.add(c);
    return parts.join(' · ');
  }

  factory Job.fromDoc(DocumentSnapshot doc) {
    final json = doc.data() as Map<String, dynamic>;
    return Job.fromJson(json, docId: doc.id);
  }

  factory Job.fromJson(Map<String, dynamic> json, {String? docId}) {
    final loc = json['location'];

    DateTime? parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) {
        try {
          return DateTime.parse(v);
        } catch (_) {}
      }
      return null;
    }

    final postedAt = parseTs(json['postedAt']);
    final createdAt = parseTs(json['createdAt']);
    final DateTime posted = postedAt ?? createdAt ?? DateTime.now();

    DateTime? closing;
    final cl = json['closingDate'];
    if (cl is Timestamp) {
      closing = cl.toDate();
    } else if (cl is String) {
      try {
        closing = DateTime.parse(cl);
      } catch (_) {}
    }

    double lat = 0;
    double lng = 0;
    String address = '';

    if (loc is GeoPoint) {
      lat = loc.latitude;
      lng = loc.longitude;
      address = (json['address'] as String?)?.trim() ?? '';
    } else if (loc is Map) {
      lat = (loc['lat'] ?? 0).toDouble();
      lng = (loc['lng'] ?? 0).toDouble();
      address = (loc['address'] as String?)?.trim() ?? '';
    } else {
      address = (json['address'] as String?)?.trim() ?? '';
    }

    final salaryRaw =
        (json['salaryText'] ?? json['salary'] ?? '').toString().trim();
    var range = _parseSalaryRange(json['salaryRange']);
    final smin = json['salaryMin'];
    final smax = json['salaryMax'];
    if (range[0] == 0 && range[1] == 0 && smin is num && smax is num) {
      range = [smin.toInt(), smax.toInt()];
    }
    if (range[0] == 0 && range[1] == 0 && salaryRaw.isNotEmpty) {
      range = _inferSalaryRangeFromText(salaryRaw);
    }

    final typeFromJson = (json['type'] as String?)?.trim() ?? '';
    final role = (json['role'] as String?)?.trim() ?? '';
    final resolvedType = typeFromJson.isNotEmpty ? typeFromJson : role;

    final careerRaw = (json['career'] as String?)?.trim() ?? '';
    final resolvedCareer = careerRaw.isNotEmpty ? careerRaw : '미정';

    final detailsRaw = (json['details'] as String?)?.trim() ?? '';
    final description = (json['description'] as String?)?.trim() ?? '';
    final resolvedDetails = detailsRaw.isNotEmpty ? detailsRaw : description;

    final emp = (json['employmentType'] as String?)?.trim() ?? '';

    // ── 교통편 ──
    final transRaw = json['transportation'];
    final TransportationInfo? trans =
        transRaw is Map<String, dynamic>
            ? TransportationInfo.fromJson(transRaw)
            : null;

    // isNearStation: 명시 값 우선, 없으면 transportation 기반 자동 판정
    final bool nearStation =
        (json['isNearStation'] as bool?) ?? (trans?.isNearStation ?? false);

    final resolvedSubwayLines = List<String>.from(
      json['subwayLines'] ??
          (trans != null
              ? trans.selectedStations
                  .expand((s) => s.lines)
                  .where((line) => line.trim().isNotEmpty)
                  .toSet()
                  .toList()
              : const []),
    );

    return Job(
      id: docId ?? (json['id'] as String? ?? ''),
      title: (json['title'] as String?)?.trim() ?? '',
      clinicName: (json['clinicName'] as String?)?.trim() ?? '',
      address: address,
      district: (json['district'] as String?)?.trim() ?? '',
      lat: lat,
      lng: lng,
      type: resolvedType,
      career: resolvedCareer,
      salaryRange: range,
      salaryText: salaryRaw,
      employmentType: emp,
      workHours: (json['workHours'] as String?)?.trim() ?? '',
      contact: (json['contact'] as String?)?.trim() ?? '',
      status: json['status'] as String?,
      postedAt: posted,
      details: resolvedDetails,
      benefits: List<String>.from(json['benefits'] ?? []),
      images: List<String>.from(json['images'] ?? []),
      jobLevel: _resolveJobLevel(json),
      matchScore: (json['matchScore'] as int?) ?? 0,
      isNearStation: nearStation,
      closingDate: closing,
      canApplyNow: (json['canApplyNow'] as bool?) ?? false,
      // 기본 정보 추가
      education: (json['education'] as String?)?.trim() ?? '',
      hireRoles: List<String>.from(json['hireRoles'] ?? []),
      // 병원 정보
      hospitalType: json['hospitalType'] as String?,
      chairCount: (json['chairCount'] as num?)?.toInt(),
      staffCount: (json['staffCount'] as num?)?.toInt(),
      specialties: List<String>.from(json['specialties'] ?? []),
      hasOralScanner: json['hasOralScanner'] as bool?,
      hasCT: json['hasCT'] as bool?,
      has3DPrinter: json['has3DPrinter'] as bool?,
      digitalEquipmentRaw: (json['digitalEquipmentRaw'] as String?)?.trim(),
      // 근무 조건
      workDays: List<String>.from(json['workDays'] ?? []),
      weekendWork: (json['weekendWork'] as bool?) ?? false,
      nightShift: (json['nightShift'] as bool?) ?? false,
      // 지원 관련
      applyMethod: List<String>.from(json['applyMethod'] ?? []),
      isAlwaysHiring: (json['isAlwaysHiring'] as bool?) ?? false,
      requiredDocuments: List<String>.from(json['requiredDocuments'] ?? []),
      // 담당 업무
      mainDutiesList: List<String>.from(json['mainDutiesList'] ?? []),
      // 교통편
      transportation: trans,
      subwayLines: resolvedSubwayLines,
      hasParking: (json['hasParking'] as bool?) ?? (trans?.parking ?? false),
      // 태그
      tags: List<String>.from(json['tags'] ?? []),
      // 홍보 이미지
      promotionalImageUrls: List<String>.from(
        json['promotionalImageUrls'] ?? [],
      ),
      // 광고
      adStartAt: parseTs(json['adStartAt']),
      adEndAt: parseTs(json['adEndAt']),
      priorityScore: (json['priorityScore'] as num?)?.toInt() ?? 0,
    );
  }

  static List<int> _parseSalaryRange(dynamic raw) {
    if (raw is List && raw.length >= 2) {
      return [
        (raw[0] is num) ? (raw[0] as num).toInt() : 0,
        (raw[1] is num) ? (raw[1] as num).toInt() : 0,
      ];
    }
    return [0, 0];
  }

  static int _resolveJobLevel(Map<String, dynamic> json) {
    final explicit = (json['jobLevel'] as num?)?.toInt();
    if (explicit == 1 || explicit == 2 || explicit == 3) return explicit!;

    final tier =
        (json['productTier'] ?? json['tier'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    switch (tier) {
      case 'premium':
      case 'a':
      case 'a_class':
        return 1;
      case 'standard':
      case 'b':
      case 'b_class':
        return 2;
      case 'basic':
      case 'c':
      case 'c_class':
        return 3;
      default:
        return 3;
    }
  }

  /// 급여 문자열에서 만원 단위 숫자 범위 추정 (예: "250~300만", "월 280")
  static List<int> _inferSalaryRangeFromText(String raw) {
    final s = raw.replaceAll(RegExp(r'\s'), '');
    if (s.isEmpty) return [0, 0];
    final tilde = RegExp(r'(\d{2,4})[~～\-](\d{2,4})');
    final m = tilde.firstMatch(s);
    if (m != null) {
      return [int.parse(m.group(1)!), int.parse(m.group(2)!)];
    }
    final nums =
        RegExp(
          r'\d{2,4}',
        ).allMatches(s).map((x) => int.parse(x.group(0)!)).toList();
    if (nums.length >= 2) return [nums[0], nums[1]];
    if (nums.length == 1) return [nums[0], nums[0]];
    return [0, 0];
  }

  /// 병원 유형 enum → 한글 표시
  static const hospitalTypeLabels = {
    'clinic': '개인의원',
    'network': '네트워크',
    'hospital': '치과병원',
    'general': '종합병원/대학병원',
  };

  String get hospitalTypeLabel =>
      hospitalTypeLabels[hospitalType] ?? hospitalType ?? '';

  /// 근무 요일 영문 코드 → 한글 약자
  static const workDayLabels = {
    'mon': '월',
    'tue': '화',
    'wed': '수',
    'thu': '목',
    'fri': '금',
    'sat': '토',
    'sun': '일',
  };

  /// 근무요일 한글 요약 (예: "월~금")
  String get workDaysSummary {
    if (workDays.isEmpty) return '';
    const weekdayOrder = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    final sorted = List<String>.from(workDays)..sort(
      (a, b) => weekdayOrder.indexOf(a).compareTo(weekdayOrder.indexOf(b)),
    );
    final labels = sorted.map((d) => workDayLabels[d] ?? d).toList();

    if (_isConsecutiveRange(sorted, weekdayOrder)) {
      return '${labels.first}~${labels.last}';
    }
    return labels.join('·');
  }

  static bool _isConsecutiveRange(List<String> days, List<String> order) {
    if (days.length < 2) return false;
    final indices = days.map((d) => order.indexOf(d)).toList();
    for (int i = 1; i < indices.length; i++) {
      if (indices[i] != indices[i - 1] + 1) return false;
    }
    return true;
  }

  /// 지원 방법 한글 표시
  static const applyMethodLabels = {
    'online': '앱 간편지원',
    'phone': '전화 지원',
    'email': '이메일 지원',
  };

  Map<String, dynamic> toJson() => {
    'title': title,
    'clinicName': clinicName,
    'location': {'address': address, 'lat': lat, 'lng': lng},
    'district': district,
    'type': type,
    'career': career,
    'salaryRange': salaryRange,
    'salaryText': salaryText,
    'employmentType': employmentType,
    'workHours': workHours,
    'contact': contact,
    if (status != null) 'status': status,
    'postedAt': Timestamp.fromDate(postedAt),
    'details': details,
    'benefits': benefits,
    'images': images,
    'jobLevel': jobLevel,
    'matchScore': matchScore,
    'isNearStation': isNearStation,
    if (closingDate != null) 'closingDate': Timestamp.fromDate(closingDate!),
    'canApplyNow': canApplyNow,
    // 기본 정보 추가
    if (education.isNotEmpty) 'education': education,
    if (hireRoles.isNotEmpty) 'hireRoles': hireRoles,
    // 병원 정보
    if (hospitalType != null) 'hospitalType': hospitalType,
    if (chairCount != null) 'chairCount': chairCount,
    if (staffCount != null) 'staffCount': staffCount,
    if (specialties.isNotEmpty) 'specialties': specialties,
    if (hasOralScanner != null) 'hasOralScanner': hasOralScanner,
    if (hasCT != null) 'hasCT': hasCT,
    if (has3DPrinter != null) 'has3DPrinter': has3DPrinter,
    if (digitalEquipmentRaw != null && digitalEquipmentRaw!.isNotEmpty)
      'digitalEquipmentRaw': digitalEquipmentRaw,
    // 근무 조건
    if (workDays.isNotEmpty) 'workDays': workDays,
    'weekendWork': weekendWork,
    'nightShift': nightShift,
    // 지원 관련
    if (applyMethod.isNotEmpty) 'applyMethod': applyMethod,
    'isAlwaysHiring': isAlwaysHiring,
    if (requiredDocuments.isNotEmpty) 'requiredDocuments': requiredDocuments,
    // 담당 업무
    if (mainDutiesList.isNotEmpty) 'mainDutiesList': mainDutiesList,
    // 교통편
    if (transportation != null) 'transportation': transportation!.toJson(),
    if (subwayLines.isNotEmpty) 'subwayLines': subwayLines,
    'hasParking': hasParking,
    // 태그
    if (tags.isNotEmpty) 'tags': tags,
    // 홍보 이미지
    if (promotionalImageUrls.isNotEmpty)
      'promotionalImageUrls': promotionalImageUrls,
    // 광고
    if (adStartAt != null) 'adStartAt': Timestamp.fromDate(adStartAt!),
    if (adEndAt != null) 'adEndAt': Timestamp.fromDate(adEndAt!),
    if (priorityScore != 0) 'priorityScore': priorityScore,
  };
}
