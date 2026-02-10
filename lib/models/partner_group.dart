import 'package:cloud_firestore/cloud_firestore.dart';

/// 파트너 그룹 (3명 고정, 1주 기간)
class PartnerGroup {
  final String id;
  final DateTime createdAt;
  final DateTime startedAt;
  final DateTime endsAt;
  final String status; // "active" | "ended"
  final List<String> memberUids;
  final MatchingMeta? matchingMeta;
  final Map<String, bool?> extensionVotes; // uid → 연장 동의 여부

  const PartnerGroup({
    required this.id,
    required this.createdAt,
    required this.startedAt,
    required this.endsAt,
    this.status = 'active',
    required this.memberUids,
    this.matchingMeta,
    this.extensionVotes = const {},
  });

  bool get isActive =>
      status == 'active' && endsAt.isAfter(DateTime.now());

  /// D-day 남은 일수
  int get daysLeft {
    final diff = endsAt.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  factory PartnerGroup.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return PartnerGroup(
      id: doc.id,
      createdAt: _toDateTime(d['createdAt']),
      startedAt: _toDateTime(d['startedAt']),
      endsAt: _toDateTime(d['endsAt']),
      status: d['status'] ?? 'active',
      memberUids: List<String>.from(d['memberUids'] ?? []),
      matchingMeta: d['matchingMeta'] != null
          ? MatchingMeta.fromMap(d['matchingMeta'])
          : null,
      extensionVotes: Map<String, bool?>.from(d['extensionVotes'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() => {
        'createdAt': Timestamp.fromDate(createdAt),
        'startedAt': Timestamp.fromDate(startedAt),
        'endsAt': Timestamp.fromDate(endsAt),
        'status': status,
        'memberUids': memberUids,
        'matchingMeta': matchingMeta?.toMap(),
        'extensionVotes': extensionVotes,
      };

  static DateTime _toDateTime(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.now();
  }
}

/// 매칭 시 사용한 메타 정보
class MatchingMeta {
  final String? mainConcern;
  final String? regionMix;
  final String? careerMix;

  const MatchingMeta({this.mainConcern, this.regionMix, this.careerMix});

  factory MatchingMeta.fromMap(Map<String, dynamic> m) => MatchingMeta(
        mainConcern: m['mainConcern'],
        regionMix: m['regionMix'],
        careerMix: m['careerMix'],
      );

  Map<String, dynamic> toMap() => {
        'mainConcern': mainConcern,
        'regionMix': regionMix,
        'careerMix': careerMix,
      };
}

/// 그룹 내 멤버 메타 (partnerGroups/{groupId}/memberMeta/{uid})
/// 닉네임/사진/병원 정보 저장 금지
class GroupMemberMeta {
  final String uid;
  final String region;
  final String careerBucket;
  final String? mainConcernShown; // 대표 고민 1개만 표시
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

  /// 표시용 라벨 ("3~5년차 · 경기 · (업무량)")
  String get displayLabel {
    final parts = <String>[];
    if (careerBucket.isNotEmpty) {
      parts.add('${careerBucket.replaceAll('-', '~')}년차');
    }
    if (region.isNotEmpty) parts.add(region);
    if (mainConcernShown != null && mainConcernShown!.isNotEmpty) {
      parts.add('($mainConcernShown)');
    }
    return parts.isEmpty ? '익명' : parts.join(' · ');
  }

  factory GroupMemberMeta.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return GroupMemberMeta(
      uid: doc.id,
      region: d['region'] ?? '',
      careerBucket: d['careerBucket'] ?? '',
      mainConcernShown: d['mainConcernShown'],
      workplaceType: d['workplaceType'],
      joinedAt: _ts(d['joinedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'region': region,
        'careerBucket': careerBucket,
        'mainConcernShown': mainConcernShown,
        'workplaceType': workplaceType,
        'joinedAt': Timestamp.fromDate(joinedAt),
      };

  static DateTime _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.now();
  }
}

