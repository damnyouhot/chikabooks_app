import 'package:cloud_firestore/cloud_firestore.dart';

/// 인재풀 엔트리 — 운영자가 한 지원자에게 덧씌우는 메타데이터.
///
/// 저장 위치:
///   `clinics_accounts/{ownerUid}/branches/{branchId}/applicantPool/{applicantUid}`
///
/// 정책 결정사항(2026-04):
///   1. **지점별 분리**: branchId 단위로 풀 관리 (한 지원자가 강남점·분당점에 모두
///      지원했다면 각 지점에 별도 엔트리)
///   2. **수동 등록**: 지원 즉시 자동 적재가 아니라, 운영자가 ⭐ 버튼을 눌러야 풀에
///      들어옴. 이미 자동 적재된 application 데이터는 살아있으므로 언제든 풀에
///      "추가" 가능.
///   3. **재알림 채널**: 1차는 이메일만 (`tags`/`memo`/`status` 자체는 채널과 무관)
///
/// `applicantUid` 는 문서 ID 와 동일 (지점 내에서 unique).
class ApplicantPoolEntry {
  final String applicantUid;
  final String branchId;

  /// UI 캐시용 이름 스냅샷 — 권한 없을 때도 카드 표시 가능하게 보관
  final String displayName;

  /// 첫 번째 지원 시점 (운영자 풀 등록 시점이 아님)
  final DateTime? firstSeenAt;

  /// 마지막 지원 시점
  final DateTime? lastAppliedAt;

  /// 풀에 포함된 application 문서 ID 들 (지점 내)
  final List<String> applicationIds;

  final bool isFavorite;
  final List<String> tags;
  final String memo;

  /// 운영자 분류 — 'new' | 'reviewing' | 'interviewed' | 'hired' | 'rejected' | 'archived'
  final String status;

  /// 마지막 재알림 발송 시점 (스팸 방지 — 24시간 룰)
  final DateTime? lastContactedAt;

  /// 마지막 재알림 발송한 jobId
  final String? lastContactedJobId;

  /// 풀에 추가된 시점
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ApplicantPoolEntry({
    required this.applicantUid,
    required this.branchId,
    this.displayName = '',
    this.firstSeenAt,
    this.lastAppliedAt,
    this.applicationIds = const [],
    this.isFavorite = false,
    this.tags = const [],
    this.memo = '',
    this.status = 'new',
    this.lastContactedAt,
    this.lastContactedJobId,
    this.createdAt,
    this.updatedAt,
  });

  ApplicantPoolEntry copyWith({
    String? displayName,
    DateTime? firstSeenAt,
    DateTime? lastAppliedAt,
    List<String>? applicationIds,
    bool? isFavorite,
    List<String>? tags,
    String? memo,
    String? status,
    DateTime? lastContactedAt,
    String? lastContactedJobId,
  }) =>
      ApplicantPoolEntry(
        applicantUid: applicantUid,
        branchId: branchId,
        displayName: displayName ?? this.displayName,
        firstSeenAt: firstSeenAt ?? this.firstSeenAt,
        lastAppliedAt: lastAppliedAt ?? this.lastAppliedAt,
        applicationIds: applicationIds ?? this.applicationIds,
        isFavorite: isFavorite ?? this.isFavorite,
        tags: tags ?? this.tags,
        memo: memo ?? this.memo,
        status: status ?? this.status,
        lastContactedAt: lastContactedAt ?? this.lastContactedAt,
        lastContactedJobId:
            lastContactedJobId ?? this.lastContactedJobId,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  Map<String, dynamic> toMap() => {
        'applicantUid': applicantUid,
        'branchId': branchId,
        'displayName': displayName,
        if (firstSeenAt != null)
          'firstSeenAt': Timestamp.fromDate(firstSeenAt!),
        if (lastAppliedAt != null)
          'lastAppliedAt': Timestamp.fromDate(lastAppliedAt!),
        'applicationIds': applicationIds,
        'isFavorite': isFavorite,
        'tags': tags,
        'memo': memo,
        'status': status,
        if (lastContactedAt != null)
          'lastContactedAt': Timestamp.fromDate(lastContactedAt!),
        if (lastContactedJobId != null)
          'lastContactedJobId': lastContactedJobId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory ApplicantPoolEntry.fromMap(
      Map<String, dynamic> m, {
        required String applicantUid,
        required String branchId,
      }) {
    return ApplicantPoolEntry(
      applicantUid: applicantUid,
      branchId: branchId,
      displayName: m['displayName'] as String? ?? '',
      firstSeenAt: (m['firstSeenAt'] as Timestamp?)?.toDate(),
      lastAppliedAt: (m['lastAppliedAt'] as Timestamp?)?.toDate(),
      applicationIds:
          (m['applicationIds'] as List?)?.cast<String>() ?? const [],
      isFavorite: m['isFavorite'] as bool? ?? false,
      tags: (m['tags'] as List?)?.cast<String>() ?? const [],
      memo: m['memo'] as String? ?? '',
      status: m['status'] as String? ?? 'new',
      lastContactedAt: (m['lastContactedAt'] as Timestamp?)?.toDate(),
      lastContactedJobId: m['lastContactedJobId'] as String?,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// 상태값 → 표시 라벨 / 컬러힌트
const Map<String, String> kApplicantStatusLabels = {
  'new': '신규',
  'reviewing': '검토 중',
  'interviewed': '면접 완료',
  'hired': '채용',
  'rejected': '불합격',
  'archived': '보관',
};

const List<String> kApplicantStatusOrder = [
  'new',
  'reviewing',
  'interviewed',
  'hired',
  'rejected',
  'archived',
];

/// 풀에 등록되지 않은 "지원 이력만 있는" 지원자도 함께 보여줘야 하므로,
/// UI 에서는 이 결합 ViewModel 로 통일해서 다룬다.
class JoinedApplicant {
  final String applicantUid;
  final String branchId;

  /// 지원자의 모든 지원 이력 (이 지점에서)
  final List<JoinedApplication> applications;

  /// 이름 — 가장 최근 application.answers 또는 resume 의 profile 에서 가져온 캐시
  final String displayName;

  /// resume 요약 — 카드에 표시할 경력연차/지역/스킬 (없을 수도)
  final String? careerYears;
  final String? region;
  final List<String> workTypes;

  /// 풀 엔트리 — null 이면 아직 운영자가 ⭐ 등록 안 함
  final ApplicantPoolEntry? pool;

  const JoinedApplicant({
    required this.applicantUid,
    required this.branchId,
    required this.applications,
    this.displayName = '',
    this.careerYears,
    this.region,
    this.workTypes = const [],
    this.pool,
  });

  bool get isInPool => pool != null;
  bool get isFavorite => pool?.isFavorite ?? false;
  String get status => pool?.status ?? 'new';
  List<String> get tags => pool?.tags ?? const [];
  String get memo => pool?.memo ?? '';

  DateTime? get lastAppliedAt {
    if (applications.isEmpty) return null;
    return applications.first.submittedAt;
  }

  DateTime? get firstSeenAt {
    if (applications.isEmpty) return null;
    return applications.last.submittedAt;
  }
}

/// `applications/{id}` 에서 인재풀 카드에 필요한 최소 필드만 추린 형태
class JoinedApplication {
  final String applicationId;
  final String jobId;
  final String? jobTitle;
  final DateTime? submittedAt;
  final String status;
  final String resumeId;

  const JoinedApplication({
    required this.applicationId,
    required this.jobId,
    this.jobTitle,
    this.submittedAt,
    this.status = 'submitted',
    this.resumeId = '',
  });
}
