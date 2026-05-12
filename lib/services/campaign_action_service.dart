import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// CampaignActionService — 캠페인 운영 Callable 호출 wrapper.
///
/// 모든 jobs/campaigns 변경은 보안 룰상 클라이언트가 직접 못 쓰고,
/// 본 서비스를 통해 Cloud Functions 으로만 가능하다.
///
///   pause / resume / close / delete / setAutoRenew / extendOrder / upgradeOrder /
///   cancelAndRefund
///
/// 설계서 §M4 — G1·G2·G3·G6·G7 묶음.
class CampaignActionService {
  CampaignActionService._();

  static FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'asia-northeast3');
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── 헬퍼: jobId → campaignId 조회 ──────────────────────
  /// jobs.campaignId 가 채워져 있으면 그대로 사용, 아니면 campaigns 컬렉션에서 jobId로 검색.
  /// 백필이 끝나기 전 레거시 jobs 호환.
  static Future<String?> resolveCampaignIdFromJob(String jobId) async {
    if (jobId.isEmpty) return null;
    try {
      final jobDoc = await _db.collection('jobs').doc(jobId).get();
      final cidFromJob = jobDoc.data()?['campaignId'] as String?;
      if (cidFromJob != null && cidFromJob.isNotEmpty) return cidFromJob;

      final uid = _uid;
      if (uid == null) return null;
      final q = await _db
          .collection('campaigns')
          .where('ownerUid', isEqualTo: uid)
          .where('jobId', isEqualTo: jobId)
          .limit(1)
          .get();
      if (q.docs.isEmpty) return null;
      return q.docs.first.id;
    } catch (e) {
      debugPrint('⚠️ resolveCampaignIdFromJob: $e');
      return null;
    }
  }

  // ── 액션: 일시정지 ────────────────────────────────────
  static Future<Map<String, dynamic>> pause({
    required String campaignId,
    String? reason,
  }) async {
    final res = await _functions.httpsCallable('pauseCampaign').call({
      'campaignId': campaignId,
      if (reason != null) 'reason': reason,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  // ── 액션: 재개 ─────────────────────────────────────────
  static Future<Map<String, dynamic>> resume({
    required String campaignId,
  }) async {
    final res = await _functions.httpsCallable('resumeCampaign').call({
      'campaignId': campaignId,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  // ── 액션: 조기 마감 ───────────────────────────────────
  static Future<Map<String, dynamic>> close({
    required String campaignId,
    String? reason,
  }) async {
    final res = await _functions.httpsCallable('closeCampaign').call({
      'campaignId': campaignId,
      if (reason != null) 'reason': reason,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  // ── 액션: 삭제(soft) ──────────────────────────────────
  static Future<Map<String, dynamic>> deleteCampaign({
    required String campaignId,
  }) async {
    final res = await _functions.httpsCallable('deleteCampaign').call({
      'campaignId': campaignId,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  // ── 액션: 자동연장 토글 ───────────────────────────────
  static Future<Map<String, dynamic>> setAutoRenew({
    required String campaignId,
    required bool enabled,
    String? consentVersion,
  }) async {
    final res = await _functions.httpsCallable('setAutoRenew').call({
      'campaignId': campaignId,
      'enabled': enabled,
      if (consentVersion != null) 'consentVersion': consentVersion,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  // ── 액션: 연장 주문 생성 (결제는 별도 토스 호출 후 confirmPayment) ──
  static Future<Map<String, dynamic>> createExtendOrder({
    required String campaignId,
    required int addDays,
  }) async {
    final res = await _functions.httpsCallable('createExtendOrder').call({
      'campaignId': campaignId,
      'addDays': addDays,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  // ── 액션: 등급변경 주문 생성 ──────────────────────────
  static Future<Map<String, dynamic>> createUpgradeOrder({
    required String campaignId,
    required String newTierKey,
  }) async {
    final res = await _functions.httpsCallable('createUpgradeOrder').call({
      'campaignId': campaignId,
      'newTierKey': newTierKey,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  // ── 액션: 환불 ─────────────────────────────────────────
  static Future<Map<String, dynamic>> cancelAndRefund({
    required String campaignId,
    String? reason,
  }) async {
    final res = await _functions.httpsCallable('cancelAndRefund').call({
      'campaignId': campaignId,
      if (reason != null) 'reason': reason,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }
}
