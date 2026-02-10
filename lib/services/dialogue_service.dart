import 'dart:math';

/// 행동 기반 대사 서비스 — 중립/힐링 톤
///
/// "냠냠", "헤헤" 등 유아체 금지.
/// 짧은 문장, 담백한 피드백, 정서적 문장(힐링 톤).
class DialogueService {
  DialogueService._();

  static final _rng = Random();

  /// 행동별 대사 풀
  static const Map<ActionTrigger, List<String>> _pool = {
    ActionTrigger.feed: [
      '기록했어요.',
      '한 걸음 더.',
      '오늘의 작은 실천.',
      '꾸준함이 힘이에요.',
    ],
    ActionTrigger.feedFull: [
      '오늘은 충분해요.',
      '천천히 해도 괜찮아요.',
      '나중에 또.',
    ],
    ActionTrigger.pet: [
      '따뜻한 마음이에요.',
      '그 마음, 전해졌어요.',
      '고마워요.',
      '괜찮아요.',
    ],
    ActionTrigger.checkIn: [
      '오늘도 와줬군요.',
      '여기 있어요.',
      '만나서 반가워요.',
    ],
    ActionTrigger.studyStart: [
      '같이 읽어요.',
      '오늘도 한 페이지.',
      '천천히, 꾸준히.',
    ],
    ActionTrigger.tap: [
      '여기 있어요.',
      '괜찮아요.',
      '잠깐 쉬어가요.',
      '조용한 시간.',
    ],
    ActionTrigger.partnerAmbient: [
      '오늘도 여기 있었어.',
      '조용했지만 비어있진 않았어.',
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
  feed,
  feedFull,
  pet,
  checkIn,
  studyStart,
  tap,
  partnerAmbient,
}
