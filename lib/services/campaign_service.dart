import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/campaign.dart';

/// 캠페인 조회 전용 서비스 (설계서 §2-2)
///
/// 모든 쓰기는 Cloud Functions Callable 을 통해서만 수행한다.
/// 클라이언트는 본인 캠페인을 읽기만 한다.
///
/// Firestore: `campaigns/{campaignId}`
class CampaignService {
  CampaignService._();

  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('campaigns');

  // ── 단건 조회 ─────────────────────────────────────────────

  static Future<Campaign?> getById(String campaignId) async {
    try {
      final snap = await _col.doc(campaignId).get();
      if (!snap.exists) return null;
      return Campaign.fromDoc(snap);
    } catch (e) {
      debugPrint('⚠️ CampaignService.getById: $e');
      return null;
    }
  }

  static Stream<Campaign?> watchById(String campaignId) {
    return _col.doc(campaignId).snapshots().map(
          (snap) => snap.exists ? Campaign.fromDoc(snap) : null,
        );
  }

  // ── 본인 캠페인 목록 ──────────────────────────────────────

  /// 내 모든 캠페인 (최근 게시순). 지점 필터는 [clinicProfileId] 로.
  static Future<List<Campaign>> getMine({
    String? clinicProfileId,
    int limit = 50,
  }) async {
    final uid = _uid;
    if (uid == null) return const [];
    try {
      Query<Map<String, dynamic>> q =
          _col.where('ownerUid', isEqualTo: uid);
      if (clinicProfileId != null) {
        q = q.where('clinicProfileId', isEqualTo: clinicProfileId);
      }
      q = q.orderBy('adEndAt', descending: true).limit(limit);
      final snap = await q.get();
      return snap.docs.map(Campaign.fromDoc).toList();
    } catch (e) {
      debugPrint('⚠️ CampaignService.getMine: $e');
      return const [];
    }
  }

  /// 활성/일시정지 상태의 본인 캠페인만.
  ///
  /// 대시보드 홈의 "활성 캠페인 미니 리스트" 등에서 사용.
  static Future<List<Campaign>> getMineLive({
    String? clinicProfileId,
    int limit = 20,
  }) async {
    final uid = _uid;
    if (uid == null) return const [];
    try {
      Query<Map<String, dynamic>> q = _col
          .where('ownerUid', isEqualTo: uid)
          .where('lifecycleStatus', whereIn: ['active', 'paused']);
      if (clinicProfileId != null) {
        q = q.where('clinicProfileId', isEqualTo: clinicProfileId);
      }
      q = q.orderBy('adEndAt', descending: false).limit(limit);
      final snap = await q.get();
      return snap.docs.map(Campaign.fromDoc).toList();
    } catch (e) {
      debugPrint('⚠️ CampaignService.getMineLive: $e');
      return const [];
    }
  }

  static Stream<List<Campaign>> watchMineLive({
    String? clinicProfileId,
  }) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    Query<Map<String, dynamic>> q = _col
        .where('ownerUid', isEqualTo: uid)
        .where('lifecycleStatus', whereIn: ['active', 'paused']);
    if (clinicProfileId != null) {
      q = q.where('clinicProfileId', isEqualTo: clinicProfileId);
    }
    q = q.orderBy('adEndAt', descending: false);
    return q.snapshots().map(
          (snap) => snap.docs.map(Campaign.fromDoc).toList(),
        );
  }

  /// 본인 모든 캠페인을 실시간 스트림으로 (대시보드 본문용).
  ///
  /// 종료/환불 포함 전체. 화면에서 필터 칩으로 다시 거른다.
  static Stream<List<Campaign>> watchMine({
    String? clinicProfileId,
    int limit = 200,
  }) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    Query<Map<String, dynamic>> q = _col.where('ownerUid', isEqualTo: uid);
    if (clinicProfileId != null) {
      q = q.where('clinicProfileId', isEqualTo: clinicProfileId);
    }
    q = q.orderBy('adEndAt', descending: true).limit(limit);
    return q.snapshots().map(
          (snap) => snap.docs.map(Campaign.fromDoc).toList(),
        );
  }

  // ── jobId ↔ campaignId 매핑 (백필 직후 호환용) ─────────────

  /// `jobs/{jobId}` 에 대응하는 캠페인 1건. 마이그레이션 직후엔 jobs.campaignId 를 우선
  /// 사용하지만, 누락된 레거시 문서를 위해 역질의도 지원한다.
  static Future<Campaign?> findByJobId(String jobId) async {
    try {
      final snap = await _col
          .where('jobId', isEqualTo: jobId)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return Campaign.fromDoc(snap.docs.first);
    } catch (e) {
      debugPrint('⚠️ CampaignService.findByJobId: $e');
      return null;
    }
  }
}
