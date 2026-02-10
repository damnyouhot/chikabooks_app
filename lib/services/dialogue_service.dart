import 'dart:math';

/// 캐릭터 행동 기반 대사 서비스
///
/// 랜덤 타이머가 아닌, 유저의 **행동**에 반응하여 대사를 반환합니다.
/// 사용법:
///   final line = DialogueService.forAction(ActionTrigger.feed);
///   spriteWidgetKey.currentState?.showDialogue(line);
class DialogueService {
  DialogueService._();

  static final _rng = Random();

  /// 행동별 대사 풀
  static const Map<ActionTrigger, List<String>> _pool = {
    ActionTrigger.feed: [
      '냠냠! 맛있어요~ 🍽️',
      '배 부르다~ 고마워요!',
      '최고의 밥이에요! ✨',
      '에너지 충전 완료!',
    ],
    ActionTrigger.feedFull: [
      '배가 너무 불러요… 🫃',
      '더 이상 못 먹겠어요~',
      '나중에 줘요!',
    ],
    ActionTrigger.pet: [
      '기분 좋아요~ 💕',
      '더 쓰다듬어 줘요!',
      '행복해요! 🦄',
      '엄마 손이 따뜻해요~',
    ],
    ActionTrigger.checkIn: [
      '와! 만나서 반가워요!',
      '오늘도 와줬군요~ 🎉',
      '보고 싶었어요!',
    ],
    ActionTrigger.studyStart: [
      '같이 공부해요! 📖',
      '오늘도 성장하는 거예요!',
      '집중! 집중! 🔥',
    ],
    ActionTrigger.tap: [
      '왜요? 뭐 필요해요?',
      '저 여기 있어요~ 👋',
      '같이 놀아요!',
      '헤헤~ 간지러워요!',
    ],
  };

  /// 행동에 맞는 대사 1줄 반환
  static String forAction(ActionTrigger trigger) {
    final lines = _pool[trigger] ?? _pool[ActionTrigger.tap]!;
    return lines[_rng.nextInt(lines.length)];
  }
}

/// 대사를 호출하는 트리거 종류
enum ActionTrigger {
  feed,       // 밥 주기
  feedFull,   // 밥 주기 (포만감 max)
  pet,        // 쓰다듬기
  checkIn,    // 출석 / 확인하기
  studyStart, // 공부 시작
  tap,        // 단순 터치
}

