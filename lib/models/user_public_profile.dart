import 'package:cloud_firestore/cloud_firestore.dart';

/// 교감 프로필 모델
/// Firestore users/{uid} 에 저장되는 공개 프로필 필드
class UserPublicProfile {
  final String nickname;
  final String region;        // "서울" | "부산" | ... (광역 단위)
  final String careerBucket;  // "0-2" | "3-5" | "6+" (매칭용)
  final String careerGroup;   // "1년차" | "2년차" | ... (표시용)
  final List<String> mainConcerns; // 최대 2개
  final String? workplaceType;     // "개인치과" | "네트워크" | "대학병원" | "기타"

  // ─── 파트너 시스템 필드 ───
  final double bondScore;          // 결 점수 (초기값 50.0, 범위 0~100)
  final int bondScoreVersion;      // 1=구버전(35~85), 2=신버전(0~100)
  final String? partnerGroupId;    // 현재 속한 파트너 그룹 ID
  final DateTime? partnerGroupEndsAt; // 그룹 종료일
  
  // ─── 매칭 설정 필드 (v1 설계) ───
  final String partnerStatus;      // 'active' | 'pause' (기본값: 'active')
  final bool willMatchNextWeek;    // 쉬는 중 매칭 되기 스위치 (기본값: true)
  final String? continueWithPartner; // 이어가기 선택한 상대 UID

  const UserPublicProfile({
    this.nickname = '',
    this.region = '',
    this.careerBucket = '',
    this.careerGroup = '',
    this.mainConcerns = const [],
    this.workplaceType,
    this.bondScore = 50.0,
    this.bondScoreVersion = 2,
    this.partnerGroupId,
    this.partnerGroupEndsAt,
    this.partnerStatus = 'active',
    this.willMatchNextWeek = true,
    this.continueWithPartner,
  });

  /// Step A(기본 프로필) 완료 여부
  bool get hasBasicProfile =>
      nickname.trim().isNotEmpty &&
      region.isNotEmpty &&
      careerBucket.isNotEmpty;

  /// Step B(파트너 프로필) 완료 여부
  bool get hasPartnerProfile =>
      hasBasicProfile && mainConcerns.isNotEmpty;

  /// 현재 파트너 그룹이 활성 상태인지
  bool get hasActiveGroup =>
      partnerGroupId != null &&
      partnerGroupId!.isNotEmpty &&
      partnerGroupEndsAt != null &&
      partnerGroupEndsAt!.isAfter(DateTime.now());

  factory UserPublicProfile.fromMap(Map<String, dynamic> m) {
    DateTime? endsAt;
    final raw = m['partnerGroupEndsAt'];
    if (raw is Timestamp) {
      endsAt = raw.toDate();
    } else if (raw is DateTime) {
      endsAt = raw;
    }

    return UserPublicProfile(
      nickname: m['nickname'] ?? '',
      region: m['region'] ?? '',
      careerBucket: m['careerBucket'] ?? '',
      careerGroup: m['careerGroup'] ?? '', // ✅ 추가
      mainConcerns: List<String>.from(m['mainConcerns'] ?? []),
      workplaceType: m['workplaceType'],
      bondScore: (m['bondScore'] ?? 50.0).toDouble(),
      bondScoreVersion: (m['bondScoreVersion'] ?? 1) as int,
      partnerGroupId: m['partnerGroupId'],
      partnerGroupEndsAt: endsAt,
      partnerStatus: m['partnerStatus'] ?? 'active',
      willMatchNextWeek: m['willMatchNextWeek'] ?? true,
      continueWithPartner: m['continueWithPartner'],
    );
  }

  Map<String, dynamic> toMap() => {
        'nickname': nickname,
        'region': region,
        'careerBucket': careerBucket,
        'mainConcerns': mainConcerns,
        'workplaceType': workplaceType,
      };

  /// 피드 뱃지용 표시 라벨 ("3~5년차 · 경기")
  String get displayLabel {
    final parts = <String>[];
    if (careerBucket.isNotEmpty) {
      parts.add('${careerBucket.replaceAll('-', '~')}년차');
    }
    if (region.isNotEmpty) parts.add(region);
    return parts.isEmpty ? '익명' : parts.join(' · ');
  }

  // ─── 고정 선택지 리스트 ───

  static const List<String> regionList = [
    '서울', '부산', '대구', '인천', '광주', '대전', '울산', '세종',
    '경기', '강원', '충북', '충남', '전북', '전남', '경북', '경남', '제주',
  ];

  static const List<String> careerBuckets = ['0-2', '3-5', '6+'];

  static const Map<String, String> careerBucketLabels = {
    '0-2': '0~2년',
    '3-5': '3~5년',
    '6+': '6년 이상',
  };

  // 온보딩용 세분화된 연차 구간
  static const List<String> careerGroups = [
    '학생',
    '1년차',
    '2년차',
    '3년차',
    '4년차',
    '5년차',
    '6~10년차',
    '11~15년차',
    '15년차 이상',
  ];

  static const List<String> concernOptions = [
    '환자 응대',
    '원장/상사 관계',
    '동료 스트레스',
    '이직/퇴사 고민',
    '공부/시험',
    '돈/연봉',
    '번아웃',
    '인간관계',
    '업무량',
    '출퇴근',
    '보험청구/실무',
    '술기 성장',
    '그냥 막연함',
    '딱히 없음',
    '비밀로 할래요',
  ];

  static const List<String> workplaceTypes = [
    '개인치과', '네트워크', '대학병원', '기타',
  ];
}

