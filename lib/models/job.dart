import 'package:cloud_firestore/cloud_firestore.dart';

class Job {
  final String id;
  final String title;
  final String clinicName;
  final String address;
  final double lat;
  final double lng;
  final String type;
  final String career;
  final List<int> salaryRange;
  final DateTime postedAt;
  final String details;
  final List<String> benefits;
  final List<String> images;

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
  });

  factory Job.fromDoc(DocumentSnapshot doc) {
    // ◀◀◀ 타입 수정
    final json = doc.data() as Map<String, dynamic>;
    return Job.fromJson(json, docId: doc.id);
  }

  factory Job.fromJson(Map<String, dynamic> json, {String? docId}) {
    final loc = json['location'] ?? {};
    DateTime posted;
    final pa = json['postedAt'];
    if (pa is Timestamp) {
      posted = pa.toDate();
    } else if (pa is String) {
      posted = DateTime.parse(pa);
    } else {
      posted = DateTime.now();
    }

    return Job(
      id: docId ?? (json['id'] ?? ''),
      title: json['title'] ?? '',
      clinicName: json['clinicName'] ?? '',
      address: loc['address'] ?? '',
      lat: (loc['lat'] ?? 0).toDouble(),
      lng: (loc['lng'] ?? 0).toDouble(),
      type: json['type'] ?? '',
      career: json['career'] ?? '미정',
      salaryRange: List<int>.from(json['salaryRange'] ?? [0, 0]),
      postedAt: posted,
      details: json['details'] ?? '',
      benefits: List<String>.from(json['benefits'] ?? []),
      images: List<String>.from(json['images'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'clinicName': clinicName,
        'location': {
          'address': address,
          'lat': lat,
          'lng': lng,
        },
        'type': type,
        'career': career,
        'salaryRange': salaryRange,
        'postedAt': Timestamp.fromDate(postedAt),
        'details': details,
        'benefits': benefits,
        'images': images,
      };
}
