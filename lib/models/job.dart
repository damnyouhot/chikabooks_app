import 'package:cloud_firestore/cloud_firestore.dart';

class Job {
  final String id;
  final String title;
  final String clinicName;
  final String address;
  final String district;   // 동/구 짧은 표시용 (예: "역삼동 · 강남구")
  final double lat;
  final double lng;
  final String type;
  final String career;
  final List<int> salaryRange;
  final DateTime postedAt;
  final String details;
  final List<String> benefits;
  final List<String> images;

  // ── 레벨/매칭 필드 ──────────────────────────────
  final int jobLevel;       // 1=프리미엄, 2=추천, 3=일반
  final int matchScore;     // 커리어 매칭 점수 0~100
  final bool isNearStation; // 역세권 여부
  final DateTime? closingDate; // 마감일 (null=상시)
  final bool canApplyNow;   // 즉시지원 가능 여부

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
    required this.postedAt,
    required this.details,
    required this.benefits,
    required this.images,
    this.jobLevel = 3,
    this.matchScore = 0,
    this.isNearStation = false,
    this.closingDate,
    this.canApplyNow = false,
  });

  factory Job.fromDoc(DocumentSnapshot doc) {
    // ◀◀◀ 타입 수정
    final json = doc.data() as Map<String, dynamic>;
    return Job.fromJson(json, docId: doc.id);
  }

  factory Job.fromJson(Map<String, dynamic> json, {String? docId}) {
    final loc = json['location'];

    // postedAt 파싱
    DateTime posted;
    final pa = json['postedAt'];
    if (pa is Timestamp) {
      posted = pa.toDate();
    } else if (pa is String) {
      posted = DateTime.parse(pa);
    } else {
      posted = DateTime.now();
    }

    // closingDate 파싱
    DateTime? closing;
    final cl = json['closingDate'];
    if (cl is Timestamp) {
      closing = cl.toDate();
    } else if (cl is String) {
      try {
        closing = DateTime.parse(cl);
      } catch (_) {}
    }

    // location이 GeoPoint 또는 Map일 수 있음
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
      district: json['district'] ?? '',
      lat: lat,
      lng: lng,
      type: json['type'] ?? '',
      career: json['career'] ?? '미정',
      salaryRange: _parseSalaryRange(json['salaryRange']),
      postedAt: posted,
      details: json['details'] ?? '',
      benefits: List<String>.from(json['benefits'] ?? []),
      images: List<String>.from(json['images'] ?? []),
      jobLevel: (json['jobLevel'] as int?) ?? 3,
      matchScore: (json['matchScore'] as int?) ?? 0,
      isNearStation: (json['isNearStation'] as bool?) ?? false,
      closingDate: closing,
      canApplyNow: (json['canApplyNow'] as bool?) ?? false,
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

  Map<String, dynamic> toJson() => {
        'title': title,
        'clinicName': clinicName,
        'location': {
          'address': address,
          'lat': lat,
          'lng': lng,
        },
        'district': district,
        'type': type,
        'career': career,
        'salaryRange': salaryRange,
        'postedAt': Timestamp.fromDate(postedAt),
        'details': details,
        'benefits': benefits,
        'images': images,
        'jobLevel': jobLevel,
        'matchScore': matchScore,
        'isNearStation': isNearStation,
        if (closingDate != null) 'closingDate': Timestamp.fromDate(closingDate!),
        'canApplyNow': canApplyNow,
      };
}
