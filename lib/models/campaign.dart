import 'package:cloud_firestore/cloud_firestore.dart';

/// 캠페인 라이프사이클 상태 (설계서 §3)
///
/// `scheduled` → `active` ⇄ `paused` → `ended` | `refunded`
enum CampaignLifecycleStatus {
  /// 결제 직후, adStartAt 도달 전. 본 v1 에서는 createOrder→confirmPayment 즉시 active 이라
  /// 사실상 사용되지 않으나 향후 예약 게시 도입을 위해 보존.
  scheduled,

  /// 노출 중
  active,

  /// 일시정지 중. 잔여기간은 그대로 두고 `pause.currentPausedAt` 부터의 시간을
  /// 재개 시 `pauseSaveRate` 를 곱해 [Campaign.adEndAt] 에 환원한다.
  paused,

  /// 노출 기간 종료 (자동연장 OFF, 또는 자동결제 실패)
  ended,

  /// 환불 처리됨. 즉시 노출 중단 + 잔여기간 무효
  refunded;

  static CampaignLifecycleStatus fromString(String? raw) {
    switch (raw) {
      case 'scheduled':
        return CampaignLifecycleStatus.scheduled;
      case 'active':
        return CampaignLifecycleStatus.active;
      case 'paused':
        return CampaignLifecycleStatus.paused;
      case 'ended':
        return CampaignLifecycleStatus.ended;
      case 'refunded':
        return CampaignLifecycleStatus.refunded;
      default:
        return CampaignLifecycleStatus.active;
    }
  }

  String get value {
    switch (this) {
      case CampaignLifecycleStatus.scheduled:
        return 'scheduled';
      case CampaignLifecycleStatus.active:
        return 'active';
      case CampaignLifecycleStatus.paused:
        return 'paused';
      case CampaignLifecycleStatus.ended:
        return 'ended';
      case CampaignLifecycleStatus.refunded:
        return 'refunded';
    }
  }

  bool get isLive =>
      this == CampaignLifecycleStatus.active ||
      this == CampaignLifecycleStatus.paused;
  bool get isTerminal =>
      this == CampaignLifecycleStatus.ended ||
      this == CampaignLifecycleStatus.refunded;
}

/// 일시정지 상태 메타 (설계서 §2-2)
class CampaignPauseState {
  final int count;
  final int totalDaysOnPause;
  final int totalDaysCredited;
  final DateTime? currentPausedAt;

  const CampaignPauseState({
    this.count = 0,
    this.totalDaysOnPause = 0,
    this.totalDaysCredited = 0,
    this.currentPausedAt,
  });

  factory CampaignPauseState.fromMap(Map<String, dynamic>? raw) {
    if (raw == null) return const CampaignPauseState();
    return CampaignPauseState(
      count: (raw['count'] as num?)?.toInt() ?? 0,
      totalDaysOnPause: (raw['totalDaysOnPause'] as num?)?.toInt() ?? 0,
      totalDaysCredited: (raw['totalDaysCredited'] as num?)?.toInt() ?? 0,
      currentPausedAt: (raw['currentPausedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// 자동연장 메타 (설계서 §3-2)
class CampaignAutoRenew {
  /// 디폴트 false. ON 토글 시 동의 모달을 거쳐 true 로 전환.
  final bool enabled;
  final String? consentVersion;
  final DateTime? enabledAt;

  /// ON 시점의 할인율 스냅샷. 정책(`productCatalog.{tier}.autoRenewDiscountRate`)이
  /// 바뀌어도 이미 ON 한 캠페인은 이 값으로 결제된다.
  final double discountRateSnapshot;

  /// 다음 자동결제 예정 시각 (`adEndAt - autoRenewLeadDays`)
  final DateTime? nextChargeAt;

  /// "succeeded" | "failed" | "none"
  final String lastChargeStatus;
  final String? failedReason;

  const CampaignAutoRenew({
    this.enabled = false,
    this.consentVersion,
    this.enabledAt,
    this.discountRateSnapshot = 0.0,
    this.nextChargeAt,
    this.lastChargeStatus = 'none',
    this.failedReason,
  });

  factory CampaignAutoRenew.fromMap(Map<String, dynamic>? raw) {
    if (raw == null) return const CampaignAutoRenew();
    return CampaignAutoRenew(
      enabled: raw['enabled'] == true,
      consentVersion: raw['consentVersion'] as String?,
      enabledAt: (raw['enabledAt'] as Timestamp?)?.toDate(),
      discountRateSnapshot:
          (raw['discountRateSnapshot'] as num?)?.toDouble() ?? 0.0,
      nextChargeAt: (raw['nextChargeAt'] as Timestamp?)?.toDate(),
      lastChargeStatus:
          (raw['lastChargeStatus'] as String?) ?? 'none',
      failedReason: raw['failedReason'] as String?,
    );
  }
}

/// 일시정지 / 연장 / 결제 시점에 박힌 정책 스냅샷
///
/// 진행 중인 캠페인은 자기 시작 시점의 정책을 따른다 — 정책 변경이 진행 중인 캠페인을
/// 깨뜨리지 않게 한다 (설계서 §12 원칙).
class CampaignPolicySnapshot {
  final double pauseSaveRate;
  final int pauseMinDaysToAllow;
  final int pauseMaxCountPerCampaign;
  final int autoRenewLeadDays;
  final int refundWindowDays;
  final String policyVersion;

  const CampaignPolicySnapshot({
    this.pauseSaveRate = 0.5,
    this.pauseMinDaysToAllow = 1,
    this.pauseMaxCountPerCampaign = 3,
    this.autoRenewLeadDays = 1,
    this.refundWindowDays = 7,
    this.policyVersion = 'fallback',
  });

  factory CampaignPolicySnapshot.fromMap(Map<String, dynamic>? raw) {
    if (raw == null) return const CampaignPolicySnapshot();
    return CampaignPolicySnapshot(
      pauseSaveRate: (raw['pauseSaveRate'] as num?)?.toDouble() ?? 0.5,
      pauseMinDaysToAllow:
          (raw['pauseMinDaysToAllow'] as num?)?.toInt() ?? 1,
      pauseMaxCountPerCampaign:
          (raw['pauseMaxCountPerCampaign'] as num?)?.toInt() ?? 3,
      autoRenewLeadDays:
          (raw['autoRenewLeadDays'] as num?)?.toInt() ?? 1,
      refundWindowDays:
          (raw['refundWindowDays'] as num?)?.toInt() ?? 7,
      policyVersion:
          (raw['policyVersion'] as String?) ?? 'fallback',
    );
  }
}

/// 캠페인(공고 운영 메타) 엔티티
///
/// Firestore: `campaigns/{campaignId}`
/// 모든 쓰기는 Cloud Functions 에서만 수행한다.
class Campaign {
  final String id;
  final String ownerUid;
  final String clinicProfileId;

  /// 1:1 매핑된 `jobs/{jobId}`
  final String jobId;

  /// 결제 주문 (`orders/{orderId}`). 테스트 무결제 게시는 null.
  final String? orderId;

  /// 결제 시점 등급 키 ("premium"|"standard"|"basic"). 변경 불가(불변식).
  final String tierKey;

  /// 결제 시점 가격 ID. 변경 불가(불변식).
  final String? priceId;

  /// 결제 시점 금액 (원). 가격 변동 후에도 영구 보존.
  final int amountPaid;

  /// 무료 공고권 사용 시 voucherId.
  final String? voucherId;

  final CampaignLifecycleStatus lifecycleStatus;
  final DateTime? adStartAt;
  final DateTime? adEndAt;

  /// 최초 종료일 — 일시정지/연장으로 [adEndAt] 이 변경되어도 이 값은 불변.
  final DateTime? originalEndAt;

  final CampaignPauseState pause;
  final CampaignAutoRenew autoRenew;
  final CampaignPolicySnapshot policySnapshot;

  /// 알림 발송/오픈 메트릭. v1 에서는 텔레메트리(M5)가 채워준다.
  final Map<String, dynamic> notificationsSent;

  /// 연장 결제 이력 (각: {orderId, addedDays, paidAmount, priceId, at})
  final List<Map<String, dynamic>> extensionHistory;

  /// 일시정지/재개 이력
  /// (각: {pausedAt, resumedAt, daysOnPause, daysCredited, savedRate, reason})
  final List<Map<String, dynamic>> pauseHistory;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Campaign({
    required this.id,
    required this.ownerUid,
    required this.clinicProfileId,
    required this.jobId,
    this.orderId,
    required this.tierKey,
    this.priceId,
    this.amountPaid = 0,
    this.voucherId,
    this.lifecycleStatus = CampaignLifecycleStatus.active,
    this.adStartAt,
    this.adEndAt,
    this.originalEndAt,
    this.pause = const CampaignPauseState(),
    this.autoRenew = const CampaignAutoRenew(),
    this.policySnapshot = const CampaignPolicySnapshot(),
    this.notificationsSent = const {},
    this.extensionHistory = const [],
    this.pauseHistory = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory Campaign.fromMap(
    Map<String, dynamic> data, {
    required String id,
  }) {
    return Campaign(
      id: id,
      ownerUid: data['ownerUid'] as String? ?? '',
      clinicProfileId: data['clinicProfileId'] as String? ?? '',
      jobId: data['jobId'] as String? ?? '',
      orderId: data['orderId'] as String?,
      tierKey: (data['tierKey'] as String?) ?? 'basic',
      priceId: data['priceId'] as String?,
      amountPaid: (data['amountPaid'] as num?)?.toInt() ?? 0,
      voucherId: data['voucherId'] as String?,
      lifecycleStatus: CampaignLifecycleStatus.fromString(
        data['lifecycleStatus'] as String?,
      ),
      adStartAt: (data['adStartAt'] as Timestamp?)?.toDate(),
      adEndAt: (data['adEndAt'] as Timestamp?)?.toDate(),
      originalEndAt: (data['originalEndAt'] as Timestamp?)?.toDate(),
      pause: CampaignPauseState.fromMap(
        (data['pause'] as Map?)?.cast<String, dynamic>(),
      ),
      autoRenew: CampaignAutoRenew.fromMap(
        (data['autoRenew'] as Map?)?.cast<String, dynamic>(),
      ),
      policySnapshot: CampaignPolicySnapshot.fromMap(
        (data['policySnapshot'] as Map?)?.cast<String, dynamic>(),
      ),
      notificationsSent:
          (data['notificationsSent'] as Map?)?.cast<String, dynamic>() ??
              const {},
      extensionHistory: _parseMapList(data['extensionHistory']),
      pauseHistory: _parseMapList(data['pauseHistory']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory Campaign.fromDoc(DocumentSnapshot doc) {
    return Campaign.fromMap(
      doc.data() as Map<String, dynamic>,
      id: doc.id,
    );
  }

  static List<Map<String, dynamic>> _parseMapList(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList();
    }
    return const [];
  }

  // ── 파생 값 ─────────────────────────────────────────────

  /// 잔여일 (소수점 버림). 종료된 캠페인은 0 으로 본다.
  int get remainingDays {
    if (lifecycleStatus.isTerminal) return 0;
    final end = adEndAt;
    if (end == null) return 0;
    final diffMs =
        end.millisecondsSinceEpoch - DateTime.now().millisecondsSinceEpoch;
    if (diffMs <= 0) return 0;
    return diffMs ~/ Duration.millisecondsPerDay;
  }

  /// 전체 노출 기간 (일).
  int get totalDays {
    final start = adStartAt;
    final origEnd = originalEndAt ?? adEndAt;
    if (start == null || origEnd == null) return 0;
    final diffMs =
        origEnd.millisecondsSinceEpoch - start.millisecondsSinceEpoch;
    if (diffMs <= 0) return 0;
    return diffMs ~/ Duration.millisecondsPerDay;
  }

  /// 진행률 (0.0~1.0). 게이지 UI 용.
  double get progressRatio {
    final t = totalDays;
    if (t == 0) return 0;
    final r = remainingDays;
    return ((t - r) / t).clamp(0.0, 1.0);
  }

  bool get canPause {
    if (lifecycleStatus != CampaignLifecycleStatus.active) return false;
    if (pause.count >= policySnapshot.pauseMaxCountPerCampaign) return false;
    if (remainingDays < policySnapshot.pauseMinDaysToAllow) return false;
    return true;
  }

  bool get canResume => lifecycleStatus == CampaignLifecycleStatus.paused;
}
