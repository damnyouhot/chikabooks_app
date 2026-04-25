import 'package:cloud_firestore/cloud_firestore.dart';

/// 알림 채널별 on/off
class NotificationChannels {
  final bool email;
  final bool kakaoTalk; // 카카오 알림톡 (외주 발송 예정)
  final bool push; // 웹/앱 푸시 (FCM 예정)

  const NotificationChannels({
    this.email = true,
    this.kakaoTalk = false,
    this.push = true,
  });

  NotificationChannels copyWith({
    bool? email,
    bool? kakaoTalk,
    bool? push,
  }) =>
      NotificationChannels(
        email: email ?? this.email,
        kakaoTalk: kakaoTalk ?? this.kakaoTalk,
        push: push ?? this.push,
      );

  Map<String, dynamic> toMap() => {
        'email': email,
        'kakaoTalk': kakaoTalk,
        'push': push,
      };

  factory NotificationChannels.fromMap(Map<String, dynamic> m) =>
      NotificationChannels(
        email: m['email'] as bool? ?? true,
        kakaoTalk: m['kakaoTalk'] as bool? ?? false,
        push: m['push'] as bool? ?? true,
      );
}

/// 이벤트(트리거)별 on/off
///
/// UI 에서 사용자가 토글할 항목.  실제 발송은 서버 Cloud Function 이
/// 이 prefs 를 참조해서 채널·수신자에 fan-out 한다.
class NotificationEvents {
  final bool jobApplied; // 새 지원 도착
  final bool jobApplicantStatus; // 지원자 상태 변경 (검토/면접 등)
  final bool jobExpiring; // 공고 만료 임박
  final bool walletLow; // 잔액/공고권 소진 임박
  final bool walletCharged; // 충전 완료
  final bool taxIssued; // 세금계산서 발급 완료
  final bool weeklyDigest; // 주간 리포트
  final bool announcements; // 공지/업데이트

  const NotificationEvents({
    this.jobApplied = true,
    this.jobApplicantStatus = true,
    this.jobExpiring = true,
    this.walletLow = true,
    this.walletCharged = true,
    this.taxIssued = true,
    this.weeklyDigest = true,
    this.announcements = false,
  });

  NotificationEvents copyWith({
    bool? jobApplied,
    bool? jobApplicantStatus,
    bool? jobExpiring,
    bool? walletLow,
    bool? walletCharged,
    bool? taxIssued,
    bool? weeklyDigest,
    bool? announcements,
  }) =>
      NotificationEvents(
        jobApplied: jobApplied ?? this.jobApplied,
        jobApplicantStatus:
            jobApplicantStatus ?? this.jobApplicantStatus,
        jobExpiring: jobExpiring ?? this.jobExpiring,
        walletLow: walletLow ?? this.walletLow,
        walletCharged: walletCharged ?? this.walletCharged,
        taxIssued: taxIssued ?? this.taxIssued,
        weeklyDigest: weeklyDigest ?? this.weeklyDigest,
        announcements: announcements ?? this.announcements,
      );

  Map<String, dynamic> toMap() => {
        'jobApplied': jobApplied,
        'jobApplicantStatus': jobApplicantStatus,
        'jobExpiring': jobExpiring,
        'walletLow': walletLow,
        'walletCharged': walletCharged,
        'taxIssued': taxIssued,
        'weeklyDigest': weeklyDigest,
        'announcements': announcements,
      };

  factory NotificationEvents.fromMap(Map<String, dynamic> m) =>
      NotificationEvents(
        jobApplied: m['jobApplied'] as bool? ?? true,
        jobApplicantStatus:
            m['jobApplicantStatus'] as bool? ?? true,
        jobExpiring: m['jobExpiring'] as bool? ?? true,
        walletLow: m['walletLow'] as bool? ?? true,
        walletCharged: m['walletCharged'] as bool? ?? true,
        taxIssued: m['taxIssued'] as bool? ?? true,
        weeklyDigest: m['weeklyDigest'] as bool? ?? true,
        announcements: m['announcements'] as bool? ?? false,
      );
}

/// 받는 사람 — 운영자가 직접 추가하는 멀티 수신자
class NotificationRecipient {
  final String id;
  final String name;
  final String role; // '원장' | '실장' | '인사담당' | '기타'
  final String? email;
  final String? phone;
  final List<String> events; // 이 사람이 받을 이벤트 키들
  final bool active;

  const NotificationRecipient({
    required this.id,
    required this.name,
    required this.role,
    this.email,
    this.phone,
    this.events = const [],
    this.active = true,
  });

  NotificationRecipient copyWith({
    String? name,
    String? role,
    String? email,
    String? phone,
    List<String>? events,
    bool? active,
  }) =>
      NotificationRecipient(
        id: id,
        name: name ?? this.name,
        role: role ?? this.role,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        events: events ?? this.events,
        active: active ?? this.active,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'role': role,
        'email': email,
        'phone': phone,
        'events': events,
        'active': active,
      };

  factory NotificationRecipient.fromMap(Map<String, dynamic> m) =>
      NotificationRecipient(
        id: m['id'] as String? ?? '',
        name: m['name'] as String? ?? '',
        role: m['role'] as String? ?? '기타',
        email: m['email'] as String?,
        phone: m['phone'] as String?,
        events: (m['events'] as List?)?.cast<String>() ?? const [],
        active: m['active'] as bool? ?? true,
      );
}

/// 알림 환경설정 묶음 — `clinics_accounts/{uid}/notificationPrefs/default`
/// 한 문서로 보관.
class NotificationPrefs {
  final NotificationChannels channels;
  final NotificationEvents events;
  final List<NotificationRecipient> recipients;
  final bool quietHours; // 야간 무음 (21:00~08:00)
  final DateTime? updatedAt;

  const NotificationPrefs({
    this.channels = const NotificationChannels(),
    this.events = const NotificationEvents(),
    this.recipients = const [],
    this.quietHours = false,
    this.updatedAt,
  });

  NotificationPrefs copyWith({
    NotificationChannels? channels,
    NotificationEvents? events,
    List<NotificationRecipient>? recipients,
    bool? quietHours,
  }) =>
      NotificationPrefs(
        channels: channels ?? this.channels,
        events: events ?? this.events,
        recipients: recipients ?? this.recipients,
        quietHours: quietHours ?? this.quietHours,
        updatedAt: updatedAt,
      );

  Map<String, dynamic> toMap() => {
        'channels': channels.toMap(),
        'events': events.toMap(),
        'recipients': recipients.map((r) => r.toMap()).toList(),
        'quietHours': quietHours,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory NotificationPrefs.fromMap(Map<String, dynamic> m) =>
      NotificationPrefs(
        channels: NotificationChannels.fromMap(
            (m['channels'] as Map?)?.cast<String, dynamic>() ??
                const {}),
        events: NotificationEvents.fromMap(
            (m['events'] as Map?)?.cast<String, dynamic>() ??
                const {}),
        recipients: ((m['recipients'] as List?) ?? const [])
            .map((e) => NotificationRecipient.fromMap(
                (e as Map).cast<String, dynamic>()))
            .toList(),
        quietHours: m['quietHours'] as bool? ?? false,
        updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
      );

  factory NotificationPrefs.defaults() =>
      const NotificationPrefs();
}

/// 이벤트 키 → 사용자 표시 라벨 (UI 용)
const Map<String, String> kNotificationEventLabels = {
  'jobApplied': '새 지원 도착',
  'jobApplicantStatus': '지원자 상태 변경',
  'jobExpiring': '공고 만료 임박 (3일 전)',
  'walletLow': '잔액·공고권 소진 임박',
  'walletCharged': '충전 완료',
  'taxIssued': '세금계산서/현금영수증 발급 완료',
  'weeklyDigest': '주간 리포트 (월요일 09:00)',
  'announcements': '서비스 공지/업데이트',
};
