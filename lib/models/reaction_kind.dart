/// 반응(리액션) 종류
enum ReactionKind {
  heart,
  thumbsUp,
  clap,
  fire,
  thinking,
  enthrone, // 추대
}

extension ReactionKindExtension on ReactionKind {
  /// 점수 적용 대상 여부
  bool get isScoring => this == ReactionKind.heart;
  
  /// 기본 점수 변화량
  double get baseDelta {
    switch (this) {
      case ReactionKind.heart:
        return 0.3;
      case ReactionKind.enthrone:
        return 0.2;
      default:
        return 0.0;
    }
  }
}

/// 이모지를 ReactionKind로 변환
ReactionKind? reactionKindFromEmoji(String emoji) {
  switch (emoji) {
    case '❤️':
      return ReactionKind.heart;
    case '👍':
      return ReactionKind.thumbsUp;
    case '👏':
      return ReactionKind.clap;
    case '🔥':
      return ReactionKind.fire;
    case '🤔':
      return ReactionKind.thinking;
    case '👑':
      return ReactionKind.enthrone;
    default:
      return null;
  }
}

/// ReactionKind를 이모지로 변환
String reactionKindToEmoji(ReactionKind kind) {
  switch (kind) {
    case ReactionKind.heart:
      return '❤️';
    case ReactionKind.thumbsUp:
      return '👍';
    case ReactionKind.clap:
      return '👏';
    case ReactionKind.fire:
      return '🔥';
    case ReactionKind.thinking:
      return '🤔';
    case ReactionKind.enthrone:
      return '👑';
  }
}
