import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../data/caring_ments.dart';
import '../services/admin_activity_service.dart';
import '../services/caring_state_service.dart';
import '../services/funnel_onboarding_service.dart';

/// 돌보기(나 탭) 액션 처리 서비스
///
/// ── 핵심 정책 ────────────────────────────────
/// 밥주기:
///   1회차(정상): hunger+25, mood+8, bond+2
///   2회차(10분내 연속): hunger+15, mood-3, energy-8
///   3회차: 1시간 쿨타임 차단
///   과식(hunger≥85, 우선): hunger+5, mood-2, energy-3
///   mood<30 → bond 절반(내림), energy<30 → 리액션 확률 50%
/// 터치:
///   1~3회: mood+5, bond+1
///   4~6회: mood+1, bond+0
///   7회+: mood-1
///   energy<30 → mood 보상 절반(내림), mood<30 → bond 절반(내림)
/// 재우기:
///   ≤30분 깨우기: energy+0, mood-5
///   >30분: energy+h*12.5, mood+5
/// ──────────────────────────────────────────────
class CaringActionService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static final _random = Random();

  static Future<String?> _ensureUidReady({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final current = _auth.currentUser?.uid;
    if (current != null) return current;
    try {
      final user = await _auth
          .authStateChanges()
          .firstWhere((u) => u != null)
          .timeout(timeout);
      return user?.uid;
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════ 앱 진입 정산 ═══════════════════════

  static Future<void>? _dailySettleInFlight;

  /// 앱 시작 시 호출: 시간 경과 반영 + 일일 리셋
  static Future<void> dailySettle() async {
    _dailySettleInFlight ??= _dailySettleInternal().whenComplete(() {
      _dailySettleInFlight = null;
    });
    return _dailySettleInFlight!;
  }

  static Future<void> _dailySettleInternal() async {
    try {
      final uid = await _ensureUidReady();
      if (uid == null) return;
      // loadState(applyTimeDecay: true)가 시간 경과 + 일일 리셋을 처리
      await CaringStateService.loadState(applyTimeDecay: true);
      debugPrint('✅ dailySettle 완료');
    } catch (e) {
      debugPrint('⚠️ CaringActionService.dailySettle error: $e');
    }
  }

  // ═══════════════════════ 밥주기 (Feed) ═══════════════════════

  static const int _feedConsecutiveWindowMin = 10;
  static const int _feedCooldownMin = 60;

  /// 연속 판정 → 쿨타임 → 과식 우선 → 상태 연동
  static Future<FeedResult> tryFeed() async {
    try {
      final uid = await _ensureUidReady();
      if (uid == null) {
        return FeedResult(success: false, rejectMent: '로그인이 필요합니다.');
      }

      final state = await CaringStateService.loadState();

      if (state.isSleeping) {
        return FeedResult(
          success: false,
          rejectMent: _pickRandom(CaringMents.feedWhileSleeping),
        );
      }

      final now = DateTime.now();
      var feedCount = state.consecutiveFeedCount;
      final lastFeed = state.lastFeedAt;

      // ── 연속 카운트 리셋 판정 ──
      if (lastFeed != null) {
        final elapsed = now.difference(lastFeed);
        if (feedCount >= 2 && elapsed.inMinutes >= _feedCooldownMin) {
          feedCount = 0;
        } else if (feedCount >= 2) {
          final remaining = _feedCooldownMin - elapsed.inMinutes;
          return FeedResult(
            success: false,
            rejectMent: '${_pickRandom(CaringMents.feedCooldown)} (${remaining}분 후)',
          );
        } else if (feedCount == 1 && elapsed.inMinutes >= _feedConsecutiveWindowMin) {
          feedCount = 0;
        }
      }

      final bool isOverfed = state.hunger >= 85;
      final bool isConsecutive = feedCount == 1;

      double hungerDelta, moodDelta, energyDelta, bondDelta;

      if (isOverfed) {
        hungerDelta = 5; moodDelta = -2; energyDelta = -3; bondDelta = 0;
      } else if (isConsecutive) {
        hungerDelta = 15; moodDelta = -3; energyDelta = -8; bondDelta = 0;
      } else {
        hungerDelta = 25; moodDelta = 8; energyDelta = 0; bondDelta = 2;
      }

      // mood < 30 → bond 보상 절반 (내림)
      if (state.mood < 30 && bondDelta > 0) {
        bondDelta = (bondDelta / 2).floorToDouble();
      }

      final updated = state.copyWith(
        hunger: state.hunger + hungerDelta,
        mood: state.mood + moodDelta,
        energy: state.energy + energyDelta,
        bond: state.bond + bondDelta,
        consecutiveFeedCount: feedCount + 1,
        lastFeedAt: now,
        lastActiveAt: now,
      );

      unawaited(CaringStateService.saveState(updated));

      String ment;
      if (isOverfed) {
        ment = _pickRandom(CaringMents.feedOverfed);
      } else if (isConsecutive) {
        ment = _pickRandom(CaringMents.feedConsecutive);
      } else {
        ment = _pickRandom(CaringMents.feedSuccessSimple);
      }

      AdminActivityService.log(
        ActivityEventType.caringFeedSuccess,
        page: 'home',
      );
      unawaited(FunnelOnboardingService.tryLogFirstFeed());

      return FeedResult(
        success: true,
        ment: ment,
        isOverfed: isOverfed,
        isConsecutive: isConsecutive,
        state: updated,
      );
    } catch (e) {
      debugPrint('⚠️ CaringActionService.tryFeed error: $e');
      return FeedResult(success: false, rejectMent: '오류가 발생했어요.');
    }
  }

  // ═══════════════════════ 터치 (Touch) ═══════════════════════

  /// 1~3: mood+5, bond+1 | 4~6: mood+1, bond+0 | 7+: mood-1
  /// energy<30 → mood 보상 절반 | mood<30 → bond 절반
  static Future<TouchResult> tryTouch() async {
    try {
      final uid = await _ensureUidReady();
      if (uid == null) {
        return TouchResult(ment: '로그인이 필요합니다.', state: null);
      }

      final state = await CaringStateService.loadState();

      if (state.isSleeping) {
        return TouchResult(
          ment: _pickRandom(CaringMents.feedWhileSleeping),
          state: null,
        );
      }

      final now = DateTime.now();
      final count = state.touchCountToday;

      double moodDelta;
      double bondDelta;

      if (count < 3) {
        moodDelta = 5; bondDelta = 1;
      } else if (count < 6) {
        moodDelta = 1; bondDelta = 0;
      } else {
        moodDelta = -1; bondDelta = 0;
      }

      // energy < 30 → mood 보상 절반 (내림, 양수일 때만)
      if (state.energy < 30 && moodDelta > 0) {
        moodDelta = (moodDelta / 2).floorToDouble();
      }

      // mood < 30 → bond 보상 절반 (내림, 양수일 때만)
      if (state.mood < 30 && bondDelta > 0) {
        bondDelta = (bondDelta / 2).floorToDouble();
      }

      final updated = state.copyWith(
        mood: state.mood + moodDelta,
        bond: state.bond + bondDelta,
        touchCountToday: count + 1,
        lastActiveAt: now,
      );

      unawaited(CaringStateService.saveState(updated));

      final ment = _pickTouchMent(state, count);

      return TouchResult(
        ment: ment,
        isEffective: count < 3,
        state: updated,
      );
    } catch (e) {
      debugPrint('⚠️ CaringActionService.tryTouch error: $e');
      return TouchResult(ment: '오류가 발생했어요.', state: null);
    }
  }

  static String _pickTouchMent(CaringState state, int count) {
    if (count >= 7) return _pickRandom(CaringMents.touchTired);
    if (count == 0) return _pickRandom(CaringMents.touchFirst);
    if (state.hunger < 40) return _pickRandom(CaringMents.touchHungry);
    if (state.mood > 70) return _pickRandom(CaringMents.touchHappy);
    if (state.bond > 60) return _pickRandom(CaringMents.touchClose);
    return _pickRandom(CaringMents.touchGeneral);
  }

  // ═══════════════════════ 재우기 / 깨우기 ═══════════════════════

  /// 재우기 시작
  static Future<CaringState> startSleep() async {
    final state = await CaringStateService.loadState();
    if (state.isSleeping) return state;
    await CaringStateService.sleep(state);
    return state.copyWith(
      isSleeping: true,
      sleepStartedAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
    );
  }

  /// 깨우기 — 30분 이하 패널티 / 초과 회복 + 상황별 멘트
  static Future<WakeResult> wakeUp() async {
    final state = await CaringStateService.loadState();
    if (!state.isSleeping) {
      return WakeResult(state: state, ment: '이미 깨어 있어요.');
    }

    final isShort = state.sleepStartedAt != null &&
        DateTime.now().difference(state.sleepStartedAt!).inMinutes <=
            CaringStateService.shortSleepThresholdMin;

    final woken = await CaringStateService.wake(state);
    final ment = isShort
        ? _pickRandom(CaringMents.sleepShort)
        : _pickRandom(CaringMents.sleepWake);

    return WakeResult(state: woken, ment: ment, isShortSleep: isShort);
  }

  // ═══════════════════════ 글쓰기 (기존 호환) ═══════════════════════

  /// 글쓰기 완료 (1탭에서 숨겼지만 서비스는 유지)
  static Future<DiaryResult> completeDiary() async {
    try {
      final uid = await _ensureUidReady();
      if (uid == null) {
        return DiaryResult(ment: '로그인이 필요합니다.');
      }

      final state = await CaringStateService.loadState();
      final now = DateTime.now();

      final updated = state.copyWith(
        mood: state.mood + 5,
        bond: state.bond + 1,
        lastActiveAt: now,
      );
      unawaited(CaringStateService.saveState(updated));

      final ment = _pickRandom(CaringMents.diary);
      return DiaryResult(ment: ment, state: updated);
    } catch (e) {
      debugPrint('⚠️ CaringActionService.completeDiary error: $e');
      return DiaryResult(ment: '오류가 발생했어요.');
    }
  }

  // ═══════════════════════ 목표 (기존 호환) ═══════════════════════

  static Future<GoalResult> handleGoalAction(GoalAction action) async {
    try {
      final uid = await _ensureUidReady();
      if (uid == null) {
        return GoalResult(ment: '로그인이 필요합니다.');
      }

      List<String> mentPool;
      switch (action) {
        case GoalAction.created:
          mentPool = CaringMents.goalCreated;
        case GoalAction.checked:
          mentPool = CaringMents.goalChecked;
        case GoalAction.completed:
          mentPool = CaringMents.goalCompleted;
        case GoalAction.missed:
          mentPool = CaringMents.goalMissed;
        case GoalAction.restarted:
          mentPool = CaringMents.goalRestarted;
      }
      return GoalResult(ment: _pickRandom(mentPool));
    } catch (e) {
      debugPrint('⚠️ CaringActionService.handleGoalAction error: $e');
      return GoalResult(ment: '오류가 발생했어요.');
    }
  }

  // ═══════════════════════ 이벤트 감지 ═══════════════════════

  /// 앱 진입 시 이벤트 감지 + lastOpenAt 업데이트
  static Future<List<String>> detectOpenEvents() async {
    final events = <String>[];
    try {
      final uid = await _ensureUidReady();
      if (uid == null) return events;

      final userRef = _db.collection('users').doc(uid);
      final doc = await userRef.get();
      final data = doc.data() ?? {};

      final lastOpenAt = (data['lastOpenAt'] as Timestamp?)?.toDate();
      if (lastOpenAt != null) {
        final daysDiff = DateTime.now().difference(lastOpenAt).inDays;
        if (daysDiff >= 3) {
          events.add('absence_3days');
          debugPrint('[EventDetect] absence_3days detected (${daysDiff}days)');
        }
      }

      await userRef.set(
        {'lastOpenAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

      final careerProfile = data['careerProfile'] as Map<String, dynamic>?;
      final skills = (careerProfile?['skills'] as Map<String, dynamic>?) ?? {};
      final lastSkillSnap =
          (data['lastKnownSkillLevels'] as Map<String, dynamic>?) ?? {};

      bool skillLeveledUp = false;
      final currentSkillSnap = <String, dynamic>{};
      for (final entry in skills.entries) {
        final skillId = entry.key;
        final currentLevel =
            ((entry.value as Map<String, dynamic>?)?['level'] as int?) ?? 0;
        currentSkillSnap[skillId] = currentLevel;
        final lastLevel = (lastSkillSnap[skillId] as int?) ?? 0;
        if (currentLevel > lastLevel) skillLeveledUp = true;
      }
      if (skillLeveledUp) {
        events.add('skill_up');
        debugPrint('[EventDetect] skill_up detected');
      }

      final lastNetworkCount = (data['lastKnownNetworkCount'] as int?) ?? -1;
      final networkSnap = await _db
          .collection('users')
          .doc(uid)
          .collection('careerNetwork')
          .get();
      final currentNetworkCount = networkSnap.docs.length;
      if (lastNetworkCount >= 0 && currentNetworkCount > lastNetworkCount) {
        events.add('new_workplace');
        debugPrint('[EventDetect] new_workplace detected');
      }

      await userRef.set({
        'lastKnownSkillLevels': currentSkillSnap,
        'lastKnownNetworkCount': currentNetworkCount,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ CaringActionService.detectOpenEvents error: $e');
    }
    return events;
  }

  // ═══════════════════════ 유틸 ═══════════════════════

  static String _pickRandom(List<String> pool) {
    if (pool.isEmpty) return '';
    return pool[_random.nextInt(pool.length)];
  }
}

// ═══════════════════════ 결과 객체들 ═══════════════════════

class FeedResult {
  final bool success;
  final String? ment;
  final String? rejectMent;
  final bool isOverfed;
  final bool isConsecutive;
  final CaringState? state;

  FeedResult({
    required this.success,
    this.ment,
    this.rejectMent,
    this.isOverfed = false,
    this.isConsecutive = false,
    this.state,
  });
}

class TouchResult {
  final String ment;
  final bool isEffective;
  final CaringState? state;

  TouchResult({required this.ment, this.isEffective = true, this.state});
}

class WakeResult {
  final CaringState state;
  final String ment;
  final bool isShortSleep;

  WakeResult({required this.state, required this.ment, this.isShortSleep = false});
}

class DiaryResult {
  final String ment;
  final CaringState? state;

  DiaryResult({required this.ment, this.state});
}

class GoalResult {
  final String ment;

  GoalResult({required this.ment});
}

enum GoalAction { created, checked, completed, missed, restarted }
