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

  // [7] 스탯 증감량
  static const double feedHungerIncrease = 0.2;
  static const double feedAffectionIncrease = 0.05;
  static const double petAffectionIncrease = 0.02;
  static const double restFatigueDecrease = 0.2;
  static const double restSleepIncrease = 0.5;
}
