/// 반응(리액션) 종류
enum ReactionKind {
  heart,
  thumbsUp,
  clap,
  fire,
  thinking,
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
  }
}
