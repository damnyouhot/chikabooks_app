import 'package:cloud_firestore/cloud_firestore.dart';

/// OCR 이력서 가져오기 드래프트
/// Firestore 경로: `resumeImportDrafts/{draftId}`
///
/// 사진/캡처 → OCR 추출 → 검수 → 이력서 반영 전용
/// (편집 임시저장은 별도 `resumeDrafts` 컬렉션 사용)
class ResumeImportDraft {
  final String id;
  final String ownerUid;
  final List<ImportDraftSourceImage> sourceImages;
  final String extractedText;
  final Map<String, dynamic> suggestedFields;
  final Map<String, double> confidence;
  final bool autoDeleteOriginal;
  final ImportDraftStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ResumeImportDraft({
    required this.id,
    required this.ownerUid,
    this.sourceImages = const [],
    this.extractedText = '',
    this.suggestedFields = const {},
    this.confidence = const {},
    this.autoDeleteOriginal = true,
    this.status = ImportDraftStatus.processing,
    this.createdAt,
    this.updatedAt,
  });

  factory ResumeImportDraft.fromMap(
    Map<String, dynamic> data, {
    required String id,
  }) {
    return ResumeImportDraft(
      id: id,
      ownerUid: data['ownerUid'] as String? ?? '',
      sourceImages: (data['sourceImages'] as List?)
              ?.map((e) => ImportDraftSourceImage.fromMap(e))
              .toList() ??
          [],
      extractedText: data['extractedText'] as String? ?? '',
      suggestedFields:
          Map<String, dynamic>.from(data['suggestedFields'] ?? {}),
      confidence: Map<String, double>.from(
        (data['confidence'] as Map?)?.map(
              (k, v) => MapEntry(k as String, (v as num).toDouble()),
            ) ??
            {},
      ),
      autoDeleteOriginal: data['autoDeleteOriginal'] as bool? ?? true,
      status: ImportDraftStatus.fromString(data['status'] as String? ?? ''),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory ResumeImportDraft.fromDoc(DocumentSnapshot doc) {
    return ResumeImportDraft.fromMap(
      doc.data() as Map<String, dynamic>,
      id: doc.id,
    );
  }

  Map<String, dynamic> toMap() => {
        'ownerUid': ownerUid,
        'sourceImages': sourceImages.map((e) => e.toMap()).toList(),
        'extractedText': extractedText,
        'suggestedFields': suggestedFields,
        'confidence': confidence,
        'autoDeleteOriginal': autoDeleteOriginal,
        'status': status.name,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

enum ImportDraftStatus {
  processing,
  ready,
  confirmed,
  failed;

  static ImportDraftStatus fromString(String s) {
    switch (s) {
      case 'processing':
        return ImportDraftStatus.processing;
      case 'ready':
        return ImportDraftStatus.ready;
      case 'confirmed':
        return ImportDraftStatus.confirmed;
      case 'failed':
        return ImportDraftStatus.failed;
      default:
        return ImportDraftStatus.processing;
    }
  }
}

class ImportDraftSourceImage {
  final String storagePath;
  final int page;

  const ImportDraftSourceImage({required this.storagePath, this.page = 0});

  factory ImportDraftSourceImage.fromMap(Map<String, dynamic> data) {
    return ImportDraftSourceImage(
      storagePath: data['storagePath'] as String? ?? '',
      page: data['page'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {'storagePath': storagePath, 'page': page};
}

