import 'job.dart';

/// 게시된 [Job] 스냅샷을 `jobDrafts` 문서 필드 형태로 변환 (복사 → 임시저장용).
///
/// [Job.fromJson]으로 정규화한 뒤 드래프트 스키마에 맞게 옮긴다.
Map<String, dynamic> publishedJobToDraftFormData(Job job) {
  final salary = job.salaryText.trim().isNotEmpty
      ? job.salaryText
      : job.salaryDisplayLine;

  final out = <String, dynamic>{
    'title': job.title,
    'clinicName': job.clinicName,
    'role': job.type,
    'career': job.career,
    'employmentType': job.employmentType,
    'workHours': job.workHours,
    'salary': salary,
    'benefits': List<String>.from(job.benefits),
    'description': job.details,
    'address': job.address,
    'contact': job.contact,
    'imageUrls': List<String>.from(job.images),
    'weekendWork': job.weekendWork,
    'nightShift': job.nightShift,
    'isAlwaysHiring': job.isAlwaysHiring,
    'tags': List<String>.from(job.tags),
  };

  if (job.hospitalType != null) {
    out['hospitalType'] = job.hospitalType;
  }
  if (job.chairCount != null) {
    out['chairCount'] = job.chairCount;
  }
  if (job.staffCount != null) {
    out['staffCount'] = job.staffCount;
  }
  if (job.workDays.isNotEmpty) {
    out['workDays'] = job.workDays;
  }
  if (job.applyMethod.isNotEmpty) {
    out['applyMethod'] = job.applyMethod;
  }
  if (job.closingDate != null) {
    out['closingDate'] = job.closingDate!.toIso8601String();
  }

  final t = job.transportation;
  if (t != null) {
    out['transportation'] = t.toJson();
  } else if (job.subwayLines.isNotEmpty) {
    out['transportation'] = {
      'subwayLines': job.subwayLines,
      'parking': job.hasParking,
    };
  } else if (job.hasParking) {
    out['transportation'] = {
      'parking': job.hasParking,
    };
  }

  if (job.lat != 0 || job.lng != 0) {
    out['lat'] = job.lat;
    out['lng'] = job.lng;
  }

  return out;
}

/// [saveDraft]에 넣을 게시 공고 복사 전용 필드 세트.
Map<String, dynamic> publishedJobCopyDraftFormData(Job job) {
  return {
    ...publishedJobToDraftFormData(job),
    'sourceType': 'copy',
    'copiedFromJobId': job.id,
    'currentStep': 'ai_generated',
    'aiParseStatus': 'done',
    'editorStep': 'step3',
  };
}
