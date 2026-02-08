/// 포인트 & 보상 정책 상수
class RewardPolicy {
  RewardPolicy._();

  // [1] 돌보기 활동 보상 (Points)
  static const int attendance = 5;
  static const int petCharacter = 2;
  static const int petCharacterDailyLimit = 5;
  static const int feed = 3;
  static const int feedDailyLimit = 3;
  static const int rest = 2;

  // [2] 성장하기 보상
  static const int ebookReadPer3Min = 1;
  static const int ebookDailyMax = 30;
  static const int dailyGrowthRecord = 10;
  static const int quizCorrect = 5;

  // [3] 구직 활동 보상
  static const int jobPostView = 1;
  static const int jobPostViewDailyMax = 10;
  static const int mapHospitalClick = 3;

  // [4] 그레이드 기준 (누적 포인트)
  static const int gradeLevel1 = 0;
  static const int gradeLevel2 = 500;
  static const int gradeLevel3 = 3000;
  static const int gradeLevel4 = 10000;
  static const int gradeLevel5 = 30000;

  static const List<String> gradeNames = ['Lv1', 'Lv2', 'Lv3', 'Lv4', 'Lv5'];

  static int getGradeLevel(int totalPoints) {
    if (totalPoints >= gradeLevel5) return 5;
    if (totalPoints >= gradeLevel4) return 4;
    if (totalPoints >= gradeLevel3) return 3;
    if (totalPoints >= gradeLevel2) return 2;
    return 1;
  }

  static String getGradeName(int level) {
    if (level < 1 || level > gradeNames.length) return gradeNames[0];
    return gradeNames[level - 1];
  }

  // [5] 가구 가격 (Points)
  static const int furnitureBed = 100;
  static const int furnitureCloset = 150;
  static const int furnitureTable = 80;
  static const int furnitureDesk = 120;
  static const int furnitureDoor = 50;
  static const int furnitureWindow = 60;

  // [6] 캐시 가격 (Cash)
  static const int jobPostBasicCash = 100;
  static const int jobPostPremiumCash = 300;

  // [7] 스탯 증감량 (레거시 - 아래 CharacterStats 사용 권장)
  static const double feedHungerIncrease = 0.2;
  static const double feedAffectionIncrease = 0.05;
  static const double petAffectionIncrease = 0.02;
  static const double restFatigueDecrease = 0.2;
  static const double restSleepIncrease = 0.5;
}

/// ============================================================
/// 캐릭터 상태 관리 상수 (0.0 ~ 100.0 범위)
/// ============================================================
class CharacterStats {
  CharacterStats._();

  /// 캐릭터가 유저를 부르는 호칭
  static const String userNickname = '엄마';

  // ─────────────────────────────────────────────
  // [1] 식사 관련
  // ─────────────────────────────────────────────
  /// 일반식 포만감 증가량
  static const double mealFullnessIncrease = 20.0;

  /// 간식 포만감 증가량
  static const double snackFullnessIncrease = 5.0;

  // ─────────────────────────────────────────────
  // [2] 쓰다듬기 관련
  // ─────────────────────────────────────────────
  /// 쓰다듬기 1회당 애정도 증가량
  static const double petAffectionIncrease = 5.0;

  /// 연속 쓰다듬기 최대 횟수
  static const int petMaxConsecutive = 3;

  /// 쓰다듬기 쿨타임 (초)
  static const int petCooldownSeconds = 60;

  // ─────────────────────────────────────────────
  // [3] 확인하기 관련
  // ─────────────────────────────────────────────
  /// 확인하기 1회당 애정도 증가량
  static const double checkAffectionIncrease = 1.0;

  /// 확인하기 하루 최대 횟수
  static const int checkDailyLimit = 12;

  // ─────────────────────────────────────────────
  // [4] 운동 관련
  // ─────────────────────────────────────────────
  /// 걷기 100보당 건강 증가량
  static const double walkHealthPer100Steps = 1.0;

  /// 뛰기 100보당 건강 증가량 (걷기의 2배)
  static const double runHealthPer100Steps = 2.0;

  // ─────────────────────────────────────────────
  // [5] 공부 관련
  // ─────────────────────────────────────────────
  /// 공부 10분당 지혜 증가량
  static const double studyWisdomPer10Min = 5.0;

  /// 공부 10분당 정신력 증가량
  static const double studySpiritPer10Min = 3.0;

  // ─────────────────────────────────────────────
  // [6] 오프라인 하락 관련
  // ─────────────────────────────────────────────
  /// 시간당 포만감 하락량
  static const double fullnessDecreasePerHour = 4.0;

  /// 시간당 애정도 하락량
  static const double affectionDecreasePerHour = 2.0;

  /// 포만감 0일 때 시간당 건강 하락량
  static const double healthDecreasePerHourWhenHungry = 3.0;

  // ─────────────────────────────────────────────
  // [7] 감정 상태 판단 임계값
  // ─────────────────────────────────────────────
  /// 번아웃 판단: 정신력 이 수치 이하
  static const double burnoutThreshold = 20.0;

  /// 배고픔 판단: 포만감 이 수치 이하
  static const double hungryThreshold = 30.0;

  /// 외로움 판단: 애정도 이 수치 이하
  static const double lonelyThreshold = 30.0;

  /// 최상 컨디션 판단: 모든 수치 이 수치 이상
  static const double bestConditionThreshold = 70.0;
}






























