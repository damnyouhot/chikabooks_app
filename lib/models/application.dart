import 'package:cloud_firestore/cloud_firestore.dart';

/// 지원서 엔티티
/// Firestore 경로: `applications/{applicationId}`
class Application {
  final String id;
  final String jobId;
  final String clinicId;
  final String applicantUid;
  final String resumeId;
  final DateTime? submittedAt;
  final Map<String, dynamic> answers; // 공고별 추가 답변
  final ApplicationVisibility visibilityGranted;
  final ApplicationStatus status;

  const Application({
    required this.id,
    required this.jobId,
    required this.clinicId,
    required this.applicantUid,
    this.resumeId = '',
    this.submittedAt,
    this.answers = const {},
    this.visibilityGranted = const ApplicationVisibility(),
    this.status = ApplicationStatus.submitted,
  });

  factory Application.fromMap(Map<String, dynamic> data,
      {required String id}) {
    return Application(
      id: id,
      jobId: data['jobId'] as String? ?? '',
      clinicId: data['clinicId'] as String? ?? '',
      applicantUid: data['applicantUid'] as String? ?? '',
      resumeId: data['resumeId'] as String? ?? '',
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
      answers: Map<String, dynamic>.from(data['answers'] ?? {}),
      visibilityGranted: ApplicationVisibility.fromMap(
        data['visibilityGranted'] as Map<String, dynamic>? ?? {},
      ),
      status:
          ApplicationStatus.fromString(data['status'] as String? ?? ''),
    );
  }

  factory Application.fromDoc(DocumentSnapshot doc) {
    return Application.fromMap(doc.data() as Map<String, dynamic>, id: doc.id);
  }

  Map<String, dynamic> toMap() => {
        'jobId': jobId,
        'clinicId': clinicId,
        'applicantUid': applicantUid,
        'resumeId': resumeId,
        'submittedAt': FieldValue.serverTimestamp(),
        'answers': answers,
        'visibilityGranted': visibilityGranted.toMap(),
        'status': status.name,
      };
}

/// 연락처 공개 여부
class ApplicationVisibility {
  final bool contactShared;
  final DateTime? sharedAt;

  const ApplicationVisibility({this.contactShared = false, this.sharedAt});

  factory ApplicationVisibility.fromMap(Map<String, dynamic> data) {
    return ApplicationVisibility(
      contactShared: data['contactShared'] as bool? ?? false,
      sharedAt: (data['sharedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'contactShared': contactShared,
        if (sharedAt != null) 'sharedAt': Timestamp.fromDate(sharedAt!),
      };
}

enum ApplicationStatus {
  submitted,
  reviewed,
  contactRequested,
  contactShared,
  rejected,
  withdrawn;

  static ApplicationStatus fromString(String s) {
    switch (s) {
      case 'submitted':
        return ApplicationStatus.submitted;
      case 'reviewed':
        return ApplicationStatus.reviewed;
      case 'contactRequested':
        return ApplicationStatus.contactRequested;
      case 'contactShared':
        return ApplicationStatus.contactShared;
      case 'rejected':
        return ApplicationStatus.rejected;
      case 'withdrawn':
        return ApplicationStatus.withdrawn;
      default:
        return ApplicationStatus.submitted;
    }
  }
}

