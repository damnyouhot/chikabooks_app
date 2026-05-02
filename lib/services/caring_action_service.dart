import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../data/caring_ments.dart';
import '../services/admin_activity_service.dart';
import '../services/caring_state_service.dart';
import '../services/caring_treat_service.dart';
import '../services/funnel_onboarding_service.dart';

/// 돌보기(나 탭) 액션 처리 서비스
///
/// **낙관적 UI ([fromLocal]):** [tryFeed]/[tryTouch]/[startSleep]/[wakeUp]에 `fromLocal`을 넘기면
/// `loadState()` 없이 해당 스냅샷만으로 계산하고 **저장은 호출자**가
/// [CaringStateService.saveStateSequential]로 처리한다.
/// 나 탭은 `dailySettle`·초기 로드 완료 전에는 액션을 열지 않는다.
///
/// ── 핵심 정책 ────────────────────────────────
/// 밥주기:
///   1회차(정상): hunger+25, mood+6, bond+1 (mood<30이면 bond 절반)
///   2회차(10분내 연속): hunger+15, mood-3, energy-8
///   3회차: 1시간 쿨타임 차단
///   과식(hunger≥85, 우선): hunger+5, mood-2, energy-3
///   mood<30 → bond 절반(내림), energy<30 → 리액션 확률 50%
///   보유 먹이(caringTreatCount)가 [CaringTreatService.feedCost] 미만이면 밥주기 불가
///   (먹이 적립: 퀴즈·공감투표·속닥속닥·오늘 단어 등 — [CaringTreatService] 참고)
/// 터치 (최근 3시간 슬라이딩 윈도우 내 횟수):
///   1~3회: mood+5, bond+1
///   4~6회: mood+1, bond+0
///   7회+: 변화 없음
///   energy<30 → mood 보상 절반(내림), mood<30 → bond 절반(내림)
/// 씻기기:
///   캐릭터 직접 터치. cleanliness+2, mood+0.1, energy-0.2
///   cleanliness≥85면 cleanliness+1, energy-0.1 / 100이면 cleanliness+0, energy-0.1
///   bond는 즉시 상승하지 않고 청결 유지 시간으로 정산
/// 재우기:
///   ≤30분 깨우기: energy+0, mood-5
///   >30분 & <12시간: energy+h*6(최대 8h), mood+5
///   ≥12시간: energy 회복 동일, mood-2, mood+5 없음, 일일 bond+1 없음(감쇠 시). 수면 중 bond는 감쇠에서만.
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
  ///
  /// [fromLocal]이 null이면 서버에서 [CaringStateService.loadState] 후 저장까지 수행.
  /// null이 아니면 해당 상태만 사용·저장은 하지 않음(호출자가 순차 저장).
  static Future<FeedResult> tryFeed({CaringState? fromLocal}) async {
    try {
      final uid = await _ensureUidReady();
      if (uid == null) {
        return FeedResult(success: false, rejectMent: '로그인이 필요합니다.');
      }

      final state = fromLocal ?? await CaringStateService.loadState();

      if (state.isSleeping) {
        return FeedResult(
          success: false,
          rejectMent: _pickRandom(CaringMents.feedWhileSleeping),
        );
      }

      final treatCount = await CaringTreatService.getTreatCount();
      if (treatCount < CaringTreatService.feedCost) {
        return FeedResult(
          success: false,
          rejectMent: '밥주기에는 먹이 ${CaringTreatService.feedCost}개가 필요해요.',
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
            rejectMent:
                '${_pickRandom(CaringMents.feedCooldown)} ($remaining분 후)',
          );
        } else if (feedCount == 1 &&
            elapsed.inMinutes >= _feedConsecutiveWindowMin) {
          feedCount = 0;
        }
      }

      final bool isOverfed = state.hunger >= 85;
      final bool isConsecutive = feedCount == 1;

      double hungerDelta, moodDelta, energyDelta, bondDelta;

      if (isOverfed) {
        hungerDelta = 5;
        moodDelta = -2;
        energyDelta = -3;
        bondDelta = 0;
      } else if (isConsecutive) {
        hungerDelta = 15;
        moodDelta = -3;
        energyDelta = -8;
        bondDelta = 0;
      } else {
        hungerDelta = 25;
        moodDelta = 6;
        energyDelta = 0;
        bondDelta = 1;
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

      if (fromLocal == null) {
        await CaringStateService.saveState(updated);
        AdminActivityService.log(
          ActivityEventType.caringFeedSuccess,
          page: 'home',
        );
        unawaited(FunnelOnboardingService.tryLogFirstFeed());
      }

      String ment;
      if (isOverfed) {
        ment = _pickRandom(CaringMents.feedOverfed);
      } else if (isConsecutive) {
        ment = _pickRandom(CaringMents.feedConsecutive);
      } else {
        ment = _pickRandom(CaringMents.feedSuccessSimple);
      }

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

  /// 최근 3시간 내 횟수 — 1~3: mood+5, bond+1 | 4~6: mood+1, bond+0 | 7+: 변화 없음
  /// energy<30 → mood 보상 절반 | mood<30 → bond 절반
  ///
  /// [fromLocal]: [tryFeed]와 동일. null이면 로드 후 저장, 아니면 저장 생략.
  static Future<TouchResult> tryTouch({CaringState? fromLocal}) async {
    try {
      final uid = await _ensureUidReady();
      if (uid == null) {
        return TouchResult(ment: '로그인이 필요합니다.', state: null);
      }

      final state = fromLocal ?? await CaringStateService.loadState();

      if (state.isSleeping) {
        return TouchResult(
          ment: _pickRandom(CaringMents.feedWhileSleeping),
          state: null,
        );
      }

      final now = DateTime.now();
      final trimmed = CaringState.trimTouchesToWindow(
        state.touchTimestamps,
        now,
        CaringStateService.touchCountWindow,
      );
      final count = trimmed.length;

      double moodDelta;
      double bondDelta;
      final todayKey = _dateKey(now);
      final dailyTouchBondGain =
          state.touchBondDateKey == todayKey ? state.dailyTouchBondGain : 0;

      if (count < 3) {
        moodDelta = 5;
        bondDelta = dailyTouchBondGain < 3 ? 1 : 0;
      } else if (count < 6) {
        moodDelta = 1;
        bondDelta = 0;
      } else {
        moodDelta = 0;
        bondDelta = 0;
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
        touchTimestamps: [...trimmed, now],
        touchBondDateKey: todayKey,
        dailyTouchBondGain:
            dailyTouchBondGain + (bondDelta > 0 ? bondDelta.toInt() : 0),
        lastActiveAt: now,
      );

      if (fromLocal == null) {
        await CaringStateService.saveState(updated);
      }

      final ment = _pickTouchMent(state, count);

      return TouchResult(ment: ment, isEffective: count < 3, state: updated);
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

  // ═══════════════════════ 씻기기 (Wash) ═══════════════════════

  static Future<WashResult> tryWash({CaringState? fromLocal}) async {
    try {
      final uid = await _ensureUidReady();
      if (uid == null) {
        return WashResult(ment: '로그인이 필요합니다.', state: null);
      }

      final state = fromLocal ?? await CaringStateService.loadState();

      if (state.isSleeping) {
        return WashResult(
          ment: _pickRandom(CaringMents.feedWhileSleeping),
          state: null,
        );
      }

      final now = DateTime.now();
      final before = state.cleanliness;
      final cleanDelta =
          before >= 100
              ? 0.0
              : before >= 85
              ? 1.0
              : 2.0;
      final energyDelta = before >= 85 ? -0.1 : -0.2;
      final after = (before + cleanDelta).clamp(0.0, 100.0);

      final updated = state.copyWith(
        cleanliness: after,
        mood: state.mood + 0.1,
        energy: state.energy + energyDelta,
        lastWashedAt: now,
        lastActiveAt: now,
        cleanlinessGoodSince:
            after >= CaringStateService.cleanBondGoodThreshold
                ? state.cleanlinessGoodSince ?? now
                : null,
        cleanlinessBadSince:
            after < CaringStateService.cleanBondBadThreshold
                ? state.cleanlinessBadSince ?? now
                : null,
        clearCleanlinessGoodSince:
            after < CaringStateService.cleanBondGoodThreshold,
        clearCleanlinessBadSince:
            after >= CaringStateService.cleanBondBadThreshold,
      );

      if (fromLocal == null) {
        await CaringStateService.saveState(updated);
      }

      return WashResult(ment: _pickWashMent(state, after), state: updated);
    } catch (e) {
      debugPrint('⚠️ CaringActionService.tryWash error: $e');
      return WashResult(ment: '오류가 발생했어요.', state: null);
    }
  }

  static String? _pickWashMent(CaringState state, double after) {
    final before = state.cleanliness;
    if (state.lastWashedAt == null) {
      return _pickRandom(CaringMents.washFirst);
    }
    if (before < 30 && after >= 30) {
      return _pickRandom(CaringMents.washRecover30);
    }
    if (before < 70 && after >= 70) {
      return _pickRandom(CaringMents.washRecover70);
    }
    if (before < 95 && after >= 95) {
      return _pickRandom(CaringMents.washSparkle);
    }
    if (before < 20 && _random.nextInt(3) == 0) {
      return _pickRandom(CaringMents.washDirty);
    }
    if (before >= 95 && _random.nextInt(5) == 0) {
      return _pickRandom(CaringMents.washAlreadyClean);
    }
    return null;
  }

  // ═══════════════════════ 재우기 / 깨우기 ═══════════════════════

  /// 재우기 시작
  ///
  /// [fromLocal]이 있으면 `loadState`·내부 저장 생략, 잠든 상태만 계산해 반환(저장은 호출자).
  /// 없으면 기존처럼 서버 로드 후 [CaringStateService.sleep]까지 수행.
  static Future<CaringState> startSleep({CaringState? fromLocal}) async {
    if (fromLocal != null) {
      if (fromLocal.isSleeping) return fromLocal;
      final now = DateTime.now();
      return fromLocal.copyWith(
        isSleeping: true,
        sleepStartedAt: now,
        lastActiveAt: now,
      );
    }
    final state = await CaringStateService.loadState();
    if (state.isSleeping) return state;
    await CaringStateService.sleep(state);
    final now = DateTime.now();
    return state.copyWith(
      isSleeping: true,
      sleepStartedAt: now,
      lastActiveAt: now,
    );
  }

  /// 깨우기 — 30분 이하 패널티 / 초과 회복 + 상황별 멘트
  ///
  /// [fromLocal]: [startSleep]과 동일. 있으면 서버 읽기 없이 판단·벌점 일관성 확보.
  /// 멘트 분기와 [CaringStateService.wake]는 동일 [DateTime]으로 맞춤.
  static Future<WakeResult> wakeUp({CaringState? fromLocal}) async {
    final state = fromLocal ?? await CaringStateService.loadState();
    if (!state.isSleeping) {
      return WakeResult(state: state, ment: '이미 깨어 있어요.');
    }

    final clock = DateTime.now();
    final sleepElapsed =
        state.sleepStartedAt != null
            ? clock.difference(state.sleepStartedAt!)
            : Duration.zero;
    final isShort =
        sleepElapsed.inMinutes <= CaringStateService.shortSleepThresholdMin;
    final isLongSleep = sleepElapsed >= CaringStateService.longSleepThreshold;

    final woken = await CaringStateService.wake(
      state,
      persist: fromLocal == null,
      now: clock,
    );
    final ment =
        isShort
            ? _pickRandom(CaringMents.sleepShort)
            : isLongSleep
            ? CaringMents.sleepWakeLongMent
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
      await CaringStateService.saveState(updated);

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

      await userRef.set({
        'lastOpenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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
      final networkSnap =
          await _db
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

  static String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
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

class WashResult {
  final String? ment;
  final CaringState? state;

  WashResult({required this.ment, this.state});
}

class WakeResult {
  final CaringState state;
  final String ment;
  final bool isShortSleep;

  WakeResult({
    required this.state,
    required this.ment,
    this.isShortSleep = false,
  });
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
