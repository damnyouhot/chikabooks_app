import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// 어드민 — 사용자 검색·상세·플래그 토글 callable 래퍼.
///
/// ── 응답 디코딩 ─────────────────────────────────────────────
/// Callable 응답은 플랫폼에 따라 [Map<Object?, Object?>] 가 깊게 중첩될 수
/// 있어, [_deepDecode] 로 평탄화 후 도메인 모델로 변환한다.
/// ────────────────────────────────────────────────────────────
class AdminUserService {
  AdminUserService._();

  static final FirebaseFunctions _fx = FirebaseFunctions.instanceFor(
    region: 'asia-northeast3',
  );

  static Future<UserSearchResult> search({required String query}) async {
    final call = _fx.httpsCallable('adminSearchUsers');
    final res = await call.call<Object?>({'query': query});
    final decoded = _deepDecode(res.data);
    if (decoded is! Map<String, dynamic>) {
      return const UserSearchResult(items: [], matchedBy: 'none');
    }
    final rawItems = decoded['items'];
    final items = <UserSearchHit>[];
    if (rawItems is List) {
      for (final r in rawItems) {
        if (r is Map<String, dynamic>) {
          items.add(UserSearchHit.fromMap(r));
        }
      }
    }
    return UserSearchResult(
      items: items,
      matchedBy: decoded['matchedBy']?.toString() ?? 'none',
    );
  }

  static Future<UserDetail?> getDetail({required String targetUid}) async {
    final call = _fx.httpsCallable('adminGetUserDetail');
    final res = await call.call<Object?>({'targetUid': targetUid});
    final decoded = _deepDecode(res.data);
    if (decoded is! Map<String, dynamic>) return null;
    return UserDetail.fromMap(decoded);
  }

  static Future<ToggleFlagResult> toggleFlag({
    required String targetUid,
    required UserFlag flag,
    required bool value,
  }) async {
    final call = _fx.httpsCallable('adminToggleUserFlag');
    final res = await call.call<Object?>({
      'targetUid': targetUid,
      'flag': flag.wire,
      'value': value,
    });
    final decoded = _deepDecode(res.data);
    if (decoded is! Map<String, dynamic>) {
      return const ToggleFlagResult(success: false);
    }
    return ToggleFlagResult(
      success: decoded['success'] == true,
      flag: decoded['flag']?.toString(),
      newValue: decoded['newValue'] == true,
    );
  }

  static dynamic _deepDecode(dynamic v) {
    if (v is Map) {
      return Map<String, dynamic>.fromEntries(
        v.entries.map(
          (e) => MapEntry(e.key.toString(), _deepDecode(e.value)),
        ),
      );
    }
    if (v is List) {
      return v.map(_deepDecode).toList();
    }
    return v;
  }
}

enum UserFlag {
  excludeFromStats('excludeFromStats'),
  isAdmin('isAdmin');

  final String wire;
  const UserFlag(this.wire);
}

@immutable
class UserSearchHit {
  final String uid;
  final String? nickname;
  final String? emailMasked;
  final String? region;
  final String? careerGroup;
  final bool isAdmin;
  final bool excludeFromStats;
  final DateTime? createdAt;
  final String matchedBy;

  const UserSearchHit({
    required this.uid,
    required this.nickname,
    required this.emailMasked,
    required this.region,
    required this.careerGroup,
    required this.isAdmin,
    required this.excludeFromStats,
    required this.createdAt,
    required this.matchedBy,
  });

  factory UserSearchHit.fromMap(Map<String, dynamic> m) {
    final ms = m['createdAtMs'];
    return UserSearchHit(
      uid: (m['uid'] ?? '').toString(),
      nickname: m['nickname']?.toString(),
      emailMasked: m['email']?.toString(),
      region: m['region']?.toString(),
      careerGroup: m['careerGroup']?.toString(),
      isAdmin: m['isAdmin'] == true,
      excludeFromStats: m['excludeFromStats'] == true,
      createdAt:
          ms is num ? DateTime.fromMillisecondsSinceEpoch(ms.toInt()) : null,
      matchedBy: (m['matchedBy'] ?? '').toString(),
    );
  }
}

@immutable
class UserSearchResult {
  final List<UserSearchHit> items;
  final String matchedBy;
  const UserSearchResult({required this.items, required this.matchedBy});
}

@immutable
class UserAuthInfo {
  final String? emailMasked;
  final bool emailVerified;
  final bool disabled;
  final List<String> providers;
  final DateTime? lastSignIn;
  final DateTime? createdAt;
  const UserAuthInfo({
    required this.emailMasked,
    required this.emailVerified,
    required this.disabled,
    required this.providers,
    required this.lastSignIn,
    required this.createdAt,
  });

  factory UserAuthInfo.fromMap(Map<String, dynamic> m) {
    final providersRaw = m['providers'];
    final providers = <String>[];
    if (providersRaw is List) {
      for (final p in providersRaw) {
        providers.add(p.toString());
      }
    }
    DateTime? ts(dynamic v) =>
        v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;
    return UserAuthInfo(
      emailMasked: m['email']?.toString(),
      emailVerified: m['emailVerified'] == true,
      disabled: m['disabled'] == true,
      providers: providers,
      lastSignIn: ts(m['lastSignInMs']),
      createdAt: ts(m['createdAtMs']),
    );
  }
}

@immutable
class UserActivityEntry {
  final String type;
  final DateTime? timestamp;
  final Map<String, dynamic> meta;
  const UserActivityEntry({
    required this.type,
    required this.timestamp,
    required this.meta,
  });

  factory UserActivityEntry.fromMap(Map<String, dynamic> m) {
    final ts = m['timestampMs'];
    final metaRaw = m['meta'];
    return UserActivityEntry(
      type: (m['type'] ?? '').toString(),
      timestamp: ts is num
          ? DateTime.fromMillisecondsSinceEpoch(ts.toInt())
          : null,
      meta: metaRaw is Map<String, dynamic>
          ? Map<String, dynamic>.from(metaRaw)
          : const {},
    );
  }
}

@immutable
class UserModerationStats {
  final int reportedAgainstCount;
  final int hiddenPostCount;
  const UserModerationStats({
    required this.reportedAgainstCount,
    required this.hiddenPostCount,
  });
  factory UserModerationStats.fromMap(Map<String, dynamic> m) {
    return UserModerationStats(
      reportedAgainstCount: (m['reportedAgainstCount'] as num?)?.toInt() ?? 0,
      hiddenPostCount: (m['hiddenPostCount'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class UserBillingStats {
  final int paidCount;
  final int paidAmountKrw;
  final int refundCount;
  final DateTime? lastPaidAt;
  const UserBillingStats({
    required this.paidCount,
    required this.paidAmountKrw,
    required this.refundCount,
    required this.lastPaidAt,
  });
  factory UserBillingStats.fromMap(Map<String, dynamic> m) {
    final ms = m['lastPaidAtMs'];
    return UserBillingStats(
      paidCount: (m['paidCount'] as num?)?.toInt() ?? 0,
      paidAmountKrw: (m['paidAmountKrw'] as num?)?.toInt() ?? 0,
      refundCount: (m['refundCount'] as num?)?.toInt() ?? 0,
      lastPaidAt:
          ms is num ? DateTime.fromMillisecondsSinceEpoch(ms.toInt()) : null,
    );
  }
}

@immutable
class UserDetail {
  final Map<String, dynamic> profile;
  final UserAuthInfo? auth;
  final List<UserActivityEntry> recentActivity;
  final UserModerationStats? moderation;
  final UserBillingStats? billing;
  final List<String> partialErrors;

  const UserDetail({
    required this.profile,
    required this.auth,
    required this.recentActivity,
    required this.moderation,
    required this.billing,
    required this.partialErrors,
  });

  factory UserDetail.fromMap(Map<String, dynamic> m) {
    final profile = m['profile'];
    final authRaw = m['auth'];
    final activityRaw = m['recentActivity'];
    final moderationRaw = m['moderation'];
    final billingRaw = m['billing'];
    final errRaw = m['partialErrors'];

    final activity = <UserActivityEntry>[];
    if (activityRaw is List) {
      for (final r in activityRaw) {
        if (r is Map<String, dynamic>) {
          activity.add(UserActivityEntry.fromMap(r));
        }
      }
    }
    final partialErrors = <String>[];
    if (errRaw is List) {
      for (final e in errRaw) {
        partialErrors.add(e.toString());
      }
    }

    return UserDetail(
      profile: profile is Map<String, dynamic>
          ? Map<String, dynamic>.from(profile)
          : const {},
      auth: authRaw is Map<String, dynamic>
          ? UserAuthInfo.fromMap(authRaw)
          : null,
      recentActivity: activity,
      moderation: moderationRaw is Map<String, dynamic>
          ? UserModerationStats.fromMap(moderationRaw)
          : null,
      billing: billingRaw is Map<String, dynamic>
          ? UserBillingStats.fromMap(billingRaw)
          : null,
      partialErrors: partialErrors,
    );
  }
}

@immutable
class ToggleFlagResult {
  final bool success;
  final String? flag;
  final bool newValue;
  const ToggleFlagResult({
    required this.success,
    this.flag,
    this.newValue = false,
  });
}
