import 'package:cloud_firestore/cloud_firestore.dart';

class Job {
  final String id;
  final String title;
  final String clinicName;
  final String career; // '신입' | '경력'
  final String type; // 정규직 등
  final List<int> salaryRange; // [min, max]  단위: 만원
  final String address; // 시/도 포함 주소
  final String details;
  final List<String> benefits;
  final List<String> images;
  final double lat;
  final double lng;

  Job({
    required this.id,
    required this.title,
    required this.clinicName,
    required this.career,
    required this.type,
    required this.salaryRange,
    required this.address,
    required this.details,
    required this.benefits,
    required this.images,
    required this.lat,
    required this.lng,
  });

  /// Firestore JSON → Job
  factory Job.fromJson(String id, Map<String, dynamic> json) => Job(
        id: id,
        title: json['title'] as String,
        clinicName: json['clinicName'] as String,
        career: json['career'] as String,
        type: json['type'] as String,
        salaryRange: (json['salaryRange'] as List)
            .map((e) => (e as num).toInt())
            .toList(),
        address: json['address'] as String,
        details: json['details'] as String? ?? '',
        benefits: (json['benefits'] as List? ?? []).cast<String>(),
        images: (json['images'] as List? ?? []).cast<String>(),
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
      );

  /// 문서 스냅샷 → Job (id 자동 포함)
  factory Job.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
      Job.fromJson(doc.id, doc.data());
}
