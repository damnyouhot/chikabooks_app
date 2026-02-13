import 'package:cloud_firestore/cloud_firestore.dart';

/// 파트너 그룹 멤버 상태
enum PartnerMemberStatus {
  /// 현재 활동 중
  active,
  
  /// 초대 대기 중
  invited,
  
  /// 자진 탈퇴
  left,
  
  /// 강제 퇴출
  removed,
}

/// 파트너 그룹 멤버 정보
class PartnerMember {
  final String uid;
  final PartnerMemberStatus status;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final String? leftReason;

  const PartnerMember({
    required this.uid,
    required this.status,
    required this.joinedAt,
    this.leftAt,
    this.leftReason,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'status': status.name,
      'joinedAt': Timestamp.fromDate(joinedAt),
      if (leftAt != null) 'leftAt': Timestamp.fromDate(leftAt!),
      if (leftReason != null) 'leftReason': leftReason,
    };
  }

  factory PartnerMember.fromMap(Map<String, dynamic> map) {
    return PartnerMember(
      uid: map['uid'] as String,
      status: PartnerMemberStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => PartnerMemberStatus.active,
      ),
      joinedAt: (map['joinedAt'] as Timestamp).toDate(),
      leftAt: map['leftAt'] != null 
          ? (map['leftAt'] as Timestamp).toDate() 
          : null,
      leftReason: map['leftReason'] as String?,
    );
  }
}

/// 파트너 그룹 (최대 3명)
class PartnerGroup {
  final String id;
  final String ownerId;
  final String title; // 예: "결 40"
  final List<PartnerMember> members;
  final DateTime createdAt;
  final int maxMembers;
  final int minMembers;

  const PartnerGroup({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.members,
    required this.createdAt,
    this.maxMembers = 3,
    this.minMembers = 1,
  });

  /// 현재 활동 중인 멤버 uid 목록
  List<String> get activeMemberUids {
    return members
        .where((m) => m.status == PartnerMemberStatus.active)
        .map((m) => m.uid)
        .toList();
  }

  /// 초대 대기 중인 멤버 uid 목록
  List<String> get invitedMemberUids {
    return members
        .where((m) => m.status == PartnerMemberStatus.invited)
        .map((m) => m.uid)
        .toList();
  }

  /// 탈퇴한 멤버 목록
  List<PartnerMember> get leftMembers {
    return members
        .where((m) => 
            m.status == PartnerMemberStatus.left || 
            m.status == PartnerMemberStatus.removed)
        .toList();
  }

  /// 빈 슬롯 수
  int get availableSlots {
    return maxMembers - activeMemberUids.length;
  }

  /// 그룹이 활성 상태인지 (최소 인원 충족)
  bool get isActive {
    return activeMemberUids.length >= minMembers;
  }

  /// 멤버 추가 가능 여부
  bool get canAddMember {
    return availableSlots > 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'title': title,
      'members': members.map((m) => m.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'maxMembers': maxMembers,
      'minMembers': minMembers,
      // 빠른 쿼리를 위한 중복 필드
      'activeMemberUids': activeMemberUids,
      'invitedMemberUids': invitedMemberUids,
    };
  }

  factory PartnerGroup.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return PartnerGroup(
      id: doc.id,
      ownerId: data['ownerId'] as String,
      title: data['title'] as String? ?? '결',
      members: (data['members'] as List<dynamic>?)
              ?.map((m) => PartnerMember.fromMap(m as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      maxMembers: data['maxMembers'] as int? ?? 3,
      minMembers: data['minMembers'] as int? ?? 1,
    );
  }

  /// 새 그룹 생성 (소유자만 포함)
  factory PartnerGroup.create({
    required String ownerId,
    required String title,
  }) {
    return PartnerGroup(
      id: '',
      ownerId: ownerId,
      title: title,
      members: [
        PartnerMember(
          uid: ownerId,
          status: PartnerMemberStatus.active,
          joinedAt: DateTime.now(),
        ),
      ],
      createdAt: DateTime.now(),
    );
  }
}
