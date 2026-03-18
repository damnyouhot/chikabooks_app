import 'package:cloud_firestore/cloud_firestore.dart';

/// 피드백 유형
enum FeedbackType {
  improvement('improvement', '개선 제안'),
  positive('positive', '좋았던 점');

  const FeedbackType(this.value, this.label);
  final String value;
  final String label;

  static FeedbackType fromValue(String v) =>
      FeedbackType.values.firstWhere((e) => e.value == v,
          orElse: () => FeedbackType.improvement);
}

/// 피드백 중요도
enum FeedbackPriority {
  high('high', '높음'),
  medium('medium', '보통'),
  low('low', '낮음');

  const FeedbackPriority(this.value, this.label);
  final String value;
  final String label;

  static FeedbackPriority fromValue(String v) =>
      FeedbackPriority.values.firstWhere((e) => e.value == v,
          orElse: () => FeedbackPriority.medium);
}

/// 피드백 공개 여부
enum FeedbackVisibility {
  public('public', '공개'),
  private('private', '비공개 (작성자/관리자만)');

  const FeedbackVisibility(this.value, this.label);
  final String value;
  final String label;

  static FeedbackVisibility fromValue(String v) =>
      FeedbackVisibility.values.firstWhere((e) => e.value == v,
          orElse: () => FeedbackVisibility.public);
}

/// 관리자 처리 상태
enum FeedbackAdminStatus {
  pending('pending', '미처리'),
  reviewing('reviewing', '검토중'),
  done('done', '처리완료');

  const FeedbackAdminStatus(this.value, this.label);
  final String value;
  final String label;

  static FeedbackAdminStatus fromValue(String v) =>
      FeedbackAdminStatus.values.firstWhere((e) => e.value == v,
          orElse: () => FeedbackAdminStatus.pending);
}

/// 피드백 게시글 모델
class FeedbackPost {
  final String id;
  final String uid;
  final String authNickname;   // Firebase Auth displayName (자동)
  final String displayName;    // 사용자 직접 입력 식별명
  final FeedbackType type;
  final FeedbackPriority priority;
  final FeedbackVisibility visibility;
  final String text;
  final List<String> imageUrls;
  final String appVersion;
  final String sourceRoute;
  final String sourceScreenLabel;
  final FeedbackAdminStatus adminStatus;
  final DateTime createdAt;
  final int commentCount;

  const FeedbackPost({
    required this.id,
    required this.uid,
    required this.authNickname,
    required this.displayName,
    required this.type,
    required this.priority,
    required this.visibility,
    required this.text,
    required this.imageUrls,
    required this.appVersion,
    required this.sourceRoute,
    required this.sourceScreenLabel,
    required this.adminStatus,
    required this.createdAt,
    this.commentCount = 0,
  });

  factory FeedbackPost.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return FeedbackPost(
      id: doc.id,
      uid: d['uid'] as String? ?? '',
      authNickname: d['authNickname'] as String? ?? '',
      displayName: d['displayName'] as String? ?? '',
      type: FeedbackType.fromValue(d['type'] as String? ?? ''),
      priority: FeedbackPriority.fromValue(d['priority'] as String? ?? ''),
      visibility: FeedbackVisibility.fromValue(d['visibility'] as String? ?? ''),
      text: d['text'] as String? ?? '',
      imageUrls: List<String>.from(d['imageUrls'] as List? ?? []),
      appVersion: d['appVersion'] as String? ?? '',
      sourceRoute: d['sourceRoute'] as String? ?? '',
      sourceScreenLabel: d['sourceScreenLabel'] as String? ?? '',
      adminStatus: FeedbackAdminStatus.fromValue(d['adminStatus'] as String? ?? ''),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      commentCount: d['commentCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'authNickname': authNickname,
    'displayName': displayName,
    'type': type.value,
    'priority': priority.value,
    'visibility': visibility.value,
    'text': text,
    'imageUrls': imageUrls,
    'appVersion': appVersion,
    'sourceRoute': sourceRoute,
    'sourceScreenLabel': sourceScreenLabel,
    'adminStatus': adminStatus.value,
    'createdAt': FieldValue.serverTimestamp(),
    'commentCount': 0,
  };
}

/// 피드백 댓글 모델
class FeedbackComment {
  final String id;
  final String uid;
  final String authNickname;
  final String displayName;
  final String text;
  final DateTime createdAt;

  const FeedbackComment({
    required this.id,
    required this.uid,
    required this.authNickname,
    required this.displayName,
    required this.text,
    required this.createdAt,
  });

  factory FeedbackComment.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return FeedbackComment(
      id: doc.id,
      uid: d['uid'] as String? ?? '',
      authNickname: d['authNickname'] as String? ?? '',
      displayName: d['displayName'] as String? ?? '',
      text: d['text'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'authNickname': authNickname,
    'displayName': displayName,
    'text': text,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
