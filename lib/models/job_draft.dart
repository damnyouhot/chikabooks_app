import 'package:cloud_firestore/cloud_firestore.dart';

/// 공고 임시저장 엔티티
/// Firestore 경로: `jobDrafts/{draftId}`
class JobDraft {
  final String id;
  final String ownerUid;
  final String clinicName;
  final String title;
  final String role;
  final String employmentType;
  final String workHours;
  final String salary;
  final List<String> benefits;
  final String description;
  final String address;
  final String contact;
  final List<String> imageUrls; // 업로드된 이미지 URL (XFile 아닌 저장용)
  final DateTime? updatedAt;
  final DateTime? createdAt;

  const JobDraft({
    required this.id,
    required this.ownerUid,
    this.clinicName = '',
    this.title = '',
    this.role = '',
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
  });

  factory JobDraft.fromMap(Map<String, dynamic> data, {required String id}) {
    return JobDraft(
      id: id,
      ownerUid: data['ownerUid'] as String? ?? '',
      clinicName: data['clinicName'] as String? ?? '',
      title: data['title'] as String? ?? '',
      role: data['role'] as String? ?? '',
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
        'employmentType': employmentType,
        'workHours': workHours,
        'salary': salary,
        'benefits': benefits,
        'description': description,
        'address': address,
        'contact': contact,
        'imageUrls': imageUrls,
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

