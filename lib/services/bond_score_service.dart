import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/activity_log.dart';

/// 결 점수 서비스 (0~100 범위)
///
/// 대부분 유저가 40~60에 머물도록 damping 적용.
/// 하락은 거의 없고, 압박 방지를 위해 완만하게 변화.
class BondScoreService {
  static final _db = FirebaseFirestore.instance;

  // ─── 범위 상수 (0~100) ───
  static const double _initialScore = 50.0;
  static const double _min = 0.0;
  static const double _max = 100.0;
  static const double _center = 50.0;

  // ─── 이벤트별 baseDelta ───
  static const Map<ActivityType, double> _baseDelta = {
    ActivityType.slotPost: 1.2,
    ActivityType.slotReaction: 0.6,
    ActivityType.cheerReaction: 0.8,
    ActivityType.ebookRead: 0.8,
    ActivityType.quizComplete: 0.8,
    ActivityType.wallPost: 0.5,
    ActivityType.pollVote: 0.4,
  };

  /// 중심(50)에서 멀어질수록 둔화되는 damping 함수
  /// score=50 → factor≈1.0
  /// score=80 → factor≈0.31
  /// score=20 → factor≈0.31
  static double damp(double score, double baseDelta) {
    final dist = (score - _center).abs();
    final factor = 1.0 / (1.0 + (dist / 25.0) * (dist / 25.0));
    return baseDelta * factor;
  }

  /// 이벤트 발생 시 결 점수 업데이트
  static Future<void> applyEvent(
    String uid,
    ActivityType type, {
    double? customDelta,
  }) async {
    try {
      final userRef = _db.collection('users').doc(uid);
      await _db.runTransaction((tx) async {
        final snap = await tx.get(userRef);
        final raw = snap.data()?['bondScore'];
        double current = _migrateIfNeeded(raw, snap.data());
        final base = customDelta ?? _baseDelta[type] ?? 0.0;
        final delta = damp(current, base);
        final newScore = (current + delta).clamp(_min, _max);
        tx.update(userRef, {
          'bondScore': newScore,
          'bondScoreVersion': 2,
        });
      });
    } catch (e) {
      debugPrint('⚠️ BondScoreService.applyEvent error: $e');
    }
  }

  /// 슬롯 포스트: 작성자 +0.8, 그룹 멤버 각 +0.2
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

  /// 응원 리액션: 준 사람 +0.4, 받은 사람 +0.4
  static Future<void> applyCheer(String giverUid, String receiverUid) async {
    await applyEvent(giverUid, ActivityType.cheerReaction, customDelta: 0.4);
    await applyEvent(
        receiverUid, ActivityType.cheerReaction, customDelta: 0.4);
  }

  /// 중심 회귀: 하루 1회 앱 실행 시 미세 조정
  /// score < 40 → +0.3, score > 60 → -0.3
  static Future<void> applyCenterGravity() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final userRef = _db.collection('users').doc(uid);
      final snap = await userRef.get();
      final raw = snap.data()?['bondScore'];
      double current = _migrateIfNeeded(raw, snap.data());

      double adjustment = 0.0;
      if (current < 40.0) {
        adjustment = 0.3;
      } else if (current > 60.0) {
        adjustment = -0.3;
      }

      if (adjustment != 0.0) {
        final newScore = (current + adjustment).clamp(_min, _max);
        await userRef.update({
          'bondScore': newScore,
          'bondScoreVersion': 2,
        });
      }
    } catch (e) {
      debugPrint('⚠️ BondScoreService.applyCenterGravity error: $e');
    }
  }

  /// 결 점수 라벨 (0~100 기준)
  static String scoreLabel(double score) {
    if (score >= 80) return '따뜻함';
    if (score >= 60) return '맑음';
    if (score >= 40) return '잔잔함';
    if (score >= 20) return '고요함';
    return '흐림';
  }

  // ─── 마이그레이션: 구버전(35~85) → 신버전(0~100) ───

  /// raw bondScore 값을 0~100 범위로 변환
  /// bondScoreVersion이 2이면 이미 변환 완료
  static double _migrateIfNeeded(dynamic rawScore, Map<String, dynamic>? data) {
    if (rawScore == null) return _initialScore;

    final score = (rawScore as num).toDouble();
    final version = data?['bondScoreVersion'] ?? 1;

    if (version >= 2) {
      // 이미 0~100 범위
      return score.clamp(_min, _max);
    }

    // 구버전: 35~85 → 0~100 변환
    // new = (old - 35) * 2
    final migrated = ((score.clamp(35.0, 85.0) - 35.0) * 2.0).clamp(_min, _max);
    return migrated;
  }

  /// 외부에서 읽기 시 마이그레이션 적용 + DB 1회 저장
  static Future<double> readAndMigrate(String uid) async {
    try {
      final userRef = _db.collection('users').doc(uid);
      final snap = await userRef.get();
      final data = snap.data();
      final raw = data?['bondScore'];
      final version = data?['bondScoreVersion'] ?? 1;

      final score = _migrateIfNeeded(raw, data);

      // 구버전이면 변환 후 DB에 1회 저장
      if (version < 2 && raw != null) {
        await userRef.update({
          'bondScore': score,
          'bondScoreVersion': 2,
        });
      }

      return score;
    } catch (e) {
      debugPrint('⚠️ BondScoreService.readAndMigrate error: $e');
      return _initialScore;
    }
  }
}
