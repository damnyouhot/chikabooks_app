import 'package:cloud_firestore/cloud_firestore.dart';

/// 추대(Enthrone) 상태
enum EnthroneStatus {
  /// 2/3 추대 달성 (후보)
  candidate,
  
  /// 3/3 추대 달성 (확정)
  confirmed,
  
  /// 24시간 만료
  expired,
  
  /// 신고로 제거
  removed,
}

/// 추대 (3인 추천)
class Enthrone {
  final String uid;
  final DateTime createdAt;

  const Enthrone({
    required this.uid,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Enthrone.fromMap(Map<String, dynamic> map) {
    return Enthrone(
      uid: map['uid'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}

/// 전광판 게시물
class BillboardPost {
  final String id;
  final String sourceBondId;
  final String sourcePostId;
  final String textSnapshot;
  final int enthroneCount;
  final int requiredCount;
  final DateTime createdAt;
  final DateTime expiresAt;
  final EnthroneStatus status;
  final String bondGroupName;
  final bool isAnonymous;

  const BillboardPost({
    required this.id,
    required this.sourceBondId,
    required this.sourcePostId,
    required this.textSnapshot,
    required this.enthroneCount,
    required this.requiredCount,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    required this.bondGroupName,
    this.isAnonymous = true,
  });

  /// 만료 여부
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// 활성 상태 여부
  bool get isActive => 
      status == EnthroneStatus.confirmed && 
      !isExpired;

  Map<String, dynamic> toMap() {
    return {
      'sourceBondId': sourceBondId,
      'sourcePostId': sourcePostId,
      'textSnapshot': textSnapshot,
      'enthroneCount': enthroneCount,
      'requiredCount': requiredCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'status': status.name,
      'bondGroupName': bondGroupName,
      'isAnonymous': isAnonymous,
    };
  }

  factory BillboardPost.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return BillboardPost(
      id: doc.id,
      sourceBondId: data['sourceBondId'] as String,
      sourcePostId: data['sourcePostId'] as String,
      textSnapshot: data['textSnapshot'] as String,
      enthroneCount: data['enthroneCount'] as int,
      requiredCount: data['requiredCount'] as int,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      status: EnthroneStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => EnthroneStatus.candidate,
      ),
      bondGroupName: data['bondGroupName'] as String? ?? '결',
      isAnonymous: data['isAnonymous'] as bool? ?? true,
    );
  }

  /// 새 전광판 게시물 생성
  factory BillboardPost.create({
    required String sourceBondId,
    required String sourcePostId,
    required String textSnapshot,
    required int enthroneCount,
    required int requiredCount,
    required String bondGroupName,
    bool isAnonymous = true,
  }) {
    final now = DateTime.now();
    return BillboardPost(
      id: '',
      sourceBondId: sourceBondId,
      sourcePostId: sourcePostId,
      textSnapshot: textSnapshot,
      enthroneCount: enthroneCount,
      requiredCount: requiredCount,
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 48)), // 48시간 유지
      status: EnthroneStatus.confirmed,
      bondGroupName: bondGroupName,
      isAnonymous: isAnonymous,
    );
  }
}

