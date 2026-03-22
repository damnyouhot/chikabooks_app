import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'admin_activity_service.dart';

/// 온보딩 퍼널 2~5단계: 계정당 1회만 `activityLogs`에 `isFunnel` 기록
///
/// `users/{uid}.funnelOnboardingV2` 플래그로 중복 방지 (트랜잭션).
/// 대시보드 집계는 [AdminDashboardService.getFunnelSteps]에서 순차 교집합 적용.
class FunnelOnboardingService {
  FunnelOnboardingService._();

  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static const _docField = 'funnelOnboardingV2';

  /// ② 캐릭터 밥주기 (최초 1회)
  static Future<void> tryLogFirstFeed() async {
    await _trySetAndLog(key: 'feed', funnelType: FunnelEventType.onboardingFeed);
  }

  /// ③ 공감투표 **첫** 선택 (이미 투표한 적 있으면 스킵)
  static Future<void> tryLogFirstPoll() async {
    await _trySetAndLog(key: 'poll', funnelType: FunnelEventType.onboardingPoll);
  }

  /// ④ 퀴즈 **첫** 제출
  static Future<void> tryLogFirstQuiz() async {
    await _trySetAndLog(key: 'quiz', funnelType: FunnelEventType.onboardingQuiz);
  }

  /// ⑤ 커리어 **전문분야(specialtyTags)** 저장 (최초 1회, 태그 1개 이상일 때만 호출)
  static Future<void> tryLogFirstCareerSpecialty() async {
    await _trySetAndLog(
      key: 'career',
      funnelType: FunnelEventType.onboardingCareerSpecialty,
    );
  }

  static Future<void> _trySetAndLog({
    required String key,
    required FunnelEventType funnelType,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final ref = _db.collection('users').doc(uid);
      final shouldLog = await _db.runTransaction<bool>((transaction) async {
        final snap = await transaction.get(ref);
        final data = snap.data() ?? <String, dynamic>{};
        final raw = data[_docField];
        final map = <String, dynamic>{};
        if (raw is Map) {
          for (final e in raw.entries) {
            final k = e.key;
            if (k is String) map[k] = e.value;
          }
        }
        if (map[key] == true) return false;
        map[key] = true;
        transaction.set(ref, {_docField: map}, SetOptions(merge: true));
        return true;
      });

      if (shouldLog == true) {
        AdminActivityService.logFunnel(funnelType);
      }
    } catch (e, st) {
      debugPrint('⚠️ FunnelOnboardingService._trySetAndLog($key): $e');
      debugPrint('$st');
    }
  }
}
