import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../config/reward_constants.dart';

/// 돌보기(1탭) 상태 서비스
///
/// hunger / mood / energy / bond 4개 상태 + 시간 경과 시스템.
/// users/{uid} 문서의 caringState 필드를 사용.
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
  static const double hungerDecayPerHour = 5.0;
  static const double moodDecayPerHour = 6.0;
  static const double energyDecayPerHour = 4.0;

  /// 시간 감소 하한 캡 (이 아래로는 떨어지지 않음)
  static const double hungerFloor = 20.0;
  static const double moodFloor = 15.0;
  static const double energyFloor = 25.0;

  /// 수면 — energy 시간당 회복량, 최대 반영 시간
  static const double sleepEnergyPerHour = 12.5;
  static const double sleepMaxHours = 8.0;
  static const double sleepMoodBonus = 5.0;

  /// bond 미접속 패널티
  static const double bondAbsencePenaltyPerDay = 3.0;
  static const double bondAbsenceMaxPenalty = 9.0;

  /// 쓰다듬기 효과 구간 — 최근 이 시간 안의 터치만 집계
  static const Duration touchCountWindow = Duration(hours: 3);

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
  /// 수면 중이면 감소/회복 없음 (회복은 wake()에서만 처리)
  static CaringState _applyTimeDecay(CaringState state, DateTime now) {
    final lastActive = state.lastActiveAt ?? now;
    final elapsed = now.difference(lastActive);
    final hours = elapsed.inMinutes / 60.0;

    if (hours < 0.05) {
      return state.copyWith(lastActiveAt: now);
    }

    double hunger = state.hunger;
    double mood = state.mood;
    double energy = state.energy;
    double bond = state.bond;

    if (state.isSleeping) {
      // 수면 중: 감소·회복 모두 없음 (wake()에서 일괄 처리)
    } else {
      // hunger < 30 → mood 시간감소 +1/h 가속
      final effectiveMoodDecay = hunger < 30
          ? moodDecayPerHour + hungerMoodAccel
          : moodDecayPerHour;

      hunger = max(hungerFloor, hunger - hours * hungerDecayPerHour);
      mood = max(moodFloor, mood - hours * effectiveMoodDecay);
      energy = max(energyFloor, energy - hours * energyDecayPerHour);
    }

    // ── bond 미접속 패널티 (24h 초과분만) ──
    if (hours >= 24) {
      final absentDays = (hours / 24).floor();
      final penalty = min(
        absentDays * bondAbsencePenaltyPerDay,
        bondAbsenceMaxPenalty,
      );
      bond = max(0, bond - penalty);
      debugPrint('🔻 bond 미접속 패널티: -$penalty (${absentDays}일)');
    }

    // ── 일일 첫 접속 bond +1 ──
    final todayKey = _dateKey(now);
    final lastDateKey = state.lastActiveAt != null ? _dateKey(state.lastActiveAt!) : null;
    if (lastDateKey != todayKey) {
      bond = min(100, bond + 1);
      debugPrint('✅ 일일 첫 접속 bond +1');
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
      lastActiveAt: now,
      touchTimestamps: touchTimestamps,
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
          await ref.set({'caringState': state.toMap()}, SetOptions(merge: true));
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

  /// 깨우기 — 30분 초과면 회복, 이하면 패널티
  ///
  /// [persist]: false면 계산만 하고 저장은 호출자([saveStateSequential] 등)에 맡김.
  static Future<CaringState> wake(CaringState current, {bool persist = true}) async {
    final now = DateTime.now();
    if (current.sleepStartedAt == null) {
      final woken = current.copyWith(isSleeping: false, lastActiveAt: now);
      if (persist) await saveState(woken);
      return woken;
    }

    final sleepElapsed = now.difference(current.sleepStartedAt!);
    final sleepMinutes = sleepElapsed.inMinutes;

    CaringState woken;
    if (sleepMinutes <= shortSleepThresholdMin) {
      woken = current.copyWith(
        isSleeping: false,
        mood: current.mood - shortSleepMoodPenalty,
        lastActiveAt: now,
      );
      debugPrint('😴 짧은 수면 패널티: mood -$shortSleepMoodPenalty (${sleepMinutes}분)');
    } else {
      final sleepHours = min(sleepElapsed.inMinutes / 60.0, sleepMaxHours);
      final recoveredEnergy = min(100.0, current.energy + sleepHours * sleepEnergyPerHour);
      final recoveredMood = min(100.0, current.mood + sleepMoodBonus);
      woken = current.copyWith(
        isSleeping: false,
        energy: recoveredEnergy,
        mood: recoveredMood,
        lastActiveAt: now,
      );
    }

    if (persist) await saveState(woken);
    return woken;
  }

  // ═══════════════════════ 유틸 ═══════════════════════

  static String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

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

/// 캐릭터 상태 — hunger / mood / energy / bond (0~100)
class CaringState {
  // ── 핵심 4대 상태 ──
  final double hunger;
  final double mood;
  final double energy;
  final double bond;

  // ── 수면 ──
  final bool isSleeping;
  final DateTime? sleepStartedAt;

  // ── 시간 추적 ──
  final DateTime? lastActiveAt;

  // ── 쓰다듬기: 최근 3시간 안의 터치 시각 목록 (Firestore `touchTimestamps` 배열) ──
  final List<DateTime> touchTimestamps;

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

  const CaringState({
    this.hunger = _initHunger,
    this.mood = _initMood,
    this.energy = _initEnergy,
    this.bond = _initBond,
    this.isSleeping = false,
    this.sleepStartedAt,
    this.lastActiveAt,
    this.touchTimestamps = const [],
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
      isSleeping: m['isSleeping'] ?? false,
      sleepStartedAt: (m['sleepStartedAt'] as Timestamp?)?.toDate(),
      lastActiveAt: (m['lastActiveAt'] as Timestamp?)?.toDate(),
      touchTimestamps: _touchTimestampsFromMap(m),
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
      'isSleeping': isSleeping,
      'sleepStartedAt': sleepStartedAt != null ? Timestamp.fromDate(sleepStartedAt!) : null,
      'lastActiveAt': lastActiveAt != null ? Timestamp.fromDate(lastActiveAt!) : null,
      'touchTimestamps': touchTimestamps
          .map((t) => Timestamp.fromDate(t))
          .toList(growable: false),
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
    bool? isSleeping,
    DateTime? sleepStartedAt,
    DateTime? lastActiveAt,
    List<DateTime>? touchTimestamps,
    int? consecutiveFeedCount,
    DateTime? lastFeedAt,
    String? hasGreetedDate,
    DateTime? lastWakeAt,
  }) {
    return CaringState(
      hunger: (hunger ?? this.hunger).clamp(0, 100),
      mood: (mood ?? this.mood).clamp(0, 100),
      energy: (energy ?? this.energy).clamp(0, 100),
      bond: (bond ?? this.bond).clamp(0, 100),
      isSleeping: isSleeping ?? this.isSleeping,
      sleepStartedAt: sleepStartedAt ?? this.sleepStartedAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      touchTimestamps: touchTimestamps ?? this.touchTimestamps,
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
}
