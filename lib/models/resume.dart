import 'package:cloud_firestore/cloud_firestore.dart';

/// 이력서 엔티티
/// Firestore 경로: `resumes/{resumeId}`
class Resume {
  final String id;
  final String ownerUid;
  final String title;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 공개 설정
  final ResumeVisibility visibility;

  /// 섹션별 데이터
  final ResumeProfile? profile;
  final List<ResumeLicense> licenses;
  final List<ResumeExperience> experiences;
  final List<ResumeSkill> skills;
  final List<ResumeEducation> education;
  final List<ResumeTraining> trainings;
  final List<ResumeAttachment> attachments;

  const Resume({
    required this.id,
    required this.ownerUid,
    this.title = '기본 이력서',
    this.createdAt,
    this.updatedAt,
    this.visibility = const ResumeVisibility(),
    this.profile,
    this.licenses = const [],
    this.experiences = const [],
    this.skills = const [],
    this.education = const [],
    this.trainings = const [],
    this.attachments = const [],
  });

  factory Resume.fromMap(Map<String, dynamic> data, {required String id}) {
    final sections = data['sections'] as Map<String, dynamic>? ?? {};
    return Resume(
      id: id,
      ownerUid: data['ownerUid'] as String? ?? '',
      title: data['title'] as String? ?? '기본 이력서',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      visibility: ResumeVisibility.fromMap(
        data['visibility'] as Map<String, dynamic>? ?? {},
      ),
      profile: sections['profile'] != null
          ? ResumeProfile.fromMap(sections['profile'])
          : null,
      licenses: (sections['licenses'] as List?)
              ?.map((e) => ResumeLicense.fromMap(e))
              .toList() ??
          [],
      experiences: (sections['experiences'] as List?)
              ?.map((e) => ResumeExperience.fromMap(e))
              .toList() ??
          [],
      skills: (sections['skills'] as List?)
              ?.map((e) => ResumeSkill.fromMap(e))
              .toList() ??
          [],
      education: (sections['education'] as List?)
              ?.map((e) => ResumeEducation.fromMap(e))
              .toList() ??
          [],
      trainings: (sections['trainings'] as List?)
              ?.map((e) => ResumeTraining.fromMap(e))
              .toList() ??
          [],
      attachments: (sections['attachments'] as List?)
              ?.map((e) => ResumeAttachment.fromMap(e))
              .toList() ??
          [],
    );
  }

  factory Resume.fromDoc(DocumentSnapshot doc) {
    return Resume.fromMap(doc.data() as Map<String, dynamic>, id: doc.id);
  }

  Map<String, dynamic> toMap() => {
        'ownerUid': ownerUid,
        'title': title,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'visibility': visibility.toMap(),
        'sections': {
          if (profile != null) 'profile': profile!.toMap(),
          'licenses': licenses.map((e) => e.toMap()).toList(),
          'experiences': experiences.map((e) => e.toMap()).toList(),
          'skills': skills.map((e) => e.toMap()).toList(),
          'education': education.map((e) => e.toMap()).toList(),
          'trainings': trainings.map((e) => e.toMap()).toList(),
          'attachments': attachments.map((e) => e.toMap()).toList(),
        },
      };
}

// ── 공개 설정 ────────────────────────────────────────────
class ResumeVisibility {
  final bool defaultAnonymous;
  final Map<String, bool> fieldsMask;

  const ResumeVisibility({
    this.defaultAnonymous = true,
    this.fieldsMask = const {
      'phone': true,
      'email': true,
      'address': true,
      'licenseNumber': true,
    },
  });

  factory ResumeVisibility.fromMap(Map<String, dynamic> data) {
    return ResumeVisibility(
      defaultAnonymous: data['defaultAnonymous'] as bool? ?? true,
      fieldsMask: Map<String, bool>.from(data['fieldsMask'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() => {
        'defaultAnonymous': defaultAnonymous,
        'fieldsMask': fieldsMask,
      };
}

// ── 기본정보 ────────────────────────────────────────────
class ResumeProfile {
  final String name;
  final String phone;
  final String email;
  final String region; // 시/구
  final List<String> workTypes; // 정규, 파트, 주말, 야간, 단기
  final String headline;
  final String summary;

  const ResumeProfile({
    this.name = '',
    this.phone = '',
    this.email = '',
    this.region = '',
    this.workTypes = const [],
    this.headline = '',
    this.summary = '',
  });

  factory ResumeProfile.fromMap(Map<String, dynamic> data) {
    return ResumeProfile(
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      email: data['email'] as String? ?? '',
      region: data['region'] as String? ?? '',
      workTypes: List<String>.from(data['workTypes'] ?? []),
      headline: data['headline'] as String? ?? '',
      summary: data['summary'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'email': email,
        'region': region,
        'workTypes': workTypes,
        'headline': headline,
        'summary': summary,
      };
}

// ── 면허/자격 ────────────────────────────────────────────
class ResumeLicense {
  final String type; // 치과위생사면허, CPR, BLS 등
  final bool has;
  final String? numberMasked;
  final int? issuedYear;

  const ResumeLicense({
    required this.type,
    this.has = false,
    this.numberMasked,
    this.issuedYear,
  });

  factory ResumeLicense.fromMap(Map<String, dynamic> data) {
    return ResumeLicense(
      type: data['type'] as String? ?? '',
      has: data['has'] as bool? ?? false,
      numberMasked: data['numberMasked'] as String?,
      issuedYear: data['issuedYear'] as int?,
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type,
        'has': has,
        if (numberMasked != null) 'numberMasked': numberMasked,
        if (issuedYear != null) 'issuedYear': issuedYear,
      };
}

// ── 경력 ────────────────────────────────────────────────
class ResumeExperience {
  final String clinicName;
  final String region;
  final String start; // YYYY-MM
  final String end; // YYYY-MM or '재직중'
  final List<String> tasks;
  final List<String> tools;
  final String? achievementsText;

  const ResumeExperience({
    required this.clinicName,
    this.region = '',
    this.start = '',
    this.end = '',
    this.tasks = const [],
    this.tools = const [],
    this.achievementsText,
  });

  factory ResumeExperience.fromMap(Map<String, dynamic> data) {
    return ResumeExperience(
      clinicName: data['clinicName'] as String? ?? '',
      region: data['region'] as String? ?? '',
      start: data['start'] as String? ?? '',
      end: data['end'] as String? ?? '',
      tasks: List<String>.from(data['tasks'] ?? []),
      tools: List<String>.from(data['tools'] ?? []),
      achievementsText: data['achievementsText'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'clinicName': clinicName,
        'region': region,
        'start': start,
        'end': end,
        'tasks': tasks,
        'tools': tools,
        if (achievementsText != null) 'achievementsText': achievementsText,
      };
}

// ── 스킬 ────────────────────────────────────────────────
class ResumeSkill {
  final String id;
  final String name;
  final int level; // 1~5

  const ResumeSkill({required this.id, required this.name, this.level = 3});

  factory ResumeSkill.fromMap(Map<String, dynamic> data) {
    return ResumeSkill(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? '',
      level: data['level'] as int? ?? 3,
    );
  }

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'level': level};
}

// ── 학력 ────────────────────────────────────────────────
class ResumeEducation {
  final String school;
  final String major;
  final int? gradYear;

  const ResumeEducation({this.school = '', this.major = '', this.gradYear});

  factory ResumeEducation.fromMap(Map<String, dynamic> data) {
    return ResumeEducation(
      school: data['school'] as String? ?? '',
      major: data['major'] as String? ?? '',
      gradYear: data['gradYear'] as int?,
    );
  }

  Map<String, dynamic> toMap() => {
        'school': school,
        'major': major,
        if (gradYear != null) 'gradYear': gradYear,
      };
}

// ── 보수교육/세미나 ─────────────────────────────────────
class ResumeTraining {
  final String title;
  final String org;
  final int? hours;
  final int? year;
  final String? proofFileRef;

  const ResumeTraining({
    this.title = '',
    this.org = '',
    this.hours,
    this.year,
    this.proofFileRef,
  });

  factory ResumeTraining.fromMap(Map<String, dynamic> data) {
    return ResumeTraining(
      title: data['title'] as String? ?? '',
      org: data['org'] as String? ?? '',
      hours: data['hours'] as int?,
      year: data['year'] as int?,
      proofFileRef: data['proofFileRef'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'org': org,
        if (hours != null) 'hours': hours,
        if (year != null) 'year': year,
        if (proofFileRef != null) 'proofFileRef': proofFileRef,
      };
}

// ── 첨부파일 ────────────────────────────────────────────
class ResumeAttachment {
  final String fileRef; // Storage path or URL
  final String type; // 자격증, 수료증, 경력증명 등
  final String title;

  const ResumeAttachment({
    this.fileRef = '',
    this.type = '',
    this.title = '',
  });

  factory ResumeAttachment.fromMap(Map<String, dynamic> data) {
    return ResumeAttachment(
      fileRef: data['fileRef'] as String? ?? '',
      type: data['type'] as String? ?? '',
      title: data['title'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'fileRef': fileRef,
        'type': type,
        'title': title,
      };
}

