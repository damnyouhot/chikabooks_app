import 'dart:math';
import '../models/activity_log.dart';

/// 파트너 활동 기반 캐릭터 우회 멘트
///
/// 규칙:
/// - "누가, 누구" 절대 금지
/// - "잘했어/힘내" 같은 진부한 위로 금지
/// - 해석/분위기만 1문장
class PartnerDialogueService {
  PartnerDialogueService._();
  static final _rng = Random();

  /// unread 로그 목록 → 분위기 1문장 (null이면 말할 게 없음)
  static String? generateAmbientLine(List<ActivityLog> allLogs) {
    if (allLogs.isEmpty) return null;

    // 주요 활동 타입별 카운트
    int reactions = 0;
    int slotPosts = 0;
    int knowledge = 0; // ebook + quiz
    int wallPosts = 0;

    for (final log in allLogs) {
      switch (log.type) {
        case ActivityType.slotReaction:
        case ActivityType.cheerReaction:
          reactions++;
          break;
        case ActivityType.slotPost:
          slotPosts++;
          break;
        case ActivityType.ebookRead:
        case ActivityType.quizComplete:
          knowledge++;
          break;
        case ActivityType.wallPost:
        case ActivityType.pollVote:
          wallPosts++;
          break;
        default:
          break;
      }
    }

    // 우선순위: 리액션 많음 > 슬롯 글 > 지식 > 한문장
    if (reactions >= 3) {
      return _pick(_reactionHeavyLines);
    }
    if (slotPosts >= 1) {
      return _pick(_slotPostLines);
    }
    if (knowledge >= 2) {
      return _pick(_knowledgeLines);
    }
    if (wallPosts >= 1) {
      return _pick(_wallPostLines);
    }
    if (reactions >= 1) {
      return _pick(_reactionLightLines);
    }

    // 기본 (활동은 있지만 분류가 어려울 때)
    return _pick(_defaultLines);
  }

  static String _pick(List<String> pool) =>
      pool[_rng.nextInt(pool.length)];

  // ─── 대사 풀 (누가 했는지 절대 언급 안 함) ───

  static const _reactionHeavyLines = [
    '오늘은 말보다, 손이 먼저 닿았어.',
    '조용한 곳에 온기가 묻어 있었어.',
    '눈에 보이지 않는 곳에서 흔들림이 있었어.',
    '누군가의 숨소리가 한 박자 느려진 날.',
  ];

  static const _slotPostLines = [
    '짧은 문장이, 오래 남았어.',
    '오늘, 한 줄이 놓였어.',
    '말이 밖으로 나온 날이야.',
    '숨을 내뱉듯, 문장이 하나 떨어졌어.',
  ];

  static const _knowledgeLines = [
    '결이 조금 또렷해졌어.',
    '알게 되는 건, 느리지만 멈추진 않아.',
    '오늘 한 페이지가 어딘가에 남겠지.',
  ];

  static const _wallPostLines = [
    '벽에 글씨가 하나 적혔어.',
    '오늘의 공기에 문장이 하나 떠 있어.',
  ];

  static const _reactionLightLines = [
    '작은 온기가 오갔어.',
    '손끝이 닿은 흔적이 있어.',
  ];

  static const _defaultLines = [
    '오늘도 여기 있었어.',
    '흐르는 시간 속에, 무언가 있었어.',
    '조용했지만 비어있진 않았어.',
  ];
}



