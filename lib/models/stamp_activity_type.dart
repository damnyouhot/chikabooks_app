/// 스탬프 활동 타입
/// 
/// 각 활동은 일정 조건 충족 시 1칸의 스탬프를 획득합니다.
enum StampActivityType {
  /// 공감투표 참여 1회 = 1칸
  empathyVote('poll_vote'),
  
  /// 오늘을 나누기 글 작성 1회 = 1칸
  bondPost('sentence_write'),
  
  /// 오늘의 한 문장 글 작성 1회 = 1칸
  dailyWallPost('daily_wall_write'),
  
  /// 목표 체크인 1회 = 1칸
  goalCheck('goal_check'),
  
  /// 리액션 3회 누적 = 1칸 (스팸 방지)
  reactionBatch('sentence_reaction');

  const StampActivityType(this.value);
  final String value;

  /// Cloud Function에 전달할 activityType 문자열
  String toActivityType() => value;

  static StampActivityType? fromString(String value) {
    switch (value) {
      case 'poll_vote':
        return StampActivityType.empathyVote;
      case 'sentence_write':
        return StampActivityType.bondPost;
      case 'daily_wall_write':
        return StampActivityType.dailyWallPost;
      case 'goal_check':
        return StampActivityType.goalCheck;
      case 'sentence_reaction':
        return StampActivityType.reactionBatch;
      default:
        return null;
    }
  }
}

/// 일일 스탬프 제한
class StampLimits {
  /// 1인당 하루 최대 스탬프 기여 (악용 방지)
  static const int maxDailyStampsPerUser = 2;

  /// 주간 총 스탬프 칸 수
  static const int weeklyTotalStamps = 7;

  /// 리액션 누적 기준 (3회 = 1칸)
  static const int reactionsPerStamp = 3;
}









