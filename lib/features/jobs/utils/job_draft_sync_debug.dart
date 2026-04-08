import 'package:flutter/foundation.dart';

import '../ui/job_post_form.dart';

/// kDebugMode 전용 — 부모 `_data`·폼·프리뷰 간 값 불일치 원인 추적용.
/// 프로덕션에서는 호출해도 출력 없음.
class JobDraftSyncDebug {
  JobDraftSyncDebug._();

  static void logPipeline(String phase, JobPostData data) {
    if (!kDebugMode) return;
    final desc = data.description.trim().replaceAll(RegExp(r'\s+'), ' ');
    final descPreview = desc.length > 48 ? '${desc.substring(0, 48)}…' : desc;
    final fs = data.fieldStatus;
    final missCount = fs == null || fs.isEmpty
        ? 0
        : fs.values.where((v) => v == 'missing').length;
    final fsSummary = fs == null || fs.isEmpty
        ? 'fs=∅'
        : 'fs=${fs.length} miss=$missCount';
    debugPrint(
      '[DraftSync][$phase] '
      'clinic="${data.clinicName.trim()}" '
      'title="${data.title.trim()}" '
      'addr="${data.address.trim()}" '
      'contact="${data.contact.trim()}" '
      'subway="${data.subwayStationName?.trim() ?? ""}" '
      'salary="${data.salary.trim()}" '
      'desc~="$descPreview" '
      'reqDoc=${data.requiredDocuments.length} '
      'tags=${data.tags.length} userEdited=${data.tagsUserEdited} '
      '$fsSummary',
    );
  }
}
