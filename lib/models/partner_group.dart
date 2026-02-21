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
  
  // ─── v1 설계 추가 필드 ───
  final DateTime startedAt;      // 그룹 시작 시각
  final DateTime endsAt;         // 그룹 종료 시각 (7일 후)
  final List<String> memberUids; // 빠른 조회용 UID 리스트
  final bool isActiveGroup;      // 활성 상태 (필드로 저장)
  final int weekNumber;          // 몇 주차 그룹인지 (연속 추적용)
  final Map<String, String>? continueSelections; // 이어가기 선택 {uidA: uidB}
  final List<String>? previousMemberUids;         // 이전 주 멤버 (이어가기 추적용)

  const PartnerGroup({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.members,
    required this.createdAt,
    this.maxMembers = 3,
    this.minMembers = 1,
    required this.startedAt,
    required this.endsAt,
    required this.memberUids,
    this.isActiveGroup = true,
    this.weekNumber = 1,
    this.continueSelections,
    this.previousMemberUids,
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
      // v1 설계 필드
      'startedAt': Timestamp.fromDate(startedAt),
      'endsAt': Timestamp.fromDate(endsAt),
      'memberUids': memberUids,
      'isActive': isActiveGroup,
      'weekNumber': weekNumber,
      if (continueSelections != null) 'continueSelections': continueSelections,
      if (previousMemberUids != null) 'previousMemberUids': previousMemberUids,
      // 빠른 쿼리를 위한 중복 필드
      'activeMemberUids': activeMemberUids,
      'invitedMemberUids': invitedMemberUids,
    };
  }

  factory PartnerGroup.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    
    // 타임스탬프 파싱
    final createdAt = (data['createdAt'] as Timestamp).toDate();
    final startedAt = data['startedAt'] != null
        ? (data['startedAt'] as Timestamp).toDate()
        : createdAt;
    final endsAt = data['endsAt'] != null
        ? (data['endsAt'] as Timestamp).toDate()
        : startedAt.add(Duration(days: 7));
    
    return PartnerGroup(
      id: doc.id,
      ownerId: data['ownerId'] as String,
      title: data['title'] as String? ?? '결',
      members: (data['members'] as List<dynamic>?)
              ?.map((m) => PartnerMember.fromMap(m as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: createdAt,
      maxMembers: data['maxMembers'] as int? ?? 3,
      minMembers: data['minMembers'] as int? ?? 1,
      startedAt: startedAt,
      endsAt: endsAt,
      memberUids: List<String>.from(data['memberUids'] ?? data['activeMemberUids'] ?? []),
      isActiveGroup: data['isActive'] as bool? ?? true,
      weekNumber: data['weekNumber'] as int? ?? 1,
      continueSelections: data['continueSelections'] != null
          ? Map<String, String>.from(data['continueSelections'])
          : null,
      previousMemberUids: data['previousMemberUids'] != null
          ? List<String>.from(data['previousMemberUids'])
          : null,
    );
  }

  /// 새 그룹 생성 (소유자만 포함)
  factory PartnerGroup.create({
    required String ownerId,
    required String title,
  }) {
    final now = DateTime.now();
    return PartnerGroup(
      id: '',
      ownerId: ownerId,
      title: title,
      members: [
        PartnerMember(
          uid: ownerId,
          status: PartnerMemberStatus.active,
          joinedAt: now,
        ),
      ],
      createdAt: now,
      startedAt: now,
      endsAt: now.add(Duration(days: 7)),
      memberUids: [ownerId],
      isActiveGroup: true,
      weekNumber: 1,
    );
  }
}

/// 그룹 멤버 메타 정보 (memberMeta 서브컬렉션용)
class GroupMemberMeta {
  final String uid;
  final String region;
  final String careerBucket;
  final String? mainConcernShown;
  final String? workplaceType;
  final DateTime joinedAt;

  const GroupMemberMeta({
    required this.uid,
    required this.region,
    required this.careerBucket,
    this.mainConcernShown,
    this.workplaceType,
    required this.joinedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'region': region,
      'careerBucket': careerBucket,
      'mainConcernShown': mainConcernShown,
      'workplaceType': workplaceType,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }

  factory GroupMemberMeta.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return GroupMemberMeta(
      uid: data['uid'] as String,
      region: data['region'] as String? ?? '',
      careerBucket: data['careerBucket'] as String? ?? '',
      mainConcernShown: data['mainConcernShown'] as String?,
      workplaceType: data['workplaceType'] as String?,
      joinedAt: (data['joinedAt'] as Timestamp).toDate(),
    );
  }
}
