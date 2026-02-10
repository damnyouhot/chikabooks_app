import 'package:cloud_firestore/cloud_firestore.dart';

/// "오늘의 한 문장" 게시물 모델
class DailyWallPost {
  final String id;
  final DateTime createdAt;
  final String dateKey; // YYYY-MM-DD (KST)
  final String authorUid;
  final AuthorMeta authorMeta;
  final String situationTag;
  final String toneEmoji;
  final String endingKey;
  final String renderedText;
  final String visibility; // "public" 고정
  // 신고 확장 예비 필드
  final bool isHidden;
  final String? hiddenReason;

  const DailyWallPost({
    required this.id,
    required this.createdAt,
    required this.dateKey,
    required this.authorUid,
    required this.authorMeta,
    required this.situationTag,
    required this.toneEmoji,
    required this.endingKey,
    required this.renderedText,
    this.visibility = 'public',
    this.isHidden = false,
    this.hiddenReason,
  });

  factory DailyWallPost.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final ts = d['createdAt'] as Timestamp?;
    final metaRaw = d['authorMeta'] as Map<String, dynamic>? ?? {};

    return DailyWallPost(
      id: doc.id,
      createdAt: ts?.toDate() ?? DateTime.now(),
      dateKey: d['dateKey'] ?? '',
      authorUid: d['authorUid'] ?? '',
      authorMeta: AuthorMeta.fromMap(metaRaw),
      situationTag: d['situationTag'] ?? '',
      toneEmoji: d['toneEmoji'] ?? '',
      endingKey: d['endingKey'] ?? '',
      renderedText: d['renderedText'] ?? '',
      visibility: d['visibility'] ?? 'public',
      isHidden: d['isHidden'] ?? false,
      hiddenReason: d['hiddenReason'],
    );
  }

  Map<String, dynamic> toMap() => {
        'createdAt': FieldValue.serverTimestamp(),
        'dateKey': dateKey,
        'authorUid': authorUid,
        'authorMeta': authorMeta.toMap(),
        'situationTag': situationTag,
        'toneEmoji': toneEmoji,
        'endingKey': endingKey,
        'renderedText': renderedText,
        'visibility': visibility,
        'isHidden': isHidden,
        'hiddenReason': hiddenReason,
      };
}

/// 작성자 메타 — 닉네임/사진 대신 경력·지역 뱃지만 노출
class AuthorMeta {
  final String careerBucket; // "0-2" | "3-5" | "6+"
  final String region; // "서울" | "경기" | ...

  const AuthorMeta({this.careerBucket = '', this.region = ''});

  factory AuthorMeta.fromMap(Map<String, dynamic> m) => AuthorMeta(
        careerBucket: m['careerBucket'] ?? '',
        region: m['region'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'careerBucket': careerBucket,
        'region': region,
      };

  /// UI 표시용 라벨 ("3~5년차 · 경기")
  String get displayLabel {
    final parts = <String>[];
    if (careerBucket.isNotEmpty) {
      parts.add('${careerBucket.replaceAll('-', '~')}년차');
    }
    if (region.isNotEmpty) parts.add(region);
    return parts.isEmpty ? '익명' : parts.join(' · ');
  }
}

/// 리액션 모델 (서브컬렉션 dailyWallPosts/{postId}/reactions/{uid})
class WallReaction {
  final String uid;
  final String reactionKey;
  final DateTime createdAt;

  const WallReaction({
    required this.uid,
    required this.reactionKey,
    required this.createdAt,
  });

  factory WallReaction.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final ts = d['createdAt'] as Timestamp?;
    return WallReaction(
      uid: doc.id,
      reactionKey: d['reactionKey'] ?? '',
      createdAt: ts?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'reactionKey': reactionKey,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

