import 'package:cloud_firestore/cloud_firestore.dart';

/// OCR 드래프트 엔티티
/// Firestore 경로: `resumeDrafts/{draftId}`
class ResumeDraft {
  final String id;
  final String ownerUid;
  final List<DraftSourceImage> sourceImages;
  final String extractedText;
  final Map<String, dynamic> suggestedFields;
  final Map<String, double> confidence;
  final bool autoDeleteOriginal;
  final ResumeDraftStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ResumeDraft({
    required this.id,
    required this.ownerUid,
    this.sourceImages = const [],
    this.extractedText = '',
    this.suggestedFields = const {},
    this.confidence = const {},
    this.autoDeleteOriginal = true,
    this.status = ResumeDraftStatus.processing,
    this.createdAt,
    this.updatedAt,
  });

  factory ResumeDraft.fromMap(Map<String, dynamic> data, {required String id}) {
    return ResumeDraft(
      id: id,
      ownerUid: data['ownerUid'] as String? ?? '',
      sourceImages: (data['sourceImages'] as List?)
              ?.map((e) => DraftSourceImage.fromMap(e))
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
      status: ResumeDraftStatus.fromString(data['status'] as String? ?? ''),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory ResumeDraft.fromDoc(DocumentSnapshot doc) {
    return ResumeDraft.fromMap(doc.data() as Map<String, dynamic>, id: doc.id);
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

enum ResumeDraftStatus {
  processing,
  ready,
  confirmed,
  failed;

  static ResumeDraftStatus fromString(String s) {
    switch (s) {
      case 'processing':
        return ResumeDraftStatus.processing;
      case 'ready':
        return ResumeDraftStatus.ready;
      case 'confirmed':
        return ResumeDraftStatus.confirmed;
      case 'failed':
        return ResumeDraftStatus.failed;
      default:
        return ResumeDraftStatus.processing;
    }
  }
}

class DraftSourceImage {
  final String storagePath;
  final int page;

  const DraftSourceImage({required this.storagePath, this.page = 0});

  factory DraftSourceImage.fromMap(Map<String, dynamic> data) {
    return DraftSourceImage(
      storagePath: data['storagePath'] as String? ?? '',
      page: data['page'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {'storagePath': storagePath, 'page': page};
}

