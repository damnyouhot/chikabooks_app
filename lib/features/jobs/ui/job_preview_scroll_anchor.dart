import 'package:flutter/widgets.dart';

/// 좌측 [JobPostPreview] 스크롤 앵커 — 에디터 포커스·탭과 대응.
enum JobPreviewScrollAnchor {
  basicInfo,
  workConditions,
  hospital,
  benefits,
  apply,
  description,
  addressContact,
}

/// 드래프트 에디터 등에서 앵커별 [GlobalKey] 한 세트.
Map<JobPreviewScrollAnchor, GlobalKey> createJobPreviewSectionKeys() {
  return {
    for (final a in JobPreviewScrollAnchor.values)
      a: GlobalKey(debugLabel: 'job_preview_${a.name}'),
  };
}
