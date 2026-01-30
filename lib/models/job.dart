import 'package:cloud_firestore/cloud_firestore.dart';

/// 직종 enum
enum JobPosition {
  dentist('치과의사'),
  hygienist('치과위생사'),
  assistant('치과조무사'),
  other('기타');

  final String label;
  const JobPosition(this.label);

  static JobPosition fromString(String? value) {
    switch (value) {
      case '치과의사':
        return JobPosition.dentist;
      case '치과위생사':
        return JobPosition.hygienist;
      case '치과조무사':
        return JobPosition.assistant;
      default:
        return JobPosition.other;
    }
  }
}

/// 고용 형태 enum
enum EmploymentType {
  fullTime('정규직'),
  contract('계약직'),
  partTime('파트타임'),
  substitute('대진');

  final String label;
  const EmploymentType(this.label);

  static EmploymentType fromString(String? value) {
    switch (value) {
      case '정규직':
        return EmploymentType.fullTime;
      case '계약직':
        return EmploymentType.contract;
      case '파트타임':
        return EmploymentType.partTime;
      case '대진':
        return EmploymentType.substitute;
      default:
        return EmploymentType.fullTime;
    }
  }
}

class Job {
  final String id;
  final String title;
  final String clinicName;
  final String address;
  final double lat;
  final double lng;
  final String type; // 고용형태 (정규직/계약직 등)
  final String career; // 경력 (신입/경력)
  final List<int> salaryRange;
  final DateTime postedAt;
  final String details;
  final List<String> benefits;
  final List<String> images;

  // 새로 추가된 필드들
  final String jobPosition; // 직종 (치과의사/치과위생사/치과조무사/기타)
  final DateTime? deadline; // 마감일
  final String contactEmail; // 연락처 이메일
  final String contactPhone; // 연락처 전화번호
  final String workHours; // 근무시간 (예: "09:00~18:00")
  final String workDays; // 근무요일 (예: "월~금")
  final String requirements; // 자격요건
  final String preferences; // 우대사항
  final String clinicIntro; // 병원 소개
  final bool isUrgent; // 급구 여부
  final int viewCount; // 조회수

  Job({
    required this.id,
    required this.title,
    required this.clinicName,
    required this.address,
    required this.lat,
    required this.lng,
    required this.type,
    required this.career,
    required this.salaryRange,
    required this.postedAt,
    required this.details,
    required this.benefits,
    required this.images,
    this.jobPosition = '치과위생사',
    this.deadline,
    this.contactEmail = '',
    this.contactPhone = '',
    this.workHours = '',
    this.workDays = '',
    this.requirements = '',
    this.preferences = '',
    this.clinicIntro = '',
    this.isUrgent = false,
    this.viewCount = 0,
  });

  /// 마감일까지 남은 일수 (D-day)
  int? get daysUntilDeadline {
    if (deadline == null) return null;
    return deadline!.difference(DateTime.now()).inDays;
  }

  /// 마감 여부
  bool get isExpired {
    if (deadline == null) return false;
    return DateTime.now().isAfter(deadline!);
  }

  /// D-day 텍스트
  String get deadlineText {
    if (deadline == null) return '상시채용';
    final days = daysUntilDeadline!;
    if (days < 0) return '마감';
    if (days == 0) return 'D-Day';
    return 'D-$days';
  }

  factory Job.fromDoc(DocumentSnapshot doc) {
    final json = doc.data() as Map<String, dynamic>;
    return Job.fromJson(json, docId: doc.id);
  }

  factory Job.fromJson(Map<String, dynamic> json, {String? docId}) {
    final loc = json['location'];
    DateTime posted;
    final pa = json['postedAt'];
    if (pa is Timestamp) {
      posted = pa.toDate();
    } else if (pa is String) {
      posted = DateTime.parse(pa);
    } else {
      posted = DateTime.now();
    }

    // deadline 파싱
    DateTime? deadline;
    final dl = json['deadline'];
    if (dl is Timestamp) {
      deadline = dl.toDate();
    } else if (dl is String && dl.isNotEmpty) {
      deadline = DateTime.tryParse(dl);
    }

    // location이 GeoPoint 타입일 수 있음
    double lat = 0;
    double lng = 0;
    String address = '';

    if (loc is GeoPoint) {
      lat = loc.latitude;
      lng = loc.longitude;
      address = json['address'] ?? '';
    } else if (loc is Map) {
      lat = (loc['lat'] ?? 0).toDouble();
      lng = (loc['lng'] ?? 0).toDouble();
      address = loc['address'] ?? '';
    }

    return Job(
      id: docId ?? (json['id'] ?? ''),
      title: json['title'] ?? '',
      clinicName: json['clinicName'] ?? '',
      address: address,
      lat: lat,
      lng: lng,
      type: json['type'] ?? '정규직',
      career: json['career'] ?? '미정',
      salaryRange: _parseSalaryRange(json['salaryRange']),
      postedAt: posted,
      details: json['details'] ?? '',
      benefits: List<String>.from(json['benefits'] ?? []),
      images: List<String>.from(json['images'] ?? []),
      // 새 필드들
      jobPosition: json['jobPosition'] ?? '치과위생사',
      deadline: deadline,
      contactEmail: json['contactEmail'] ?? '',
      contactPhone: json['contactPhone'] ?? '',
      workHours: json['workHours'] ?? '',
      workDays: json['workDays'] ?? '',
      requirements: json['requirements'] ?? '',
      preferences: json['preferences'] ?? '',
      clinicIntro: json['clinicIntro'] ?? '',
      isUrgent: json['isUrgent'] ?? false,
      viewCount: json['viewCount'] ?? 0,
    );
  }

  /// salaryRange 파싱 - String/int 혼합 처리
  static List<int> _parseSalaryRange(dynamic value) {
    if (value == null) return [0, 0];
    if (value is List) {
      return value
          .map((e) {
            if (e is int) return e;
            if (e is double) return e.toInt();
            if (e is String) return int.tryParse(e) ?? 0;
            return 0;
          })
          .toList()
          .cast<int>();
    }
    return [0, 0];
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'clinicName': clinicName,
    'location': {'address': address, 'lat': lat, 'lng': lng},
    'type': type,
    'career': career,
    'salaryRange': salaryRange,
    'postedAt': Timestamp.fromDate(postedAt),
    'details': details,
    'benefits': benefits,
    'images': images,
    // 새 필드들
    'jobPosition': jobPosition,
    'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
    'contactEmail': contactEmail,
    'contactPhone': contactPhone,
    'workHours': workHours,
    'workDays': workDays,
    'requirements': requirements,
    'preferences': preferences,
    'clinicIntro': clinicIntro,
    'isUrgent': isUrgent,
    'viewCount': viewCount,
  };
}
