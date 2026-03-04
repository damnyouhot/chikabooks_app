import 'package:cloud_firestore/cloud_firestore.dart';

/// 치과(병원) 엔티티
/// Firestore 경로: `clinics/{clinicId}`
class Clinic {
  final String id;
  final String name;
  final String bizNo;
  final String address;
  final List<String> ownerUids; // 소유자(관리자) uid 목록
  final List<String> memberUids; // 멤버 uid 목록 (최대 3명)
  final DateTime? createdAt;
  final DateTime? verifiedAt;

  const Clinic({
    required this.id,
    required this.name,
    this.bizNo = '',
    this.address = '',
    this.ownerUids = const [],
    this.memberUids = const [],
    this.createdAt,
    this.verifiedAt,
  });

  factory Clinic.fromMap(Map<String, dynamic> data, {required String id}) {
    return Clinic(
      id: id,
      name: data['name'] as String? ?? '',
      bizNo: data['bizNo'] as String? ?? '',
      address: data['address'] as String? ?? '',
      ownerUids: List<String>.from(data['ownerUids'] ?? []),
      memberUids: List<String>.from(data['memberUids'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      verifiedAt: (data['verifiedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory Clinic.fromDoc(DocumentSnapshot doc) {
    return Clinic.fromMap(doc.data() as Map<String, dynamic>, id: doc.id);
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'bizNo': bizNo,
        'address': address,
        'ownerUids': ownerUids,
        'memberUids': memberUids,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        if (verifiedAt != null) 'verifiedAt': Timestamp.fromDate(verifiedAt!),
      };
}

