import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/reward_constants.dart';

/// 캐릭터 감정 상태
enum CharacterEmotion {
  burnout, // 번아웃 (정신력 낮음)
  hungry, // 배고픔 (포만감 낮음)
  lonely, // 외로움 (애정도 낮음)
  bestCondition, // 최상 컨디션
  idle, // 평상시
}

/// 캐릭터 감정별 대사
class CharacterDialogue {
  static const String nickname = CharacterStats.userNickname;

  static const Map<CharacterEmotion, List<String>> dialogues = {
    CharacterEmotion.burnout: [
      '$nickname, 머리가 너무 아파요...',
      '$nickname, 오늘은 좀 쉬고 싶어요.',
      '$nickname, 힘들어요... 안아주세요.',
      '$nickname, 아무것도 하기 싫어요...',
    ],
    CharacterEmotion.hungry: [
      '$nickname, 저 배고파요!',
      '$nickname~ 밥 주세요!',
      '$nickname, 배에서 꼬르륵 소리 나요...',
      '$nickname, 맛있는 거 먹고 싶어요!',
    ],
    CharacterEmotion.lonely: [
      '$nickname, 저 보고 싶었어요...',
      '$nickname, 어디 갔다 오셨어요?',
      '$nickname, 저랑 놀아주세요!',
      '$nickname, 심심해요...',
    ],
    CharacterEmotion.bestCondition: [
      '$nickname! 오늘 기분 최고예요!',
      '$nickname랑 있으면 행복해요!',
      '$nickname, 사랑해요! ❤️',
      '$nickname랑 공부하니까 힘이 나요!',
      '$nickname, 오늘도 화이팅이에요!',
    ],
    CharacterEmotion.idle: [
      '$nickname, 뭐 해요?',
      '$nickname~ 심심해요~',
      '$nickname, 오늘 뭐 할까요?',
      '$nickname, 저 예쁘죠?',
    ],
  };

  /// 현재 감정에 맞는 랜덤 대사 반환
  static String getRandomDialogue(CharacterEmotion emotion) {
    final list = dialogues[emotion] ?? dialogues[CharacterEmotion.idle]!;
    list.shuffle();
    return list.first;
  }
}

/// 캐릭터 상태 관리 Provider
class CharacterStatusProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────
  // 상태 값 (0.0 ~ 100.0, wisdom은 무제한)
  // ─────────────────────────────────────────────
  double _fullness = 50.0; // 포만감
  double _affection = 50.0; // 애정도
  double _health = 100.0; // 건강
  double _spirit = 50.0; // 정신력
  double _wisdom = 0.0; // 지혜 (무제한)

  // ─────────────────────────────────────────────
  // 쓰다듬기 관련
  // ─────────────────────────────────────────────
  int _petCount = 0; // 현재 연속 쓰다듬기 횟수
  DateTime? _petCooldownEnd; // 쿨타임 종료 시간

  // ─────────────────────────────────────────────
  // 확인하기 관련
  // ─────────────────────────────────────────────
  int _checkCountToday = 0; // 오늘 확인하기 횟수
  DateTime? _lastCheckDate; // 마지막 확인 날짜

  // ─────────────────────────────────────────────
  // 오프라인 추적
  // ─────────────────────────────────────────────
  DateTime? _lastActiveTime; // 마지막 활동 시간

  // Getters
  double get fullness => _fullness;
  double get affection => _affection;
  double get health => _health;
  double get spirit => _spirit;
  double get wisdom => _wisdom;
  int get petCount => _petCount;
  bool get canPet =>
      _petCooldownEnd == null || DateTime.now().isAfter(_petCooldownEnd!);
  int get petCooldownRemaining {
    if (_petCooldownEnd == null) return 0;
    final remaining = _petCooldownEnd!.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  int get checkCountToday => _checkCountToday;
  bool get canCheck => _checkCountToday < CharacterStats.checkDailyLimit;
  int get checkRemaining => CharacterStats.checkDailyLimit - _checkCountToday;

  /// 현재 감정 상태 반환
  CharacterEmotion get currentEmotion {
    // 우선순위: 번아웃 > 배고픔 > 외로움 > 최상 > 평상시
    if (_spirit <= CharacterStats.burnoutThreshold) {
      return CharacterEmotion.burnout;
    }
    if (_fullness <= CharacterStats.hungryThreshold) {
      return CharacterEmotion.hungry;
    }
    if (_affection <= CharacterStats.lonelyThreshold) {
      return CharacterEmotion.lonely;
    }
    if (_fullness >= CharacterStats.bestConditionThreshold &&
        _affection >= CharacterStats.bestConditionThreshold &&
        _health >= CharacterStats.bestConditionThreshold &&
        _spirit >= CharacterStats.bestConditionThreshold) {
      return CharacterEmotion.bestCondition;
    }
    return CharacterEmotion.idle;
  }

  /// 현재 감정에 맞는 대사 반환
  String get currentDialogue =>
      CharacterDialogue.getRandomDialogue(currentEmotion);

  /// 초기화 - 앱 시작 시 호출
  Future<void> initialize() async {
    await _loadFromFirestore();
    await _loadLocalState();
    _applyOfflineDecay();
    _startPeriodicSave();
  }

  /// Firestore에서 데이터 로드
  Future<void> _loadFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    _fullness = (data['fullness'] ?? 50.0).toDouble().clamp(0.0, 100.0);
    _affection = (data['affection'] ?? 50.0).toDouble().clamp(0.0, 100.0);
    _health = (data['health'] ?? 100.0).toDouble().clamp(0.0, 100.0);
    _spirit = (data['spirit'] ?? 50.0).toDouble().clamp(0.0, 100.0);
    _wisdom = (data['wisdom'] ?? 0.0).toDouble();
    _checkCountToday = data['checkCountToday'] ?? 0;

    final lastCheckTs = data['lastCheckDate'] as Timestamp?;
    _lastCheckDate = lastCheckTs?.toDate();

    final lastActiveTs = data['lastActiveTime'] as Timestamp?;
    _lastActiveTime = lastActiveTs?.toDate();

    // 날짜가 바뀌었으면 확인하기 횟수 리셋
    _resetDailyCountersIfNeeded();

    notifyListeners();
  }

  /// 로컬 상태 로드 (쿨타임 등)
  Future<void> _loadLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    final cooldownMs = prefs.getInt('petCooldownEnd');
    if (cooldownMs != null) {
      _petCooldownEnd = DateTime.fromMillisecondsSinceEpoch(cooldownMs);
      if (DateTime.now().isAfter(_petCooldownEnd!)) {
        _petCooldownEnd = null;
        _petCount = 0;
      }
    }
  }

  /// 오프라인 시간에 따른 수치 하락 적용
  void _applyOfflineDecay() {
    if (_lastActiveTime == null) {
      _lastActiveTime = DateTime.now();
      return;
    }

    final now = DateTime.now();
    final hoursOffline = now.difference(_lastActiveTime!).inMinutes / 60.0;

    if (hoursOffline > 0) {
      // 포만감 하락
      final fullnessLoss =
          hoursOffline * CharacterStats.fullnessDecreasePerHour;
      _fullness = (_fullness - fullnessLoss).clamp(0.0, 100.0);

      // 애정도 하락
      final affectionLoss =
          hoursOffline * CharacterStats.affectionDecreasePerHour;
      _affection = (_affection - affectionLoss).clamp(0.0, 100.0);

      // 포만감이 0이면 건강도 하락
      if (_fullness <= 0) {
        final healthLoss =
            hoursOffline * CharacterStats.healthDecreasePerHourWhenHungry;
        _health = (_health - healthLoss).clamp(0.0, 100.0);
      }
    }

    _lastActiveTime = now;
    notifyListeners();
  }

  /// 날짜가 바뀌었으면 일일 카운터 리셋
  void _resetDailyCountersIfNeeded() {
    final now = DateTime.now();
    if (_lastCheckDate == null ||
        _lastCheckDate!.day != now.day ||
        _lastCheckDate!.month != now.month ||
        _lastCheckDate!.year != now.year) {
      _checkCountToday = 0;
      _lastCheckDate = now;
    }
  }

  /// 주기적 저장 시작 (5분마다)
  void _startPeriodicSave() {
    Timer.periodic(const Duration(minutes: 5), (_) {
      _saveToFirestore();
    });
  }

  /// Firestore에 저장
  Future<void> _saveToFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _lastActiveTime = DateTime.now();

    await _db.collection('users').doc(uid).update({
      'fullness': _fullness,
      'affection': _affection,
      'health': _health,
      'spirit': _spirit,
      'wisdom': _wisdom,
      'checkCountToday': _checkCountToday,
      'lastCheckDate': Timestamp.fromDate(_lastCheckDate ?? DateTime.now()),
      'lastActiveTime': Timestamp.fromDate(_lastActiveTime!),
    });
  }

  // ═══════════════════════════════════════════════════════════
  // 액션 메서드들
  // ═══════════════════════════════════════════════════════════

  /// 식사하기 (일반식)
  Future<String> eatMeal() async {
    _fullness = (_fullness + CharacterStats.mealFullnessIncrease).clamp(
      0.0,
      100.0,
    );
    notifyListeners();
    await _saveToFirestore();
    return '${CharacterStats.userNickname}, 맛있어요! 배불러요~';
  }

  /// 간식 먹기
  Future<String> eatSnack() async {
    _fullness = (_fullness + CharacterStats.snackFullnessIncrease).clamp(
      0.0,
      100.0,
    );
    notifyListeners();
    await _saveToFirestore();
    return '${CharacterStats.userNickname}, 간식 고마워요!';
  }

  /// 쓰다듬기
  Future<String> pet() async {
    // 쿨타임 체크
    if (!canPet) {
      return '조금만 쉬게 해주세요... (${petCooldownRemaining}초 남음)';
    }

    _petCount++;
    _affection = (_affection + CharacterStats.petAffectionIncrease).clamp(
      0.0,
      100.0,
    );

    // 3번 연속 후 쿨타임 시작
    if (_petCount >= CharacterStats.petMaxConsecutive) {
      _petCooldownEnd = DateTime.now().add(
        Duration(seconds: CharacterStats.petCooldownSeconds),
      );
      _petCount = 0;

      // 로컬에 쿨타임 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'petCooldownEnd',
        _petCooldownEnd!.millisecondsSinceEpoch,
      );
    }

    notifyListeners();
    await _saveToFirestore();

    if (_petCount == 0) {
      return '${CharacterStats.userNickname}, 너무 좋아요! 잠깐 쉴게요~';
    }
    return '${CharacterStats.userNickname}, 기분 좋아요~ ❤️ (${_petCount}/${CharacterStats.petMaxConsecutive})';
  }

  /// 확인하기
  Future<String> checkCharacter() async {
    _resetDailyCountersIfNeeded();

    if (!canCheck) {
      return '${CharacterStats.userNickname}, 오늘은 많이 봤어요! 내일 또 봐요~';
    }

    _checkCountToday++;
    _affection = (_affection + CharacterStats.checkAffectionIncrease).clamp(
      0.0,
      100.0,
    );

    notifyListeners();
    await _saveToFirestore();
    return currentDialogue;
  }

  /// 운동하기 - 걷기
  Future<String> walkSteps(int steps) async {
    final healthGain = (steps / 100) * CharacterStats.walkHealthPer100Steps;
    _health = (_health + healthGain).clamp(0.0, 100.0);

    notifyListeners();
    await _saveToFirestore();
    return '${CharacterStats.userNickname}랑 산책 좋아요! 건강 +${healthGain.toStringAsFixed(1)}';
  }

  /// 운동하기 - 뛰기
  Future<String> runSteps(int steps) async {
    final healthGain = (steps / 100) * CharacterStats.runHealthPer100Steps;
    _health = (_health + healthGain).clamp(0.0, 100.0);

    notifyListeners();
    await _saveToFirestore();
    return '${CharacterStats.userNickname}, 달리기 신나요! 건강 +${healthGain.toStringAsFixed(1)}';
  }

  /// 공부하기 (분 단위)
  Future<String> study(int minutes) async {
    final units = minutes / 10.0;
    final wisdomGain = units * CharacterStats.studyWisdomPer10Min;
    final spiritGain = units * CharacterStats.studySpiritPer10Min;

    _wisdom += wisdomGain; // 무제한
    _spirit = (_spirit + spiritGain).clamp(0.0, 100.0);

    notifyListeners();
    await _saveToFirestore();
    return '${CharacterStats.userNickname}랑 공부하니까 힘이 나요! 지혜 +${wisdomGain.toStringAsFixed(1)}, 정신력 +${spiritGain.toStringAsFixed(1)}';
  }

  /// 앱 종료 시 호출 (상태 저장)
  Future<void> onAppPause() async {
    _lastActiveTime = DateTime.now();
    await _saveToFirestore();
  }

  /// 앱 재개 시 호출 (오프라인 하락 적용)
  Future<void> onAppResume() async {
    _applyOfflineDecay();
    await _saveToFirestore();
  }

  /// 테스트용: 수치 직접 설정
  void setTestValues({
    double? fullness,
    double? affection,
    double? health,
    double? spirit,
    double? wisdom,
  }) {
    if (fullness != null) _fullness = fullness.clamp(0.0, 100.0);
    if (affection != null) _affection = affection.clamp(0.0, 100.0);
    if (health != null) _health = health.clamp(0.0, 100.0);
    if (spirit != null) _spirit = spirit.clamp(0.0, 100.0);
    if (wisdom != null) _wisdom = wisdom;
    notifyListeners();
  }
}











