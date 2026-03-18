import 'package:cloud_firestore/cloud_firestore.dart';

/// 업로드 원본 이력서 파일 모델
/// Firestore 경로: `resumeFiles/{resumeFileId}`
/// Storage 경로: `resumeFiles/{userId}/{resumeFileId}/{fileName}`
class ResumeFile {
  final String id;
  final String userId;
  final String fileName;       // 원본 파일명 (예: 이력서_홍길동.pdf)
  final String displayName;    // 사용자가 지정한 표시 이름
  final ResumeFileType fileType;
  final String mimeType;
  final String storagePath;    // Storage 전체 경로
  final String downloadUrl;    // 공개 다운로드 URL
  final int fileSize;          // bytes
  final String sourcePlatform; // "web" | "app"
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isPrimary;
  final ResumeFileStatus status;
  final String? linkedResumeId; // 연결된 작성형 이력서 ID (선택)

  const ResumeFile({
    required this.id,
    required this.userId,
    required this.fileName,
    required this.displayName,
    required this.fileType,
    required this.mimeType,
    required this.storagePath,
    required this.downloadUrl,
    required this.fileSize,
    this.sourcePlatform = 'web',
    this.createdAt,
    this.updatedAt,
    this.isPrimary = false,
    this.status = ResumeFileStatus.active,
    this.linkedResumeId,
  });

  String get fileSizeLabel {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  bool get canPreviewInApp =>
      fileType == ResumeFileType.pdf ||
      fileType == ResumeFileType.jpg ||
      fileType == ResumeFileType.jpeg ||
      fileType == ResumeFileType.png;

  factory ResumeFile.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ResumeFile(
      id:              doc.id,
      userId:          d['userId'] as String? ?? '',
      fileName:        d['fileName'] as String? ?? '',
      displayName:     d['displayName'] as String? ?? d['fileName'] as String? ?? '',
      fileType:        ResumeFileType.fromString(d['fileType'] as String? ?? ''),
      mimeType:        d['mimeType'] as String? ?? '',
      storagePath:     d['storagePath'] as String? ?? '',
      downloadUrl:     d['downloadUrl'] as String? ?? '',
      fileSize:        (d['fileSize'] as num?)?.toInt() ?? 0,
      sourcePlatform:  d['sourcePlatform'] as String? ?? 'web',
      createdAt:       (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt:       (d['updatedAt'] as Timestamp?)?.toDate(),
      isPrimary:       d['isPrimary'] as bool? ?? false,
      status:          ResumeFileStatus.fromString(d['status'] as String? ?? 'active'),
      linkedResumeId:  d['linkedResumeId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'userId':         userId,
    'fileName':       fileName,
    'displayName':    displayName,
    'fileType':       fileType.value,
    'mimeType':       mimeType,
    'storagePath':    storagePath,
    'downloadUrl':    downloadUrl,
    'fileSize':       fileSize,
    'sourcePlatform': sourcePlatform,
    'createdAt':      FieldValue.serverTimestamp(),
    'updatedAt':      FieldValue.serverTimestamp(),
    'isPrimary':      isPrimary,
    'status':         status.value,
    'linkedResumeId': linkedResumeId,
  };

  ResumeFile copyWith({
    String? displayName,
    bool? isPrimary,
    ResumeFileStatus? status,
    String? linkedResumeId,
  }) => ResumeFile(
    id:             id,
    userId:         userId,
    fileName:       fileName,
    displayName:    displayName ?? this.displayName,
    fileType:       fileType,
    mimeType:       mimeType,
    storagePath:    storagePath,
    downloadUrl:    downloadUrl,
    fileSize:       fileSize,
    sourcePlatform: sourcePlatform,
    createdAt:      createdAt,
    updatedAt:      updatedAt,
    isPrimary:      isPrimary ?? this.isPrimary,
    status:         status ?? this.status,
    linkedResumeId: linkedResumeId ?? this.linkedResumeId,
  );
}

enum ResumeFileType {
  pdf('pdf'),
  jpg('jpg'),
  jpeg('jpeg'),
  png('png'),
  unknown('unknown');

  const ResumeFileType(this.value);
  final String value;

  static ResumeFileType fromString(String v) {
    return ResumeFileType.values.firstWhere(
      (e) => e.value == v.toLowerCase(),
      orElse: () => ResumeFileType.unknown,
    );
  }

  static ResumeFileType fromMime(String mime) {
    switch (mime) {
      case 'application/pdf': return ResumeFileType.pdf;
      case 'image/jpeg':      return ResumeFileType.jpeg;
      case 'image/jpg':       return ResumeFileType.jpg;
      case 'image/png':       return ResumeFileType.png;
      default:                return ResumeFileType.unknown;
    }
  }

  String get label {
    switch (this) {
      case pdf:     return 'PDF';
      case jpg:
      case jpeg:    return 'JPG';
      case png:     return 'PNG';
      case unknown: return '파일';
    }
  }
}

enum ResumeFileStatus {
  active('active'),
  deleted('deleted');

  const ResumeFileStatus(this.value);
  final String value;

  static ResumeFileStatus fromString(String v) =>
      v == 'deleted' ? ResumeFileStatus.deleted : ResumeFileStatus.active;
}
