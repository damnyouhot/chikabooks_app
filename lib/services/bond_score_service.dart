import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/activity_log.dart';

/// 결 점수 서비스
///
/// 대부분 유저가 50~70에 머물도록 damping 적용.
/// 하락은 거의 없고, 압박 방지를 위해 완만하게 변화.
class BondScoreService {
  static final _db = FirebaseFirestore.instance;
  static const double _initialScore = 60.0;
  static const double _min = 35.0;
  static const double _max = 85.0;
  static const double _center = 60.0;

  // ─── 이벤트별 baseDelta ───

  static const Map<ActivityType, double> _baseDelta = {
    ActivityType.slotPost: 1.2,       // 작성자 +0.8, 나머지 각 +0.2
    ActivityType.slotReaction: 0.6,   // 리액션 한 사람
    ActivityType.cheerReaction: 0.8,  // 준 사람 +0.4, 받은 쪽 +0.4
    ActivityType.ebookRead: 0.8,
    ActivityType.quizComplete: 0.8,
    ActivityType.wallPost: 0.5,
    ActivityType.pollVote: 0.4,
  };

  /// 중심(60)에서 멀어질수록 둔화되는 damping 함수
  /// score=60 → factor≈1.0
  /// score=80 → factor≈0.31
  /// score=40 → factor≈0.31
  static double damp(double score, double baseDelta) {
    final dist = (score - _center).abs();
    final factor = 1.0 / (1.0 + (dist / 12.0) * (dist / 12.0));
    return baseDelta * factor;
  }

  /// 이벤트 발생 시 결 점수 업데이트
  /// [uid] 대상 유저, [type] 활동 타입, [customDelta] 커스텀 delta (null이면 기본값)
  static Future<void> applyEvent(
    String uid,
    ActivityType type, {
    double? customDelta,
  }) async {
    try {
      final userRef = _db.collection('users').doc(uid);
      await _db.runTransaction((tx) async {
        final snap = await tx.get(userRef);
        final current =
            (snap.data()?['bondScore'] ?? _initialScore).toDouble();
        final base = customDelta ?? _baseDelta[type] ?? 0.0;
        final delta = damp(current, base);
        final newScore = (current + delta).clamp(_min, _max);
        tx.update(userRef, {'bondScore': newScore});
      });
    } catch (e) {
      debugPrint('⚠️ BondScoreService.applyEvent error: $e');
    }
  }

  /// 슬롯 포스트 시: 작성자 +0.8, 같은 그룹 나머지 멤버 각 +0.2
  static Future<void> applySlotPost(
    String authorUid,
    List<String> allMemberUids,
  ) async {
    await applyEvent(authorUid, ActivityType.slotPost, customDelta: 0.8);
    for (final uid in allMemberUids) {
      if (uid != authorUid) {
        await applyEvent(uid, ActivityType.slotPost, customDelta: 0.2);
      }
    }
  }

  /// 북돋기(응원 리액션): 준 사람 +0.4, 받은 쪽 +0.4
  static Future<void> applyCheer(String giverUid, String receiverUid) async {
    await applyEvent(giverUid, ActivityType.cheerReaction, customDelta: 0.4);
    await applyEvent(
        receiverUid, ActivityType.cheerReaction, customDelta: 0.4);
  }

  /// 중심 회귀: 하루 1회 앱 실행 시 미세 조정
  /// score < 50 → +0.2, score > 70 → -0.2
  static Future<void> applyCenterGravity() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final userRef = _db.collection('users').doc(uid);
      final snap = await userRef.get();
      final current =
          (snap.data()?['bondScore'] ?? _initialScore).toDouble();

      double adjustment = 0.0;
      if (current < 50.0) {
        adjustment = 0.2;
      } else if (current > 70.0) {
        adjustment = -0.2;
      }

      if (adjustment != 0.0) {
        final newScore = (current + adjustment).clamp(_min, _max);
        await userRef.update({'bondScore': newScore});
      }
    } catch (e) {
      debugPrint('⚠️ BondScoreService.applyCenterGravity error: $e');
    }
  }

  /// 결 점수 라벨 (숫자 → 분위기 단어)
  static String scoreLabel(double score) {
    if (score >= 70) return '따뜻함';
    if (score >= 60) return '맑음';
    if (score >= 50) return '잔잔함';
    if (score >= 40) return '고요함';
    return '흐림';
  }
}

