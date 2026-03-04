import 'package:cloud_firestore/cloud_firestore.dart';

/// 이력서 편집 임시저장 드래프트
/// Firestore 경로: `resumeDrafts/{draftId}`
///
/// 이력서 편집 중 자동/수동 임시저장 전용.
/// data 필드에 이력서 전체 구조(Resume와 동일)를 저장.
/// OCR 가져오기 드래프트는 별도 `resumeImportDrafts` 컬렉션 사용.
class ResumeDraft {
  final String id;
  final String ownerUid;

  /// 사용자가 지정한 이력서 제목
  final String title;

  /// 원본 이력서 ID (기존 이력서 편집 시). null이면 새 이력서.
  final String? resumeId;

  /// 이력서 전체 데이터 (Resume.sections 구조)
  final Map<String, dynamic> data;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ResumeDraft({
    required this.id,
    required this.ownerUid,
    this.title = '',
    this.resumeId,
    this.data = const {},
    this.createdAt,
    this.updatedAt,
  });

  factory ResumeDraft.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    return ResumeDraft(
      id: id,
      ownerUid: map['ownerUid'] as String? ?? '',
      title: map['title'] as String? ?? '',
      resumeId: map['resumeId'] as String?,
      data: Map<String, dynamic>.from(map['data'] ?? {}),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory ResumeDraft.fromDoc(DocumentSnapshot doc) {
    return ResumeDraft.fromMap(
      doc.data() as Map<String, dynamic>,
      id: doc.id,
    );
  }

  Map<String, dynamic> toMap() => {
        'ownerUid': ownerUid,
        'title': title,
        if (resumeId != null) 'resumeId': resumeId,
        'data': data,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  ResumeDraft copyWith({
    String? title,
    String? resumeId,
    Map<String, dynamic>? data,
  }) {
    return ResumeDraft(
      id: id,
      ownerUid: ownerUid,
      title: title ?? this.title,
      resumeId: resumeId ?? this.resumeId,
      data: data ?? this.data,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
