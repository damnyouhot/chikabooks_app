import 'package:cloud_firestore/cloud_firestore.dart';

class SeniorQuestion {
  final String id;
  final String uid;
  final String authorNickname;
  final String category;
  final bool isAnonymous;
  final String body;
  final List<String> imageUrls;
  final String? stickerId;
  final List<String> stickerIds;
  final int likeCount;
  final int cheerCount;
  final int commentCount;
  final int reportCount;
  final bool isHidden;
  final bool isDeleted;
  final String? hiddenReason;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const SeniorQuestion({
    required this.id,
    required this.uid,
    required this.authorNickname,
    required this.category,
    required this.isAnonymous,
    required this.body,
    required this.imageUrls,
    required this.stickerId,
    required this.stickerIds,
    required this.likeCount,
    required this.cheerCount,
    required this.commentCount,
    required this.reportCount,
    required this.isHidden,
    required this.isDeleted,
    required this.hiddenReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SeniorQuestion.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return SeniorQuestion(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      authorNickname: data['authorNickname'] as String? ?? '',
      category: data['category'] as String? ?? '관계',
      isAnonymous: data['isAnonymous'] as bool? ?? false,
      body: data['body'] as String? ?? '',
      imageUrls: List<String>.from(data['imageUrls'] as List? ?? const []),
      stickerId: _firstStickerId(data),
      stickerIds: _stickerIdsFromData(data),
      likeCount: data['likeCount'] as int? ?? 0,
      cheerCount: data['cheerCount'] as int? ?? 0,
      commentCount: data['commentCount'] as int? ?? 0,
      reportCount: data['reportCount'] as int? ?? 0,
      isHidden: data['isHidden'] as bool? ?? false,
      isDeleted: data['isDeleted'] as bool? ?? false,
      hiddenReason: data['hiddenReason'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  String get displayName {
    if (isAnonymous) return '익명';
    final nickname = authorNickname.trim();
    return nickname.isEmpty ? '익명' : nickname;
  }
}

class SeniorComment {
  final String id;
  final String uid;
  final String authorNickname;
  final bool isAnonymous;
  final String body;
  final List<String> imageUrls;
  final String? stickerId;
  final List<String> stickerIds;
  final int likeCount;
  final int replyCount;
  final int reportCount;
  final bool isHidden;
  final bool isDeleted;
  final String? hiddenReason;
  final DateTime createdAt;

  const SeniorComment({
    required this.id,
    required this.uid,
    required this.authorNickname,
    required this.isAnonymous,
    required this.body,
    required this.imageUrls,
    required this.stickerId,
    required this.stickerIds,
    required this.likeCount,
    required this.replyCount,
    required this.reportCount,
    required this.isHidden,
    required this.isDeleted,
    required this.hiddenReason,
    required this.createdAt,
  });

  factory SeniorComment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return SeniorComment(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      authorNickname: data['authorNickname'] as String? ?? '',
      isAnonymous: data['isAnonymous'] as bool? ?? false,
      body: data['body'] as String? ?? '',
      imageUrls: List<String>.from(data['imageUrls'] as List? ?? const []),
      stickerId: _firstStickerId(data),
      stickerIds: _stickerIdsFromData(data),
      likeCount: data['likeCount'] as int? ?? 0,
      replyCount: data['replyCount'] as int? ?? 0,
      reportCount: data['reportCount'] as int? ?? 0,
      isHidden: data['isHidden'] as bool? ?? false,
      isDeleted: data['isDeleted'] as bool? ?? false,
      hiddenReason: data['hiddenReason'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  String get displayName {
    if (isAnonymous) return '익명';
    final nickname = authorNickname.trim();
    return nickname.isEmpty ? '익명' : nickname;
  }
}

class SeniorReply {
  final String id;
  final String uid;
  final String authorNickname;
  final bool isAnonymous;
  final String body;
  final List<String> imageUrls;
  final String? stickerId;
  final List<String> stickerIds;
  final int likeCount;
  final int reportCount;
  final bool isHidden;
  final bool isDeleted;
  final String? hiddenReason;
  final DateTime createdAt;

  const SeniorReply({
    required this.id,
    required this.uid,
    required this.authorNickname,
    required this.isAnonymous,
    required this.body,
    required this.imageUrls,
    required this.stickerId,
    required this.stickerIds,
    required this.likeCount,
    required this.reportCount,
    required this.isHidden,
    required this.isDeleted,
    required this.hiddenReason,
    required this.createdAt,
  });

  factory SeniorReply.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return SeniorReply(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      authorNickname: data['authorNickname'] as String? ?? '',
      isAnonymous: data['isAnonymous'] as bool? ?? false,
      body: data['body'] as String? ?? '',
      imageUrls: List<String>.from(data['imageUrls'] as List? ?? const []),
      stickerId: _firstStickerId(data),
      stickerIds: _stickerIdsFromData(data),
      likeCount: data['likeCount'] as int? ?? 0,
      reportCount: data['reportCount'] as int? ?? 0,
      isHidden: data['isHidden'] as bool? ?? false,
      isDeleted: data['isDeleted'] as bool? ?? false,
      hiddenReason: data['hiddenReason'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  String get displayName {
    if (isAnonymous) return '익명';
    final nickname = authorNickname.trim();
    return nickname.isEmpty ? '익명' : nickname;
  }
}

List<String> _stickerIdsFromData(Map<String, dynamic> data) {
  final stickerIds =
      (data['stickerIds'] as List?)
          ?.whereType<String>()
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toList(growable: false) ??
      const <String>[];
  if (stickerIds.isNotEmpty) return stickerIds;
  final legacyStickerId = (data['stickerId'] as String?)?.trim();
  if (legacyStickerId == null || legacyStickerId.isEmpty) return const [];
  return [legacyStickerId];
}

String? _firstStickerId(Map<String, dynamic> data) {
  final ids = _stickerIdsFromData(data);
  return ids.isEmpty ? null : ids.first;
}
