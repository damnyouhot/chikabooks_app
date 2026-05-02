import 'package:animated_emoji/animated_emoji.dart';

class SeniorSticker {
  final String id;
  final String label;
  final SeniorStickerCategory category;
  final SeniorStickerSource source;
  final AnimatedEmojiData? emoji;
  final String? assetPath;
  final String sourceLabel;

  const SeniorSticker({
    required this.id,
    required this.label,
    required this.category,
    this.source = SeniorStickerSource.notoAnimatedEmoji,
    this.emoji,
    this.assetPath,
    this.sourceLabel = 'Noto Animated Emoji',
  });
}

enum SeniorStickerSource { notoAnimatedEmoji, assetSvg }

enum SeniorStickerCategory {
  basic('기본'),
  heart('마음'),
  cheer('응원'),
  emotion('감정'),
  negative('부정감정'),
  reaction('반응'),
  cute('귀여움'),
  event('축하'),
  work('일상·도구'),
  weird('기타');

  final String label;
  const SeniorStickerCategory(this.label);
}

class SeniorStickerPickerGroup {
  final String label;
  final Set<SeniorStickerCategory> categories;

  const SeniorStickerPickerGroup({
    required this.label,
    required this.categories,
  });
}

const seniorStickerPickerGroups = <SeniorStickerPickerGroup>[
  SeniorStickerPickerGroup(
    label: '긍정',
    categories: {
      SeniorStickerCategory.basic,
      SeniorStickerCategory.heart,
      SeniorStickerCategory.cheer,
      SeniorStickerCategory.emotion,
    },
  ),
  SeniorStickerPickerGroup(
    label: '부정감정',
    categories: {SeniorStickerCategory.negative},
  ),
  SeniorStickerPickerGroup(
    label: '반응',
    categories: {SeniorStickerCategory.reaction},
  ),
  SeniorStickerPickerGroup(
    label: '귀여움·축하',
    categories: {SeniorStickerCategory.cute, SeniorStickerCategory.event},
  ),
  SeniorStickerPickerGroup(
    label: '일상·기타',
    categories: {SeniorStickerCategory.work, SeniorStickerCategory.weird},
  ),
];

const seniorStickerFallbackPrefix = '[스티커] ';
const maxSeniorStickersPerEntry = 5;

String seniorStickerFallbackBody(String stickerId) {
  final label = seniorStickerById(stickerId)?.label ?? '스티커';
  return '$seniorStickerFallbackPrefix$label';
}

bool isSeniorStickerFallbackBody(String body, String? stickerId) {
  if (stickerId == null) return false;
  return body.trim() == seniorStickerFallbackBody(stickerId);
}

String seniorStickerFallbackBodyForIds(List<String> stickerIds) {
  if (stickerIds.isEmpty) return seniorStickerFallbackBody('');
  final firstLabel = seniorStickerById(stickerIds.first)?.label ?? '스티커';
  if (stickerIds.length == 1) return '$seniorStickerFallbackPrefix$firstLabel';
  return '$seniorStickerFallbackPrefix$firstLabel 외 ${stickerIds.length - 1}개';
}

bool isSeniorStickerFallbackBodyForIds(String body, List<String> stickerIds) {
  if (stickerIds.isEmpty) return false;
  final trimmed = body.trim();
  return trimmed == seniorStickerFallbackBodyForIds(stickerIds) ||
      (stickerIds.length == 1 &&
          trimmed == seniorStickerFallbackBody(stickerIds.first));
}

const seniorStickerPool = <SeniorSticker>[
  SeniorSticker(
    id: 'basic_smile',
    label: '안녕',
    category: SeniorStickerCategory.basic,
    emoji: AnimatedEmojis.smile,
  ),
  SeniorSticker(
    id: 'basic_thumbs_up',
    label: '좋아요',
    category: SeniorStickerCategory.basic,
    emoji: AnimatedEmojis.thumbsUp,
  ),
  SeniorSticker(
    id: 'basic_clap',
    label: '박수',
    category: SeniorStickerCategory.basic,
    emoji: AnimatedEmojis.clap,
  ),
  SeniorSticker(
    id: 'basic_heart',
    label: '마음',
    category: SeniorStickerCategory.basic,
    emoji: AnimatedEmojis.beatingHeart,
  ),
  SeniorSticker(
    id: 'basic_thinking',
    label: '생각중',
    category: SeniorStickerCategory.basic,
    emoji: AnimatedEmojis.thinkingFace,
  ),
  SeniorSticker(
    id: 'basic_party',
    label: '축하',
    category: SeniorStickerCategory.basic,
    emoji: AnimatedEmojis.partyPopper,
  ),
  SeniorSticker(
    id: 'basic_sparkles',
    label: '반짝',
    category: SeniorStickerCategory.basic,
    emoji: AnimatedEmojis.sparkles,
  ),
  SeniorSticker(
    id: 'basic_crying',
    label: '눈물',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.loudlyCrying,
  ),

  SeniorSticker(
    id: 'warm_smile',
    label: '따뜻한 미소',
    category: SeniorStickerCategory.heart,
    emoji: AnimatedEmojis.warmSmile,
  ),
  SeniorSticker(
    id: 'folded_hands',
    label: '고마워요',
    category: SeniorStickerCategory.heart,
    emoji: AnimatedEmojis.foldedHands,
  ),
  SeniorSticker(
    id: 'heart_face',
    label: '감동',
    category: SeniorStickerCategory.heart,
    emoji: AnimatedEmojis.heartFace,
  ),
  SeniorSticker(
    id: 'heart_eyes',
    label: '반했어요',
    category: SeniorStickerCategory.heart,
    emoji: AnimatedEmojis.heartEyes,
  ),
  SeniorSticker(
    id: 'beating_heart',
    label: '마음',
    category: SeniorStickerCategory.heart,
    emoji: AnimatedEmojis.beatingHeart,
  ),
  SeniorSticker(
    id: 'bandaged_heart',
    label: '토닥토닥',
    category: SeniorStickerCategory.heart,
    emoji: AnimatedEmojis.bandagedHeart,
  ),
  SeniorSticker(
    id: 'two_hearts',
    label: '공감해요',
    category: SeniorStickerCategory.heart,
    emoji: AnimatedEmojis.twoHearts,
  ),
  SeniorSticker(
    id: 'heart_grow',
    label: '커지는 마음',
    category: SeniorStickerCategory.heart,
    emoji: AnimatedEmojis.heartGrow,
  ),
  SeniorSticker(
    id: 'revolving_hearts',
    label: '빙글 마음',
    category: SeniorStickerCategory.heart,
    emoji: AnimatedEmojis.revolvingHearts,
  ),
  SeniorSticker(
    id: 'pink_heart',
    label: '분홍 하트',
    category: SeniorStickerCategory.heart,
    emoji: AnimatedEmojis.pinkHeart,
  ),

  SeniorSticker(
    id: 'muscle',
    label: '힘내요',
    category: SeniorStickerCategory.cheer,
    emoji: AnimatedEmojis.muscle,
  ),
  SeniorSticker(
    id: 'clap',
    label: '박수',
    category: SeniorStickerCategory.cheer,
    emoji: AnimatedEmojis.clap,
  ),
  SeniorSticker(
    id: 'thumbs_up',
    label: '좋아요',
    category: SeniorStickerCategory.cheer,
    emoji: AnimatedEmojis.thumbsUp,
  ),
  SeniorSticker(
    id: 'salute',
    label: '존경해요',
    category: SeniorStickerCategory.cheer,
    emoji: AnimatedEmojis.salute,
  ),
  SeniorSticker(
    id: 'fire',
    label: '불타요',
    category: SeniorStickerCategory.cheer,
    emoji: AnimatedEmojis.fire,
  ),
  SeniorSticker(
    id: 'sparkles',
    label: '반짝',
    category: SeniorStickerCategory.cheer,
    emoji: AnimatedEmojis.sparkles,
  ),
  SeniorSticker(
    id: 'check',
    label: '확인했어요',
    category: SeniorStickerCategory.cheer,
    emoji: AnimatedEmojis.checkMark,
  ),
  SeniorSticker(
    id: 'battery_full',
    label: '충전 완료',
    category: SeniorStickerCategory.cheer,
    emoji: AnimatedEmojis.batteryFull,
  ),
  SeniorSticker(
    id: 'rocket',
    label: '날아가요',
    category: SeniorStickerCategory.cheer,
    emoji: AnimatedEmojis.rocket,
  ),
  SeniorSticker(
    id: 'idea',
    label: '아이디어',
    category: SeniorStickerCategory.cheer,
    emoji: AnimatedEmojis.lightBulb,
  ),

  SeniorSticker(
    id: 'smile',
    label: '미소',
    category: SeniorStickerCategory.emotion,
    emoji: AnimatedEmojis.smile,
  ),
  SeniorSticker(
    id: 'grin',
    label: '방긋',
    category: SeniorStickerCategory.emotion,
    emoji: AnimatedEmojis.grin,
  ),
  SeniorSticker(
    id: 'laughing',
    label: '웃음',
    category: SeniorStickerCategory.emotion,
    emoji: AnimatedEmojis.laughing,
  ),
  SeniorSticker(
    id: 'joy',
    label: '웃겨요',
    category: SeniorStickerCategory.emotion,
    emoji: AnimatedEmojis.joy,
  ),
  SeniorSticker(
    id: 'rofl',
    label: '빵터짐',
    category: SeniorStickerCategory.emotion,
    emoji: AnimatedEmojis.rofl,
  ),
  SeniorSticker(
    id: 'happy_cry',
    label: '감격',
    category: SeniorStickerCategory.emotion,
    emoji: AnimatedEmojis.happyCry,
  ),
  SeniorSticker(
    id: 'holding_back_tears',
    label: '울컥',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.holdingBackTears,
  ),
  SeniorSticker(
    id: 'crying',
    label: '슬퍼요',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.loudlyCrying,
  ),
  SeniorSticker(
    id: 'relieved',
    label: '괜찮아요',
    category: SeniorStickerCategory.emotion,
    emoji: AnimatedEmojis.relieved,
  ),
  SeniorSticker(
    id: 'pleading',
    label: '부탁해요',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.pleading,
  ),
  SeniorSticker(
    id: 'worried',
    label: '걱정돼요',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.worried,
  ),
  SeniorSticker(
    id: 'sweat',
    label: '식은땀',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.sweat,
  ),
  SeniorSticker(
    id: 'sad',
    label: '시무룩',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.sad,
  ),
  SeniorSticker(
    id: 'cry',
    label: '눈물찔끔',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.cry,
  ),
  SeniorSticker(
    id: 'frown',
    label: '속상해요',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.frown,
  ),
  SeniorSticker(
    id: 'pensive',
    label: '우울',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.pensive,
  ),
  SeniorSticker(
    id: 'angry',
    label: '화나요',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.angry,
  ),
  SeniorSticker(
    id: 'rage',
    label: '분노',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.rage,
  ),
  SeniorSticker(
    id: 'triumph',
    label: '씩씩',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.triumph,
  ),
  SeniorSticker(
    id: 'unamused',
    label: '못마땅',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.unamused,
  ),
  SeniorSticker(
    id: 'expressionless',
    label: '무표정',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.expressionless,
  ),
  SeniorSticker(
    id: 'neutral_face',
    label: '할말없음',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.neutralFace,
  ),
  SeniorSticker(
    id: 'grimacing',
    label: '난감',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.grimacing,
  ),
  SeniorSticker(
    id: 'anxious_with_sweat',
    label: '불안',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.anxiousWithSweat,
  ),
  SeniorSticker(
    id: 'weary',
    label: '지쳤어요',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.weary,
  ),
  SeniorSticker(
    id: 'woozy',
    label: '어질어질',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.woozy,
  ),
  SeniorSticker(
    id: 'screaming',
    label: '공포',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.screaming,
  ),
  SeniorSticker(
    id: 'hot_face',
    label: '열받음',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.hotFace,
  ),
  SeniorSticker(
    id: 'cold_face',
    label: '얼어붙음',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.coldFace,
  ),
  SeniorSticker(
    id: 'vomit',
    label: '토할듯',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.vomit,
  ),
  SeniorSticker(
    id: 'mask',
    label: '아파요',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.mask,
  ),
  SeniorSticker(
    id: 'skull',
    label: '끝났다',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.skull,
  ),
  SeniorSticker(
    id: 'smile_with_big_eyes',
    label: '큰눈웃음',
    category: SeniorStickerCategory.emotion,
    emoji: AnimatedEmojis.smileWithBigEyes,
  ),
  SeniorSticker(
    id: 'grinning',
    label: '싱글벙글',
    category: SeniorStickerCategory.emotion,
    emoji: AnimatedEmojis.grinning,
  ),
  SeniorSticker(
    id: 'grin_sweat',
    label: '땀웃음',
    category: SeniorStickerCategory.emotion,
    emoji: AnimatedEmojis.grinSweat,
  ),
  SeniorSticker(
    id: 'wink',
    label: '윙크',
    category: SeniorStickerCategory.emotion,
    emoji: AnimatedEmojis.wink,
  ),
  SeniorSticker(
    id: 'kissing',
    label: '쪽',
    category: SeniorStickerCategory.heart,
    emoji: AnimatedEmojis.kissing,
  ),
  SeniorSticker(
    id: 'kissing_heart',
    label: '하트뽀뽀',
    category: SeniorStickerCategory.heart,
    emoji: AnimatedEmojis.kissingHeart,
  ),
  SeniorSticker(
    id: 'star_struck',
    label: '별눈',
    category: SeniorStickerCategory.emotion,
    emoji: AnimatedEmojis.starStruck,
  ),
  SeniorSticker(
    id: 'partying_face',
    label: '파티얼굴',
    category: SeniorStickerCategory.event,
    emoji: AnimatedEmojis.partyingFace,
  ),
  SeniorSticker(
    id: 'upside_down_face',
    label: '거꾸로',
    category: SeniorStickerCategory.reaction,
    emoji: AnimatedEmojis.upsideDownFace,
  ),
  SeniorSticker(
    id: 'slightly_happy',
    label: '은은미소',
    category: SeniorStickerCategory.emotion,
    emoji: AnimatedEmojis.slightlyHappy,
  ),
  SeniorSticker(
    id: 'blush',
    label: '볼빨개짐',
    category: SeniorStickerCategory.emotion,
    emoji: AnimatedEmojis.blush,
  ),
  SeniorSticker(
    id: 'smirk',
    label: '흐뭇',
    category: SeniorStickerCategory.reaction,
    emoji: AnimatedEmojis.smirk,
  ),
  SeniorSticker(
    id: 'drool',
    label: '침줄줄',
    category: SeniorStickerCategory.reaction,
    emoji: AnimatedEmojis.drool,
  ),
  SeniorSticker(
    id: 'yum',
    label: '맛있다',
    category: SeniorStickerCategory.emotion,
    emoji: AnimatedEmojis.yum,
  ),
  SeniorSticker(
    id: 'stuck_out_tongue',
    label: '메롱',
    category: SeniorStickerCategory.reaction,
    emoji: AnimatedEmojis.stuckOutTongue,
  ),
  SeniorSticker(
    id: 'squinting_tongue',
    label: '찡긋메롱',
    category: SeniorStickerCategory.reaction,
    emoji: AnimatedEmojis.squintingTongue,
  ),
  SeniorSticker(
    id: 'winky_tongue',
    label: '윙크메롱',
    category: SeniorStickerCategory.reaction,
    emoji: AnimatedEmojis.winkyTongue,
  ),
  SeniorSticker(
    id: 'zany_face',
    label: '헤롱장난',
    category: SeniorStickerCategory.weird,
    emoji: AnimatedEmojis.zanyFace,
  ),
  SeniorSticker(
    id: 'mouth_none',
    label: '입없음',
    category: SeniorStickerCategory.reaction,
    emoji: AnimatedEmojis.mouthNone,
  ),
  SeniorSticker(
    id: 'face_in_clouds',
    label: '멍구름',
    category: SeniorStickerCategory.reaction,
    emoji: AnimatedEmojis.faceInClouds,
  ),
  SeniorSticker(
    id: 'dotted_line_face',
    label: '투명인간',
    category: SeniorStickerCategory.weird,
    emoji: AnimatedEmojis.dottedLineFace,
  ),
  SeniorSticker(
    id: 'zipper_face',
    label: '지퍼입',
    category: SeniorStickerCategory.reaction,
    emoji: AnimatedEmojis.zipperFace,
  ),
  SeniorSticker(
    id: 'hug_face',
    label: '안아줘요',
    category: SeniorStickerCategory.heart,
    emoji: AnimatedEmojis.hugFace,
  ),
  SeniorSticker(
    id: 'peeking',
    label: '훔쳐보기',
    category: SeniorStickerCategory.reaction,
    emoji: AnimatedEmojis.peeking,
  ),
  SeniorSticker(
    id: 'raised_eyebrow',
    label: '한쪽눈썹',
    category: SeniorStickerCategory.reaction,
    emoji: AnimatedEmojis.raisedEyebrow,
  ),
  SeniorSticker(
    id: 'rolling_eyes',
    label: '눈굴림',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.rollingEyes,
  ),
  SeniorSticker(
    id: 'exhale',
    label: '후우',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.exhale,
  ),
  SeniorSticker(
    id: 'cursing',
    label: '욕나옴',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.cursing,
  ),
  SeniorSticker(
    id: 'concerned',
    label: '걱정땀',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.concerned,
  ),
  SeniorSticker(
    id: 'big_frown',
    label: '대실망',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.bigFrown,
  ),
  SeniorSticker(
    id: 'diagonal_mouth',
    label: '애매해요',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.diagonalMouth,
  ),
  SeniorSticker(
    id: 'slightly_frowning',
    label: '살짝찡긋',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.slightlyFrowning,
  ),
  SeniorSticker(
    id: 'scared',
    label: '무서워요',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.scared,
  ),
  SeniorSticker(
    id: 'anguished',
    label: '괴로움',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.anguished,
  ),
  SeniorSticker(
    id: 'gasp',
    label: '헉',
    category: SeniorStickerCategory.reaction,
    emoji: AnimatedEmojis.gasp,
  ),
  SeniorSticker(
    id: 'mouth_open',
    label: '입벌림',
    category: SeniorStickerCategory.reaction,
    emoji: AnimatedEmojis.mouthOpen,
  ),
  SeniorSticker(
    id: 'astonished',
    label: '경악',
    category: SeniorStickerCategory.reaction,
    emoji: AnimatedEmojis.astonished,
  ),
  SeniorSticker(
    id: 'flushed',
    label: '당황홍조',
    category: SeniorStickerCategory.reaction,
    emoji: AnimatedEmojis.flushed,
  ),
  SeniorSticker(
    id: 'scrunched_mouth',
    label: '입찌그러짐',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.scrunchedMouth,
  ),
  SeniorSticker(
    id: 'scrunched_eyes',
    label: '눈찌그러짐',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.scrunchedEyes,
  ),
  SeniorSticker(
    id: 'distraught',
    label: '괴로워죽음',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.distraught,
  ),
  SeniorSticker(
    id: 'x_eyes',
    label: 'X눈',
    category: SeniorStickerCategory.weird,
    emoji: AnimatedEmojis.xEyes,
  ),
  SeniorSticker(
    id: 'dizzy_face',
    label: '어지러운얼굴',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.dizzyFace,
  ),
  SeniorSticker(
    id: 'shaking_face',
    label: '덜덜',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.shakingFace,
  ),
  SeniorSticker(
    id: 'sick',
    label: '메스꺼움',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.sick,
  ),
  SeniorSticker(
    id: 'sneeze',
    label: '재채기',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.sneeze,
  ),
  SeniorSticker(
    id: 'thermometer_face',
    label: '열나요',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.thermometerFace,
  ),
  SeniorSticker(
    id: 'bandage_face',
    label: '다쳤어요',
    category: SeniorStickerCategory.negative,
    emoji: AnimatedEmojis.bandageFace,
  ),
  SeniorSticker(
    id: 'liar',
    label: '거짓말코',
    category: SeniorStickerCategory.reaction,
    emoji: AnimatedEmojis.liar,
  ),
  SeniorSticker(
    id: 'halo',
    label: '천사',
    category: SeniorStickerCategory.emotion,
    emoji: AnimatedEmojis.halo,
  ),

  SeniorSticker(
    id: 'thinking',
    label: '생각중',
    category: SeniorStickerCategory.reaction,
    emoji: AnimatedEmojis.thinkingFace,
  ),
  SeniorSticker(
    id: 'monocle',
    label: '살펴봐요',
    category: SeniorStickerCategory.reaction,
    emoji: AnimatedEmojis.monocle,
  ),
  SeniorSticker(
    id: 'eyes',
    label: '봤어요',
    category: SeniorStickerCategory.reaction,
    emoji: AnimatedEmojis.eyes,
  ),
  SeniorSticker(
    id: 'shushing',
    label: '쉿',
    category: SeniorStickerCategory.reaction,
    emoji: AnimatedEmojis.shushingFace,
  ),
  SeniorSticker(
    id: 'hand_over_mouth',
    label: '앗',
    category: SeniorStickerCategory.reaction,
    emoji: AnimatedEmojis.handOverMouth,
  ),
  SeniorSticker(
    id: 'surprised',
    label: '놀랐어요',
    category: SeniorStickerCategory.reaction,
    emoji: AnimatedEmojis.surprised,
  ),
  SeniorSticker(
    id: 'mind_blown',
    label: '대박',
    category: SeniorStickerCategory.reaction,
    emoji: AnimatedEmojis.mindBlown,
  ),
  SeniorSticker(
    id: 'melting',
    label: '녹아요',
    category: SeniorStickerCategory.reaction,
    emoji: AnimatedEmojis.melting,
  ),
  SeniorSticker(
    id: 'yawn',
    label: '하품',
    category: SeniorStickerCategory.reaction,
    emoji: AnimatedEmojis.yawn,
  ),
  SeniorSticker(
    id: 'sleep',
    label: '졸려요',
    category: SeniorStickerCategory.reaction,
    emoji: AnimatedEmojis.sleep,
  ),

  SeniorSticker(
    id: 'dog',
    label: '강아지',
    category: SeniorStickerCategory.cute,
    emoji: AnimatedEmojis.dog,
  ),
  SeniorSticker(
    id: 'baby_chick',
    label: '병아리',
    category: SeniorStickerCategory.cute,
    emoji: AnimatedEmojis.babyChick,
  ),
  SeniorSticker(
    id: 'bird',
    label: '새',
    category: SeniorStickerCategory.cute,
    emoji: AnimatedEmojis.bird,
  ),
  SeniorSticker(
    id: 'rose',
    label: '장미',
    category: SeniorStickerCategory.cute,
    emoji: AnimatedEmojis.rose,
  ),
  SeniorSticker(
    id: 'rainbow',
    label: '무지개',
    category: SeniorStickerCategory.cute,
    emoji: AnimatedEmojis.rainbow,
  ),
  SeniorSticker(
    id: 'red_heart',
    label: '빨간 마음',
    category: SeniorStickerCategory.cute,
    emoji: AnimatedEmojis.redHeart,
  ),
  SeniorSticker(
    id: 'yellow_heart',
    label: '노란 마음',
    category: SeniorStickerCategory.cute,
    emoji: AnimatedEmojis.yellowHeart,
  ),
  SeniorSticker(
    id: 'blue_heart',
    label: '파란 마음',
    category: SeniorStickerCategory.cute,
    emoji: AnimatedEmojis.blueHeart,
  ),

  SeniorSticker(
    id: 'party_popper',
    label: '축하해요',
    category: SeniorStickerCategory.event,
    emoji: AnimatedEmojis.partyPopper,
  ),
  SeniorSticker(
    id: 'balloon',
    label: '풍선',
    category: SeniorStickerCategory.event,
    emoji: AnimatedEmojis.balloon,
  ),
  SeniorSticker(
    id: 'birthday_cake',
    label: '케이크',
    category: SeniorStickerCategory.event,
    emoji: AnimatedEmojis.birthdayCake,
  ),
  SeniorSticker(
    id: 'wrapped_gift',
    label: '선물',
    category: SeniorStickerCategory.event,
    emoji: AnimatedEmojis.wrappedGift,
  ),
  SeniorSticker(
    id: 'fireworks',
    label: '불꽃놀이',
    category: SeniorStickerCategory.event,
    emoji: AnimatedEmojis.fireworks,
  ),
  SeniorSticker(
    id: 'bell',
    label: '알림',
    category: SeniorStickerCategory.event,
    emoji: AnimatedEmojis.bell,
  ),
  SeniorSticker(
    id: 'alarm_clock',
    label: '시간이에요',
    category: SeniorStickerCategory.event,
    emoji: AnimatedEmojis.alarmClock,
  ),
  SeniorSticker(
    id: 'gift_heart',
    label: '마음 선물',
    category: SeniorStickerCategory.event,
    emoji: AnimatedEmojis.giftHeart,
  ),

  SeniorSticker(
    id: 'weird_soul_out',
    label: '영혼 탈출',
    category: SeniorStickerCategory.weird,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/weird_soul_out.svg',
    sourceLabel: 'ChikaBooks Original',
  ),
  SeniorSticker(
    id: 'weird_brain_stop',
    label: '뇌정지',
    category: SeniorStickerCategory.weird,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/weird_brain_stop.svg',
    sourceLabel: 'ChikaBooks Original',
  ),
  SeniorSticker(
    id: 'weird_fake_smile',
    label: '괜찮은 척',
    category: SeniorStickerCategory.weird,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/weird_fake_smile.svg',
    sourceLabel: 'ChikaBooks Original',
  ),
  SeniorSticker(
    id: 'weird_mental_escape',
    label: '멘탈 탈출',
    category: SeniorStickerCategory.weird,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/weird_mental_escape.svg',
    sourceLabel: 'ChikaBooks Original',
  ),
  SeniorSticker(
    id: 'weird_understood',
    label: '이해한 척',
    category: SeniorStickerCategory.weird,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/weird_understood.svg',
    sourceLabel: 'ChikaBooks Original',
  ),
  SeniorSticker(
    id: 'weird_nope',
    label: '어림없지',
    category: SeniorStickerCategory.weird,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/weird_nope.svg',
    sourceLabel: 'ChikaBooks Original',
  ),

  SeniorSticker(
    id: 'work_chart_dizzy',
    label: '차트 현기증',
    category: SeniorStickerCategory.work,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/work_chart_dizzy.svg',
    sourceLabel: 'ChikaBooks Original',
  ),
  SeniorSticker(
    id: 'work_claim_swamp',
    label: '청구의 늪',
    category: SeniorStickerCategory.work,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/work_claim_swamp.svg',
    sourceLabel: 'ChikaBooks Original',
  ),
  SeniorSticker(
    id: 'work_quiz_wrong',
    label: '오답 충격',
    category: SeniorStickerCategory.work,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/work_quiz_wrong.svg',
    sourceLabel: 'ChikaBooks Original',
  ),
  SeniorSticker(
    id: 'work_study_zombie',
    label: '공부 좀비',
    category: SeniorStickerCategory.work,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/work_study_zombie.svg',
    sourceLabel: 'ChikaBooks Original',
  ),
  SeniorSticker(
    id: 'work_shutdown',
    label: '업무 종료',
    category: SeniorStickerCategory.work,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/work_shutdown.svg',
    sourceLabel: 'ChikaBooks Original',
  ),
  SeniorSticker(
    id: 'work_coffee_empty',
    label: '카페인 없음',
    category: SeniorStickerCategory.work,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/work_coffee_empty.svg',
    sourceLabel: 'ChikaBooks Original',
  ),
  SeniorSticker(
    id: 'symbol_book_stack',
    label: '책더미',
    category: SeniorStickerCategory.work,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/symbol_book_stack.svg',
    sourceLabel: 'ChikaBooks Symbol Pack',
  ),
  SeniorSticker(
    id: 'symbol_calendar_check',
    label: '일정 체크',
    category: SeniorStickerCategory.work,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/symbol_calendar_check.svg',
    sourceLabel: 'ChikaBooks Symbol Pack',
  ),
  SeniorSticker(
    id: 'symbol_capsule',
    label: '캡슐',
    category: SeniorStickerCategory.work,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/symbol_capsule.svg',
    sourceLabel: 'ChikaBooks Symbol Pack',
  ),
  SeniorSticker(
    id: 'symbol_warning',
    label: '주의',
    category: SeniorStickerCategory.work,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/symbol_warning.svg',
    sourceLabel: 'ChikaBooks Symbol Pack',
  ),
  SeniorSticker(
    id: 'symbol_trophy',
    label: '달성',
    category: SeniorStickerCategory.work,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/symbol_trophy.svg',
    sourceLabel: 'ChikaBooks Symbol Pack',
  ),
  SeniorSticker(
    id: 'symbol_rain_cloud',
    label: '비구름',
    category: SeniorStickerCategory.work,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/symbol_rain_cloud.svg',
    sourceLabel: 'ChikaBooks Symbol Pack',
  ),
  SeniorSticker(
    id: 'weird_spinner',
    label: '로딩중',
    category: SeniorStickerCategory.weird,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/weird_spinner.svg',
    sourceLabel: 'ChikaBooks Motion Card Pack',
  ),
  SeniorSticker(
    id: 'weird_receipt_bomb',
    label: '영수증 폭탄',
    category: SeniorStickerCategory.weird,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/weird_receipt_bomb.svg',
    sourceLabel: 'ChikaBooks Motion Card Pack',
  ),
  SeniorSticker(
    id: 'weird_paper_airplane',
    label: '날려보냄',
    category: SeniorStickerCategory.weird,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/weird_paper_airplane.svg',
    sourceLabel: 'ChikaBooks Motion Card Pack',
  ),
  SeniorSticker(
    id: 'weird_rubber_duck',
    label: '오리 상담',
    category: SeniorStickerCategory.weird,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/weird_rubber_duck.svg',
    sourceLabel: 'ChikaBooks Motion Card Pack',
  ),
  SeniorSticker(
    id: 'weird_black_hole',
    label: '블랙홀',
    category: SeniorStickerCategory.weird,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/weird_black_hole.svg',
    sourceLabel: 'ChikaBooks Motion Card Pack',
  ),
  SeniorSticker(
    id: 'weird_no_signal',
    label: '신호 없음',
    category: SeniorStickerCategory.weird,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/weird_no_signal.svg',
    sourceLabel: 'ChikaBooks Motion Card Pack',
  ),
  SeniorSticker(
    id: 'emotion_glow_awe',
    label: '눈반짝',
    category: SeniorStickerCategory.emotion,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/emotion_glow_awe.svg',
    sourceLabel: 'ChikaBooks Original',
  ),
  SeniorSticker(
    id: 'emotion_soft_hug',
    label: '포근포옹',
    category: SeniorStickerCategory.emotion,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/emotion_soft_hug.svg',
    sourceLabel: 'ChikaBooks Original',
  ),
  SeniorSticker(
    id: 'emotion_teary_glitter',
    label: '울컥반짝',
    category: SeniorStickerCategory.emotion,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/emotion_teary_glitter.svg',
    sourceLabel: 'ChikaBooks Original',
  ),
  SeniorSticker(
    id: 'reaction_peek',
    label: '몰래봄',
    category: SeniorStickerCategory.reaction,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/reaction_peek.svg',
    sourceLabel: 'ChikaBooks Reaction Pack',
  ),
  SeniorSticker(
    id: 'reaction_suspicious',
    label: '의심중',
    category: SeniorStickerCategory.reaction,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/reaction_suspicious.svg',
    sourceLabel: 'ChikaBooks Reaction Pack',
  ),
  SeniorSticker(
    id: 'reaction_zip',
    label: '입꾹닫',
    category: SeniorStickerCategory.reaction,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/reaction_zip.svg',
    sourceLabel: 'ChikaBooks Reaction Pack',
  ),
  SeniorSticker(
    id: 'reaction_scream',
    label: '비명각',
    category: SeniorStickerCategory.reaction,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/reaction_scream.svg',
    sourceLabel: 'ChikaBooks Reaction Pack',
  ),
  SeniorSticker(
    id: 'reaction_sigh',
    label: '한숨',
    category: SeniorStickerCategory.reaction,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/reaction_sigh.svg',
    sourceLabel: 'ChikaBooks Reaction Pack',
  ),
  SeniorSticker(
    id: 'cute_otter_float',
    label: '수달둥둥',
    category: SeniorStickerCategory.cute,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/cute_otter_float.svg',
    sourceLabel: 'ChikaBooks Cute Pack',
  ),
  SeniorSticker(
    id: 'cute_jellyfish_dream',
    label: '해파리멍',
    category: SeniorStickerCategory.cute,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/cute_jellyfish_dream.svg',
    sourceLabel: 'ChikaBooks Cute Pack',
  ),
  SeniorSticker(
    id: 'cute_frog_blank',
    label: '개구리멍',
    category: SeniorStickerCategory.cute,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/cute_frog_blank.svg',
    sourceLabel: 'ChikaBooks Cute Pack',
  ),
  SeniorSticker(
    id: 'cute_octopus_wave',
    label: '문어인사',
    category: SeniorStickerCategory.cute,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/cute_octopus_wave.svg',
    sourceLabel: 'ChikaBooks Cute Pack',
  ),
  SeniorSticker(
    id: 'work_microbe_alert',
    label: '균주의보',
    category: SeniorStickerCategory.work,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/work_microbe_alert.svg',
    sourceLabel: 'ChikaBooks Work Pack',
  ),
  SeniorSticker(
    id: 'work_mask_mode',
    label: '마스크온',
    category: SeniorStickerCategory.work,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/work_mask_mode.svg',
    sourceLabel: 'ChikaBooks Work Pack',
  ),
  SeniorSticker(
    id: 'work_battery_low',
    label: '방전',
    category: SeniorStickerCategory.work,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/work_battery_low.svg',
    sourceLabel: 'ChikaBooks Work Pack',
  ),
  SeniorSticker(
    id: 'work_money_wings',
    label: '월급순삭',
    category: SeniorStickerCategory.work,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/work_money_wings.svg',
    sourceLabel: 'ChikaBooks Work Pack',
  ),
  SeniorSticker(
    id: 'work_pencil_study',
    label: '필기중',
    category: SeniorStickerCategory.work,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/work_pencil_study.svg',
    sourceLabel: 'ChikaBooks Work Pack',
  ),
  SeniorSticker(
    id: 'work_gear_spin',
    label: '머리회전',
    category: SeniorStickerCategory.work,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/work_gear_spin.svg',
    sourceLabel: 'ChikaBooks Work Pack',
  ),
  SeniorSticker(
    id: 'weird_clown_mode',
    label: '광대모드',
    category: SeniorStickerCategory.weird,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/weird_clown_mode.svg',
    sourceLabel: 'ChikaBooks Weird Pack',
  ),
  SeniorSticker(
    id: 'weird_skull_dead',
    label: '죽겠다',
    category: SeniorStickerCategory.weird,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/weird_skull_dead.svg',
    sourceLabel: 'ChikaBooks Weird Pack',
  ),
  SeniorSticker(
    id: 'weird_alien_signal',
    label: '외계신호',
    category: SeniorStickerCategory.weird,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/weird_alien_signal.svg',
    sourceLabel: 'ChikaBooks Weird Pack',
  ),
  SeniorSticker(
    id: 'weird_cockroach_panic',
    label: '바퀴출몰',
    category: SeniorStickerCategory.weird,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/weird_cockroach_panic.svg',
    sourceLabel: 'ChikaBooks Weird Pack',
  ),
  SeniorSticker(
    id: 'weird_worm_loading',
    label: '꿈틀로딩',
    category: SeniorStickerCategory.weird,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/weird_worm_loading.svg',
    sourceLabel: 'ChikaBooks Weird Pack',
  ),
  SeniorSticker(
    id: 'twemoji_clown',
    label: '광대',
    category: SeniorStickerCategory.weird,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/twemoji/twemoji_clown.svg',
    sourceLabel: 'Twemoji CC-BY 4.0',
  ),
  SeniorSticker(
    id: 'twemoji_alien',
    label: '외계인',
    category: SeniorStickerCategory.weird,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/twemoji/twemoji_alien.svg',
    sourceLabel: 'Twemoji CC-BY 4.0',
  ),
  SeniorSticker(
    id: 'twemoji_robot',
    label: '로봇',
    category: SeniorStickerCategory.reaction,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/twemoji/twemoji_robot.svg',
    sourceLabel: 'Twemoji CC-BY 4.0',
  ),
  SeniorSticker(
    id: 'twemoji_ghost',
    label: '유령',
    category: SeniorStickerCategory.weird,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/twemoji/twemoji_ghost.svg',
    sourceLabel: 'Twemoji CC-BY 4.0',
  ),
  SeniorSticker(
    id: 'twemoji_skull',
    label: '해골',
    category: SeniorStickerCategory.weird,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/twemoji/twemoji_skull.svg',
    sourceLabel: 'Twemoji CC-BY 4.0',
  ),
  SeniorSticker(
    id: 'twemoji_unicorn',
    label: '유니콘',
    category: SeniorStickerCategory.cute,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/twemoji/twemoji_unicorn.svg',
    sourceLabel: 'Twemoji CC-BY 4.0',
  ),
  SeniorSticker(
    id: 'twemoji_otter',
    label: '수달',
    category: SeniorStickerCategory.cute,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/twemoji/twemoji_otter.svg',
    sourceLabel: 'Twemoji CC-BY 4.0',
  ),
  SeniorSticker(
    id: 'twemoji_crystal_ball',
    label: '수정구슬',
    category: SeniorStickerCategory.reaction,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/twemoji/twemoji_crystal_ball.svg',
    sourceLabel: 'Twemoji CC-BY 4.0',
  ),
  SeniorSticker(
    id: 'twemoji_gem',
    label: '보석',
    category: SeniorStickerCategory.cheer,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/twemoji/twemoji_gem.svg',
    sourceLabel: 'Twemoji CC-BY 4.0',
  ),
  SeniorSticker(
    id: 'twemoji_flying_saucer',
    label: '비행접시',
    category: SeniorStickerCategory.weird,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/twemoji/twemoji_flying_saucer.svg',
    sourceLabel: 'Twemoji CC-BY 4.0',
  ),
  SeniorSticker(
    id: 'twemoji_syringe',
    label: '주사기',
    category: SeniorStickerCategory.work,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/twemoji/twemoji_syringe.svg',
    sourceLabel: 'Twemoji CC-BY 4.0',
  ),
  SeniorSticker(
    id: 'twemoji_tooth',
    label: '치아',
    category: SeniorStickerCategory.work,
    source: SeniorStickerSource.assetSvg,
    assetPath: 'assets/stickers/twemoji/twemoji_tooth.svg',
    sourceLabel: 'Twemoji CC-BY 4.0',
  ),
  SeniorSticker(
    id: 'nature_fallen_leaf',
    label: '낙엽',
    category: SeniorStickerCategory.work,
    emoji: AnimatedEmojis.fallenLeaf,
  ),
  SeniorSticker(
    id: 'nature_plant',
    label: '새싹',
    category: SeniorStickerCategory.work,
    emoji: AnimatedEmojis.plant,
  ),
  SeniorSticker(
    id: 'nature_leaves',
    label: '잎사귀',
    category: SeniorStickerCategory.work,
    emoji: AnimatedEmojis.leaves,
  ),
  SeniorSticker(
    id: 'nature_luck',
    label: '행운',
    category: SeniorStickerCategory.cheer,
    emoji: AnimatedEmojis.luck,
  ),
  SeniorSticker(
    id: 'nature_snowflake',
    label: '눈송이',
    category: SeniorStickerCategory.work,
    emoji: AnimatedEmojis.snowflake,
  ),
  SeniorSticker(
    id: 'nature_volcano',
    label: '화산',
    category: SeniorStickerCategory.weird,
    emoji: AnimatedEmojis.volcano,
  ),
  SeniorSticker(
    id: 'nature_sunrise',
    label: '해돋이',
    category: SeniorStickerCategory.work,
    emoji: AnimatedEmojis.sunrise,
  ),
  SeniorSticker(
    id: 'nature_bubbles',
    label: '방울',
    category: SeniorStickerCategory.work,
    emoji: AnimatedEmojis.bubbles,
  ),
  SeniorSticker(
    id: 'nature_ocean',
    label: '파도',
    category: SeniorStickerCategory.work,
    emoji: AnimatedEmojis.ocean,
  ),
  SeniorSticker(
    id: 'nature_wind_face',
    label: '바람',
    category: SeniorStickerCategory.work,
    emoji: AnimatedEmojis.windFace,
  ),
  SeniorSticker(
    id: 'nature_tornado',
    label: '토네이도',
    category: SeniorStickerCategory.weird,
    emoji: AnimatedEmojis.tornado,
  ),
  SeniorSticker(
    id: 'nature_electricity',
    label: '번개',
    category: SeniorStickerCategory.reaction,
    emoji: AnimatedEmojis.electricity,
  ),
  SeniorSticker(
    id: 'nature_droplet',
    label: '물방울',
    category: SeniorStickerCategory.work,
    emoji: AnimatedEmojis.droplet,
  ),
  SeniorSticker(
    id: 'nature_rain_cloud',
    label: '비구름',
    category: SeniorStickerCategory.work,
    emoji: AnimatedEmojis.rainCloud,
  ),
  SeniorSticker(
    id: 'nature_cloud_lightning',
    label: '먹구름',
    category: SeniorStickerCategory.reaction,
    emoji: AnimatedEmojis.cloudWithLightning,
  ),
  SeniorSticker(
    id: 'space_comet',
    label: '혜성',
    category: SeniorStickerCategory.weird,
    emoji: AnimatedEmojis.comet,
  ),
  SeniorSticker(
    id: 'space_globe_asia',
    label: '지구',
    category: SeniorStickerCategory.work,
    emoji: AnimatedEmojis.globeShowingAsiaAustralia,
  ),
  SeniorSticker(
    id: 'animal_cow_face',
    label: '소',
    category: SeniorStickerCategory.cute,
    emoji: AnimatedEmojis.cowFace,
  ),
  SeniorSticker(
    id: 'animal_lizard',
    label: '도마뱀',
    category: SeniorStickerCategory.weird,
    emoji: AnimatedEmojis.lizard,
  ),
  SeniorSticker(
    id: 'animal_dragon',
    label: '용',
    category: SeniorStickerCategory.weird,
    emoji: AnimatedEmojis.dragon,
  ),
  SeniorSticker(
    id: 'animal_t_rex',
    label: '티라노',
    category: SeniorStickerCategory.weird,
    emoji: AnimatedEmojis.tRex,
  ),
  SeniorSticker(
    id: 'animal_dinosaur',
    label: '공룡',
    category: SeniorStickerCategory.weird,
    emoji: AnimatedEmojis.dinosaur,
  ),
  SeniorSticker(
    id: 'animal_turtle',
    label: '거북이',
    category: SeniorStickerCategory.cute,
    emoji: AnimatedEmojis.turtle,
  ),
  SeniorSticker(
    id: 'animal_crocodile',
    label: '악어',
    category: SeniorStickerCategory.weird,
    emoji: AnimatedEmojis.crocodile,
  ),
  SeniorSticker(
    id: 'animal_snake',
    label: '뱀',
    category: SeniorStickerCategory.weird,
    emoji: AnimatedEmojis.snake,
  ),
  SeniorSticker(
    id: 'animal_frog',
    label: '개구리',
    category: SeniorStickerCategory.cute,
    emoji: AnimatedEmojis.frog,
  ),
  SeniorSticker(
    id: 'animal_rabbit',
    label: '토끼',
    category: SeniorStickerCategory.cute,
    emoji: AnimatedEmojis.rabbit,
  ),
  SeniorSticker(
    id: 'animal_rat',
    label: '쥐',
    category: SeniorStickerCategory.weird,
    emoji: AnimatedEmojis.rat,
  ),
  SeniorSticker(
    id: 'animal_pig',
    label: '돼지',
    category: SeniorStickerCategory.cute,
    emoji: AnimatedEmojis.pig,
  ),
  SeniorSticker(
    id: 'animal_donkey',
    label: '당나귀',
    category: SeniorStickerCategory.cute,
    emoji: AnimatedEmojis.donkey,
  ),
  SeniorSticker(
    id: 'animal_kangaroo',
    label: '캥거루',
    category: SeniorStickerCategory.cute,
    emoji: AnimatedEmojis.kangaroo,
  ),
  SeniorSticker(
    id: 'animal_tiger',
    label: '호랑이',
    category: SeniorStickerCategory.cute,
    emoji: AnimatedEmojis.tiger,
  ),
  SeniorSticker(
    id: 'animal_monkey',
    label: '원숭이',
    category: SeniorStickerCategory.cute,
    emoji: AnimatedEmojis.monkey,
  ),
  SeniorSticker(
    id: 'animal_gorilla',
    label: '고릴라',
    category: SeniorStickerCategory.weird,
    emoji: AnimatedEmojis.gorilla,
  ),
  SeniorSticker(
    id: 'animal_otter',
    label: '수달',
    category: SeniorStickerCategory.cute,
    emoji: AnimatedEmojis.otter,
  ),
  SeniorSticker(
    id: 'animal_bat',
    label: '박쥐',
    category: SeniorStickerCategory.weird,
    emoji: AnimatedEmojis.bat,
  ),
  SeniorSticker(
    id: 'animal_black_bird',
    label: '까마귀',
    category: SeniorStickerCategory.weird,
    emoji: AnimatedEmojis.blackBird,
  ),
  SeniorSticker(
    id: 'animal_rooster',
    label: '수탉',
    category: SeniorStickerCategory.cute,
    emoji: AnimatedEmojis.rooster,
  ),
  SeniorSticker(
    id: 'animal_hatching_chick',
    label: '부화중',
    category: SeniorStickerCategory.cute,
    emoji: AnimatedEmojis.hatchingChick,
  ),
  SeniorSticker(
    id: 'animal_goose',
    label: '거위',
    category: SeniorStickerCategory.cute,
    emoji: AnimatedEmojis.goose,
  ),
  SeniorSticker(
    id: 'animal_peacock',
    label: '공작',
    category: SeniorStickerCategory.cute,
    emoji: AnimatedEmojis.peacock,
  ),
  SeniorSticker(
    id: 'animal_seal',
    label: '물범',
    category: SeniorStickerCategory.cute,
    emoji: AnimatedEmojis.seal,
  ),
  SeniorSticker(
    id: 'animal_shark',
    label: '상어',
    category: SeniorStickerCategory.weird,
    emoji: AnimatedEmojis.shark,
  ),
  SeniorSticker(
    id: 'animal_dolphin',
    label: '돌고래',
    category: SeniorStickerCategory.cute,
    emoji: AnimatedEmojis.dolphin,
  ),
  SeniorSticker(
    id: 'animal_whale',
    label: '고래',
    category: SeniorStickerCategory.cute,
    emoji: AnimatedEmojis.whale,
  ),
  SeniorSticker(
    id: 'animal_blowfish',
    label: '복어',
    category: SeniorStickerCategory.weird,
    emoji: AnimatedEmojis.blowfish,
  ),
  SeniorSticker(
    id: 'animal_crab',
    label: '게',
    category: SeniorStickerCategory.cute,
    emoji: AnimatedEmojis.crab,
  ),
  SeniorSticker(
    id: 'animal_octopus',
    label: '문어',
    category: SeniorStickerCategory.weird,
    emoji: AnimatedEmojis.octopus,
  ),
  SeniorSticker(
    id: 'animal_jellyfish',
    label: '해파리',
    category: SeniorStickerCategory.weird,
    emoji: AnimatedEmojis.jellyfish,
  ),
  SeniorSticker(
    id: 'animal_cockroach',
    label: '바퀴',
    category: SeniorStickerCategory.weird,
    emoji: AnimatedEmojis.cockroach,
  ),
];

List<SeniorSticker> seniorStickersForCategory(SeniorStickerCategory category) {
  final categories = switch (category) {
    SeniorStickerCategory.emotion => {
      SeniorStickerCategory.emotion,
      SeniorStickerCategory.heart,
    },
    SeniorStickerCategory.reaction => {
      SeniorStickerCategory.reaction,
      SeniorStickerCategory.cute,
    },
    SeniorStickerCategory.work => {
      SeniorStickerCategory.work,
      SeniorStickerCategory.event,
    },
    _ => {category},
  };
  return seniorStickerPool
      .where((sticker) => categories.contains(sticker.category))
      .toList(growable: false);
}

List<SeniorSticker> seniorStickersForPickerGroup(
  SeniorStickerPickerGroup group,
) {
  return seniorStickerPool
      .where((sticker) => group.categories.contains(sticker.category))
      .toList(growable: false);
}

SeniorSticker? seniorStickerById(String? id) {
  if (id == null || id.trim().isEmpty) return null;
  for (final sticker in seniorStickerPool) {
    if (sticker.id == id) return sticker;
  }
  return null;
}
