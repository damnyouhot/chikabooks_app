import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../config/reward_constants.dart';

/// 돌보기(1탭) 상태 서비스
///
/// hunger / mood / energy / bond / cleanliness 5개 상태 + 시간 경과 시스템.
/// users/{uid} 문서의 caringState 필드를 사용.
///
/// **수면·깨우기 ([wake]):** 짧은 수면(≤30분)은 기분 벌점만. 그 외는 에너지 회복(시간당 +6, 최대 8h분).
/// 12시간 이상은 기분 패널티·고정 멘트(액션 서비스). 장시간 수면 bond는 [_applyTimeDecay]에서만 처리.
/// 수면 중 시간 감쇠는 배고픔만.
///
/// **저장:** [saveState] / [saveStateSequential]는 동일 FIFO 큐로 처리되어
/// `caringState` 전체 덮어쓰기가 동시에 끝나며 순서가 뒤바뀌지 않도록 한다.
class CaringStateService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static DocumentReference<Map<String, dynamic>>? get _userRef {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  // ═══════════════════════ 상수 ═══════════════════════

  /// 시간당 감소량
  static const double hungerDecayPerHour = 8.0;
  static const double moodDecayPerHour = 6.0;
  static const double energyDecayPerHour = 4.0;
  static const double cleanlinessDecayPerHourAwake = 10.0;
  static const double cleanlinessDecayPerHourSleeping = 8.0;

  /// 시간 감소 하한 캡 (이 아래로는 떨어지지 않음)
  static const double hungerFloor = 5.0;
  static const double moodFloor = 15.0;
  static const double energyFloor = 5.0;
  static const double cleanlinessFloor = 0.0;

  /// 수면 — energy 시간당 회복량, 최대 반영 시간
  static const double sleepEnergyPerHour = 6.0;
  static const double sleepMaxHours = 8.0;
  static const double sleepMoodBonus = 5.0;

  /// 이 시간 이상 수면 후 깨우면: 기분 +5 없음, 기분·유대 패널티 적용.
  /// [_applyTimeDecay] 중 수면이면서 이 이상이면 일일 bond +1도 생략.
  static const Duration longSleepThreshold = Duration(hours: 12);
  static const double longSleepMoodPenalty = 2.0;

  /// bond 미접속 패널티
  static const double bondAbsencePenaltyPerDay = 2.0;
  static const double bondAbsenceMaxPenalty = 6.0;

  /// bond — 정산 구간 내 밥 없음: [bondUnfedHoursPerPenalty]시간마다 −1
  static const double bondUnfedHoursPerPenalty = 8.0;
  static const int bondUnfedPenaltyPerStep = 1;

  /// bond — 연속 깨어 있음: [bondAwakeHoursPerPenalty]시간마다 −1 ([lastWakeAt] 기준)
  static const double bondAwakeHoursPerPenalty = 20.0;
  static const int bondAwakePenaltyPerStep = 1;

  /// bond — 연속 수면: [bondSleepHoursPerPenalty]시간마다 −2
  static const double bondSleepHoursPerPenalty = 12.0;
  static const int bondSleepPenaltyPerStep = 2;

  /// 쓰다듬기 효과 구간 — 최근 이 시간 안의 터치만 집계
  static const Duration touchCountWindow = Duration(hours: 3);

  /// 청결 유지 기반 유대 정산
  static const double cleanBondHighThreshold = 85.0;
  static const double cleanBondGoodThreshold = 70.0;
  static const double cleanBondBadThreshold = 50.0;
  static const double cleanBondVeryBadThreshold = 30.0;
  static const int cleanBondHighRewardHours = 4;
  static const int cleanBondGoodRewardHours = 6;
  static const int cleanBondBadPenaltyHours = 3;
  static const int cleanBondVeryBadPenaltyHours = 3;
  static const int cleanBondPenaltyPerStep = 1;
  static const int cleanBondDailyGainCap = 4;
  static const int cleanBondDailyLossCap = 6;

  /// 관리 실패 기반 유대 패널티
  static const double hungerBondBadThreshold = 30.0;
  static const int hungerBondBadPenaltyHours = 3;
  static const int hungerBondPenaltyPerStep = 2;
  static const double energyBondBadThreshold = 25.0;
  static const int energyBondBadPenaltyHours = 5;
  static const int energyBondPenaltyPerStep = 2;

  // ═══════════════════════ 읽기 ═══════════════════════

  /// 상태 로드 → 시간 경과 반영 → 반환
  ///
  /// [applyTimeDecay] = true면 경과 시간만큼 상태를 감소시킨 뒤 Firestore에 저장.
  /// UI에서 최초 로드 시만 true, 액션 내부에서는 false로 호출.
  static Future<CaringState> loadState({bool applyTimeDecay = false}) async {
    try {
      final ref = _userRef;
      if (ref == null) return CaringState.initial();

      DocumentSnapshot<Map<String, dynamic>> doc;
      try {
        doc = await ref.get(const GetOptions(source: Source.cache));
      } catch (_) {
        doc = await ref.get();
      }
      final data = doc.data();
      if (data == null) return CaringState.initial();

      final cs = data['caringState'] as Map<String, dynamic>?;
      if (cs == null) return CaringState.initial();

      var state = CaringState.fromMap(cs);

      if (applyTimeDecay) {
        state = _applyTimeDecay(state, DateTime.now());
        await saveState(state);
      }

      return state;
    } catch (e) {
      debugPrint('⚠️ CaringStateService.loadState error: $e');
      return CaringState.initial();
    }
  }

  // ═══════════════════════ 시간 경과 ═══════════════════════

  /// 배고픔 → mood 감소 가속 추가치
  static const double hungerMoodAccel = 1.0;

  /// 오프라인 시간 반영 (순수 함수)
  ///
  /// 수면 중: 배고픔은 깨어 있을 때와 동일 비율로 감소. 기분·에너지 시간감소 없음.
  /// 에너지·기분 회복은 wake()에서만 처리.
  static CaringState _applyTimeDecay(CaringState state, DateTime now) {
    final lastActive = state.lastActiveAt ?? now;
    final elapsed = now.difference(lastActive);
    final hours = elapsed.inMinutes / 60.0;

    double hunger = state.hunger;
    double mood = state.mood;
    double energy = state.energy;
    double bond = state.bond;
    double cleanliness = state.cleanliness;
    var cleanlinessGoodSince = state.cleanlinessGoodSince;
    var cleanlinessBadSince = state.cleanlinessBadSince;
    var lastCleanBondRewardAt = state.lastCleanBondRewardAt;
    var lastCleanBondPenaltyAt = state.lastCleanBondPenaltyAt;
    var hungerLowSince = state.hungerLowSince;
    var energyLowSince = state.energyLowSince;
    var lastHungerBondPenaltyAt = state.lastHungerBondPenaltyAt;
    var lastEnergyBondPenaltyAt = state.lastEnergyBondPenaltyAt;
    var cleanBondDateKey = state.cleanBondDateKey;
    var dailyCleanBondGain = state.dailyCleanBondGain;
    var dailyCleanBondLoss = state.dailyCleanBondLoss;
    var dailyVisitDateKey = state.dailyVisitDateKey;
    var dailyVisitCount = state.dailyVisitCount;

    final todayKey = _dateKey(now);
    if (cleanBondDateKey != todayKey) {
      cleanBondDateKey = todayKey;
      dailyCleanBondGain = 0;
      dailyCleanBondLoss = 0;
    }

    final skipDailyBondForLongSleep =
        state.isSleeping &&
        state.sleepStartedAt != null &&
        now.difference(state.sleepStartedAt!) >= longSleepThreshold;

    if (dailyVisitDateKey != todayKey) {
      dailyVisitDateKey = todayKey;
      dailyVisitCount = 0;
    }
    dailyVisitCount += 1;
    if (!skipDailyBondForLongSleep) {
      if (dailyVisitCount == 1) {
        bond = min(100, bond + 2);
        debugPrint('✅ 일일 첫 접속 bond +2');
      } else if (dailyVisitCount == 3 || dailyVisitCount == 5) {
        bond = min(100, bond + 1);
        debugPrint('✅ 일일 $dailyVisitCount회 접속 bond +1');
      }
    }

    if (hours < 0.05) {
      return state.copyWith(
        bond: bond,
        lastActiveAt: now,
        cleanBondDateKey: cleanBondDateKey,
        dailyCleanBondGain: dailyCleanBondGain,
        dailyCleanBondLoss: dailyCleanBondLoss,
        dailyVisitDateKey: dailyVisitDateKey,
        dailyVisitCount: dailyVisitCount,
      );
    }

    if (state.isSleeping) {
      hunger = max(hungerFloor, hunger - hours * hungerDecayPerHour);
      cleanliness = max(
        cleanlinessFloor,
        cleanliness - hours * cleanlinessDecayPerHourSleeping,
      );
    } else {
      // hunger < 30 → mood 시간감소 +1/h 가속
      final effectiveMoodDecay =
          hunger < 30 ? moodDecayPerHour + hungerMoodAccel : moodDecayPerHour;

      hunger = max(hungerFloor, hunger - hours * hungerDecayPerHour);
      mood = max(moodFloor, mood - hours * effectiveMoodDecay);
      energy = max(energyFloor, energy - hours * energyDecayPerHour);
      cleanliness = max(
        cleanlinessFloor,
        cleanliness - hours * cleanlinessDecayPerHourAwake,
      );
    }

    // ── bond 미접속 패널티 (24h 초과분만) ──
    if (hours >= 24) {
      final absentDays = (hours / 24).floor();
      final penalty = min(
        absentDays * bondAbsencePenaltyPerDay,
        bondAbsenceMaxPenalty,
      );
      bond = max(0, bond - penalty);
      debugPrint('🔻 bond 미접속 패널티: -$penalty ($absentDays일)');
    }

    // ── bond: 밥 안 준 누적 시간 → 8h당 -1
    // 낮은 배고픔 상태 패널티가 메인이므로, 기존 밥 없음 패널티는 보조 안전장치로 유지.
    final t0 = state.lastActiveAt ?? now;
    final lastFeed = state.lastFeedAt;
    final double unfedHours =
        lastFeed != null
            ? max(0.0, now.difference(lastFeed).inMinutes / 60.0)
            : hours;
    final starvePenalty =
        (unfedHours / bondUnfedHoursPerPenalty).floor() *
        bondUnfedPenaltyPerStep;
    if (starvePenalty > 0) {
      bond = max(0.0, bond - starvePenalty);
      debugPrint(
        '🔻 bond 밥 없음: -$starvePenalty (${unfedHours.toStringAsFixed(1)}h)',
      );
    }

    // ── bond: 연속 깨어 있음 → 20h당 -1 ([lastWakeAt] 없으면 이번 구간 시작 t0) ──
    if (!state.isSleeping) {
      final wakeRef = state.lastWakeAt ?? t0;
      final awakeHours = now.difference(wakeRef).inMinutes / 60.0;
      if (awakeHours > 0) {
        final awakePenalty =
            (awakeHours / bondAwakeHoursPerPenalty).floor() *
            bondAwakePenaltyPerStep;
        if (awakePenalty > 0) {
          bond = max(0.0, bond - awakePenalty);
          debugPrint(
            '🔻 bond 연속 깨어 있음: -$awakePenalty (${awakeHours.toStringAsFixed(1)}h)',
          );
        }
      }
    }

    // ── bond: 연속 수면 → 12h당 -2 ──
    if (state.isSleeping && state.sleepStartedAt != null) {
      final sleepHours = now.difference(state.sleepStartedAt!).inMinutes / 60.0;
      if (sleepHours > 0) {
        final sleepPenalty =
            (sleepHours / bondSleepHoursPerPenalty).floor() *
            bondSleepPenaltyPerStep;
        if (sleepPenalty > 0) {
          bond = max(0.0, bond - sleepPenalty);
          debugPrint(
            '🔻 bond 연속 수면: -$sleepPenalty (${sleepHours.toStringAsFixed(1)}h)',
          );
        }
      }
    }

    // ── cleanliness: 좋은/나쁜 청결 상태 유지 시간에 따른 bond 정산 ──
    if (cleanliness >= cleanBondGoodThreshold) {
      cleanlinessGoodSince ??= state.lastActiveAt ?? now;
      cleanlinessBadSince = null;

      final rewardHours =
          cleanliness >= cleanBondHighThreshold
              ? cleanBondHighRewardHours
              : cleanBondGoodRewardHours;
      final rewardRef = _laterOf(
        cleanlinessGoodSince,
        lastCleanBondRewardAt ?? cleanlinessGoodSince,
      );
      final elapsedRewardHours = now.difference(rewardRef).inMinutes / 60.0;
      final remainingGain = cleanBondDailyGainCap - dailyCleanBondGain;
      final steps = min(
        (elapsedRewardHours / rewardHours).floor(),
        max(0, remainingGain),
      );
      if (steps > 0) {
        bond = min(100.0, bond + steps);
        dailyCleanBondGain += steps;
        lastCleanBondRewardAt = rewardRef.add(
          Duration(hours: rewardHours * steps),
        );
        debugPrint('✅ bond 청결 유지 보상: +$steps');
      }
    } else {
      cleanlinessGoodSince = null;
    }

    // ── cleanliness: 낮은 청결 상태 유지 → 3h당 -1 ──
    if (cleanliness < cleanBondBadThreshold) {
      cleanlinessBadSince ??= state.lastActiveAt ?? now;
      cleanlinessGoodSince = null;

      final penaltyHours =
          cleanliness < cleanBondVeryBadThreshold
              ? cleanBondVeryBadPenaltyHours
              : cleanBondBadPenaltyHours;
      final penaltyRef = _laterOf(
        cleanlinessBadSince,
        lastCleanBondPenaltyAt ?? cleanlinessBadSince,
      );
      final elapsedPenaltyHours = now.difference(penaltyRef).inMinutes / 60.0;
      final steps = (elapsedPenaltyHours / penaltyHours).floor();
      if (steps > 0) {
        final penalty = steps * cleanBondPenaltyPerStep;
        bond = max(0.0, bond - penalty);
        dailyCleanBondLoss += penalty;
        lastCleanBondPenaltyAt = penaltyRef.add(
          Duration(hours: penaltyHours * steps),
        );
        debugPrint('🔻 bond 청결 낮음 패널티: -$penalty');
      }
    } else {
      cleanlinessBadSince = null;
    }

    // ── hunger: 낮은 배고픔 상태 유지 → 3h당 -2 ──
    if (hunger < hungerBondBadThreshold) {
      hungerLowSince ??= state.lastActiveAt ?? now;
      final penaltyRef = _laterOf(
        hungerLowSince,
        lastHungerBondPenaltyAt ?? hungerLowSince,
      );
      final elapsedPenaltyHours = now.difference(penaltyRef).inMinutes / 60.0;
      final steps = (elapsedPenaltyHours / hungerBondBadPenaltyHours).floor();
      if (steps > 0) {
        final penalty = steps * hungerBondPenaltyPerStep;
        bond = max(0.0, bond - penalty);
        dailyCleanBondLoss += penalty;
        lastHungerBondPenaltyAt = penaltyRef.add(
          Duration(hours: hungerBondBadPenaltyHours * steps),
        );
        debugPrint('🔻 bond 배고픔 낮음 패널티: -$penalty');
      }
    } else {
      hungerLowSince = null;
    }

    // ── energy: 낮은 에너지 상태 유지 → 5h당 -2 ──
    if (energy < energyBondBadThreshold) {
      energyLowSince ??= state.lastActiveAt ?? now;
      final penaltyRef = _laterOf(
        energyLowSince,
        lastEnergyBondPenaltyAt ?? energyLowSince,
      );
      final elapsedPenaltyHours = now.difference(penaltyRef).inMinutes / 60.0;
      final steps = (elapsedPenaltyHours / energyBondBadPenaltyHours).floor();
      if (steps > 0) {
        final penalty = steps * energyBondPenaltyPerStep;
        bond = max(0.0, bond - penalty);
        dailyCleanBondLoss += penalty;
        lastEnergyBondPenaltyAt = penaltyRef.add(
          Duration(hours: energyBondBadPenaltyHours * steps),
        );
        debugPrint('🔻 bond 에너지 낮음 패널티: -$penalty');
      }
    } else {
      energyLowSince = null;
    }

    // ── 쓰다듬기: 3시간 밖 타임스탬프 제거 ──
    final touchTimestamps = CaringState.trimTouchesToWindow(
      state.touchTimestamps,
      now,
      touchCountWindow,
    );

    return state.copyWith(
      hunger: hunger,
      mood: mood,
      energy: energy,
      bond: bond,
      cleanliness: cleanliness,
      lastActiveAt: now,
      touchTimestamps: touchTimestamps,
      cleanlinessGoodSince: cleanlinessGoodSince,
      cleanlinessBadSince: cleanlinessBadSince,
      lastCleanBondRewardAt: lastCleanBondRewardAt,
      lastCleanBondPenaltyAt: lastCleanBondPenaltyAt,
      hungerLowSince: hungerLowSince,
      energyLowSince: energyLowSince,
      lastHungerBondPenaltyAt: lastHungerBondPenaltyAt,
      lastEnergyBondPenaltyAt: lastEnergyBondPenaltyAt,
      clearHungerLowSince: hungerLowSince == null,
      clearEnergyLowSince: energyLowSince == null,
      cleanBondDateKey: cleanBondDateKey,
      dailyCleanBondGain: dailyCleanBondGain,
      dailyCleanBondLoss: dailyCleanBondLoss,
      dailyVisitDateKey: dailyVisitDateKey,
      dailyVisitCount: dailyVisitCount,
      // 한 번도 깨우기 API를 안 탄 유저도 연속 깨어 있음 패널티가 누적되도록
      lastWakeAt: state.lastWakeAt ?? (!state.isSleeping ? t0 : null),
    );
  }

  // ═══════════════════════ 쓰기 ═══════════════════════

  static Future<void> _saveTail = Future.value();

  /// `caringState` 전체를 Firestore에 쓸 때 **한 번에 하나씩** 순차 처리.
  /// 동시 저장 완료 순서 뒤바뀜으로 인한 옛 스냅샷 덮어쓰기를 방지한다.
  /// ref 없음 또는 예외 시 `false`.
  static Future<bool> saveStateSequential(CaringState state) {
    final completer = Completer<bool>();
    _saveTail = _saveTail.then((_) async {
      var ok = false;
      try {
        final ref = _userRef;
        if (ref == null) {
          ok = false;
        } else {
          await ref.set({
            'caringState': state.toMap(),
          }, SetOptions(merge: true));
          ok = true;
        }
      } catch (e) {
        debugPrint('⚠️ CaringStateService.saveStateSequential: $e');
        ok = false;
      }
      if (!completer.isCompleted) completer.complete(ok);
    });
    return completer.future;
  }

  /// [saveStateSequential]을 await하는 래퍼 (수면·깨우기 등 기존 호출부 호환).
  static Future<void> saveState(CaringState state) async {
    await saveStateSequential(state);
  }

  /// 아침 인사 완료 처리 (출석 체크 통합, 기존 호환)
  static Future<String> completeGreeting() async {
    try {
      final ref = _userRef;
      if (ref == null) return '로그인이 필요합니다.';

      final now = DateTime.now();
      final todayKey = _dateKey(now);

      await ref.set({
        'caringState': {
          'hasGreetedDate': todayKey,
          'isSleeping': false,
          'lastWakeAt': Timestamp.fromDate(now),
          'lastActiveAt': Timestamp.fromDate(now),
        },
        'emotionPoints': FieldValue.increment(RewardPolicy.attendance),
        'lastCheckIn': Timestamp.fromDate(now),
      }, SetOptions(merge: true));

      return '좋은 아침이에요.';
    } catch (e) {
      debugPrint('⚠️ CaringStateService.completeGreeting error: $e');
      return '오류가 발생했어요.';
    }
  }

  /// 재우기
  static Future<void> sleep(CaringState current) async {
    final now = DateTime.now();
    final updated = current.copyWith(
      isSleeping: true,
      sleepStartedAt: now,
      lastActiveAt: now,
    );
    await saveState(updated);
  }

  /// 짧은 수면 패널티 기준 (분)
  static const int shortSleepThresholdMin = 30;
  static const double shortSleepMoodPenalty = 5.0;

  /// 깨우기
  ///
  /// - [sleepStartedAt] 없음: 잠만 해제.
  /// - **≤30분:** 기분 [shortSleepMoodPenalty], 에너지 변화 없음.
  /// - **30분 초과 ~ 12시간 미만:** 에너지 회복(최대 [sleepMaxHours]만큼), 기분 +[sleepMoodBonus].
  /// - **≥12시간:** 에너지 회복은 동일, 기분 [longSleepMoodPenalty] (bond는 [_applyTimeDecay] 수면 패널티만).
  ///
  /// [now]를 넘기면 [CaringActionService.wakeUp]과 동일 시각으로 경과·멘트 분기를 맞출 수 있음.
  /// [persist]: false면 계산만 하고 저장은 호출자([saveStateSequential] 등)에 맡김.
  static Future<CaringState> wake(
    CaringState current, {
    bool persist = true,
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();
    if (current.sleepStartedAt == null) {
      final woken = current.copyWith(
        isSleeping: false,
        lastActiveAt: clock,
        lastWakeAt: clock,
      );
      if (persist) await saveState(woken);
      return woken;
    }

    var sleepElapsed = clock.difference(current.sleepStartedAt!);
    if (sleepElapsed.isNegative) {
      debugPrint('⚠️ wake: sleepElapsed < 0 (시계 역행 등) → 0으로 처리');
      sleepElapsed = Duration.zero;
    }

    final sleepMinutes = sleepElapsed.inMinutes;

    CaringState woken;
    if (sleepMinutes <= shortSleepThresholdMin) {
      woken = current.copyWith(
        isSleeping: false,
        mood: current.mood - shortSleepMoodPenalty,
        lastActiveAt: clock,
        lastWakeAt: clock,
      );
      debugPrint('😴 짧은 수면 패널티: mood -$shortSleepMoodPenalty ($sleepMinutes분)');
    } else {
      final sleepHoursTotal = sleepElapsed.inMinutes / 60.0;
      final sleepHours = min(sleepHoursTotal, sleepMaxHours);
      final recoveredEnergy = min(
        100.0,
        current.energy + sleepHours * sleepEnergyPerHour,
      );
      final isLongSleep = sleepElapsed >= longSleepThreshold;
      final recoveredMood =
          isLongSleep
              ? max(moodFloor, current.mood - longSleepMoodPenalty)
              : min(100.0, current.mood + sleepMoodBonus);
      woken = current.copyWith(
        isSleeping: false,
        energy: recoveredEnergy,
        mood: recoveredMood,
        lastActiveAt: clock,
        lastWakeAt: clock,
      );
      if (isLongSleep) {
        debugPrint(
          '😴 장시간 수면: mood -$longSleepMoodPenalty ($sleepHoursTotal h)',
        );
      }
    }

    if (persist) await saveState(woken);
    return woken;
  }

  // ═══════════════════════ 유틸 ═══════════════════════

  static String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static DateTime _laterOf(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  static bool hasGreetedToday(CaringState state) {
    final todayKey = _dateKey(DateTime.now());
    return state.hasGreetedDate == todayKey;
  }
}

// ═══════════════════════════════════════════════════════════
// CaringState 값 객체
// ═══════════════════════════════════════════════════════════

List<DateTime> _touchTimestampsFromMap(Map<String, dynamic> m) {
  final raw = m['touchTimestamps'];
  if (raw is List && raw.isNotEmpty) {
    return raw
        .map((e) => e is Timestamp ? e.toDate() : null)
        .whereType<DateTime>()
        .toList(growable: false);
  }
  return const [];
}

/// 캐릭터 상태 — hunger / mood / energy / bond / cleanliness (0~100)
class CaringState {
  // ── 핵심 5대 상태 ──
  final double hunger;
  final double mood;
  final double energy;
  final double bond;
  final double cleanliness;

  // ── 수면 ──
  final bool isSleeping;
  final DateTime? sleepStartedAt;

  // ── 시간 추적 ──
  final DateTime? lastActiveAt;

  // ── 쓰다듬기: 최근 3시간 안의 터치 시각 목록 (Firestore `touchTimestamps` 배열) ──
  final List<DateTime> touchTimestamps;

  // ── 씻기기/청결 유지 ──
  final DateTime? lastWashedAt;
  final DateTime? cleanlinessGoodSince;
  final DateTime? cleanlinessBadSince;
  final DateTime? lastCleanBondRewardAt;
  final DateTime? lastCleanBondPenaltyAt;
  final DateTime? hungerLowSince;
  final DateTime? energyLowSince;
  final DateTime? lastHungerBondPenaltyAt;
  final DateTime? lastEnergyBondPenaltyAt;
  final String? cleanBondDateKey;
  final int dailyCleanBondGain;
  final int dailyCleanBondLoss;
  final String? dailyVisitDateKey;
  final int dailyVisitCount;
  final String? touchBondDateKey;
  final int dailyTouchBondGain;

  // ── 밥주기 연속 카운터 (시간 기반) ──
  final int consecutiveFeedCount;
  final DateTime? lastFeedAt;

  // ── 기존 호환 (아침 인사 등) ──
  final String? hasGreetedDate;
  final DateTime? lastWakeAt;

  // ── 초기값 상수 (신규·미저장 유저 기본 게이지) ──
  static const double _initHunger = 30;
  static const double _initMood = 40;
  static const double _initEnergy = 20;
  static const double _initBond = 10;
  static const double _initCleanliness = 30;

  const CaringState({
    this.hunger = _initHunger,
    this.mood = _initMood,
    this.energy = _initEnergy,
    this.bond = _initBond,
    this.cleanliness = _initCleanliness,
    this.isSleeping = false,
    this.sleepStartedAt,
    this.lastActiveAt,
    this.touchTimestamps = const [],
    this.lastWashedAt,
    this.cleanlinessGoodSince,
    this.cleanlinessBadSince,
    this.lastCleanBondRewardAt,
    this.lastCleanBondPenaltyAt,
    this.hungerLowSince,
    this.energyLowSince,
    this.lastHungerBondPenaltyAt,
    this.lastEnergyBondPenaltyAt,
    this.cleanBondDateKey,
    this.dailyCleanBondGain = 0,
    this.dailyCleanBondLoss = 0,
    this.dailyVisitDateKey,
    this.dailyVisitCount = 0,
    this.touchBondDateKey,
    this.dailyTouchBondGain = 0,
    this.consecutiveFeedCount = 0,
    this.lastFeedAt,
    this.hasGreetedDate,
    this.lastWakeAt,
  });

  factory CaringState.initial() => const CaringState();

  /// [window] 이전 시각은 제외한 목록 (슬라이딩 윈도우)
  static List<DateTime> trimTouchesToWindow(
    List<DateTime> times,
    DateTime now,
    Duration window,
  ) {
    final cutoff = now.subtract(window);
    return times.where((t) => !t.isBefore(cutoff)).toList(growable: false);
  }

  /// Firestore → Dart
  factory CaringState.fromMap(Map<String, dynamic> m) {
    return CaringState(
      hunger: (m['hunger'] as num?)?.toDouble() ?? _initHunger,
      mood: (m['mood'] as num?)?.toDouble() ?? _initMood,
      energy: (m['energy'] as num?)?.toDouble() ?? _initEnergy,
      bond: (m['bond'] as num?)?.toDouble() ?? _initBond,
      cleanliness: (m['cleanliness'] as num?)?.toDouble() ?? _initCleanliness,
      isSleeping: m['isSleeping'] ?? false,
      sleepStartedAt: (m['sleepStartedAt'] as Timestamp?)?.toDate(),
      lastActiveAt: (m['lastActiveAt'] as Timestamp?)?.toDate(),
      touchTimestamps: _touchTimestampsFromMap(m),
      lastWashedAt: (m['lastWashedAt'] as Timestamp?)?.toDate(),
      cleanlinessGoodSince: (m['cleanlinessGoodSince'] as Timestamp?)?.toDate(),
      cleanlinessBadSince: (m['cleanlinessBadSince'] as Timestamp?)?.toDate(),
      lastCleanBondRewardAt:
          (m['lastCleanBondRewardAt'] as Timestamp?)?.toDate(),
      lastCleanBondPenaltyAt:
          (m['lastCleanBondPenaltyAt'] as Timestamp?)?.toDate(),
      hungerLowSince: (m['hungerLowSince'] as Timestamp?)?.toDate(),
      energyLowSince: (m['energyLowSince'] as Timestamp?)?.toDate(),
      lastHungerBondPenaltyAt:
          (m['lastHungerBondPenaltyAt'] as Timestamp?)?.toDate(),
      lastEnergyBondPenaltyAt:
          (m['lastEnergyBondPenaltyAt'] as Timestamp?)?.toDate(),
      cleanBondDateKey: m['cleanBondDateKey'],
      dailyCleanBondGain: m['dailyCleanBondGain'] ?? 0,
      dailyCleanBondLoss: m['dailyCleanBondLoss'] ?? 0,
      dailyVisitDateKey: m['dailyVisitDateKey'],
      dailyVisitCount: m['dailyVisitCount'] ?? 0,
      touchBondDateKey: m['touchBondDateKey'],
      dailyTouchBondGain: m['dailyTouchBondGain'] ?? 0,
      consecutiveFeedCount: m['consecutiveFeedCount'] ?? 0,
      lastFeedAt: (m['lastFeedAt'] as Timestamp?)?.toDate(),
      hasGreetedDate: m['hasGreetedDate'],
      lastWakeAt: (m['lastWakeAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Dart → Firestore
  Map<String, dynamic> toMap() {
    return {
      'hunger': hunger,
      'mood': mood,
      'energy': energy,
      'bond': bond,
      'cleanliness': cleanliness,
      'isSleeping': isSleeping,
      'sleepStartedAt':
          sleepStartedAt != null ? Timestamp.fromDate(sleepStartedAt!) : null,
      'lastActiveAt':
          lastActiveAt != null ? Timestamp.fromDate(lastActiveAt!) : null,
      'touchTimestamps': touchTimestamps
          .map((t) => Timestamp.fromDate(t))
          .toList(growable: false),
      'lastWashedAt':
          lastWashedAt != null ? Timestamp.fromDate(lastWashedAt!) : null,
      'cleanlinessGoodSince':
          cleanlinessGoodSince != null
              ? Timestamp.fromDate(cleanlinessGoodSince!)
              : null,
      'cleanlinessBadSince':
          cleanlinessBadSince != null
              ? Timestamp.fromDate(cleanlinessBadSince!)
              : null,
      'lastCleanBondRewardAt':
          lastCleanBondRewardAt != null
              ? Timestamp.fromDate(lastCleanBondRewardAt!)
              : null,
      'lastCleanBondPenaltyAt':
          lastCleanBondPenaltyAt != null
              ? Timestamp.fromDate(lastCleanBondPenaltyAt!)
              : null,
      'hungerLowSince':
          hungerLowSince != null ? Timestamp.fromDate(hungerLowSince!) : null,
      'energyLowSince':
          energyLowSince != null ? Timestamp.fromDate(energyLowSince!) : null,
      'lastHungerBondPenaltyAt':
          lastHungerBondPenaltyAt != null
              ? Timestamp.fromDate(lastHungerBondPenaltyAt!)
              : null,
      'lastEnergyBondPenaltyAt':
          lastEnergyBondPenaltyAt != null
              ? Timestamp.fromDate(lastEnergyBondPenaltyAt!)
              : null,
      'cleanBondDateKey': cleanBondDateKey,
      'dailyCleanBondGain': dailyCleanBondGain,
      'dailyCleanBondLoss': dailyCleanBondLoss,
      'dailyVisitDateKey': dailyVisitDateKey,
      'dailyVisitCount': dailyVisitCount,
      'touchBondDateKey': touchBondDateKey,
      'dailyTouchBondGain': dailyTouchBondGain,
      'consecutiveFeedCount': consecutiveFeedCount,
      'lastFeedAt': lastFeedAt != null ? Timestamp.fromDate(lastFeedAt!) : null,
      'hasGreetedDate': hasGreetedDate,
      'lastWakeAt': lastWakeAt != null ? Timestamp.fromDate(lastWakeAt!) : null,
    };
  }

  CaringState copyWith({
    double? hunger,
    double? mood,
    double? energy,
    double? bond,
    double? cleanliness,
    bool? isSleeping,
    DateTime? sleepStartedAt,
    DateTime? lastActiveAt,
    List<DateTime>? touchTimestamps,
    DateTime? lastWashedAt,
    DateTime? cleanlinessGoodSince,
    DateTime? cleanlinessBadSince,
    DateTime? lastCleanBondRewardAt,
    DateTime? lastCleanBondPenaltyAt,
    DateTime? hungerLowSince,
    DateTime? energyLowSince,
    DateTime? lastHungerBondPenaltyAt,
    DateTime? lastEnergyBondPenaltyAt,
    String? cleanBondDateKey,
    int? dailyCleanBondGain,
    int? dailyCleanBondLoss,
    String? dailyVisitDateKey,
    int? dailyVisitCount,
    String? touchBondDateKey,
    int? dailyTouchBondGain,
    int? consecutiveFeedCount,
    DateTime? lastFeedAt,
    String? hasGreetedDate,
    DateTime? lastWakeAt,
    bool clearCleanlinessGoodSince = false,
    bool clearCleanlinessBadSince = false,
    bool clearHungerLowSince = false,
    bool clearEnergyLowSince = false,
  }) {
    return CaringState(
      hunger: (hunger ?? this.hunger).clamp(0, 100),
      mood: (mood ?? this.mood).clamp(0, 100),
      energy: (energy ?? this.energy).clamp(0, 100),
      bond: (bond ?? this.bond).clamp(0, 100),
      cleanliness: (cleanliness ?? this.cleanliness).clamp(0, 100),
      isSleeping: isSleeping ?? this.isSleeping,
      sleepStartedAt: sleepStartedAt ?? this.sleepStartedAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      touchTimestamps: touchTimestamps ?? this.touchTimestamps,
      lastWashedAt: lastWashedAt ?? this.lastWashedAt,
      cleanlinessGoodSince:
          clearCleanlinessGoodSince
              ? null
              : (cleanlinessGoodSince ?? this.cleanlinessGoodSince),
      cleanlinessBadSince:
          clearCleanlinessBadSince
              ? null
              : (cleanlinessBadSince ?? this.cleanlinessBadSince),
      lastCleanBondRewardAt:
          lastCleanBondRewardAt ?? this.lastCleanBondRewardAt,
      lastCleanBondPenaltyAt:
          lastCleanBondPenaltyAt ?? this.lastCleanBondPenaltyAt,
      hungerLowSince:
          clearHungerLowSince ? null : (hungerLowSince ?? this.hungerLowSince),
      energyLowSince:
          clearEnergyLowSince ? null : (energyLowSince ?? this.energyLowSince),
      lastHungerBondPenaltyAt:
          lastHungerBondPenaltyAt ?? this.lastHungerBondPenaltyAt,
      lastEnergyBondPenaltyAt:
          lastEnergyBondPenaltyAt ?? this.lastEnergyBondPenaltyAt,
      cleanBondDateKey: cleanBondDateKey ?? this.cleanBondDateKey,
      dailyCleanBondGain: dailyCleanBondGain ?? this.dailyCleanBondGain,
      dailyCleanBondLoss: dailyCleanBondLoss ?? this.dailyCleanBondLoss,
      dailyVisitDateKey: dailyVisitDateKey ?? this.dailyVisitDateKey,
      dailyVisitCount: dailyVisitCount ?? this.dailyVisitCount,
      touchBondDateKey: touchBondDateKey ?? this.touchBondDateKey,
      dailyTouchBondGain: dailyTouchBondGain ?? this.dailyTouchBondGain,
      consecutiveFeedCount: consecutiveFeedCount ?? this.consecutiveFeedCount,
      lastFeedAt: lastFeedAt ?? this.lastFeedAt,
      hasGreetedDate: hasGreetedDate ?? this.hasGreetedDate,
      lastWakeAt: lastWakeAt ?? this.lastWakeAt,
    );
  }

  /// 정수 반환 헬퍼 (UI 표시용)
  int get hungerInt => hunger.round();
  int get moodInt => mood.round();
  int get energyInt => energy.round();
  int get bondInt => bond.round();
  int get cleanlinessInt => cleanliness.round();
}
